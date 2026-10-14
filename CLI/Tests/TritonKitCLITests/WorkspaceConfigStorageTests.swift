import Darwin
import Foundation
import Testing
@testable import TritonKitCLI

@Suite("Workspace managed config storage")
struct WorkspaceConfigStorageTests {
    @Test("save creates private config and preserves exact previous bytes before replacement")
    func privateSaveAndRawBackup() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = Data("{ \"value\" : 1 }\n".utf8)
        let updated = Data("{\"value\":2}".utf8)
        let store = try HostWorkspaceConfigStorage(workspace: root.path, create: true)
        try store.save(name: "host-defaults.json", data: original, validate: validate)
        try store.save(name: "host-defaults.json", data: updated, validate: validate)
        #expect(try store.read(name: "host-defaults.json") == updated)
        let backups = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent(".triton/config-backups"), includingPropertiesForKeys: nil)
        #expect(backups.count == 1)
        #expect(try Data(contentsOf: #require(backups.first)) == original)
        for (url, mode) in [(root.appendingPathComponent(".triton"), 0o700), (root.appendingPathComponent(".triton/host-defaults.json"), 0o600), (root.appendingPathComponent(".triton/config-backups"), 0o700)] {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            #expect((attrs[.posixPermissions] as? NSNumber)?.intValue == mode)
        }
    }

    @Test("invalid or oversized old config is never overwritten")
    func rejectsInvalidOldConfig() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try HostWorkspaceConfigStorage(workspace: root.path, create: true)
        let file = root.appendingPathComponent(".triton/host-defaults.json")
        let invalid = Data("invalid private config".utf8)
        try invalid.write(to: file)
        #expect(throws: (any Error).self) { try store.save(name: "host-defaults.json", data: Data("{}".utf8), validate: validate) }
        #expect(try Data(contentsOf: file) == invalid)
        #expect(throws: (any Error).self) { try store.read(name: "host-defaults.json", maximumBytes: 4) }
    }

    @Test("symlink directory, ancestor, final config and backup directory are rejected")
    func rejectsSymlinks() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let outside = root.appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: false)
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        #expect(throws: (any Error).self) { try HostWorkspaceConfigStorage(workspace: link.path, create: true) }
        let managed = root.appendingPathComponent(".triton")
        try FileManager.default.createSymbolicLink(at: managed, withDestinationURL: outside)
        #expect(throws: (any Error).self) { try HostWorkspaceConfigStorage(workspace: root.path, create: true) }
        try FileManager.default.removeItem(at: managed)
        let store = try HostWorkspaceConfigStorage(workspace: root.path, create: true)
        let file = managed.appendingPathComponent("host-defaults.json")
        try Data("{}".utf8).write(to: outside.appendingPathComponent("target"))
        try FileManager.default.createSymbolicLink(at: file, withDestinationURL: outside.appendingPathComponent("target"))
        #expect(throws: (any Error).self) { try store.read(name: "host-defaults.json") }
        #expect(throws: (any Error).self) { try store.save(name: "host-defaults.json", data: Data("{}".utf8), validate: validate) }
        try FileManager.default.removeItem(at: file)
        try store.save(name: "host-defaults.json", data: Data("{}".utf8), validate: validate)
        try FileManager.default.createSymbolicLink(at: managed.appendingPathComponent("config-backups"), withDestinationURL: outside)
        #expect(throws: (any Error).self) { try store.save(name: "host-defaults.json", data: Data("{\"v\":1}".utf8), validate: validate) }
        #expect(try Data(contentsOf: file) == Data("{}".utf8))
    }

    @Test("future alias schema refuses reads and replacement while preserving original bytes")
    func preservesFutureAliasSchema() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try HostWorkspaceConfigStorage(workspace: root.path, create: true)
        let file = root.appendingPathComponent(".triton/host-targets.json")
        let future = Data(#"{ "schemaVersion": 999, "aliases": {}, "futureValue": "preserve" }"#.utf8)
        try future.write(to: file)
        #expect(throws: (any Error).self) { try store.read(name: "host-targets.json") }
        #expect(throws: (any Error).self) { try store.save(name: "host-targets.json", data: Data(#"{"schemaVersion":2,"aliases":{}}"#.utf8), validate: validate) }
        #expect(try Data(contentsOf: file) == future)
        try FileManager.default.removeItem(at: file)
        #expect(throws: (any Error).self) { try store.save(name: "host-targets.json", data: future, validate: validate) }
        for valid in [#"{"aliases":{}}"#, #"{"schemaVersion":1,"aliases":{}}"#, #"{"schemaVersion":2,"aliases":{}}"#] {
            try store.save(name: "host-targets.json", data: Data(valid.utf8), validate: validate)
            #expect(try store.read(name: "host-targets.json") == Data(valid.utf8))
        }
    }

    @Test("missing managed config is a readonly absence and invalid names are rejected")
    func missingDoesNotCreate() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(try HostWorkspaceConfigStorage.existing(workspace: root.path) == nil)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(".triton").path))
        let store = try HostWorkspaceConfigStorage(workspace: root.path, create: true)
        #expect(throws: (any Error).self) { try store.read(name: "../outside") }
    }

    @Test("publication failure retains old config and its exact backup")
    func publicationFailureKeepsOriginal() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try HostWorkspaceConfigStorage(workspace: root.path, create: true)
        let original = Data("{\"v\":1}".utf8)
        try store.save(name: "host-defaults.json", data: original, validate: validate)
        #expect(throws: (any Error).self) {
            try store.save(name: "host-defaults.json", data: Data("{\"v\":2}".utf8), validate: validate, beforePublish: { throw RuntimeError("fixture publication failure") })
        }
        #expect(try store.read(name: "host-defaults.json") == original)
    }

    private func validate(_ data: Data) throws { _ = try JSONSerialization.jsonObject(with: data) }
    private func fixture() throws -> URL {
        let canonical = try #require(realpath(FileManager.default.temporaryDirectory.path, nil))
        defer { free(canonical) }
        let root = URL(fileURLWithPath: String(cString: canonical)).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
