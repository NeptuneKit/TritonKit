import Foundation
import TritonKitShared

struct HostDeviceFileEntryOutput: Encodable {
    let token: String
    let kind: String
    let sizeBytes: UInt64?
    let modifiedAt: String?
    let isHidden: Bool?
    let isReadable: Bool?
    let name: String?
    let relativePath: String?
}
struct HostDeviceFilesOutput: Encodable {
    let ok: Bool = true
    let action: String = "device.files"
    let runtimeScope: String = "host-device"
    let riskLevel: String = "readonly"
    let target: HostDeviceTarget
    let domain: String
    let recursive: Bool = false
    let sensitiveMetadataIncluded: Bool
    let entries: [HostDeviceFileEntryOutput]
    let count: Int
    let maximumJSONBytes: Int
    let maximumEntries: Int
    let limitSemantics: String = "local-acceptance-only; not a remote traversal, transport or disk limit"
    let sourceCommands: [String]
    let artifacts: [String]
    let verification: String = "executed-file-json"
    let businessReadinessVerified: Bool = false
}
enum HostDeviceFilesError: Error, Equatable {
    case unsupportedPlatform, identityMismatch, domainMismatch, queryFailed, queryUnsupported, timeout, jsonMissing, invalidJSON, limitExceeded
    var detail: TKCLIErrorDetail {
        let code: String
        switch self {
        case .unsupportedPlatform: code = "unsupported_device_files_platform"
        case .identityMismatch: code = "device_files_identity_mismatch"
        case .domainMismatch: code = "device_files_domain_mismatch"
        case .queryFailed: code = "device_files_query_failed"
        case .queryUnsupported: code = "unsupported_device_file_query"
        case .timeout: code = "host_command_timeout"
        case .jsonMissing: code = "devicectl_json_missing"
        case .invalidJSON: code = "devicectl_json_parse_failed"
        case .limitExceeded: code = "device_files_limit_exceeded"
        }
        return TKCLIErrorDetail(code: code, message: "No successful device file metadata snapshot was produced (\(code)).", hint: "Inspect private artifacts and refresh device selection. This is a shallow metadata query, not file content or write permission. No automatic boot/pair/unlock, temporary namespace creation or alternate-backend retry was performed; limits apply to local acceptance only.")
    }
}
func deviceFilesRequestErrorDetail(_ error: TKDevicectlFilesError) -> TKCLIErrorDetail {
    switch error {
    case .temporaryRequiresPolicy:
        return TKCLIErrorDetail(code: "device_file_domain_policy_required", message: "The temporary namespace requires a separate side-effect policy and is not admitted by this readonly command.", hint: "Do not infer platform unsupported or silently create a temporary space; use an implemented readonly domain.")
    case .invalidRequest:
        return TKCLIErrorDetail(code: "parameter_conflict", message: "Invalid file domain, identifier, relative directory or username.", hint: "App domains require a nonblank identifier; crash logs omit it. Paths must be domain-relative without empty/dot/traversal segments or control characters.")
    case .limitExceeded: return HostDeviceFilesError.limitExceeded.detail
    case .malformedJSON: return HostDeviceFilesError.invalidJSON.detail
    }
}
