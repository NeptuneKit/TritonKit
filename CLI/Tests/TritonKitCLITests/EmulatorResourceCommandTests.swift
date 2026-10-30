import ArgumentParser
import Foundation
import XCTest
import TritonKitShared
@testable import TritonKitCLI

final class EmulatorResourceCommandTests: XCTestCase {
    func testDeviceRootDispatchesAllResourceActions() throws {
        for action in ["profiles", "features", "status", "doctor", "plan", "apply", "verify", "restore", "measure"] {
            var args = ["resource", action, "--platform", "android", "--json"]
            if !["profiles", "features"].contains(action) { args += ["--device", "emulator-5556"] }
            if ["apply", "verify", "restore"].contains(action) { args += ["--receipt", "/private/tmp/resource-receipt.json"] }
            let command = try Device.parseAsRoot(args)
            XCTAssertEqual(type(of: command).configuration.commandName, action)
        }
    }

    func testPlatformTargetAndReceiptAreExplicit() {
        XCTAssertThrowsError(try Device.parseAsRoot(["resource", "profiles"]))
        XCTAssertThrowsError(try Device.parseAsRoot(["resource", "status", "--platform", "android"]))
        XCTAssertThrowsError(try Device.parseAsRoot(["resource", "profiles", "--platform", "ios"]))
        for action in ["apply", "verify", "restore"] {
            XCTAssertThrowsError(try Device.parseAsRoot(["resource", action, "--platform", "harmony", "--device", "127.0.0.1:10101"]))
        }
    }

    func testPlanAndApplyShareFeatureSelectionAndOverrides() throws {
        let args = ["--platform", "android", "--device", "emulator-5556", "--profile", "stock", "--disable", "assistant,music", "--keep", "bluetooth", "--adb", "/opt/android/adb", "--hdc", "/opt/harmony/hdc", "--format", "text"]
        let plan = try DeviceResourcePlan.parseAsRoot(args) as! DeviceResourcePlan
        let apply = try DeviceResourceApply.parseAsRoot(args + ["--receipt", "/private/tmp/resource.json", "--confirm", "--json"]) as! DeviceResourceApply
        XCTAssertEqual(plan.selection.profile, apply.selection.profile)
        XCTAssertEqual(plan.selection.disable, "assistant,music")
        XCTAssertEqual(plan.selection.keep, "bluetooth")
        XCTAssertEqual(apply.options.adb, "/opt/android/adb")
        XCTAssertEqual(apply.options.hdc, "/opt/harmony/hdc")
        XCTAssertEqual(apply.options.outputFormat, .json)
        XCTAssertEqual(plan.options.outputFormat, .text)
        XCTAssertTrue(apply.confirm)
    }

    func testDefaultsDoNotImplicitlyConfirmMutations() throws {
        let apply = try DeviceResourceApply.parseAsRoot(["--platform", "android", "--device", "emulator-5556", "--receipt", "/private/tmp/resource.json"]) as! DeviceResourceApply
        XCTAssertFalse(apply.confirm)
        XCTAssertEqual(apply.selection.profile, "ui-minimal")
        XCTAssertEqual(apply.options.adb, "adb")
        XCTAssertEqual(apply.options.hdc, "hdc")
        XCTAssertEqual(apply.options.outputFormat, .json)
    }

    func testRecursiveSchemaDescribesScopeConfirmationAndOutput() throws {
        let device = try XCTUnwrap(commandSchemas().first { $0.name == "device" })
        let resource = try XCTUnwrap(device.subcommands.first { $0.name == "resource" })
        XCTAssertEqual(Set(resource.subcommands.map(\.name)), ["profiles", "features", "status", "doctor", "plan", "apply", "verify", "restore", "measure"])
        let decoded = try JSONDecoder().decode(TKCommandSubcommandSchema.self, from: JSONEncoder().encode(resource))
        XCTAssertEqual(decoded, resource)
        for child in resource.subcommands {
            XCTAssertTrue(child.requiredOptions.contains("--platform"))
            XCTAssertEqual(child.requiresTarget, !["profiles", "features"].contains(child.name))
            XCTAssertEqual(child.requiresConfirmation, ["apply", "restore"].contains(child.name))
            XCTAssertEqual(child.outputSelectors, ["device.resource"])
            XCTAssertFalse(child.retryable)
        }
        let output = try XCTUnwrap(device.outputContracts.first { $0.selector == "device.resource" })
        XCTAssertTrue(Set(["ok", "action", "platform", "identity", "features", "states", "receipt", "partial", "error", "memory", "hostMemory", "profiles", "businessVerified", "hostSavingsVerified"]).isSubset(of: Set(output.fields.map(\.name))))
        let hostMemory = try XCTUnwrap(output.fields.first { $0.name == "hostMemory" })
        XCTAssertEqual(hostMemory.type, "EmulatorResourceHostMemory")
        XCTAssertFalse(hostMemory.required)
        XCTAssertEqual(try XCTUnwrap(output.fields.first { $0.name == "error" }).type, "EmulatorResourceFailure")
        XCTAssertTrue(device.failureCodes.contains("resource_identity_mismatch"))
        XCTAssertTrue(device.failureCodes.contains("resource_permission_denied"))
    }

    func testResourceRecoveryPreservesReceiptAndDoesNotReplayUncertainWrites() {
        let groups: [([String], [String])] = [
            (["resource_confirmation_required", "resource_invalid_action", "resource_invalid_feature", "resource_invalid_item", "resource_invalid_profile", "resource_invalid_state", "resource_control_permission_unverified", "resource_permission_denied", "resource_unsupported_control"], ["diagnose", "plan"]),
            (["resource_busy", "resource_lock_failed"], ["diagnose", "prepare-target", "plan"]),
            (["resource_identity_mismatch", "resource_identity_unavailable", "resource_invalid_identity", "resource_invalid_target", "resource_target_not_ready"], ["diagnose", "observe", "prepare-target", "plan"]),
            (["resource_invalid_receipt", "resource_receipt_exists", "resource_receipt_write_failed"], ["archive", "diagnose", "plan"]),
            (["resource_invalid_output", "resource_memory_invalid_output", "resource_output_invalid", "resource_output_truncated", "resource_state_unavailable"], ["diagnose", "observe", "archive"]),
            (["resource_command_failed", "resource_failed", "resource_state_mismatch", "resource_verification_failed", "resource_write_unconfirmed"], ["diagnose", "observe", "verify", "archive"]),
            (["resource_state_conflict"], ["diagnose", "observe", "plan"]),
        ]
        XCTAssertEqual(Set(groups.flatMap { $0.0 }), Set(emulatorResourceFailureCodes))
        for (codes, categories) in groups {
            for code in codes {
                XCTAssertEqual(TKCommandRecoveryCommand.recoveryCategories(forFailureCode: code), categories, code)
                XCTAssertEqual(recoveryCategories(forFailureCode: code), Set(categories), code)
                XCTAssertTrue(Set(categories).isDisjoint(with: ["act", "replay"]), code)
            }
        }
        XCTAssertNil(TKCommandRecoveryCommand.emulatorResourceRecoveryCategories(forFailureCode: "resource_future_extension"))
        XCTAssertTrue(TKCommandRecoveryCommand.recoveryCategories(forFailureCode: "resource_future_extension").isEmpty)
        XCTAssertNil(recoveryCategories(forFailureCode: "resource_future_extension"))
    }
}
