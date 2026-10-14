import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Simulator Resize target binding and touch protection")
struct SimulatorResizeTests {
    let udid = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
    let display = "11111111-2222-3333-4444-555555555555"
    func document(active: Bool = true) -> Data {
        let info: [String: Any] = ["commandType": "devicectl.device.info.appResize", "outcome": active ? "success" : "failed", "arguments": ["devicectl", "device", "info", "appResize", "--device", udid]]
        var object: [String: Any] = ["info": info]
        if active {
            object["result"] = ["deviceIdentifier": udid, "displayUniqueId": display, "displayName": "Resizable", "preferredSize": [560, 874]]
        } else {
            object["error"] = ["domain": "com.apple.dt.CoreDeviceError", "code": 24004]
        }
        return try! JSONSerialization.data(withJSONObject: object)
    }
    func changed(_ transform: (inout [String: Any]) -> Void) -> Data {
        var object = try! JSONSerialization.jsonObject(with: document()) as! [String: Any]
        transform(&object)
        return try! JSONSerialization.data(withJSONObject: object)
    }
    @Test func strictClassification() {
        #expect(classifyIOSSimulatorResize(data: document(), target: udid, exitCode: 0) == .active(IOSSimulatorResizeSession(displayUniqueID: display, width: 560, height: 874)))
        #expect(classifyIOSSimulatorResize(data: document(active: false), target: udid, exitCode: 1) == .inactive)
        #expect(classifyIOSSimulatorResize(data: document(), target: udid, exitCode: 1) == .unknown(.invalidResponse))
        #expect(classifyIOSSimulatorResize(data: Data("{}".utf8), target: udid, exitCode: 0) == .unknown(.invalidResponse))
    }
    @Test func identityAndShape() {
        let mismatch = changed { $0["result"] = ["deviceIdentifier": "OTHER", "displayUniqueId": display, "preferredSize": [560, 874]] }
        #expect(classifyIOSSimulatorResize(data: mismatch, target: udid, exitCode: 0) == .unknown(.identityMismatch))
        let badSize = changed { var result = $0["result"] as! [String: Any]; result["preferredSize"] = [true, 874]; $0["result"] = result }
        #expect(classifyIOSSimulatorResize(data: badSize, target: udid, exitCode: 0) == .unknown(.invalidResponse))
        let ambiguous = changed { var info = $0["info"] as! [String: Any]; info["arguments"] = ["--device", udid, "--device", udid]; $0["info"] = info }
        #expect(classifyIOSSimulatorResize(data: ambiguous, target: udid, exitCode: 0) == .unknown(.identityMismatch))
        let contradictory = changed { $0["error"] = ["domain": "com.apple.dt.CoreDeviceError", "code": 24004] }
        #expect(classifyIOSSimulatorResize(data: contradictory, target: udid, exitCode: 0) == .unknown(.invalidResponse))
        #expect(classifyIOSSimulatorResize(data: Data(repeating: 0x20, count: 1_048_577), target: udid, exitCode: 0) == .unknown(.outputTooLarge))
    }
    @Test func exactErrorDomain() {
        var object = try! JSONSerialization.jsonObject(with: document(active: false)) as! [String: Any]
        object["error"] = ["domain": "other", "code": 24004]
        let data = try! JSONSerialization.data(withJSONObject: object)
        #expect(classifyIOSSimulatorResize(data: data, target: udid, exitCode: 1) == .unknown(.queryFailed))
    }
    @Test func guardEachCommand() throws {
        let tap = TKHostCommand(executable: "baguette", arguments: ["tap", "--udid", udid])
        var calls = 0
        let probe: IOSSimulatorResizeProbe = { target, environment in
            #expect(target == udid)
            calls += 1
            return calls == 1 ? .inactive : .active(IOSSimulatorResizeSession(displayUniqueID: display, width: 560, height: 874))
        }
        try assertIOSSimulatorResizeTouchAllowed(tap, probe: probe)
        #expect(throws: IOSSimulatorResizeError.activeSession) { try assertIOSSimulatorResizeTouchAllowed(tap, probe: probe) }
        #expect(calls == 2)
        #expect(throws: IOSSimulatorResizeError.stateUnknown(.unsupportedQuery)) { try assertIOSSimulatorResizeTouchAllowed(tap, probe: { _, _ in .unknown(.unsupportedQuery) }) }
    }
    @Test func keyboardAndObservationBypassTouchGuard() throws {
        for verb in ["type", "key", "chrome", "layout"] {
            let command = TKHostCommand(executable: "baguette", arguments: [verb, "--udid", udid])
            try assertIOSSimulatorResizeTouchAllowed(command, probe: { _, _ in Issue.record("non-touch must not probe"); return .unknown(.queryFailed) })
        }
        let input = TKHostCommand(executable: "baguette", arguments: ["input", "--udid", udid])
        #expect(throws: IOSSimulatorResizeError.activeSession) { try assertIOSSimulatorResizeTouchAllowed(input, probe: { _, _ in .active(IOSSimulatorResizeSession(displayUniqueID: display, width: 560, height: 874)) }) }
    }
    @Test func malformedTouchTargetCannotDispatch() {
        for args in [["tap"], ["tap", "--udid", udid, "--udid", udid], ["tap", "--udid", "booted"]] {
            #expect(throws: IOSSimulatorResizeError.invalidTarget) { try assertIOSSimulatorResizeTouchAllowed(TKHostCommand(executable: "baguette", arguments: args), probe: { _, _ in Issue.record("must not probe invalid target"); return .inactive }) }
        }
    }
    @Test func fileJSONProbeAcceptsBoundNegativeErrorAndRejectsStaleReceipt() throws {
        var captured: TKHostCommand?
        func nativeResult(_ command: TKHostCommand, exit: Int32) -> HostProcessResult {
            HostProcessResult(stdoutData: Data(), stderrData: Data(), exitCode: exit, sourceCommand: "fixture", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0)
        }
        let artifacts: (String) throws -> (json: String, log: String) = { _ in ("/not-existing-fixture/resize.json", "/not-existing-fixture/resize.log") }
        let reader: (String, Int) throws -> Data = { _, maximum in
            #expect(maximum == 1_048_576)
            var root = try JSONSerialization.jsonObject(with: document(active: false)) as! [String: Any]
            var info = root["info"] as! [String: Any]; info["arguments"] = captured!.arguments; root["info"] = info
            return try JSONSerialization.data(withJSONObject: root)
        }
        let state = probeIOSSimulatorResize(target: udid, environment: ["DEVELOPER_DIR": "/selected"], artifactProvider: artifacts, runner: { command in
            captured = command
            throw HostCommandRunError.nonZeroExit(command: command, result: nativeResult(command, exit: 1))
        }, reader: reader)
        #expect(state == .inactive)
        #expect(captured?.environment["DEVELOPER_DIR"] == "/selected")
        #expect(probeIOSSimulatorResize(target: udid, artifactProvider: artifacts, runner: { captured = $0; return nativeResult($0, exit: 0) }, reader: { _, _ in document() }) == .unknown(.identityMismatch))
        #expect(probeIOSSimulatorResize(target: udid, artifactProvider: artifacts, runner: { throw HostCommandRunError.timeout(command: $0, timeoutSeconds: 6, stdoutLogPath: nil, stderrLogPath: nil) }, reader: reader) == .unknown(.queryTimedOut))
    }
    @Test func oldToolchainUnsupportedStaysUnknownWithoutVersionShortcut() {
        let state = probeIOSSimulatorResize(target: udid, environment: ["DEVELOPER_DIR": "/fixture/Xcode-26.app/Contents/Developer"], artifactProvider: { _ in ("/not-existing-fixture/resize.json", "/not-existing-fixture/resize.log") }, runner: { command in
            let stderr = Data("Error: Unrecognized subcommand 'appResize'".utf8)
            let failure = HostProcessResult(stdoutData: Data(), stderrData: stderr, exitCode: 64, sourceCommand: "fixture", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: stderr.count)
            throw HostCommandRunError.nonZeroExit(command: command, result: failure)
        }, reader: { _, _ in throw HostDeviceFilesError.jsonMissing })
        #expect(state == .unknown(.unsupportedQuery))
    }
    @Test func observationHelpersNeverPromoteUnknownToInactive() throws {
        let state = IOSSimulatorResizeState.active(IOSSimulatorResizeSession(displayUniqueID: display, width: 560, height: 874))
        #expect(iosSimulatorResizeAdvisory(state)?.code == "resizable_app_session")
        #expect(iosSimulatorResizeAdvisory(state)?.pointHitTestingReliable == false)
        #expect(try iosSimulatorResizeScreenshotDisplay(state) == display)
        #expect(iosSimulatorResizeAdvisory(.unknown(.queryFailed))?.code == "resizable_app_session_unknown")
        #expect(throws: IOSSimulatorResizeCaptureError.stateUnknown(.queryFailed)) { _ = try iosSimulatorResizeScreenshotDisplay(.unknown(.queryFailed)) }
        #expect(try iosSimulatorResizeScreenshotDisplay(.inactive) == nil)
        #expect(iosSimulatorResizeAdvisory(.inactive) == nil)
    }
    @Test func persistentGestureRefusalDoesNotStartRunner() throws {
        let lifecycle = try webIOSBaguetteSwipeLifecycle(input: .swipe(startX: 1, startY: 1, endX: 2, endY: 2), udid: udid, screen: .init(width: 10, height: 10), executable: "/fake/baguette")
        var started = false
        #expect(throws: IOSSimulatorResizeError.activeSession) {
            _ = try runWebIOSBaguetteLifecycle(lifecycle, resizeProbe: { _, _ in .active(IOSSimulatorResizeSession(displayUniqueID: display, width: 560, height: 874)) }, runner: { _ in started = true; throw RuntimeError("must not start") })
        }
        #expect(!started)
    }
    @Test func processRunnerRefusesBeforeLaunchingTap() {
        let command = TKHostCommand(executable: "/nonexistent/baguette", arguments: ["tap", "--udid", udid])
        #expect(throws: IOSSimulatorResizeError.activeSession) {
            _ = try runHostCommand(command, simulatorResizeProbe: { _, _ in .active(IOSSimulatorResizeSession(displayUniqueID: display, width: 560, height: 874)) })
        }
    }
    @Test func mainFramebufferCaptureRequiresKnownInactiveSession() throws {
        try assertIOSSimulatorResizeCaptureAllowed(target: udid, probe: { _, _ in .inactive })
        #expect(throws: IOSSimulatorResizeCaptureError.activeSession) { try assertIOSSimulatorResizeCaptureAllowed(target: udid, probe: { _, _ in .active(IOSSimulatorResizeSession(displayUniqueID: display, width: 560, height: 874)) }) }
        #expect(throws: IOSSimulatorResizeCaptureError.stateUnknown(.queryTimedOut)) { try assertIOSSimulatorResizeCaptureAllowed(target: udid, probe: { _, _ in .unknown(.queryTimedOut) }) }
        #expect(IOSSimulatorResizeCaptureError.activeSession.detail.code == "ios_simulator_resize_capture_unroutable")
        #expect(!IOSSimulatorResizeCaptureError.stateUnknown(.jsonMissing).detail.message.contains("gesture"))
    }
    @Test func stableFailureDetailsDoNotExposeNativeOutput() throws {
        #expect(IOSSimulatorResizeError.activeSession.detail.code == "ios_simulator_resize_touch_unroutable")
        #expect(IOSSimulatorResizeError.stateUnknown(.queryTimedOut).detail.code == "ios_simulator_resize_state_unknown")
        #expect(IOSSimulatorResizeError.invalidTarget.detail.code == "ios_simulator_resize_target_invalid")
        for error in [IOSSimulatorResizeError.activeSession, .stateUnknown(.unsupportedQuery), .invalidTarget] {
            let text = try encodeJSON(error.detail)
            #expect(!text.contains(udid) && !text.contains(display))
        }
    }
    @Test func selectedToolchainAndBoundedArgv() {
        let command = iosSimulatorResizeQueryCommand(target: udid, json: "/private/fixture.json", log: "/private/fixture.log", environment: ["DEVELOPER_DIR": "/selected/Xcode.app/Contents/Developer"])
        #expect(command.executable == "xcrun")
        #expect(command.arguments.prefix(6) == ["devicectl", "device", "info", "appResize", "--device", udid])
        #expect(command.environment["DEVELOPER_DIR"] == "/selected/Xcode.app/Contents/Developer")
        #expect(command.defaultTimeoutSeconds == 6)
        #expect(command.arguments.contains("5"))
        #expect(command.redactedArgumentIndexes.contains(5))
    }
}
