import ArgumentParser
import Foundation
import Testing
@testable import TritonKitCLI

@Suite("DeviceFS crash scope separated from diagnostics")
struct DeviceFSCrashScopeTests {
    @Test func crashNamespace() throws {
        let view = try #require(DeviceFSView(rawValue: "diagnostic-reports"))
        #expect(view.relativeDirectory == "DiagnosticReports")
        #expect(try deviceFSRelativeDirectory(view: view, containerIdentifier: nil) == "DiagnosticReports")
        #expect(throws: (any Error).self) { try deviceFSRelativeDirectory(view: view, containerIdentifier: "guess") }
        #expect(throws: (any Error).self) { try deviceFSRelativeDirectory(view: view, containerIdentifier: nil, subdirectory: "guess") }
        _ = try TritonKitCLI.parseAsRoot(["device", "fs", "list", "--view", "diagnostic-reports", "--json"])
    }
    @Test func absentNamespaceIsUnavailableNotUnsafe() throws {
        let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent("triton-crash-fixture-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(throws: DeviceFSReaderError.directoryUnavailable) {
            try readDeviceFSShallowMetadata(root: root.path, relativeDirectory: "DiagnosticReports")
        }
    }
    @Test func temporaryNeverMasqueradesAsReadonly() {
        #expect(DeviceFSView(rawValue: "temporary") == nil)
        #expect(DeviceFSView(rawValue: "Temporary") == nil)
    }
}
