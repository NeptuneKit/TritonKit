import CryptoKit
import Foundation
import TritonKitShared

struct HostTemporaryDomainPolicy {
    var allowDomainCreation = false
    var confirm = false
    var executeRunner = false
    var auditRecord: String? = nil
    func validate() throws {
        guard allowDomainCreation, confirm, executeRunner, let auditRecord,
              !auditRecord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              auditRecord.utf8.count <= 256, auditRecord.rangeOfCharacter(from: .controlCharacters) == nil else {
            throw TKDevicectlFilesError.temporaryRequiresPolicy
        }
    }
}

enum HostTemporaryDomainFailure: Error {
    case uncertain(String)
    var detail: TKCLIErrorDetail {
        let token: String
        switch self { case .uncertain(let value): token = value }
        return TKCLIErrorDetail(code: "device_file_domain_execution_uncertain", message: "Temporary query or completion audit was not accepted; the client domain may have been created. Audit: \(token).", hint: "Inspect the durable device-administration intent/completion journal and private artifacts locally. Do not retry automatically or infer rollback. No business file contents were read.")
    }
}

/// A temporary namespace query may create remote state. Persist policy before any native command.
func withTemporaryDomainAudit<T>(
    policy: HostTemporaryDomainPolicy, target: String, domainIdentifier: String,
    workspace: () throws -> String = makeDeviceAdministrationWorkspace,
    persist: (([String: Any], String, String) throws -> Void)? = nil,
    artifacts: () -> [String] = { [] },
    operation: (String) throws -> T
) throws -> T {
    try policy.validate()
    let directory = try workspace()
    let auditDirectory = persist == nil ? try DeviceAuditDirectory(path: directory) : nil
    try auditDirectory?.verifyPathIdentity()
    let token = "audit:" + URL(fileURLWithPath: directory).lastPathComponent
    let domainToken = SHA256.hash(data: Data((target + "\0" + domainIdentifier).utf8)).map { String(format: "%02x", $0) }.joined()
    func persistAudit(_ payload: [String: Any], _ name: String) throws {
        if let persist { try persist(payload, directory, name) }
        else { try auditDirectory!.write(name: name, payload: payload) }
    }
    try persistAudit(["action": "device.files.temporary", "target": target, "domainToken": domainToken,
                      "auditRecord": policy.auditRecord!, "status": "intent", "possibleDomainCreationAuthorized": true,
                      "created": "unknown", "timestamp": ISO8601DateFormatter().string(from: Date())], "intent.json")
    do {
        let value = try operation(token)
        try auditDirectory?.verifyPathIdentity()
        try persistAudit(["status": "metadata-accepted", "created": "unknown", "contentsRead": false, "artifacts": artifacts()], "completion.json")
        try auditDirectory?.verifyPathIdentity()
        return value
    } catch {
        // If the pathname was replaced, never write a success record to the replacement.
        // The original FD remains available for an uncertainty record.
        let uncertainty: [String: Any] = ["status": "uncertain", "created": "unknown", "automaticRetry": false, "artifacts": artifacts()]
        if let auditDirectory, (try? auditDirectory.verifyPathIdentity()) != nil {
            try? persistAudit(uncertainty, "completion.json")
        } else if let auditDirectory {
            try? auditDirectory.write(name: "completion.json", payload: uncertainty)
        } else {
            try? persistAudit(uncertainty, "completion.json")
        }
        throw HostTemporaryDomainFailure.uncertain(token)
    }
}

func validateTemporaryFilesReceipt(_ data: Data, command: TKHostCommand) throws {
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          root["error"] == nil || root["error"] is NSNull,
          let info = root["info"] as? [String: Any], info["outcome"] as? String == "success",
          info["commandType"] as? String == "devicectl.device.info.files",
          info["arguments"] as? [String] == command.arguments,
          root["result"] is [String: Any] else { throw HostDeviceFilesError.invalidJSON }
}
