import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct XcodeDerivedDataSafetyTests {
    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-derived-data-safety-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(".triton", isDirectory: true)
            .appendingPathComponent("DerivedData", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func idleStatus() -> XcodeProcessStatusOutput {
        XcodeProcessStatusOutput(
            ok: true,
            active: false,
            workspaceFilter: nil,
            processes: [],
            summary: XcodeProcessStatusSummary(xcodebuildCount: 0, buildServiceCount: 0, xctestCount: 0, matchingWorkspaceCount: 0),
            sourceCommand: "fixture"
        )
    }

    @Test("DerivedData root validation requires exact path components")
    func rootValidationRejectsNearMatches() throws {
        for suffix in ["repo/.triton/DerivedDataBackup", "repo/.triton/DerivedData/Build", "repo/.tritonOther/DerivedData"] {
            let nearMatch = FileManager.default.temporaryDirectory.appendingPathComponent(suffix, isDirectory: true).path
            do {
                try XcodeDerivedDataService.execute(root: nearMatch, cleanup: false, confirm: false, format: .json)
                Issue.record("Unexpectedly accepted root")
            } catch let error as XcodeDerivedDataSafetyError {
                #expect(error.code == "derived_data_root_rejected")
            }
        }
    }

    @Test("DerivedData dry-run leaves cache and external data unchanged")
    func dryRunDoesNotDelete() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent().deletingLastPathComponent()) }
        let cache = root.appendingPathComponent("Build", isDirectory: true)
        let external = root.deletingLastPathComponent().appendingPathComponent("outside.txt")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try Data("cache".utf8).write(to: cache.appendingPathComponent("state"))
        try Data("keep".utf8).write(to: external)

        try XcodeDerivedDataService.execute(root: root.path, cleanup: true, confirm: false, format: .json, activeStatusProvider: idleStatus)

        #expect(FileManager.default.fileExists(atPath: cache.path))
        #expect(FileManager.default.fileExists(atPath: external.path))
    }

    @Test("DerivedData confirm fails closed without deleting cache or external data")
    func confirmFailsClosed() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent().deletingLastPathComponent()) }
        let cache = root.appendingPathComponent("Build", isDirectory: true)
        let external = root.deletingLastPathComponent().appendingPathComponent("outside.txt")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try Data("cache".utf8).write(to: cache.appendingPathComponent("state"))
        try Data("keep".utf8).write(to: external)

        do {
            try XcodeDerivedDataService.execute(root: root.path, cleanup: true, confirm: true, format: .json, activeStatusProvider: idleStatus)
            Issue.record("Confirmed cleanup unexpectedly succeeded")
        } catch let error as XcodeDerivedDataSafetyError {
            #expect(error.code == "derived_data_cleanup_unavailable")
        }

        #expect(FileManager.default.fileExists(atPath: root.path))
        #expect(FileManager.default.fileExists(atPath: cache.path))
        #expect(FileManager.default.fileExists(atPath: external.path))
    }

    @Test("DerivedData confirm refuses active builds before deletion")
    func activeBuildBlocksCleanup() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent().deletingLastPathComponent()) }
        let cache = root.appendingPathComponent("Build", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try Data("cache".utf8).write(to: cache.appendingPathComponent("state"))
        let process = XcodeProcessSummary(pid: 42, name: "xcodebuild", commandLine: "xcodebuild", elapsed: "00:01", elapsedSeconds: 1, workspace: nil, project: nil, scheme: nil, destination: nil, derivedDataPath: root.path, confidence: "fixture")
        let active = XcodeProcessStatusOutput(
            ok: true,
            active: true,
            workspaceFilter: nil,
            processes: [process],
            summary: XcodeProcessStatusSummary(xcodebuildCount: 1, buildServiceCount: 0, xctestCount: 0, matchingWorkspaceCount: 0),
            sourceCommand: "fixture"
        )

        #expect(throws: XcodeDerivedDataSafetyError.self) {
            try XcodeDerivedDataService.execute(root: root.path, cleanup: true, confirm: true, format: .json, activeStatusProvider: { active })
        }
        #expect(FileManager.default.fileExists(atPath: cache.path))
    }

    @Test("DerivedData scan skips symlink entries")
    func scanSkipsSymlinks() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent().deletingLastPathComponent()) }
        let external = root.deletingLastPathComponent().appendingPathComponent("external", isDirectory: true)
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        try Data("outside".utf8).write(to: external.appendingPathComponent("state"))
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: external)
        var skipped: [String] = []
        let entries = try XcodeDerivedDataService.scan(root, symlinkSkipped: &skipped)
        #expect(entries.isEmpty)
        #expect(skipped.count == 1)
        #expect(URL(fileURLWithPath: skipped[0]).lastPathComponent == "link")
        #expect(FileManager.default.fileExists(atPath: external.appendingPathComponent("state").path))
    }
    @Test("DerivedData schema declares fail-closed deletion and exact failure codes")
    func schemaDeclaresSafetyBoundary() throws {
        let xcode = try #require(commandSchemas().first { $0.name == "xcode" })
        let cache = try #require(xcode.subcommands.first { $0.name == "derived-data" })
        let cleanup = try #require(cache.subcommands.first { $0.name == "cleanup" })
        #expect(cleanup.failureCodes.contains("derived_data_cleanup_unavailable"))
        #expect(cleanup.failureCodes.contains("xcode_not_idle"))
        #expect(cleanup.summary.contains("fails closed"))
        #expect(cache.failureCodes.contains("derived_data_root_rejected"))
        let decoded = try JSONDecoder().decode(TKCommandSchema.self, from: JSONEncoder().encode(xcode))
        let nested = try #require(decoded.subcommands.first { $0.name == "derived-data" })
        #expect(nested.subcommands.map(\.name) == ["inspect", "cleanup"])
        #expect(nested.subcommands.last?.failureCodes.contains("derived_data_cleanup_unavailable") == true)
    }

    @Test("DerivedData scan counts regular bytes and includes empty directory mtime")
    func scanStatistics() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent().deletingLastPathComponent()) }
        let directory = root.appendingPathComponent("empty", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("12345".utf8).write(to: root.appendingPathComponent("file"))
        let date = Date(timeIntervalSince1970: 1_600_000_000)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: directory.path)
        var skipped: [String] = []
        let entries = try XcodeDerivedDataService.scan(root, symlinkSkipped: &skipped)
        #expect(entries.filter { $0.action == "directory" }.count == 1)
        #expect(entries.reduce(0) { $0 + $1.fileCount } == 1)
        #expect(entries.reduce(0) { $0 + $1.bytes } == 5)
        #expect(entries.first { $0.name == "empty" }?.latestModification == date)
    }

    @Test("DerivedData nested schema accepts space and dot forms and rejects unknown children")
    func nestedSchemaLookup() throws {
        for path in ["xcode derived-data cleanup", "xcode.derived-data.cleanup"] {
            let result = try buildSchemaResponse(command: path)
            #expect(result.commands.first?.subcommands.map(\.name) == ["cleanup"])
            #expect(result.commands.first?.subcommands.first?.failureCodes.contains("derived_data_cleanup_unavailable") == true)
        }
        let parent = try buildSchemaResponse(command: "xcode derived-data")
        #expect(parent.commands.first?.subcommands.first?.subcommands.map(\.name) == ["inspect", "cleanup"])
        #expect(throws: SchemaCommandLookupError.self) {
            _ = try buildSchemaResponse(command: "xcode derived-data nonexistent")
        }
    }

}
