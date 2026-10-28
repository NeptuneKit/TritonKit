import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Explicit primary framebuffer capture")
struct SimulatorPrimaryFramebufferTests {
    let target = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
    let displayID = "11111111-2222-3333-4444-555555555555"
    var arguments: [String] {
        iosSimulatorDisplayTopologyQueryCommand(target: target, json: "/fixture/result.json", log: "/fixture/result.log", environment: [:]).arguments
    }
    var lcd: [String: Any] {
        ["displayId": 1, "uniqueId": displayID, "name": "LCD", "primary": true,
         "backlightState": "activeOn", "type": ["integrated": [:]]]
    }
    func document(displays: [[String: Any]]? = nil, _ mutate: (inout [String: Any]) -> Void = { _ in }) throws -> Data {
        var root: [String: Any] = [
            "info": ["commandType": "devicectl.device.info.displays", "outcome": "success", "arguments": arguments],
            "result": ["displays": displays ?? [lcd]]
        ]
        mutate(&root)
        return try JSONSerialization.data(withJSONObject: root)
    }
    func classify(_ data: Data, exitCode: Int32 = 0) -> IOSSimulatorPrimaryFramebufferDisplay {
        classifyIOSSimulatorPrimaryFramebufferDisplay(data: data, target: target, exitCode: exitCode, expectedArguments: arguments)
    }

    @Test func requiresCompleteTargetBoundSingleLCDInventory() throws {
        #expect(classify(try document()) == .display(displayID))
        let mutations: [(inout [String: Any]) -> Void] = [
            { $0["error"] = [:] }, { $0["errors"] = [] },
            { $0["info"] = ["commandType": "devicectl.device.info.displays", "outcome": "success", "arguments": arguments, "error": [:]] },
            { $0["info"] = ["commandType": "devicectl.device.info.displays", "outcome": "success", "arguments": arguments, "errors": []] },
            { $0["result"] = ["displays": [lcd], "error": [:]] },
            { $0["result"] = ["displays": [lcd], "errors": []] },
            { $0["result"] = ["displays": [lcd], "deviceIdentifier": "OTHER"] },
            { $0["info"] = ["commandType": "devicectl.device.info.displays", "outcome": "success", "arguments": Array(arguments.prefix(6))] },
            { $0["info"] = ["commandType": "devicectl.device.info.appResize", "outcome": "success", "arguments": arguments] },
            { $0["info"] = ["commandType": "devicectl.device.info.displays", "outcome": "failed", "arguments": arguments] },
            { var wrong = arguments; wrong[5] = "BBBBBBBB-BBBB-CCCC-DDDD-EEEEEEEEEEEE"; $0["info"] = ["commandType": "devicectl.device.info.displays", "outcome": "success", "arguments": wrong] },
            { var stale = arguments; stale[7] = "/fixture/stale.json"; $0["info"] = ["commandType": "devicectl.device.info.displays", "outcome": "success", "arguments": stale] }
        ]
        for mutate in mutations { if case .display = classify(try document(mutate)) { Issue.record("Malformed or mismatched inventory accepted") } }
        #expect(classify(try document(), exitCode: 1) != .display(displayID))
        #expect(classify(Data(repeating: 32, count: 1_048_577)) == .unknown(.truncated))
    }

    @Test func rejectsExtraOffVirtualDisplayAndIncompleteOrConflictingLCDFields() throws {
        let virtual: [String: Any] = ["displayId": 4, "uniqueId": "22222222-2222-3333-4444-555555555555", "name": "Resizable", "primary": false, "backlightState": "off", "type": ["virtual": [:]]]
        #expect(classify(try document(displays: [lcd, virtual])) != .display(displayID))
        #expect(classify(try document(displays: [])) != .display(displayID))
        let mutations: [(inout [String: Any]) -> Void] = [
            { $0.removeValue(forKey: "uniqueId") }, { $0["uniqueId"] = "internal" },
            { $0.removeValue(forKey: "name") }, { $0["name"] = "Resizable" },
            { $0["primary"] = 1 }, { $0["primary"] = false },
            { $0["backlightState"] = "off" }, { $0["backlightState"] = "unknown" },
            { $0["type"] = ["virtual": [:]] }, { $0["type"] = ["integrated": [:], "virtual": [:]] },
            { $0["error"] = [:] }, { $0["errors"] = [] }, { $0["displayId"] = true }
        ]
        for mutate in mutations {
            var item = lcd; mutate(&item)
            if case .display = classify(try document(displays: [item])) { Issue.record("Incomplete or conflicting LCD accepted") }
        }
    }

    @Test func explicitUnsupportedCaptureBindsUUIDAndPreservesUnknown() throws {
        var resizeCalls = 0; var displayCalls = 0
        let command = TKHostCommand(executable: "xcrun", arguments: ["simctl", "io", target, "screenshot", "/fixture/frame.png"], workingDirectory: "/fixture", environment: ["DEVELOPER_DIR": "/Selected/Xcode"], redactedEnvironmentKeys: ["SECRET"], redactedArgumentIndexes: [2, 4], riskLevel: .evidence, defaultTimeoutSeconds: 17, capturesArtifacts: true, sensitiveOutput: true)
        let route = try primaryFramebufferSimulatorScreenshotRoute(command, simulator: target, resizeProbe: { target, environment in
            #expect(target == self.target); #expect(environment == command.environment); resizeCalls += 1
            return .unknown(.unsupportedDevice)
        }, displayProbe: { target, environment in
            #expect(resizeCalls == 1); #expect(target == self.target); #expect(environment == command.environment); displayCalls += 1
            return .display(displayID)
        })
        #expect(resizeCalls == 1 && displayCalls == 1)
        #expect(route.command.arguments == ["simctl", "io", target, "screenshot", "--type=png", "--display=\(displayID)", "/fixture/frame.png"])
        #expect(route.command.redactedArgumentIndexes == [2, 5, 6])
        #expect(route.command.workingDirectory == command.workingDirectory)
        #expect(route.command.environment == command.environment)
        #expect(route.command.defaultTimeoutSeconds == 17)
        #expect(route.command.redactedEnvironmentKeys == command.redactedEnvironmentKeys)
        #expect(route.command.capturesArtifacts && route.command.sensitiveOutput)
        #expect(route.evidence.resizeState == "unknown" && route.evidence.resizeReason == "unsupportedDevice")
        #expect(!route.evidence.resizeVerified && !route.evidence.inputDispatchVerified)
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(route.evidence)) as! [String: Any]
        #expect(json["captureScope"] as? String == "primary-display-framebuffer")
        #expect(json["topologySource"] as? String == "devicectl.device.info.displays")
        #expect(json["displayUniqueID"] as? String == displayID)
    }

    @Test func inactiveIsRetainedButNeverGrantsInputAndStillRequiresSingleDisplay() throws {
        let command = TKSimctlCommand.screenshot(udid: target, output: "/fixture/frame.png")
        let route = try primaryFramebufferSimulatorScreenshotRoute(command, simulator: target, resizeProbe: { _, _ in .inactive }, displayProbe: { _, _ in .display(displayID) })
        #expect(route.evidence.resizeState == "inactive" && route.evidence.resizeReason == nil && route.evidence.resizeVerified)
        #expect(!route.evidence.inputDispatchVerified)
        #expect(throws: IOSSimulatorDisplayError.topologyUnknown(.invalidResponse)) {
            _ = try primaryFramebufferSimulatorScreenshotRoute(command, simulator: target, resizeProbe: { _, _ in .inactive }, displayProbe: { _, _ in .unknown(.invalidResponse) })
        }
    }

    @Test func activeAndOtherUnknownRefuseBeforeDisplayQuery() throws {
        let command = TKSimctlCommand.screenshot(udid: target, output: "/fixture/frame.png")
        var displayCalls = 0
        let displayProbe: IOSSimulatorPrimaryFramebufferDisplayProbe = { _, _ in displayCalls += 1; return .display(displayID) }
        #expect(throws: IOSSimulatorResizeCaptureError.activeSession) {
            _ = try primaryFramebufferSimulatorScreenshotRoute(command, simulator: target, resizeProbe: { _, _ in .active(.init(displayUniqueID: displayID, width: 560, height: 874)) }, displayProbe: displayProbe)
        }
        for reason in [IOSSimulatorResizeUnknownReason.invalidResponse, .identityMismatch, .outputTooLarge, .jsonMissing, .queryFailed, .queryTimedOut, .unsupportedQuery] {
            #expect(throws: IOSSimulatorResizeCaptureError.stateUnknown(reason)) {
                _ = try primaryFramebufferSimulatorScreenshotRoute(command, simulator: target, resizeProbe: { _, _ in .unknown(reason) }, displayProbe: displayProbe)
            }
        }
        #expect(displayCalls == 0)
    }

    @Test func malformedCommandsAreRejectedBeforeProbes() throws {
        var calls = 0
        let invalid = [
            TKSimctlCommand.screenshot(udid: target, output: "/fixture/frame.png", display: "internal"),
            TKSimctlCommand.screenshot(udid: "BBBBBBBB-BBBB-CCCC-DDDD-EEEEEEEEEEEE", output: "/fixture/frame.png"),
            TKSimctlCommand.screenshot(udid: target, output: "--display=external"),
            TKSimctlCommand.screenshot(udid: target, output: ""),
            TKHostCommand(executable: "other", arguments: ["simctl", "io", target, "screenshot", "/fixture/frame.png"]),
            TKHostCommand(executable: "xcrun", arguments: ["simctl", "io", target, "recordVideo", "/fixture/frame.png"]),
            TKHostCommand(executable: "xcrun", arguments: ["simctl", "io", target, "screenshot", "--type=jpeg", "/fixture/frame.png"])
        ]
        for command in invalid {
            #expect(throws: IOSSimulatorResizeCaptureError.stateUnknown(.invalidResponse)) {
                _ = try primaryFramebufferSimulatorScreenshotRoute(command, simulator: target, resizeProbe: { _, _ in calls += 1; return .inactive }, displayProbe: { _, _ in calls += 1; return .display(displayID) })
            }
        }
        #expect(calls == 0)
    }


    @Test func productionProbeBindsActualFreshArgumentsAndPreservesFailureReasons() throws {
        let artifacts: (String) throws -> (json: String, log: String) = { _ in
            ("/missing-primary-framebuffer-fixture/result.json", "/missing-primary-framebuffer-fixture/result.log")
        }
        var issued: TKHostCommand?
        var reads = 0
        let runner: (TKHostCommand) throws -> HostProcessResult = { command in
            issued = command
            return HostProcessResult(stdoutData: Data(), stderrData: Data(), exitCode: 0, sourceCommand: "fixture", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0)
        }
        let result = probeIOSSimulatorPrimaryFramebufferDisplay(target: target, environment: ["DEVELOPER_DIR": "/selected/Xcode"], artifactProvider: artifacts, runner: runner, reader: { path, limit in
            reads += 1
            #expect(path == "/missing-primary-framebuffer-fixture/result.json")
            #expect(limit == 1_048_576)
            return try document { root in
                var info = root["info"] as! [String: Any]
                info["arguments"] = issued!.arguments
                root["info"] = info
            }
        })
        #expect(result == .display(displayID) && reads == 1)
        #expect(issued?.environment == ["DEVELOPER_DIR": "/selected/Xcode"])
        #expect(issued?.defaultTimeoutSeconds == 6)
        #expect(probeIOSSimulatorPrimaryFramebufferDisplay(target: target, artifactProvider: artifacts, runner: runner, reader: { _, _ in try document() }) != .display(displayID))
        #expect(probeIOSSimulatorPrimaryFramebufferDisplay(target: target, artifactProvider: artifacts, runner: { command in
            throw HostCommandRunError.timeout(command: command, timeoutSeconds: 6, stdoutLogPath: nil, stderrLogPath: nil)
        }, reader: { _, _ in Issue.record("Timeout must not read stale JSON"); return Data() }) == .unknown(.timedOut))
        #expect(probeIOSSimulatorPrimaryFramebufferDisplay(target: "booted", artifactProvider: { _ in
            Issue.record("Invalid target must not allocate artifacts"); return ("/unused.json", "/unused.log")
        }, runner: runner) == .unknown(.identityMismatch))
        #expect(probeIOSSimulatorPrimaryFramebufferDisplay(target: target, artifactProvider: artifacts, runner: { command in
            let result = HostProcessResult(stdoutData: Data(), stderrData: Data(), exitCode: 1, sourceCommand: "fixture", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 0, stderrBytes: 0)
            throw HostCommandRunError.nonZeroExit(command: command, result: result)
        }, reader: { _, _ in try document() }) != .display(displayID))
    }
}
