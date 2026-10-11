import Foundation
import Darwin
import TritonKitShared

/// The smallest executable boundary for a specialized Apple UI-test runner.
/// The runner itself is an external xctestrun bundle; Triton only accepts a
/// result that binds the exact target, action, nonce, and postcondition.
enum HostApplePlatformRunnerOutcome: String, Codable, Equatable {
    case planned
    case executed
    case failed
    case unknown
}

struct HostApplePlatformRunnerRequest: Equatable {
    let platform: HostApplePlatformControlPlatform
    let action: HostApplePlatformControlAction
    let device: String
    let xctestrun: String
    let testIdentifier: String
    let resultBundle: String?
    let nonce: String
    let timeout: Double
    let executeRunner: Bool
    let confirm: Bool
    let auditRecord: String
}

struct HostApplePlatformRunnerReceipt: Encodable, Equatable {
    let ok: Bool
    let action = "device.platform-control"
    let platform: HostApplePlatformControlPlatform
    let control: HostApplePlatformControlAction
    let outcome: HostApplePlatformRunnerOutcome
    let executable: Bool
    let actionsExecuted: Bool
    let targetBinding: String
    let nonce: String
    let sourceCommand: String?
    let verification: String
    let failureCode: String?
}


private func isApplePlatformRunnerAction(platform: HostApplePlatformControlPlatform, action: HostApplePlatformControlAction) -> Bool {
    switch (platform, action) {
    case (.watchos, .crownRotate), (.watchos, .actionButton),
         (.tvos, .remoteUp), (.tvos, .remoteDown), (.tvos, .remoteLeft),
         (.tvos, .remoteRight), (.tvos, .remoteSelect), (.tvos, .remoteMenu):
        return true
    default:
        return false
    }
}

private struct RawApplePlatformRunnerResult: Decodable {
    let ok: Bool
    let platform: String
    let action: String
    let device: String
    let nonce: String
    let eventDelivered: Bool
    let postconditionVerified: Bool
}

func makeApplePlatformRunnerRequest(
    platform: HostApplePlatformControlPlatform,
    action: HostApplePlatformControlAction,
    device: String,
    xctestrun: String,
    testIdentifier: String,
    resultBundle: String?,
    nonce: String,
    timeout: Double,
    executeRunner: Bool,
    confirm: Bool,
    auditRecord: String
) throws -> HostApplePlatformRunnerRequest {
    guard isApplePlatformRunnerAction(platform: platform, action: action) else {
        throw HostApplePlatformControlError(code: "unsupported_runner_action", message: "This platform control has no executable XCTest runner contract.", hint: "Use a supported watchOS Crown/Action or tvOS remote action, or keep the request fixture-only.")
    }
    guard isExactSimulatorUDID(device) else {
        throw HostApplePlatformControlError(code: "invalid_runner_device", message: "Runner execution requires one exact Simulator UDID.", hint: "Do not use booted, current, aliases, names, or physical-device selectors.")
    }
    guard xctestrun.hasPrefix("/"), !xctestrun.contains("\0") else {
        throw HostApplePlatformControlError(code: "invalid_runner_bundle", message: "The xctestrun path must be an absolute local path.", hint: "Pass a fresh private .xctestrun path.")
    }
    guard !testIdentifier.isEmpty, testIdentifier.count <= 256, testIdentifier.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "./_-".contains($0)) }) else {
        throw HostApplePlatformControlError(code: "invalid_runner_test", message: "The XCTest identifier is malformed.", hint: "Use Target/Class or Target/Class/testMethod without whitespace.")
    }
    guard nonce.count >= 8, nonce.count <= 128, nonce.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || ".-_".contains($0)) }) else {
        throw HostApplePlatformControlError(code: "invalid_runner_nonce", message: "The runner nonce is malformed.", hint: "Use 8...128 ASCII letters, numbers, dot, dash, or underscore characters.")
    }
    guard timeout.isFinite, timeout > 0, timeout <= 3600 else {
        throw HostApplePlatformControlError(code: "invalid_runner_timeout", message: "Runner timeout must be between 0 and 3600 seconds.", hint: "Pass a finite positive --timeout.")
    }
    guard !auditRecord.isEmpty, auditRecord.count <= 128, auditRecord.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || ".-_".contains($0)) }) else {
        throw HostApplePlatformControlError(code: "invalid_runner_audit_record", message: "An audit record is required for specialized input execution.", hint: "Pass a bounded opaque --audit-record value.")
    }
    guard executeRunner, confirm else {
        throw HostApplePlatformControlError(code: "runner_execution_not_authorized", message: "Specialized input execution requires --execute-runner and --confirm.", hint: "Without both flags Triton only returns the fixture-only contract.")
    }
    guard let resultBundle = resultBundle, resultBundle.hasPrefix("/"), !resultBundle.contains("\0") else {
        throw HostApplePlatformControlError(code: "runner_result_bundle_required", message: "Execution requires an absolute result bundle path.", hint: "Pass a fresh private --result-bundle path.")
    }
    return HostApplePlatformRunnerRequest(platform: platform, action: action, device: device, xctestrun: xctestrun, testIdentifier: testIdentifier, resultBundle: resultBundle, nonce: nonce, timeout: timeout, executeRunner: executeRunner, confirm: confirm, auditRecord: auditRecord)
}

func makeApplePlatformRunnerCommand(_ request: HostApplePlatformRunnerRequest) throws -> TKHostCommand {
    let destinationPlatform = request.platform == .watchos ? "watchOS Simulator" : "tvOS Simulator"
    var arguments = ["-xctestrun", request.xctestrun, "-destination", "platform=\(destinationPlatform),id=\(request.device)"]
    if let resultBundle = request.resultBundle { arguments += ["-resultBundlePath", resultBundle] }
    arguments += ["-only-testing:\(request.testIdentifier)", "test-without-building"]
    return TKHostCommand(
        executable: "xcodebuild",
        arguments: arguments,
        redactedArgumentIndexes: Set([1, 3, 5].filter { $0 < arguments.count }),
        riskLevel: .automation,
        requiredConfig: [.target, .timeout, .auditRecord, .artifactDir],
        defaultTimeoutSeconds: request.timeout,
        capturesArtifacts: true,
        sensitiveOutput: true
    )
}


func validateApplePlatformRunnerTarget(_ data: Data, platform: HostApplePlatformControlPlatform, device: String) throws {
    let targets: [TKHostSimulatorTarget]
    do { targets = try TKSimctlDeviceListParser.parse(data) }
    catch {
        throw HostApplePlatformControlError(code: "runner_target_inventory_invalid", message: "Simulator inventory could not be parsed for runner target binding.", hint: "Inspect the private simulator inventory and do not retry input automatically.")
    }
    guard let target = targets.first(where: { $0.udid == device && $0.isAvailable }) else {
        throw HostApplePlatformControlError(code: "runner_target_unavailable", message: "The exact Simulator UDID is not available.", hint: "Use an available dedicated watchOS or tvOS Simulator UDID.")
    }
    let runtime = target.runtimeIdentifier.lowercased()
    let matches = (platform == .watchos && runtime.contains("watchos-")) || (platform == .tvos && runtime.contains("tvos-"))
    guard matches else {
        throw HostApplePlatformControlError(code: "runner_target_family_mismatch", message: "The exact Simulator runtime family does not match the requested platform.", hint: "Select a dedicated watchOS or tvOS Simulator; iOS and visionOS runtimes are rejected.")
    }
}

private func validateRunnerArtifactPaths(_ request: HostApplePlatformRunnerRequest) throws {
    var info = stat()
    guard lstat(request.xctestrun, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else {
        throw HostApplePlatformControlError(code: "runner_bundle_unavailable", message: "The xctestrun bundle is missing or is not a regular file.", hint: "Build the dedicated runner with build-for-testing and pass its private .xctestrun path.")
    }
    guard request.xctestrun.hasSuffix(".xctestrun"), let resultBundle = request.resultBundle else { return }
    guard lstat(resultBundle, &info) != 0 else {
        throw HostApplePlatformControlError(code: "runner_result_path_exists", message: "The result bundle path already exists.", hint: "Use a fresh private .xcresult path; existing paths are never overwritten.")
    }
}

func verifyApplePlatformRunnerResult(
    _ data: Data,
    platform: HostApplePlatformControlPlatform,
    action: HostApplePlatformControlAction,
    device: String,
    nonce: String
) throws -> HostApplePlatformRunnerReceipt {
    let raw: RawApplePlatformRunnerResult
    do { raw = try JSONDecoder().decode(RawApplePlatformRunnerResult.self, from: data) }
    catch {
        throw HostApplePlatformControlError(code: "runner_result_invalid", message: "The specialized runner did not return valid result JSON.", hint: "Inspect the private result bundle and runner logs; do not retry an unknown input automatically.")
    }
    guard raw.ok, raw.platform == platform.rawValue, raw.action == action.rawValue, raw.device == device, raw.nonce == nonce, raw.eventDelivered, raw.postconditionVerified else {
        throw HostApplePlatformControlError(code: "runner_result_mismatch", message: "The specialized runner result does not bind the requested target, action, nonce, and postcondition.", hint: "Treat the action outcome as unknown and inspect the private result bundle.")
    }
    return HostApplePlatformRunnerReceipt(ok: true, platform: platform, control: action, outcome: .executed, executable: true, actionsExecuted: true, targetBinding: "exact-simulator-udid-bound", nonce: nonce, sourceCommand: nil, verification: "strict-runner-result-target-action-nonce-postcondition", failureCode: nil)
}

func executeApplePlatformRunner(
    _ request: HostApplePlatformRunnerRequest,
    targetInventory: () throws -> Data = { try runHostCommand(TKSimctlCommand.listAvailableDevices()).stdoutData },
    runner: (TKHostCommand) throws -> HostProcessResult = { try runHostCommand($0) }
) throws -> HostApplePlatformRunnerReceipt {
    let command = try makeApplePlatformRunnerCommand(request)
    do {
        try validateRunnerArtifactPaths(request)
        try validateApplePlatformRunnerTarget(try targetInventory(), platform: request.platform, device: request.device)
        let result = try runner(command)
        let verified = try verifyApplePlatformRunnerResult(result.stdoutData, platform: request.platform, action: request.action, device: request.device, nonce: request.nonce)
        return HostApplePlatformRunnerReceipt(ok: verified.ok, platform: verified.platform, control: verified.control, outcome: verified.outcome, executable: verified.executable, actionsExecuted: verified.actionsExecuted, targetBinding: verified.targetBinding, nonce: verified.nonce, sourceCommand: result.sourceCommand, verification: verified.verification, failureCode: verified.failureCode)
    } catch let error as HostApplePlatformControlError {
        return HostApplePlatformRunnerReceipt(ok: false, platform: request.platform, control: request.action, outcome: .unknown, executable: true, actionsExecuted: false, targetBinding: "exact-simulator-udid-bound", nonce: request.nonce, sourceCommand: nil, verification: error.message, failureCode: error.code)
    } catch {
        return HostApplePlatformRunnerReceipt(ok: false, platform: request.platform, control: request.action, outcome: .unknown, executable: true, actionsExecuted: false, targetBinding: "exact-simulator-udid-bound", nonce: request.nonce, sourceCommand: nil, verification: "runner process outcome is unknown; no automatic retry", failureCode: "runner_execution_unknown")
    }
}

private func isExactSimulatorUDID(_ value: String) -> Bool {
    let chars = Array(value)
    guard chars.count == 36 else { return false }
    for (index, char) in chars.enumerated() {
        if [8, 13, 18, 23].contains(index) { guard char == "-" else { return false } }
        else { guard char.isHexDigit else { return false } }
    }
    return true
}
