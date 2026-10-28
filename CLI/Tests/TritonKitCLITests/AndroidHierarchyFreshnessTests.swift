import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

struct AndroidHierarchyFreshnessTests {
    private let xml = #"<hierarchy><node text="current" bounds="[0,0][720,1600]"/></hierarchy>"#
    private var target: HostDeviceTarget {
        HostDeviceTarget(platform: "android", id: "android:fixture", target: "fixture", state: "device", ready: true, source: "adb", name: nil, runtime: nil, transport: nil)
    }
    private func result(_ command: TKHostCommand, stdout: String = "", stderr: String = "", code: Int32 = 0, truncated: Bool = false) -> HostProcessResult {
        HostProcessResult(stdoutData: Data(stdout.utf8), stderrData: Data(stderr.utf8), exitCode: code, sourceCommand: hostSourceCommand(command), stdoutTruncated: truncated, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: stdout.utf8.count, stderrBytes: stderr.utf8.count)
    }

    @Test("capture and coordinate resolution use a fresh path and only clean up that owned path")
    func uniqueCaptures() throws {
        var commands: [TKHostCommand] = []
        let runner: AndroidObserveHostRunner = { command in
            commands.append(command)
            if command.arguments.contains("uiautomator") {
                return result(command, stdout: "UI hierchary dumped to: \(command.arguments.last!)\n")
            }
            return result(command, stdout: command.arguments.contains("cat") ? xml : "")
        }
        let first = try captureAndroidHierarchy(serial: "fixture", runner: runner)
        let second = try observeAndroidNodes(selected: target, adb: "adb", runner: runner)
        #expect(first.collected.nodes.first?.text == "current")
        #expect(second.0.first?.text == "current")
        #expect(commands.count == 6)
        let firstPath = try #require(commands.first?.arguments.last)
        let secondPath = try #require(commands[3].arguments.last)
        #expect(firstPath != secondPath)
        #expect(firstPath.hasPrefix("/sdcard/triton-window-"))
        #expect(firstPath != "/sdcard/window_dump.xml")
        for offset in [0, 3] {
            #expect(commands[offset + 1].arguments.contains("cat"))
            #expect(commands[offset + 2].arguments.contains("rm"))
            #expect(commands[offset].arguments.last == commands[offset + 1].arguments.last)
            #expect(commands[offset].arguments.last == commands[offset + 2].arguments.last)
        }
    }

    @Test("failed dump never reads old XML or yields coordinates", arguments: ["null-root", "error", "missing-ack", "wrong-path", "nonzero", "throw-nonzero"])
    func failedDump(_ mode: String) throws {
        var commands: [TKHostCommand] = []
        let runner: AndroidObserveHostRunner = { command in
            commands.append(command)
            if command.arguments.contains("rm") { return result(command) }
            if command.arguments.contains("cat") { return result(command, stdout: "<hierarchy><node text=\"stale\"/></hierarchy>") }
            let path = command.arguments.last!
            let text = mode == "missing-ack" ? "" : "UI hierchary dumped to: \(mode == "wrong-path" ? "/sdcard/window_dump.xml" : path)"
            let failure = result(command, stdout: text,
                stderr: mode == "null-root" ? "ERROR: null root node returned by UiTestAutomationBridge." : (mode == "error" ? "ERROR: could not dump window" : ""),
                code: mode == "nonzero" ? 1 : 0)
            if mode == "throw-nonzero" { throw HostCommandRunError.nonZeroExit(command: command, result: failure) }
            return failure
        }
        #expect(throws: AndroidObserveError.self) { try observeAndroidNodes(selected: target, adb: "adb", runner: runner) }
        #expect(!commands.contains { $0.arguments.contains("cat") })
        #expect(commands.last?.arguments.contains("rm") == true)
        #expect(commands.last?.arguments.last == commands.first?.arguments.last)
    }

    @Test("missing or invalid current XML is hierarchy unavailable", arguments: ["missing", "empty", "malformed", "no-nodes", "truncated", "throw-nonzero"])
    func failedRead(_ mode: String) throws {
        var cleaned = false
        #expect(throws: AndroidObserveError.self) {
            try captureAndroidHierarchy(serial: "fixture", runner: { command in
                if command.arguments.contains("rm") { cleaned = true; return result(command) }
                if command.arguments.contains("uiautomator") { return result(command, stdout: "UI hierchary dumped to: \(command.arguments.last!)") }
                let text = mode == "empty" ? "" : (mode == "malformed" ? "<hierarchy><node" : (mode == "no-nodes" ? "<unrelated/>" : xml))
                let read = result(command, stdout: text, code: mode == "missing" ? 1 : 0, truncated: mode == "truncated")
                if mode == "throw-nonzero" { throw HostCommandRunError.nonZeroExit(command: command, result: read) }
                return read
            })
        }
        #expect(cleaned)
    }

    @Test("cleanup failure does not hide a dump failure")
    func cleanupFailure() throws {
        #expect(throws: AndroidObserveError.self) {
            try captureAndroidHierarchy(serial: "fixture", runner: { command in
                if command.arguments.contains("rm") { throw HostCommandRunError.launchFailed("cleanup fixture") }
                return result(command, stdout: "ERROR: null root node returned by UiTestAutomationBridge.")
            })
        }
    }
}
