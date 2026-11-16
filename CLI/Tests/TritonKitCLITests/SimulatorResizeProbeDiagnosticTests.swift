import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite struct SimulatorResizeProbeDiagnosticTests {
    let target = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
    @Test("native failure facts retain static phase and domain/code without private text")
    func nativeFailure() throws {
        var command: TKHostCommand?
        let result = probeIOSSimulatorResizeReport(target: target, artifactProvider: { _ in ("/missing-fixture/probe.json", "/missing-fixture/probe.log") }, runner: {
            command = $0
            return HostProcessResult(stdoutData: Data("PRIVATE OUTPUT".utf8), stderrData: Data(), exitCode: 1, sourceCommand: "PRIVATE COMMAND", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 14, stderrBytes: 0)
        }, reader: { _, _ in
            try JSONSerialization.data(withJSONObject: ["info": ["commandType": "devicectl.device.info.appResize", "outcome": "failed", "arguments": command!.arguments], "error": ["domain": "com.apple.dt.CoreDeviceError", "code": 12345, "userInfo": ["NSLocalizedDescription": "PRIVATE DESCRIPTION"]]])
        })
        #expect(result.state == .unknown(.queryFailed))
        #expect(result.diagnostic.stage == "native-result")
        #expect(result.diagnostic.nativeErrorDomain == "com.apple.dt.CoreDeviceError")
        #expect(result.diagnostic.nativeErrorCode == 12345)
        #expect(result.diagnostic.exitCode == 1)
        #expect(!String(decoding: try JSONEncoder().encode(result.diagnostic), as: UTF8.self).contains("PRIVATE"))
    }
    @Test("transport failure is not automatically retried")
    func transport() {
        var calls = 0
        let result = probeIOSSimulatorResizeReport(target: target, artifactProvider: { _ in ("/missing-fixture/probe.json", "/missing-fixture/probe.log") }, runner: { _ in calls += 1; throw RuntimeError("PRIVATE ERROR") })
        #expect(result.state == .unknown(.queryFailed))
        #expect(result.diagnostic.stage == "process")
        #expect(calls == 1)
        #expect(result.diagnostic.nativeErrorCode == nil)
    }
    @Test("mismatched receipt never attributes another target's native error")
    func mismatch() throws {
        let result = probeIOSSimulatorResizeReport(target: target, artifactProvider: { _ in ("/missing-fixture/probe.json", "/missing-fixture/probe.log") }, runner: { _ in
            HostProcessResult(stdoutData: Data(), stderrData: Data(), exitCode: 1, sourceCommand: "fixture", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0)
        }, reader: { _, _ in try JSONSerialization.data(withJSONObject: ["info": ["arguments": ["wrong-target"]], "error": ["domain": "com.apple.dt.CoreDeviceError", "code": 42]]) })
        #expect(result.state == .unknown(.identityMismatch))
        #expect(result.diagnostic.nativeErrorCode == nil)
    }
}

@Suite struct SimulatorResizeFailurePropagationTests {
    let target = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
    @Test func actionFailureSurvivesRepeatedBindingAndJSON() throws {
        let diagnostic = TKCLIHostProbeDiagnostic(stage: "process", exitCode: 1, nativeErrorDomain: nil, nativeErrorCode: nil, artifactPaths: ["/private/probe.json"])
        do {
            _ = try resizeStateForOperation(target: target, capture: true, reportProbe: { _, _ in .init(state: .unknown(.queryFailed), diagnostic: diagnostic) })
            Issue.record("Must reject unknown capture")
        } catch let error as SimulatorTargetDiagnosticError {
            let detail = simulatorTargetBoundDetail(error.detail, target: target)
            #expect(detail.probeDiagnostic == diagnostic)
            #expect(try JSONDecoder().decode(TKCLIErrorDetail.self, from: JSONEncoder().encode(detail)).probeDiagnostic == diagnostic)
        }
    }
    @Test func timeoutDistinctFromMissingJSON() {
        let paths: (String) throws -> (json: String, log: String) = { _ in ("/missing/probe.json", "/missing/probe.log") }
        let timeout = probeIOSSimulatorResizeReport(target: target, artifactProvider: paths, runner: { command in
            throw HostCommandRunError.timeout(command: command, timeoutSeconds: 6, stdoutLogPath: nil, stderrLogPath: nil)
        })
        #expect(timeout.state == .unknown(.queryTimedOut))
        let missing = probeIOSSimulatorResizeReport(target: target, artifactProvider: paths, runner: { _ in
            HostProcessResult(stdoutData: Data(), stderrData: Data(), exitCode: 1, sourceCommand: "fixture", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0)
        }, reader: { _, _ in throw RuntimeError("missing") })
        #expect(missing.state == .unknown(.jsonMissing))
        #expect(missing.diagnostic.exitCode == 1)
    }
    @Test func failedProbeRetainsOriginalArtifacts() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let json = root.appendingPathComponent("probe.json"), log = root.appendingPathComponent("probe.log")
        let raw = Data("original invalid JSON".utf8)
        try raw.write(to: json); try Data("native log".utf8).write(to: log)
        let report = probeIOSSimulatorResizeReport(target: target, artifactProvider: { _ in (json.path, log.path) }, runner: { _ in throw RuntimeError("original process failure") })
        #expect(report.diagnostic.artifactPaths?.count == 3)
        #expect(try Data(contentsOf: json) == raw)
        #expect(try String(contentsOfFile: json.path + ".process.json", encoding: .utf8).contains("original process failure"))
    }
}
