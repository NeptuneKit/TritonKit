import TritonKitShared

struct HostAppContainerBindingOutput: Encodable {
    let ok: Bool = true
    let action: String = "device.containers"
    let runtimeScope: String = "host-device"
    let riskLevel: String = "readonly"
    let target: HostDeviceTarget
    let backend: String
    let bindingSource: String = "devicectl.device.info.apps.explicit-fields"
    let bindingStatus: String
    let containerKind: String
    let applicationToken: String
    let groupToken: String?
    let containerToken: String?
    let containerAccessible: Bool?
    let hostFilesystemInspected: Bool
    let entries: [HostDeviceFileEntryOutput]
    let count: Int
    let maximumJSONBytes: Int
    let maximumEntries: Int
    let contentsRead: Bool = false
    let recursive: Bool = false
    let deviceFSBindingVerified: Bool = false
    let readWriteAuthorizationVerified: Bool = false
    let verification: String
    let limitSemantics: String = "local acceptance only; metadata query timeout is not a filesystem syscall deadline or atomic snapshot guarantee"
    let sourceCommands: [String]
    let artifacts: [String]
}

enum HostAppContainerBindingError: Error, Equatable {
    case unsupportedPlatform, unsupportedSDK, unsupportedListing, queryFailed, timeout, jsonMissing, invalidJSON, identityMismatch, unavailable, rootMismatch, unsafeRoot, readFailed, limitExceeded
    var detail: TKCLIErrorDetail {
        let suffix: String
        switch self {
        case .unsupportedPlatform: suffix = "unsupported_platform"
        case .unsupportedSDK: suffix = "unsupported_sdk"
        case .unsupportedListing: suffix = "unsupported_listing"
        case .queryFailed: suffix = "query_failed"
        case .timeout: suffix = "timeout"
        case .jsonMissing: suffix = "json_missing"
        case .invalidJSON: suffix = "invalid_json"
        case .identityMismatch: suffix = "identity_mismatch"
        case .unavailable: suffix = "unavailable"
        case .rootMismatch: suffix = "root_mismatch"
        case .unsafeRoot: suffix = "unsafe_root"
        case .readFailed: suffix = "read_failed"
        case .limitExceeded: suffix = "limit_exceeded"
        }
        return TKCLIErrorDetail(code: "app_container_" + suffix, message: "No accepted application container result (app_container_\(suffix)).", hint: "Requires SDK explicit bundle/group metadata and exact selected target identity. Listing supports only a bound native CoreSimulator container, never a guessed DeviceFS mapping. No business file contents, creation, mount, boot, pairing, fallback or write authorization. Private query artifacts may exist; inspect locally without publishing paths or identities.")
    }
}
