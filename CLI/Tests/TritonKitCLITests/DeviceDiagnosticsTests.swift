import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Device diagnostics bounded reads") struct DeviceDiagnosticsTests {
    @Test func unsafeReportNamesRejected() throws {
        for name in ["../x", "/tmp/x", "a/b", ".", "..", "a\n", "", "-flag"] {
            #expect(throws: (any Error).self) { try validateDeviceCrashName(name) }
        }
        try validateDeviceCrashName("Demo-2026.ips")
    }
    @Test func boundedLogPlansAreReadonly() throws {
        let ios = try deviceDiagnosticsLogCommand(platform: .ios, scope: "simulator", target: "booted", timeout: 5, lastSeconds: 60, adb: "adb", hdc: "hdc", idevicesyslog: "idevicesyslog")
        #expect(ios.arguments == ["simctl", "spawn", "booted", "log", "show", "--style", "json", "--last", "60s"])
        let android = try deviceDiagnosticsLogCommand(platform: .android, scope: "real", target: "serial", timeout: 5, lastSeconds: 60, adb: "adb", hdc: "hdc", idevicesyslog: "idevicesyslog")
        #expect(android.arguments.contains("-d"))
        #expect(!android.arguments.contains("-c"))
        #expect(throws: (any Error).self) { try validateDeviceDiagnosticsBudget(timeout: .infinity, maximumBytes: 3, maximumEntries: 3) }
    }
}
