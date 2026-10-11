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
    case notStarted = "not_started"
    case timedOut = "timed_out"
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
    let crownDelta: Double?
}

struct HostApplePlatformRunnerReceipt: Encodable, Equatable {
    let ok: Bool
    let action = "device.platform-control"
    let platform: HostApplePlatformControlPlatform
    let control: HostApplePlatformControlAction
    let outcome: HostApplePlatformRunnerOutcome
    let executable: Bool
    let actionsExecuted: Bool?
    let targetBinding: String
    let nonce: String
    var sourceCommand: String?
    let verification: String
    let failureCode: String?
    var auditPath: String? = nil
    enum CodingKeys: String, CodingKey { case ok, action, platform, control, outcome, executable, actionsExecuted, targetBinding, nonce, sourceCommand, verification, failureCode, auditPath }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(ok, forKey: .ok); try c.encode(action, forKey: .action)
        try c.encode(platform, forKey: .platform); try c.encode(control, forKey: .control)
        try c.encode(outcome, forKey: .outcome); try c.encode(executable, forKey: .executable)
        try c.encode(actionsExecuted, forKey: .actionsExecuted)
        try c.encode(targetBinding, forKey: .targetBinding); try c.encode(nonce, forKey: .nonce)
        try c.encodeIfPresent(sourceCommand, forKey: .sourceCommand)
        try c.encode(verification, forKey: .verification)
        try c.encodeIfPresent(failureCode, forKey: .failureCode); try c.encodeIfPresent(auditPath, forKey: .auditPath)
    }
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
    let version: Int
    let crownDelta: Double?
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
    auditRecord: String,
    crownDelta: Double? = nil
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
    guard testIdentifier.split(separator: "/", omittingEmptySubsequences: false).count == 3, testIdentifier.split(separator: "/", omittingEmptySubsequences: false).allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }), !testIdentifier.isEmpty, testIdentifier.count <= 256, testIdentifier.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "./_-".contains($0)) }) else {
        throw HostApplePlatformControlError(code: "invalid_runner_test", message: "The XCTest identifier is malformed.", hint: "Use exactly Target/Class/testMethod without whitespace.")
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
    _ = try makeApplePlatformControlPlan(platform: platform, action: action, crownDelta: crownDelta)
    return HostApplePlatformRunnerRequest(platform: platform, action: action, device: device, xctestrun: xctestrun, testIdentifier: testIdentifier, resultBundle: resultBundle, nonce: nonce, timeout: timeout, executeRunner: executeRunner, confirm: confirm, auditRecord: auditRecord, crownDelta: crownDelta)
}

func makeApplePlatformRunnerCommand(_ request: HostApplePlatformRunnerRequest, preparedPath: String? = nil) throws -> TKHostCommand {
    let destinationPlatform = request.platform == .watchos ? "watchOS Simulator" : "tvOS Simulator"
    var arguments = ["-xctestrun", preparedPath ?? request.xctestrun, "-destination", "platform=\(destinationPlatform),id=\(request.device)"]
    if let resultBundle = request.resultBundle { arguments += ["-resultBundlePath", resultBundle] }
    arguments += ["-parallel-testing-enabled", "NO", "-maximum-concurrent-test-simulator-destinations", "1", "-parallel-testing-worker-count", "1", "-test-iterations", "1", "-only-testing:\(request.testIdentifier)", "test-without-building"]
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
    let matching = targets.filter { $0.udid == device }
    guard matching.count == 1, let target = matching.first, target.isAvailable else {
        throw HostApplePlatformControlError(code: "runner_target_unavailable", message: "The exact Simulator UDID is not available.", hint: "Use an available dedicated watchOS or tvOS Simulator UDID.")
    }
    let family = appleSimulatorPlatformFamily(runtime: target.runtimeIdentifier)
    let matches = (platform == .watchos && family == .watchos) || (platform == .tvos && family == .tvos)
    guard matches else {
        throw HostApplePlatformControlError(code: "runner_target_family_mismatch", message: "The exact Simulator runtime family does not match the requested platform.", hint: "Select a dedicated watchOS or tvOS Simulator; iOS and visionOS runtimes are rejected.")
    }
}

func verifyApplePlatformRunnerResult(
    _ data: Data,
    platform: HostApplePlatformControlPlatform,
    action: HostApplePlatformControlAction,
    device: String,
    nonce: String,
    crownDelta: Double? = nil
) throws -> HostApplePlatformRunnerReceipt {
    guard data.count <= 65536 else { throw runnerError("runner_result_invalid", "Result exceeds 64 KiB budget.") }
    let raw: RawApplePlatformRunnerResult
    do { raw = try JSONDecoder().decode(RawApplePlatformRunnerResult.self, from: data) }
    catch {
        throw HostApplePlatformControlError(code: "runner_result_invalid", message: "The specialized runner did not return valid result JSON.", hint: "Inspect the private result bundle and runner logs; do not retry an unknown input automatically.")
    }
    guard data.count <= 65536, raw.version == 1, raw.crownDelta == crownDelta, raw.ok, raw.platform == platform.rawValue, raw.action == action.rawValue, raw.device == device, raw.nonce == nonce, raw.eventDelivered, raw.postconditionVerified else {
        throw HostApplePlatformControlError(code: "runner_result_mismatch", message: "The specialized runner result does not bind the requested target, action, nonce, and postcondition.", hint: "Treat the action outcome as unknown and inspect the private result bundle.")
    }
    return HostApplePlatformRunnerReceipt(ok: true, platform: platform, control: action, outcome: .executed, executable: true, actionsExecuted: true, targetBinding: "exact-simulator-udid-bound", nonce: nonce, sourceCommand: nil, verification: "strict-runner-result-target-action-nonce-postcondition", failureCode: nil)
}

func executeApplePlatformRunner(
    _ request: HostApplePlatformRunnerRequest,
    targetInventory: () throws -> Data = { try runHostCommand(TKSimctlCommand.listAvailableDevices()).stdoutData },
    runner: ((TKHostCommand) throws -> HostProcessResult)? = nil
) throws -> HostApplePlatformRunnerReceipt {
    var started = false
    var bound = false
    var inputReturned = false
    var audit: String?
    var receipt: HostApplePlatformRunnerReceipt
    do {
        let workspace = try prepareApplePlatformRunnerWorkspace(request)
        audit = workspace
        try writeApplePlatformRunnerAudit(["phase": "intent", "version": 1, "device": request.device, "platform": request.platform.rawValue, "action": request.action.rawValue, "nonce": request.nonce, "auditRecord": request.auditRecord, "testIdentifier": request.testIdentifier, "xctestrun": request.xctestrun, "resultBundle": request.resultBundle as Any? ?? NSNull(), "timeoutSeconds": request.timeout, "executeRunner": request.executeRunner, "confirm": request.confirm, "timestamp": ISO8601DateFormatter().string(from: Date()), "crownDelta": request.crownDelta as Any? ?? NSNull()], to: workspace + "/intent.json")
        try validateApplePlatformRunnerTarget(try targetInventory(), platform: request.platform, device: request.device)
        bound = true
        let command = try makeApplePlatformRunnerCommand(request, preparedPath: workspace + "/request.xctestrun")
        started = true
        let result = try runner?(command) ?? runApplePlatformRunnerProcess(command, logPrefix: workspace + "/xcodebuild")
        inputReturned = true
        guard result.exitCode == 0 else { throw runnerError("runner_process_failed", "XCTest exited unsuccessfully; input delivery is unknown.") }
        try validateApplePlatformResultTree(request.resultBundle!)
        let exportPath = workspace + "/attachments"
        let method = request.testIdentifier.split(separator: "/").dropFirst().joined(separator: "/") + "()"
        let export = TKHostCommand(executable: "xcrun", arguments: ["xcresulttool", "export", "attachments", "--path", request.resultBundle!, "--test-id", method, "--output-path", exportPath], redactedArgumentIndexes: [4, 6, 8], riskLevel: .readonly, requiredConfig: [.artifactDir], defaultTimeoutSeconds: 30, capturesArtifacts: true, sensitiveOutput: true)
        let exported = try runner?(export) ?? runApplePlatformRunnerProcess(export, logPrefix: workspace + "/xcresulttool")
        guard exported.exitCode == 0 else { throw runnerError("runner_attachment_export_failed", "Cannot export the XCTest result attachment.") }
        let manifest = try readApplePlatformRunnerFile(exportPath + "/manifest.json", limit: 1_048_576)
        let name = try applePlatformResultAttachmentName(manifest, request: request)
        let data = try readApplePlatformRunnerFile(exportPath + "/" + name, limit: 65536)
        receipt = try verifyApplePlatformRunnerResult(data, platform: request.platform, action: request.action, device: request.device, nonce: request.nonce, crownDelta: request.crownDelta)
        receipt.sourceCommand = result.sourceCommand
    } catch {
        var code = (error as? HostApplePlatformControlError)?.code ?? "runner_execution_unknown"
        var outcome: HostApplePlatformRunnerOutcome = started ? .unknown : .notStarted
        if let processError = error as? HostCommandRunError {
            switch processError {
            case .timeout: outcome = started ? .timedOut : .notStarted; code = started ? "runner_timed_out" : "runner_inventory_timed_out"
            case .nonZeroExit: outcome = started ? .failed : .notStarted; code = started ? "runner_process_failed" : "runner_inventory_failed"
            case .launchFailed: code = "runner_launch_failed"; if !inputReturned { started = false; outcome = .notStarted }
            default: break
            }
        } else if code == "runner_process_failed" { outcome = .failed }
        receipt = HostApplePlatformRunnerReceipt(ok: false, platform: request.platform, control: request.action, outcome: outcome, executable: true, actionsExecuted: started ? nil : false, targetBinding: bound ? "exact-simulator-udid-bound" : "unverified", nonce: request.nonce, sourceCommand: nil, verification: started ? "Input delivery unknown; no automatic retry." : "Runner was not invoked.", failureCode: code)
    }
    receipt.auditPath = audit
    if let audit {
        do { try writeApplePlatformRunnerAuditData(JSONEncoder().encode(receipt), to: audit + "/completion.json") }
        catch {
            receipt = HostApplePlatformRunnerReceipt(ok: false, platform: request.platform, control: request.action, outcome: started ? .unknown : .notStarted, executable: true, actionsExecuted: started ? nil : false, targetBinding: bound ? "exact-simulator-udid-bound" : "unverified", nonce: request.nonce, sourceCommand: nil, verification: "Completion audit could not be persisted; never retry automatically.", failureCode: "runner_audit_failed", auditPath: audit)
        }
    }
    return receipt
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
