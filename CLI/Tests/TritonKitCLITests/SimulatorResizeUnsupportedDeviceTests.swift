import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Resize capability rejection from native Xcode 27.1 JSON")
struct SimulatorResizeUnsupportedDeviceTests {
    let target = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
    let feature = "com.apple.coredevice.feature.resizableappmanagement"

    // Shape captured from a task-owned, booted iPad A16 / iOS 27.0.
    // Identity and descriptions are sanitized; localized text is never authority.
    func document(_ change: (inout [String: Any]) -> Void = { _ in }) throws -> Data {
        var root: [String: Any] = [
            "info": ["commandType": "devicectl.device.info.appResize", "outcome": "failed",
                     "arguments": ["devicectl", "device", "info", "appResize", "--device", target]],
            "error": ["domain": "com.apple.dt.CoreDeviceError", "code": 1001,
                      "userInfo": ["CapabilityFeatureIdentifier": ["string": feature],
                                   "DeviceIdentifier": ["string": target],
                                   "NSLocalizedDescription": ["string": "PRIVATE LOCALIZED TEXT"]]]
        ]
        change(&root)
        return try JSONSerialization.data(withJSONObject: root)
    }

    func reason(_ state: IOSSimulatorResizeState) -> String? {
        if case .unknown(let reason) = state { return reason.rawValue }
        return nil
    }

    @Test func exactNativeCapabilityFailureIsExplainedWithoutGrantingInactive() throws {
        let state = classifyIOSSimulatorResize(data: try document(), target: target, exitCode: 1)
        #expect(reason(state) == "unsupportedDevice")
        #expect(throws: IOSSimulatorResizeCaptureError.stateUnknown(.unsupportedDevice)) { _ = try iosSimulatorResizeScreenshotDisplay(state) }
        let report = try #require(simulatorDoctorDiagnostics(target: target, resizeProbe: { _, _ in state }, displayProbe: { _, _ in .primary(.init(id: "1", primary: true, active: true, integrated: true)) }))
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(report)) as! [String: Any]
        let resize = json["resize"] as! [String: Any]
        #expect(resize["state"] as? String == "unknown")
        #expect((resize["hint"] as? String)?.contains("Repeating") == true)
        #expect(!report.captureVerified && !report.inputDispatchVerified)
        #expect(!String(decoding: try JSONEncoder().encode(report), as: UTF8.self).contains("PRIVATE"))
        let schema = try #require(commandSchemas().first { $0.name == "device" })
        #expect(schema.outputContracts.first { $0.selector == "host.device-doctor" }?.fields.contains { $0.name == "simulatorDiagnostics.resize.hint" } == true)
    }

    @Test func unrelatedMalformedOrConflictingCapabilityErrorsStayUnknown() throws {
        let mutations: [(inout [String: Any]) -> Void] = [
            { $0["domain"] = "other" }, { $0["code"] = true }, { $0["code"] = 1002 },
            { $0["userInfo"] = [:] },
            { $0["userInfo"] = ["CapabilityFeatureIdentifier": ["string": "other"], "DeviceIdentifier": ["string": target]] },
            { $0["userInfo"] = ["CapabilityFeatureIdentifier": ["string": feature], "DeviceIdentifier": ["string": "OTHER"]] },
            { $0["userInfo"] = ["CapabilityFeatureIdentifier": feature, "DeviceIdentifier": target] },
            { $0["underlyingErrors"] = [["domain": "com.apple.dt.CoreDeviceError", "code": 24004]] }
        ]
        for mutation in mutations {
            let data = try document { root in var error = root["error"] as! [String: Any]; mutation(&error); root["error"] = error }
            let state = classifyIOSSimulatorResize(data: data, target: target, exitCode: 1)
            #expect(reason(state) != nil)
            #expect(reason(state) != "unsupportedDevice")
        }
        for data in [try document { $0["result"] = [:] }, try document { $0["errors"] = [] }] {
            #expect(reason(classifyIOSSimulatorResize(data: data, target: target, exitCode: 1)) != "unsupportedDevice")
        }
        #expect(reason(classifyIOSSimulatorResize(data: try document(), target: target, exitCode: 0)) != "unsupportedDevice")
    }

    @Test func productionProbeRequiresCompleteReceiptAndKeepsTouchBlocked() throws {
        var issued: TKHostCommand?
        let artifacts: (String) throws -> (json: String, log: String) = { _ in ("/missing-resize-fixture/response.json", "/missing-resize-fixture/log") }
        let runner: (TKHostCommand) throws -> HostProcessResult = { command in
            issued = command
            let result = HostProcessResult(stdoutData: Data(), stderrData: Data(), exitCode: 1, sourceCommand: "fixture", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0)
            throw HostCommandRunError.nonZeroExit(command: command, result: result)
        }
        let state = probeIOSSimulatorResize(target: target, artifactProvider: artifacts, runner: runner, reader: { _, _ in
            try document { root in var info = root["info"] as! [String: Any]; info["arguments"] = issued!.arguments; root["info"] = info }
        })
        #expect(reason(state) == "unsupportedDevice")
        #expect(throws: IOSSimulatorResizeError.stateUnknown(.unsupportedDevice)) {
            _ = try nativeHIDGuardSnapshot(target: target, environment: [:], resizeProbe: { _, _ in state })
        }
        var captures = 0
        #expect(throws: IOSSimulatorResizeCaptureError.stateUnknown(.unsupportedDevice)) {
            _ = try resizeAwareSimulatorScreenshotCommand(TKSimctlCommand.screenshot(udid: target, output: "/unused.png"), simulator: target, probe: { _, _ in state }, displayProbe: { _, _ in .primary(.init(id: "1", primary: true, active: true, integrated: true)) })
            captures += 1
        }
        #expect(captures == 0)
        #expect(throws: IOSSimulatorResizeCaptureError.stateUnknown(.unsupportedDevice)) {
            try assertIOSSimulatorResizeCaptureAllowed(target: target, probe: { _, _ in state })
        }
        #expect(throws: IOSSimulatorResizeError.stateUnknown(.unsupportedDevice)) {
            try assertIOSSimulatorAXActivationAllowed(target: target, probe: { _, _ in state }, displayProbe: { _, _ in
                Issue.record("Unsupported Resize must refuse before AX display routing")
                return .primary(.init(id: "1", primary: true, active: true, integrated: true))
            })
        }
        #expect(probeIOSSimulatorResize(target: target, artifactProvider: artifacts, runner: runner, reader: { _, _ in try document() }) == .unknown(.identityMismatch))
    }
}
