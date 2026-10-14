import Darwin
import Foundation
import Testing
@testable import TritonKitCLI

@Suite
struct SimulatorResourceOfflineStoreTests {
    @Test("Offline store rejects path traversal and unmanaged mutations")
    func rejectsUnsafeInput() {
        #expect(throws: (any Error).self) { try SimulatorResourceOfflineStore.read("../outside") }
        #expect(throws: (any Error).self) { try SimulatorResourceOfflineStore.merge("AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", disable: ["private.custom"], enable: []) }
        #expect(throws: (any Error).self) { try SimulatorResourceOfflineStore.merge("AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", disable: ["com.apple.assistantd"], enable: []) }
    }

    @Test("Offline store rejects symlinked stores and non-boolean values")
    func rejectsUnsafeStore() throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let old = SimulatorResourceOfflineStore.root
        SimulatorResourceOfflineStore.root = try resourceFixturePhysicalPath(root)
        defer { SimulatorResourceOfflineStore.root = old }
        let udid = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        let destination = SimulatorResourceOfflineStore.url(for: udid)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: false)
        let outside = root.appendingPathComponent("outside.plist")
        let invalid = try PropertyListSerialization.data(fromPropertyList: ["private.custom": 1], format: .xml, options: 0)
        try invalid.write(to: outside)
        try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: outside)
        #expect(throws: (any Error).self) { try SimulatorResourceOfflineStore.read(udid) }
        #expect(throws: (any Error).self) { try SimulatorResourceOfflineStore.merge(udid, disable: ["com.apple.apsd"], enable: []) }
        #expect(try Data(contentsOf: outside) == invalid)
        try FileManager.default.removeItem(at: destination)
        try invalid.write(to: destination)
        #expect(throws: (any Error).self) { try SimulatorResourceOfflineStore.read(udid) }
    }

    @Test("offline store merges managed labels and preserves explicit entries")
    func mergePreservesEntries() throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let old = SimulatorResourceOfflineStore.root
        SimulatorResourceOfflineStore.root = try resourceFixturePhysicalPath(root)
        defer { SimulatorResourceOfflineStore.root = old }
        let udid = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        let destination = SimulatorResourceOfflineStore.url(for: udid)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: false)
        try PropertyListSerialization.data(fromPropertyList: ["private.custom": true, "private.enabled": false], format: .xml, options: 0).write(to: destination)
        try SimulatorResourceOfflineStore.merge(udid, disable: ["com.apple.apsd"], enable: [])
        try SimulatorResourceOfflineStore.merge("AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", disable: [], enable: ["com.apple.apsd"])
        let entries = try SimulatorResourceOfflineStore.read("AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
        #expect(entries["com.apple.apsd"] == false)
        #expect(entries["private.custom"] == true)
        #expect(entries["private.enabled"] == false)
    }
}

/// Foundation can preserve the /var alias on macOS even after resolvingSymlinksInPath.
/// Use an existing directory's physical path so nofollow production IO stays strict.
func resourceFixturePhysicalPath(_ url: URL) throws -> String {
    guard let path = realpath(url.path, nil) else { throw CocoaError(.fileReadUnknown) }
    defer { free(path) }
    return String(cString: path)
}
