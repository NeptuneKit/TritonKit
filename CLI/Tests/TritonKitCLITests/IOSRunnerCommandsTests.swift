import ArgumentParser
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("iOS resident Runner CLI contracts")
struct IOSRunnerCommandsTests {
    @Test func explicitDeviceRequired() {
        for operation in ["doctor", "prepare", "start", "status", "stop", "inspect", "activate", "scroll"] {
            #expect(throws: Error.self) { _ = try DeviceRunner.parseAsRoot([operation]) }
        }
    }
    @Test func selectorsAreExclusive() {
        #expect(throws: Error.self) { _ = try IOSRunnerTap.parse(["--device", "ios-real:test", "--bundle-id", "test.app"]) }
        #expect(throws: Error.self) { _ = try IOSRunnerTap.parse(["--device", "ios-real:test", "--bundle-id", "test.app", "--identifier", "a", "--label", "b"]) }
    }
    @Test func startIsExplicitAndBounded() throws {
        let command = try IOSRunnerStart.parse(["--device", "sim:test", "--allow-bundle", "test.app", "--allow-bundle", "other.app"])
        let payload = try command.payload()
        #expect(payload["device"] as? String == "sim:test")
        #expect(payload["allowProvisioning"] == nil)
        #expect(payload["allowBundles"] as? [String] == ["test.app", "other.app"])
        #expect(payload["ttl"] as? Double == 600)
        #expect(throws: Error.self) { _ = try IOSRunnerStart.parse(["--device", "sim:test", "--ttl", "nan"]) }
        #expect(throws: Error.self) { _ = try IOSRunnerStart.parse(["--device", "sim:test", "--ttl", "3601"]) }
    }
    @Test func typedTapMapsToExactObservedSelector() throws {
        let command = try IOSRunnerTap.parse(["--device", "ios-real:test", "--bundle-id", "test.app", "--identifier", "seven", "--request-id", "action-1"])
        let payload = try command.payload()
        let body = try #require(payload["body"] as? [String: Any])
        #expect(body["app"] as? String == "target")
        #expect(body["expectedBundle"] as? String == "test.app")
        #expect(body["operation"] as? String == "tap")
        #expect((body["selector"] as? [String: String]) == ["kind": "identifier", "value": "seven"])
        #expect(payload["route"] as? String == "/crossApp")
        #expect(payload["requestID"] as? String == "action-1")
    }
    @Test func boundedFilesRejectArrayAndOversizedBody() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("body.json")
        try Data("[]".utf8).write(to: file)
        #expect(throws: Error.self) { _ = try iosRunnerBodyFile(file.path) }
        try Data(repeating: 32, count: 65537).write(to: file)
        #expect(throws: Error.self) { _ = try iosRunnerBodyFile(file.path) }
    }
    @Test func operationDefaultsAndRawRequestValidation() throws {
        #expect(try IOSRunnerPrepare.parse(["--device", "sim:test"]).payload()["timeout"] as? Double == 600)
        #expect(try IOSRunnerStart.parse(["--device", "sim:test"]).payload()["timeout"] as? Double == 120)
        #expect(try IOSRunnerStatus.parse(["--device", "sim:test"]).payload()["timeout"] as? Double == 10)
        #expect(throws: Error.self) { _ = try IOSRunnerRequest.parse(["--device", "sim:test"]) }
        #expect(throws: Error.self) { _ = try IOSRunnerRequest.parse(["--device", "sim:test", "--body-file", "body.json", "--route", "/stop"]) }
        #expect(throws: Error.self) { _ = try IOSRunnerInspect.parse(["--device", "sim:test", "--bundle-id", "test.app", "--timeout", "121"]) }
    }
    @Test func signingIsPrepareOnlyAndReceiptRecoversScreenshot() throws {
        #expect(throws: Error.self) { _ = try IOSRunnerStart.parse(["--device", "sim:test", "--team", "ABCDEFGHIJ"]) }
        #expect(throws: Error.self) { _ = try IOSRunnerStart.parse(["--device", "sim:test", "--allow-provisioning-updates"]) }
        let command = try IOSRunnerReceipt.parse(["--device", "sim:test", "--request-id", "shot-1", "--output", "/private/recovered.png"])
        #expect(try command.payload()["screenshotOutput"] as? String == "/private/recovered.png")
        #expect(try command.payload()["requestID"] as? String == "shot-1")
        let prepare = try IOSRunnerPrepare.parse(["--device", "sim:test"])
        #expect(try prepare.payload()["allowProvisioning"] as? Bool == false)
    }
    @Test func residentFailuresUseSpecificRecoveryFamilies() {
        #expect(TKCommandRecoveryCommand.residentRunnerRecoveryCategories(forFailureCode: "ios_runner_transport_unknown") == ["diagnose", "observe", "archive", "plan"])
        #expect(TKCommandRecoveryCommand.residentRunnerRecoveryCategories(forFailureCode: "ios_runner_owner_unknown") == ["diagnose", "prepare-target", "plan"])
        #expect(TKCommandRecoveryCommand.residentRunnerRecoveryCategories(forFailureCode: "cross_app_unobserved") == ["diagnose", "observe", "plan"])
        #expect(TKCommandRecoveryCommand.residentRunnerRecoveryCategories(forFailureCode: "ios_runner_invalid_team") == ["diagnose", "project", "plan"])
        #expect(TKCommandRecoveryCommand.residentRunnerRecoveryCategories(forFailureCode: "ios_runner_receipt_save_failed") == ["diagnose", "archive", "plan"])
        #expect(TKCommandRecoveryCommand.residentRunnerRecoveryCategories(forFailureCode: "ios_runner_future_unknown") == nil)
    }
    @Test func schemaAndCapabilitiesAreHostOnly() throws {
        let device = try #require(commandSchemas().first { $0.name == "device" })
        let runner = try #require(device.subcommands.first { $0.name == "runner" })
        #expect(runner.subcommands.map(\.name).contains("start"))
        #expect(runner.subcommands.allSatisfy { !$0.name.contains(".") })
        for name in iosRunnerCapabilityNames {
            #expect(runtimeCapabilityGroup(for: name) == "host")
            #expect(!runtimeCapabilityRequiresServer(name))
        }
    }
}
