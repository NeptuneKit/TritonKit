import Foundation
import TritonKitShared

struct HostDeviceMountPolicy: Equatable {
    let allowMount: Bool
    let confirm: Bool
    let executeRunner: Bool
    let auditRecord: String?
    init(allowMount: Bool = false, confirm: Bool = false, executeRunner: Bool = false, auditRecord: String? = nil) {
        self.allowMount = allowMount; self.confirm = confirm; self.executeRunner = executeRunner; self.auditRecord = auditRecord
    }
    func validate() throws {
        guard allowMount, confirm, executeRunner, let auditRecord,
              !auditRecord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              auditRecord.utf8.count <= 256, auditRecord.rangeOfCharacter(from: .controlCharacters) == nil else { throw HostDeviceMountPolicyError.required }
    }
}
enum HostDeviceMountPolicyError: Error, Equatable {
    case required
    var detail: TKCLIErrorDetail {
        TKCLIErrorDetail(code: "device_mount_policy_required", message: "Explicit authorization for a possible native mount is required.", hint: "Provide --allow-mount --confirm --execute-runner and a non-empty --audit-record before device discovery or query artifacts. The query may change mount state; no automatic retry or rollback is performed.")
    }
}

struct HostDeviceMountAudit {
    fileprivate let directory: DeviceAuditDirectory
    fileprivate let token: String
    func beforeNativeExecution() throws { try directory.verifyPathIdentity() }
}
struct HostDeviceMountExecutionFailure: Error {
    let status: String
    let auditToken: String
    let detail: TKCLIErrorDetail
    init(status: String, auditToken: String, detail: TKCLIErrorDetail) { self.status = status; self.auditToken = auditToken; self.detail = detail }
}

func resolveAuthorizedMountpointSelection(
    policy: HostDeviceMountPolicy,
    request: HostDeviceSelectionRequest,
    resolver: (HostDeviceSelectionRequest) throws -> HostDeviceSelectionResult
) throws -> HostDeviceSelectionResult {
    try policy.validate()
    return try resolver(request)
}

func mountCauseDetail(_ error: Error, auditToken: String) -> TKCLIErrorDetail {
    let detail: TKCLIErrorDetail
    if let error = error as? HostDeviceFSError { detail = error.detail }
    else if let error = error as? HostDeviceMountpointError { detail = error.detail }
    else if error is HostDeviceSelectionError { detail = TKCLIErrorDetail(code: "device_selection_failed", message: "Device selection failed.", hint: nil) }
    else if error is HostDeviceMountPolicyError { detail = TKCLIErrorDetail(code: "device_mount_policy_required", message: "Explicit mount policy required.", hint: nil) }
    else { detail = TKCLIErrorDetail(code: "device_mount_execution_failed", message: "Native mount operation failed.", hint: nil) }
    let hint = [detail.hint, "auditToken=\(auditToken); mountCreated=unknown; native operation may have occurred; do not retry automatically."].compactMap { $0 }.joined(separator: " ")
    return TKCLIErrorDetail(code: detail.code, message: detail.message, endpoint: detail.endpoint, hint: hint, nextAction: detail.nextAction, nearestCandidates: detail.nearestCandidates, suggestedCommands: detail.suggestedCommands, candidateCount: detail.candidateCount, leaseReason: detail.leaseReason, currentOwner: detail.currentOwner, currentLeaseID: detail.currentLeaseID, currentExpiresAt: detail.currentExpiresAt)
}

func withDeviceMountAudit<T>(
    policy: HostDeviceMountPolicy, action: String, target: String,
    workspace: () throws -> String = makeDeviceAdministrationWorkspace,
    operation: (HostDeviceMountAudit) throws -> T
) throws -> T {
    try policy.validate()
    let directoryPath = try workspace()
    let directory = try DeviceAuditDirectory(path: directoryPath)
    let token = "audit:" + URL(fileURLWithPath: directoryPath).lastPathComponent
    let targetToken = target.data(using: .utf8).map { "target:" + $0.base64EncodedString() } ?? "target"
    try directory.write(name: "intent.json", payload: ["action": action, "targetToken": targetToken, "auditRecord": policy.auditRecord!, "status": "intent", "mountCreated": "unknown", "contentsRead": false])
    let audit = HostDeviceMountAudit(directory: directory, token: token)
    do {
        try directory.verifyPathIdentity()
        let value = try operation(audit)
        try directory.verifyPathIdentity()
        try directory.write(name: "completion.json", payload: ["status": "metadata-accepted", "mountCreated": "unknown", "contentsRead": false, "auditToken": token])
        return value
    } catch let failure as HostDeviceMountExecutionFailure { throw failure }
    catch {
        let detail = mountCauseDetail(error, auditToken: token)
        try? directory.write(name: "completion.json", payload: ["status": "uncertain", "mountCreated": "unknown", "contentsRead": false, "auditToken": token, "causeCode": detail.code])
        throw HostDeviceMountExecutionFailure(status: "uncertain", auditToken: token, detail: detail)
    }
}

func validateDeviceMountReceipt(_ data: Data, command: TKHostCommand) throws {
    guard data.count <= 1_048_576,
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any], root["error"] == nil || root["error"] is NSNull,
          let info = root["info"] as? [String: Any], info["arguments"] as? [String] == command.arguments,
          info["outcome"] as? String == "success", info["commandType"] as? String == "devicectl.device.info.mountpoint",
          root["result"] is [String: Any] else { throw HostDeviceMountpointError.invalidJSON }
}
