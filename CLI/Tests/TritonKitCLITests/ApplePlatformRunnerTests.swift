import XCTest
@testable import TritonKitCLI
import TritonKitShared

final class ApplePlatformRunnerTests: XCTestCase {
    func testCommandBindsExactSimulatorAndAction() throws {
        let request = try makeApplePlatformRunnerRequest(
            platform: .tvos,
            action: .remoteSelect,
            device: "11111111-1111-1111-1111-111111111111",
            xctestrun: "/private/runner/tv.xctestrun",
            testIdentifier: "ControlTests/testRemoteSelect",
            resultBundle: "/private/runner/result.xcresult",
            nonce: "nonce-123",
            timeout: 45,
            executeRunner: true,
            confirm: true,
            auditRecord: "audit-1"
        )
        let command = try makeApplePlatformRunnerCommand(request)
        XCTAssertEqual(command.executable, "xcodebuild")
        XCTAssertEqual(command.arguments, [
            "-xctestrun", "/private/runner/tv.xctestrun",
            "-destination", "platform=tvOS Simulator,id=11111111-1111-1111-1111-111111111111",
            "-resultBundlePath", "/private/runner/result.xcresult",
            "-only-testing:ControlTests/testRemoteSelect",
            "test-without-building"
        ])
        XCTAssertEqual(command.riskLevel, .automation)
        XCTAssertTrue(command.requiredConfig.contains(.auditRecord))
        XCTAssertTrue(command.redactedArgumentIndexes.contains(3))
    }

    func testRejectsAliasAndMissingExecutionGate() {
        XCTAssertThrowsError(try makeApplePlatformRunnerRequest(
            platform: .watchos, action: .crownRotate, device: "booted",
            xctestrun: "/tmp/a.xctestrun", testIdentifier: "ControlTests/testCrown",
            resultBundle: nil, nonce: "n", timeout: 30, executeRunner: true,
            confirm: true, auditRecord: "a"
        )) { error in
            XCTAssertEqual((error as? HostApplePlatformControlError)?.code, "invalid_runner_device")
        }
        XCTAssertThrowsError(try makeApplePlatformRunnerRequest(
            platform: .watchos, action: .crownRotate, device: "11111111-1111-1111-1111-111111111111",
            xctestrun: "/tmp/a.xctestrun", testIdentifier: "ControlTests/testCrown",
            resultBundle: nil, nonce: "nonce-123", timeout: 30, executeRunner: false,
            confirm: true, auditRecord: "a"
        )) { error in
            XCTAssertEqual((error as? HostApplePlatformControlError)?.code, "runner_execution_not_authorized")
        }
    }

    func testStrictResultRequiresTargetActionNonceAndPostcondition() throws {
        let json = #"{"ok":true,"platform":"tvos","action":"remote-select","device":"11111111-1111-1111-1111-111111111111","nonce":"nonce-123","eventDelivered":true,"postconditionVerified":true}"#.data(using: .utf8)!
        let result = try verifyApplePlatformRunnerResult(json, platform: .tvos, action: .remoteSelect, device: "11111111-1111-1111-1111-111111111111", nonce: "nonce-123")
        XCTAssertEqual(result.outcome, .executed)
        XCTAssertTrue(result.actionsExecuted)
    }

    func testTargetBindingRequiresExactRuntimeFamily() throws {
        let fixture = #"{"devices":{"com.apple.CoreSimulator.SimRuntime.tvOS-27-0":[{"udid":"11111111-1111-1111-1111-111111111111","name":"Apple TV","state":"Shutdown","isAvailable":true}]}}"#.data(using: .utf8)!
        XCTAssertNoThrow(try validateApplePlatformRunnerTarget(fixture, platform: .tvos, device: "11111111-1111-1111-1111-111111111111"))
        XCTAssertThrowsError(try validateApplePlatformRunnerTarget(fixture, platform: .watchos, device: "11111111-1111-1111-1111-111111111111")) { error in
            XCTAssertEqual((error as? HostApplePlatformControlError)?.code, "runner_target_family_mismatch")
        }
    }

    func testStrictResultRejectsMismatchedNonce() throws {
        let json = #"{"ok":true,"platform":"watchos","action":"crown-rotate","device":"11111111-1111-1111-1111-111111111111","nonce":"other","eventDelivered":true,"postconditionVerified":true}"#.data(using: .utf8)!
        XCTAssertThrowsError(try verifyApplePlatformRunnerResult(json, platform: .watchos, action: .crownRotate, device: "11111111-1111-1111-1111-111111111111", nonce: "nonce-123")) { error in
            XCTAssertEqual((error as? HostApplePlatformControlError)?.code, "runner_result_mismatch")
        }
    }
}
