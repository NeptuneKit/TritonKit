import Foundation
import Darwin
import Testing
@testable import TritonKitCLI

private final class IOSRunnerHarness {
    let root: URL
    let target = IOSRunnerTarget(device: "sim:fixture", scope: "simulator", address: "11111111-1111-1111-1111-111111111111")
    var now = Date(timeIntervalSince1970: 1000)
    var alive = false
    var terminated = 0
    var calls = [String]()
    var commands = [[String]]()
    var actionResponse: [String: Any] = ["ok": true, "result": ["submitted": true]]
    var nativeStderr = ""
    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("runner-lifecycle-test-" + UUID().uuidString)
        try IOSRunnerSessionStore.privateDirectory(root)
        try IOSRunnerSessionStore.privateDirectory(root.appendingPathComponent("project/TritonIOSRunner.xcodeproj"))
        try Data("{\"sourceVersion\":\"test\"}".utf8).write(to: root.appendingPathComponent("project/RUNNER_MANIFEST.json"))
    }
    deinit { try? FileManager.default.removeItem(at: root) }
    var dependencies: IOSRunnerDependencies {
        IOSRunnerDependencies(registryRoot: root.appendingPathComponent("store"), resolve: { _ in self.target }, command: { args, _ in
            self.commands.append(args)
            if let index = args.firstIndex(of: "-derivedDataPath") {
                let products = URL(fileURLWithPath: args[index + 1]).appendingPathComponent("Build/Products")
                try IOSRunnerSessionStore.privateDirectory(products)
                let config: [String: Any] = ["Tests": ["TestBundlePath": "__TESTROOT__/TritonIOSRunnerTests.xctest", "TestHostPath": "__TESTROOT__/Runner.app", "EnvironmentVariables": ["preserved": "yes"]]]
                try PropertyListSerialization.data(fromPropertyList: config, format: .xml, options: 0).write(to: products.appendingPathComponent("Runner.xctestrun"))
            }
            return IOSRunnerCommandResult(status: 0, stdout: "", stderr: "")
        }, launch: { _, directory in
            self.alive = true
            if !self.nativeStderr.isEmpty {
                try? Data(self.nativeStderr.utf8).write(to: directory.appendingPathComponent("native.stderr"))
            }
            return 1234
        }, processExists: { _ in self.alive }, ownsProcess: { _, _ in self.alive }, terminate: { _, _ in self.terminated += 1; self.alive = false; return true }, exchange: { session, route, _, requestID, _ in
            self.calls.append(route)
            if route == "/health" { return IOSRunnerWireResponse(envelope: ["ok": true, "sessionID": session.sessionID, "requestID": requestID, "result": ["networkReady": true]]) }
            if route == "/probe" { return IOSRunnerWireResponse(envelope: ["ok": true, "sessionID": session.sessionID, "requestID": requestID, "result": ["automationReady": true]]) }
            return IOSRunnerWireResponse(envelope: self.actionResponse.merging(["sessionID": session.sessionID, "requestID": requestID]) { _, new in new })
        }, project: { self.root.appendingPathComponent("project") }, now: { self.now }, sleep: { self.now = self.now.addingTimeInterval($0) })
    }
    var input: [String: Any] { ["device": target.device, "sessionRoot": root.appendingPathComponent("store").path, "allowBundles": ["com.example.app"]] }
    func call(_ service: IOSRunnerService, _ operation: String, _ overrides: [String: Any] = [:]) throws -> [String: Any] {
        let output = try service.execute(operation: operation, payload: iosRunnerJSON(input.merging(overrides) { _, new in new }))
        return try #require(JSONSerialization.jsonObject(with: output) as? [String: Any])
    }
    func ready() throws -> IOSRunnerService {
        let service = IOSRunnerService(dependencies: dependencies)
        #expect(try call(service, "prepare")["ok"] as? Bool == true)
        #expect(try call(service, "start")["ok"] as? Bool == true)
        return service
    }
    func store() throws -> IOSRunnerSessionStore { try IOSRunnerSessionStore(root: root.appendingPathComponent("store"), device: target.device) }
}

@Suite("iOS Runner lifecycle contracts")
struct IOSRunnerLifecycleTests {
    @Test func prepareOwnsBuildAndDoesNotEnableProvisioningByDefault() throws {
        let harness = try IOSRunnerHarness(), service = IOSRunnerService(dependencies: harness.dependencies)
        #expect(try harness.call(service, "prepare")["ok"] as? Bool == true)
        let command = try #require(harness.commands.first)
        #expect(command.contains("build-for-testing"))
        #expect(command.contains("CODE_SIGNING_ALLOWED=NO"))
        #expect(!command.contains("-allowProvisioningUpdates"))
        #expect(command.contains("platform=iOS Simulator,id=" + harness.target.address))
    }
    @Test func freshSessionCredentialsAndAbsoluteProducts() throws {
        let harness = try IOSRunnerHarness(), service = try harness.ready()
        let first = try #require(try harness.store().read("session", as: IOSRunnerSession.self))
        let plist = try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: URL(fileURLWithPath: first.xctestrun)), format: nil) as? [String: Any])
        let target = try #require(plist["Tests"] as? [String: Any])
        #expect((target["TestBundlePath"] as? String)?.contains("__TESTROOT__") == false)
        let env = try #require(target["EnvironmentVariables"] as? [String: String])
        #expect(env["preserved"] == "yes")
        #expect(env["TRITON_RUNNER_ALLOWED_BUNDLES"] == "com.example.app,dev.tritonkit.runnerfixture")
        harness.alive = false
        #expect(try harness.call(service, "start")["ok"] as? Bool == true)
        let second = try #require(try harness.store().read("session", as: IOSRunnerSession.self))
        #expect(first.sessionID != second.sessionID)
        #expect(first.token != second.token)
        #expect(first.xctestrun != second.xctestrun)
        #expect((try FileManager.default.attributesOfItem(atPath: second.xctestrun)[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        let output = try iosRunnerJSON(harness.call(service, "status"))
        #expect(!String(decoding: output, as: UTF8.self).contains(second.token))
        #expect(!String(decoding: output, as: UTF8.self).contains(harness.target.address))
    }
    @Test func crossProcessLockRejectsAnotherOwner() throws {
        let harness = try IOSRunnerHarness(), first = try harness.store(), second = try harness.store()
        try first.locked {
            #expect(throws: IOSRunnerFailure.self) { try second.locked { true } }
        }
    }
    @Test func duplicateStartNeverLaunchesAnotherProcess() throws {
        let harness = try IOSRunnerHarness(), service = try harness.ready()
        let response = try harness.call(service, "start")
        #expect((response["error"] as? [String: Any])?["code"] as? String == "ios_runner_already_running")
        #expect(harness.terminated == 0)
    }
    @Test func unknownActionIsReturnedWithoutRetry() throws {
        let harness = try IOSRunnerHarness(), service = try harness.ready()
        harness.actionResponse = ["ok": false, "error": ["code": "ios_runner_transport_unknown", "delivery": "unknown", "retryable": false]]
        let before = harness.calls.count
        let response = try harness.call(service, "request", ["requestID": "action-one", "body": ["app": "target", "expectedBundle": "com.example.app", "operation": "tap"]])
        #expect(harness.calls.count == before + 1)
        #expect((response["error"] as? [String: Any])?["delivery"] as? String == "unknown")
        #expect((response["error"] as? [String: Any])?["retryable"] as? Bool == false)
    }
    @Test func targetBindingRejectsStaleStoreBeforeTransport() throws {
        let harness = try IOSRunnerHarness(), _ = try harness.ready()
        var dependencies = harness.dependencies
        dependencies.resolve = { _ in IOSRunnerTarget(device: harness.target.device, scope: "real", address: "different") }
        let response = try harness.call(IOSRunnerService(dependencies: dependencies), "request", ["body": ["expectedBundle": "com.example.app"]])
        #expect((response["error"] as? [String: Any])?["code"] as? String == "ios_runner_session_target_mismatch")
        #expect(harness.calls == ["/health", "/probe"])
    }
    @Test func bundleAllowlistRejectsBeforeTransport() throws {
        let harness = try IOSRunnerHarness(), service = try harness.ready()
        let response = try harness.call(service, "request", ["body": ["expectedBundle": "com.other.app", "operation": "activate"]])
        #expect((response["error"] as? [String: Any])?["code"] as? String == "ios_runner_bundle_not_allowed")
        #expect(harness.calls == ["/health", "/probe"])
    }
    @Test func stopDoesNotSignalUnverifiedPID() throws {
        let harness = try IOSRunnerHarness(), service = try harness.ready()
        harness.alive = false
        let response = try harness.call(service, "stop")
        #expect(response["ok"] as? Bool == true)
        #expect(harness.terminated == 0)
        #expect(!harness.calls.contains("/stop"))
    }
    @Test func stopFallsBackOnlyToRecordedOwnerAndVerifiesExit() throws {
        let harness = try IOSRunnerHarness(), service = try harness.ready()
        let response = try harness.call(service, "stop", ["timeout": 1])
        #expect(response["ok"] as? Bool == true)
        #expect(harness.terminated == 1)
        #expect((response["result"] as? [String: Any])?["nativeExited"] as? Bool == true)
    }
    @Test func expiredSessionCannotExecuteActions() throws {
        let harness = try IOSRunnerHarness(), service = try harness.ready()
        harness.now = harness.now.addingTimeInterval(601)
        let response = try harness.call(service, "request", ["body": ["expectedBundle": "com.example.app"]])
        #expect((response["error"] as? [String: Any])?["code"] as? String == "ios_runner_session_not_ready")
        #expect(harness.calls == ["/health", "/probe"])
    }
    @Test func receiptSanitizesNestedImageAndDoesNotRepeatAction() throws {
        let harness = try IOSRunnerHarness(), service = try harness.ready()
        harness.actionResponse = ["ok": true, "result": ["found": true, "receipt": ["response": ["ok": true, "result": ["pngBase64": "private-pixels", "token": "private-token", "byteCount": 20]]]]]
        let response = try harness.call(service, "receipt", ["actionRequestID": "already-existing"])
        #expect(harness.calls.last == "/receipt")
        let text = String(decoding: try iosRunnerJSON(response), as: UTF8.self)
        #expect(!text.contains("private-pixels"))
        #expect(!text.contains("private-token"))
    }
    @Test func explicitDeviceIsRequired() throws {
        let harness = try IOSRunnerHarness(), service = IOSRunnerService(dependencies: harness.dependencies)
        let output = try service.execute(operation: "start", payload: Data("{}".utf8))
        let response = try #require(JSONSerialization.jsonObject(with: output) as? [String: Any])
        #expect((response["error"] as? [String: Any])?["code"] as? String == "ios_runner_explicit_device_required")
        #expect(harness.commands.isEmpty)
    }
    @Test func simulatorTransportUsesLoopbackButKeepsNativeUDID() throws {
        let harness = try IOSRunnerHarness(), _ = try harness.ready()
        let session = try #require(try harness.store().read("session", as: IOSRunnerSession.self))
        #expect(iosRunnerConnection(session).targetAddress == "127.0.0.1")
        #expect(session.target.address == harness.target.address)
    }
    @Test func unknownProcessProbeCannotClaimStoppedOrSignal() throws {
        let harness = try IOSRunnerHarness(), _ = try harness.ready()
        var dependencies = harness.dependencies
        dependencies.ownsProcess = { _, _ in false }
        dependencies.processExists = { _ in nil }
        let response = try harness.call(IOSRunnerService(dependencies: dependencies), "stop", ["timeout": 1])
        #expect((response["error"] as? [String: Any])?["code"] as? String == "ios_runner_stop_unknown")
        #expect(harness.terminated == 0)
        #expect(try harness.store().read("session", as: IOSRunnerSession.self)?.state == "stop_unknown")
    }
    @Test func offlineCanonicalDeviceCanStopRecordedHostOwner() throws {
        let harness = try IOSRunnerHarness(), _ = try harness.ready()
        var dependencies = harness.dependencies
        dependencies.resolve = { _ in throw IOSRunnerFailure("offline", "No connected device.") }
        let response = try harness.call(IOSRunnerService(dependencies: dependencies), "stop", ["timeout": 1])
        #expect(response["ok"] as? Bool == true)
        #expect(harness.terminated == 1)
    }
    @Test func healthDoesNotClaimCurrentUIAutomationReadiness() throws {
        let harness = try IOSRunnerHarness(), service = try harness.ready()
        let result = try #require(try harness.call(service, "status")["result"] as? [String: Any])
        #expect(result["healthVerified"] as? Bool == true)
        #expect(result["automationReady"] is NSNull)
        #expect(result["automationPreviouslyVerified"] as? Bool == true)
        #expect(result["state"] as? String == "network_ready")
    }
    @Test func verifiedStopRemainsStoppedAfterItsOriginalTTL() throws {
        let harness = try IOSRunnerHarness(), service = try harness.ready()
        #expect(try harness.call(service, "stop", ["timeout": 1])["ok"] as? Bool == true)
        harness.now = harness.now.addingTimeInterval(601)
        let result = try #require(try harness.call(service, "status")["result"] as? [String: Any])
        #expect(result["state"] as? String == "stopped")
        #expect(result["expired"] as? Bool == true)
        #expect(result["ownershipVerified"] as? Bool == false)
    }
    @Test func alternateArtifactRootCannotBypassGlobalTargetOwner() throws {
        let harness = try IOSRunnerHarness(), service = try harness.ready()
        let response = try harness.call(service, "start", ["sessionRoot": harness.root.appendingPathComponent("another-artifact-root").path])
        #expect((response["error"] as? [String: Any])?["code"] as? String == "ios_runner_already_running")
        #expect(harness.terminated == 0)
    }
    @Test func changedBundledManifestRequiresPrepare() throws {
        let harness = try IOSRunnerHarness(), service = try harness.ready()
        harness.alive = false
        try Data("different-manifest".utf8).write(to: harness.root.appendingPathComponent("project/RUNNER_MANIFEST.json"))
        let response = try harness.call(service, "start")
        #expect((response["error"] as? [String: Any])?["code"] as? String == "ios_runner_prepare_required")
    }
    @Test func startupRequiresUIProbeAndCleansOnlyOwnedProcess() throws {
        let harness = try IOSRunnerHarness()
        var dependencies = harness.dependencies
        dependencies.exchange = { session, _, _, requestID, _ in IOSRunnerWireResponse(envelope: ["ok": true, "sessionID": session.sessionID, "requestID": requestID, "result": ["networkReady": true, "automationReady": false]]) }
        let service = IOSRunnerService(dependencies: dependencies)
        #expect(try harness.call(service, "prepare")["ok"] as? Bool == true)
        let response = try harness.call(service, "start", ["timeout": 1])
        #expect((response["error"] as? [String: Any])?["code"] as? String == "ios_runner_start_not_ready")
        #expect(harness.terminated == 1)
        #expect(try harness.store().read("session", as: IOSRunnerSession.self)?.state == "startup_failed")
    }
    @Test func startupClassifiesXCTestDriverChannelRefusal() throws {
        let harness = try IOSRunnerHarness()
        harness.nativeStderr = #"""
Running tests... PRIVATE-TOKEN /Users/private/secret
Connection peer refused channel request for "dtxproxy:XCTestDriverInterface:XCTestManager_IDEInterface"
Exiting due to IDE disconnection.
"""#
        var dependencies = harness.dependencies
        dependencies.exchange = { session, _, _, requestID, _ in
            IOSRunnerWireResponse(envelope: ["ok": false, "sessionID": session.sessionID, "requestID": requestID, "error": ["code": "ios_runner_transport_unknown"]])
        }
        let service = IOSRunnerService(dependencies: dependencies)
        #expect(try harness.call(service, "prepare")["ok"] as? Bool == true)
        let response = try harness.call(service, "start", ["timeout": 1])
        #expect((response["error"] as? [String: Any])?["code"] as? String == "ios_runner_xctest_driver_channel_refused")
        #expect(((response["error"] as? [String: Any])?["message"] as? String)?.contains("XCTest") == true)
        #expect(harness.terminated == 1)
        let diagnostic = try #require((response["error"] as? [String: Any])?["startup"] as? [String: String])
        #expect(diagnostic["launch"] == "verified")
        #expect(diagnostic["transport"] == "unverified")
        #expect(diagnostic["health"] == "unverified")
        #expect(diagnostic["uiAutomation"] == "unverified")
        #expect(harness.now.timeIntervalSince1970 < 1001)
        let serialized = String(decoding: try iosRunnerJSON(response), as: UTF8.self)
        #expect(!serialized.contains("PRIVATE-TOKEN"))
        #expect(!serialized.contains("/Users/private"))
    }
    @Test func recoveredHealthOverridesEarlierDriverLog() throws {
        let harness = try IOSRunnerHarness()
        harness.nativeStderr = "Connection peer refused channel request for dtxproxy:XCTestDriverInterface:XCTestManager_IDEInterface"
        let service = IOSRunnerService(dependencies: harness.dependencies)
        #expect(try harness.call(service, "prepare")["ok"] as? Bool == true)
        #expect(try harness.call(service, "start")["ok"] as? Bool == true)
        #expect(harness.terminated == 0)
    }
    @Test func readinessFailureDistinguishesHealthFromAutomation() throws {
        let harness = try IOSRunnerHarness()
        var dependencies = harness.dependencies
        dependencies.exchange = { session, route, _, requestID, _ in
            IOSRunnerWireResponse(envelope: ["ok": true, "sessionID": session.sessionID, "requestID": requestID,
                "result": ["networkReady": route == "/health", "automationReady": false]])
        }
        let service = IOSRunnerService(dependencies: dependencies)
        #expect(try harness.call(service, "prepare")["ok"] as? Bool == true)
        let response = try harness.call(service, "start", ["timeout": 1])
        let diagnostic = try #require((response["error"] as? [String: Any])?["startup"] as? [String: String])
        #expect(diagnostic["transport"] == "verified")
        #expect(diagnostic["health"] == "verified")
        #expect(diagnostic["uiAutomation"] == "unverified")
    }
    @Test func nativeLaunchFailureDoesNotPublishPrivateError() throws {
        let harness = try IOSRunnerHarness()
        var dependencies = harness.dependencies
        dependencies.launch = { _, _ in throw NSError(domain: "PRIVATE-LAUNCH-PATH", code: 1) }
        let service = IOSRunnerService(dependencies: dependencies)
        #expect(try harness.call(service, "prepare")["ok"] as? Bool == true)
        let response = try harness.call(service, "start", ["timeout": 1])
        let error = try #require(response["error"] as? [String: Any])
        #expect(error["code"] as? String == "ios_runner_native_launch_failed")
        #expect((error["startup"] as? [String: String])?["launch"] == "unverified")
        #expect(!String(decoding: try iosRunnerJSON(response), as: UTF8.self).contains("PRIVATE-LAUNCH-PATH"))
    }
    @Test func nativeExitIsSeparateFromReadinessDeadline() throws {
        let harness = try IOSRunnerHarness()
        var dependencies = harness.dependencies
        dependencies.launch = { _, _ in 1234 }
        let service = IOSRunnerService(dependencies: dependencies)
        #expect(try harness.call(service, "prepare")["ok"] as? Bool == true)
        let response = try harness.call(service, "start", ["timeout": 1])
        let error = try #require(response["error"] as? [String: Any])
        #expect(error["code"] as? String == "ios_runner_native_exited")
        #expect((error["startup"] as? [String: String])?["launch"] == "verified")
        #expect(harness.terminated == 0)
    }
    @Test func nativeDiagnosticReadIsBoundedAndRejectsSymlinksAndFIFOs() throws {
        let harness = try IOSRunnerHarness()
        let text = "Connection peer refused channel request for dtxproxy:XCTestDriverInterface:XCTestManager_IDEInterface\n"
        let log = harness.root.appendingPathComponent("native.stderr")
        try Data((String(repeating: "x", count: 200_000) + "\n" + text).utf8).write(to: log)
        #expect(iosRunnerDriverChannelRefused(directory: harness.root))
        try Data((text + String(repeating: "x", count: 200_000)).utf8).write(to: log)
        #expect(!iosRunnerDriverChannelRefused(directory: harness.root))
        try FileManager.default.removeItem(at: log)
        let target = harness.root.appendingPathComponent("private-log")
        try Data(text.utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: log, withDestinationURL: target)
        #expect(!iosRunnerDriverChannelRefused(directory: harness.root))
        try FileManager.default.removeItem(at: log)
        #expect(mkfifo(log.path, 0o600) == 0)
        #expect(!iosRunnerDriverChannelRefused(directory: harness.root))
    }
    @Test func unknownScreenshotRecoversVerifiedOriginalReceiptWithoutRetaking() throws {
        let harness = try IOSRunnerHarness(), service = try harness.ready()
        harness.actionResponse = ["ok": false, "error": ["code": "ios_runner_transport_unknown", "delivery": "unknown", "retryable": false]]
        let first = try harness.call(service, "request", ["requestID": "image-original", "body": ["app": "target", "expectedBundle": "com.example.app", "operation": "screenshot"]])
        #expect(first["ok"] as? Bool == false)
        let session = try #require(try harness.store().read("session", as: IOSRunnerSession.self))
        let png = Data([137,80,78,71,13,10,26,10, 0,0,0,13,73,72,68,82, 0,0,0,1,0,0,0,1, 8,6,0,0,0,0,0,0,0])
        harness.actionResponse = ["ok": true, "result": ["found": true, "receipt": ["ok": true, "sessionID": session.sessionID, "requestID": "image-original", "result": ["pngBase64": png.base64EncodedString(), "byteCount": png.count]]]]
        let output = harness.root.appendingPathComponent("recovered.png")
        let receipt = try harness.call(service, "receipt", ["actionRequestID": "image-original", "screenshotOutput": output.path])
        #expect(receipt["ok"] as? Bool == true)
        #expect(try Data(contentsOf: output) == png)
        #expect((try FileManager.default.attributesOfItem(atPath: output.path)[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        #expect(harness.calls.filter { $0 == "/crossApp" }.count == 1)
        #expect(harness.calls.filter { $0 == "/receipt" }.count == 1)
        #expect(!String(decoding: try iosRunnerJSON(receipt), as: UTF8.self).contains("pngBase64"))
    }
    @Test func receiptImageMustMatchOriginalActionAndSession() throws {
        let harness = try IOSRunnerHarness(), service = try harness.ready()
        harness.actionResponse = ["ok": true, "result": ["found": true, "receipt": ["ok": true, "sessionID": "another-session", "requestID": "image-original", "result": ["pngBase64": "private", "byteCount": 7]]]]
        let output = harness.root.appendingPathComponent("mismatched.png")
        let receipt = try harness.call(service, "receipt", ["actionRequestID": "image-original", "screenshotOutput": output.path])
        #expect((receipt["error"] as? [String: Any])?["code"] as? String == "ios_runner_receipt_image_unverified")
        #expect(!FileManager.default.fileExists(atPath: output.path))
        #expect(!String(decoding: try iosRunnerJSON(receipt), as: UTF8.self).contains("private"))
    }
    @Test func existingScreenshotOutputIsRejectedBeforeDeviceAction() throws {
        let harness = try IOSRunnerHarness(), service = try harness.ready()
        let output = harness.root.appendingPathComponent("existing.png")
        try Data("keep".utf8).write(to: output)
        let response = try harness.call(service, "request", ["body": ["app": "target", "expectedBundle": "com.example.app", "operation": "screenshot"], "screenshotOutput": output.path])
        #expect((response["error"] as? [String: Any])?["code"] as? String == "ios_runner_artifact_exists")
        #expect(harness.calls == ["/health", "/probe"])
        #expect(try Data(contentsOf: output) == Data("keep".utf8))
    }
    @Test func artifactDiskFailurePreservesReceivedActionIdentity() throws {
        let harness = try IOSRunnerHarness(), _ = try harness.ready()
        let png = Data([137,80,78,71,13,10,26,10, 0,0,0,13,73,72,68,82, 0,0,0,1,0,0,0,1, 8,6,0,0,0,0,0,0,0])
        harness.actionResponse = ["ok": true, "result": ["pngBase64": png.base64EncodedString(), "byteCount": png.count]]
        var dependencies = harness.dependencies
        dependencies.writeArtifact = { _, _ in throw CocoaError(.fileWriteOutOfSpace) }
        let response = try harness.call(IOSRunnerService(dependencies: dependencies), "request", ["requestID": "disk-full-action", "body": ["app": "target", "expectedBundle": "com.example.app", "operation": "screenshot"], "screenshotOutput": harness.root.appendingPathComponent("new.png").path])
        #expect(response["requestID"] as? String == "disk-full-action")
        #expect(response["sessionID"] is String)
        #expect(response["artifactError"] is [String: Any])
        #expect((response["error"] as? [String: Any])?["delivery"] as? String == "response_received")
        #expect(harness.calls.filter { $0 == "/crossApp" }.count == 1)
    }
    @Test func receiptDiskFailurePreservesSuccessfulActionEnvelope() throws {
        let harness = try IOSRunnerHarness(), _ = try harness.ready()
        var dependencies = harness.dependencies
        dependencies.writeReceipt = { _, _ in throw CocoaError(.fileWriteOutOfSpace) }
        let response = try harness.call(IOSRunnerService(dependencies: dependencies), "request", ["requestID": "receipt-disk-full", "body": ["app": "target", "expectedBundle": "com.example.app", "operation": "activate"]])
        #expect(response["ok"] as? Bool == true)
        #expect(response["requestID"] as? String == "receipt-disk-full")
        #expect(response["receiptError"] is [String: Any])
        #expect(harness.calls.filter { $0 == "/crossApp" }.count == 1)
    }
    @Test func exclusiveArtifactCreationPreservesExistingFile() throws {
        let harness = try IOSRunnerHarness(), output = harness.root.appendingPathComponent("image.png")
        try IOSRunnerSessionStore.writeExclusive(Data("original".utf8), to: output)
        #expect(throws: IOSRunnerFailure.self) { try IOSRunnerSessionStore.writeExclusive(Data("replacement".utf8), to: output) }
        #expect(try Data(contentsOf: output) == Data("original".utf8))
    }
}
