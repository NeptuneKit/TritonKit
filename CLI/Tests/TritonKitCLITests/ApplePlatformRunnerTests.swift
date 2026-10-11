import XCTest
@testable import TritonKitCLI
import TritonKitShared

final class ApplePlatformRunnerTests: XCTestCase {
    let udid = "11111111-1111-1111-1111-111111111111"
    func request(platform: HostApplePlatformControlPlatform = .tvos, action: HostApplePlatformControlAction = .remoteSelect, delta: Double? = nil, test: String = "ControlTests/RemoteTests/testRemoteSelect") throws -> HostApplePlatformRunnerRequest {
        try makeApplePlatformRunnerRequest(platform: platform, action: action, device: udid, xctestrun: "/private/runner/tv.xctestrun", testIdentifier: test, resultBundle: "/private/runner/result.xcresult", nonce: "nonce-123", timeout: 45, executeRunner: true, confirm: true, auditRecord: "audit-1", crownDelta: delta)
    }
    func testCommandBindsExactSimulatorAndDisablesRetryParallelism() throws {
        let command = try makeApplePlatformRunnerCommand(request())
        XCTAssertTrue(command.arguments.contains("platform=tvOS Simulator,id=\(udid)"))
        XCTAssertTrue(command.arguments.contains("-only-testing:ControlTests/RemoteTests/testRemoteSelect"))
        XCTAssertTrue(command.arguments.contains("-parallel-testing-enabled"))
        XCTAssertFalse(command.arguments.contains("-retry-tests-on-failure"))
        XCTAssertTrue(command.arguments.contains("-test-iterations"))
    }
    func testRequiresSingleMethodAndValidDelta() throws {
        XCTAssertThrowsError(try request(test: "ControlTests/RemoteTests"))
        XCTAssertThrowsError(try request(platform: .watchos, action: .crownRotate))
        XCTAssertThrowsError(try request(delta: 1))
        XCTAssertEqual(try request(platform: .watchos, action: .crownRotate, delta: 1.5).crownDelta, 1.5)
    }
    func testInjectsRequestIntoBothLayoutsAndKeepsOriginalTestRoot() throws {
        for plist: [String: Any] in [
            ["ControlTests": ["TestBundlePath": "__TESTROOT__/Runner.xctest", "EnvironmentVariables": ["KEEP": "yes"]]],
            ["TestConfigurations": [["TestTargets": [["BlueprintName": "ControlTests", "TestBundlePath": "__TESTROOT__/Runner.xctest"]]]], "__xctestrun_metadata__": ["FormatVersion": 2]]
        ] {
            let input = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            let data = try prepareApplePlatformXCTestRun(input, request: request(), originalRoot: "/private/runner")
            let text = String(decoding: data, as: UTF8.self)
            XCTAssertTrue(text.contains("TRITON_PLATFORM_REQUEST"))
            XCTAssertTrue(text.contains("TestingEnvironmentVariables"))
            XCTAssertTrue(text.contains("/private/runner/Runner.xctest"))
            XCTAssertFalse(text.contains("__TESTROOT__"))
        }
    }
    func testStrictResultRequiresVersionDeltaAndPostcondition() throws {
        let good = Data("{\"version\":1,\"ok\":true,\"platform\":\"watchos\",\"action\":\"crown-rotate\",\"device\":\"\(udid)\",\"nonce\":\"nonce-123\",\"crownDelta\":1.5,\"eventDelivered\":true,\"postconditionVerified\":true}".utf8)
        let result = try verifyApplePlatformRunnerResult(good, platform: .watchos, action: .crownRotate, device: udid, nonce: "nonce-123", crownDelta: 1.5)
        XCTAssertEqual(result.actionsExecuted, true)
        XCTAssertThrowsError(try verifyApplePlatformRunnerResult(good, platform: .watchos, action: .crownRotate, device: udid, nonce: "nonce-123", crownDelta: 2))
    }
    func testManifestRejectsDuplicateOrWrongDeviceAttachment() throws {
        let item: [String: Any] = ["exportedFileName": "result.json", "suggestedHumanReadableName": "triton-platform-result", "deviceId": udid]
        let good = try JSONSerialization.data(withJSONObject: [["testIdentifier": "RemoteTests/testRemoteSelect()", "testIdentifierURL": "test://com.apple.xcode/Probe/ControlTests/RemoteTests/testRemoteSelect", "attachments": [item]]])
        XCTAssertEqual(try applePlatformResultAttachmentName(good, request: request()), "result.json")
        let duplicate = try JSONSerialization.data(withJSONObject: [["testIdentifier": "RemoteTests/testRemoteSelect()", "testIdentifierURL": "test://com.apple.xcode/Probe/ControlTests/RemoteTests/testRemoteSelect", "attachments": [item, item]]])
        XCTAssertThrowsError(try applePlatformResultAttachmentName(duplicate, request: request()))
        let wrong = try JSONSerialization.data(withJSONObject: [["testIdentifier": "RemoteTests/testOther()", "attachments": [item]]])
        XCTAssertThrowsError(try applePlatformResultAttachmentName(wrong, request: request()))
    }
    func testTargetBindingRequiresExactRuntimeFamily() throws {
        let fixture = Data("{\"devices\":{\"com.apple.CoreSimulator.SimRuntime.tvOS-27-0\":[{\"udid\":\"\(udid)\",\"name\":\"Apple TV\",\"state\":\"Shutdown\",\"isAvailable\":true}]}}".utf8)
        XCTAssertNoThrow(try validateApplePlatformRunnerTarget(fixture, platform: .tvos, device: udid))
        XCTAssertThrowsError(try validateApplePlatformRunnerTarget(fixture, platform: .watchos, device: udid))
    }
    func withWorkspace(_ body: (HostApplePlatformRunnerRequest, String) throws -> Void) throws {
        let root = "/private/tmp/platform-runner-" + UUID().uuidString
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(atPath: root) }
        let plist = try PropertyListSerialization.data(fromPropertyList: ["ControlTests": ["TestBundlePath": "__TESTROOT__/Runner.xctest"]], format: .xml, options: 0)
        try plist.write(to: URL(fileURLWithPath: root + "/runner.xctestrun"))
        let req = try makeApplePlatformRunnerRequest(platform: .tvos, action: .remoteSelect, device: udid, xctestrun: root + "/runner.xctestrun", testIdentifier: "ControlTests/RemoteTests/testRemoteSelect", resultBundle: root + "/result.xcresult", nonce: "nonce-123", timeout: 45, executeRunner: true, confirm: true, auditRecord: "audit-1")
        try body(req, root)
    }
    var inventory: Data { Data("{\"devices\":{\"com.apple.CoreSimulator.SimRuntime.tvOS-27-0\":[{\"udid\":\"\(udid)\",\"name\":\"Apple TV\",\"state\":\"Shutdown\",\"isAvailable\":true}]}}".utf8) }
    func process(_ stdout: String = "", code: Int32 = 0) -> HostProcessResult {
        HostProcessResult(stdoutData: Data(stdout.utf8), stderrData: Data(), exitCode: code, sourceCommand: "fixture", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: stdout.utf8.count, stderrBytes: 0)
    }
    func testExitZeroAndForgedStdoutAreUnknownWithPersistentAudit() throws {
        try withWorkspace { request, root in
            var invocations = 0
            let receipt = try executeApplePlatformRunner(request, targetInventory: { self.inventory }, runner: { _ in
                invocations += 1
                return self.process("{\"ok\":true,\"eventDelivered\":true,\"postconditionVerified\":true}")
            })
            XCTAssertEqual(invocations, 1)
            XCTAssertFalse(receipt.ok)
            XCTAssertEqual(receipt.outcome, .unknown)
            XCTAssertNil(receipt.actionsExecuted)
            let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(receipt)) as! [String: Any]
            XCTAssertTrue(json["actionsExecuted"] is NSNull)
            XCTAssertTrue(FileManager.default.fileExists(atPath: root + "/result.xcresult.triton-audit/intent.json"))
            XCTAssertTrue(FileManager.default.fileExists(atPath: root + "/result.xcresult.triton-audit/completion.json"))
        }
    }
    func testUnavailableTargetNeverInvokesRunnerOrClaimsBinding() throws {
        try withWorkspace { request, _ in
            let receipt = try executeApplePlatformRunner(request, targetInventory: { Data("{\"devices\":{}}".utf8) }, runner: { _ in XCTFail("Must not execute"); return self.process() })
            XCTAssertEqual(receipt.outcome, .notStarted)
            XCTAssertEqual(receipt.actionsExecuted, false)
            XCTAssertEqual(receipt.targetBinding, "unverified")
        }
    }
    func testSuccessUsesUniqueBoundAttachmentAndAuditsCompletion() throws {
        try withWorkspace { request, root in
            var invocations = 0
            let receipt = try executeApplePlatformRunner(request, targetInventory: { self.inventory }, runner: { command in
                invocations += 1
                if command.executable == "xcodebuild" {
                    XCTAssertTrue(command.arguments.contains(root + "/result.xcresult.triton-audit/request.xctestrun"))
                    try FileManager.default.createDirectory(atPath: request.resultBundle!, withIntermediateDirectories: false)
                } else {
                    XCTAssertEqual(command.arguments[6], "RemoteTests/testRemoteSelect()")
                    let path = command.arguments[8]
                    try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false)
                    let manifest: [[String: Any]] = [["testIdentifier": "RemoteTests/testRemoteSelect()", "testIdentifierURL": "test://com.apple.xcode/Probe/ControlTests/RemoteTests/testRemoteSelect", "attachments": [["deviceId": self.udid, "suggestedHumanReadableName": "triton-platform-result_0_24BED0E8-0C1F-4D7F-AC92-0A79A524E2C3.json", "exportedFileName": "result.json"]]]]
                    try JSONSerialization.data(withJSONObject: manifest).write(to: URL(fileURLWithPath: path + "/manifest.json"))
                    let response: [String: Any] = ["version": 1, "platform": "tvos", "action": "remote-select", "device": self.udid, "nonce": "nonce-123", "ok": true, "eventDelivered": true, "postconditionVerified": true]
                    try JSONSerialization.data(withJSONObject: response).write(to: URL(fileURLWithPath: path + "/result.json"))
                }
                return self.process("untrusted stdout")
            })
            XCTAssertTrue(receipt.ok)
            XCTAssertEqual(receipt.actionsExecuted, true)
            XCTAssertEqual(invocations, 2)
        }
    }
    func testRejectsExistingResultAndSymlinkWithoutExecution() throws {
        try withWorkspace { request, root in
            try FileManager.default.createSymbolicLink(atPath: request.resultBundle!, withDestinationPath: root + "/runner.xctestrun")
            let receipt = try executeApplePlatformRunner(request, targetInventory: { self.inventory }, runner: { _ in XCTFail("Must not execute"); return self.process() })
            XCTAssertEqual(receipt.failureCode, "runner_result_path_exists")
            XCTAssertEqual(receipt.actionsExecuted, false)
        }
    }

    func testTimeoutPreservesUnknownDeliveryAndDoesNotRetry() throws {
        try withWorkspace { request, _ in
            var calls = 0
            let receipt = try executeApplePlatformRunner(request, targetInventory: { self.inventory }, runner: { command in
                calls += 1
                throw HostCommandRunError.timeout(command: command, timeoutSeconds: 1, stdoutLogPath: nil, stderrLogPath: nil)
            })
            XCTAssertEqual(calls, 1)
            XCTAssertEqual(receipt.outcome, .timedOut)
            XCTAssertEqual(receipt.failureCode, "runner_timed_out")
            XCTAssertNil(receipt.actionsExecuted)
        }
    }
    func testBoundedNativeProcessPersistsBothLogsOnFailure() throws {
        try withWorkspace { _, root in
            let command = TKHostCommand(executable: "/bin/sh", arguments: ["-c", "printf test-output; printf test-error >&2; exit 3"], defaultTimeoutSeconds: 2)
            XCTAssertThrowsError(try runApplePlatformRunnerProcess(command, logPrefix: root + "/native"))
            XCTAssertEqual(try String(contentsOfFile: root + "/native.stdout.log", encoding: .utf8), "test-output")
            XCTAssertEqual(try String(contentsOfFile: root + "/native.stderr.log", encoding: .utf8), "test-error")
            let attrs = try FileManager.default.attributesOfItem(atPath: root + "/native.stdout.log")
            XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        }
    }

}
