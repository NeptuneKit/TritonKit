import TritonKitShared

struct HostDeviceMountpointOutput: Encodable {
    let ok: Bool = true
    let action: String = "device.mountpoint"
    let runtimeScope: String = "host-device"
    let riskLevel: String = "automation"
    let target: HostDeviceTarget
    let mountpointToken: String
    let identityBinding: String = "exact-file-json-device-argument"
    let verification: String = "executed-file-json"
    let hostFilesystemInspected: Bool = false
    let mountStateVerified: Bool = false
    let mountCreated: String = "unknown"
    let contentsListed: Bool = false
    let businessReadinessVerified: Bool = false
    let maximumJSONBytes: Int
    let limitSemantics: String = "local-acceptance-only; not a remote transport or disk limit"
    let sourceCommands: [String]
    let artifacts: [String]
}
enum HostDeviceMountpointError: Error, Equatable {
    case unsupportedPlatform, identityMismatch, queryFailed, timeout, jsonMissing, invalidJSON, limitExceeded
    var detail: TKCLIErrorDetail {
        let code: String
        switch self {
        case .unsupportedPlatform: code = "unsupported_device_mountpoint_platform"
        case .identityMismatch: code = "device_mountpoint_identity_mismatch"
        case .queryFailed: code = "device_mountpoint_query_failed"
        case .timeout: code = "host_command_timeout"
        case .jsonMissing: code = "devicectl_json_missing"
        case .invalidJSON: code = "devicectl_json_parse_failed"
        case .limitExceeded: code = "device_mountpoint_limit_exceeded"
        }
        return TKCLIErrorDetail(code: code, message: "No bound DeviceFS mountpoint metadata snapshot was produced (\(code)).", hint: "Inspect private artifacts and refresh selection. The native query may implicitly mount the device filesystem; mountCreated remains unknown. No Finder, path traversal, explicit unmount, boot/pair/unlock or alternate-backend retry was performed. CoreDevice service communication and private artifact production occur; a returned path does not prove existence, mount state or read/write access. Local JSON acceptance only.")
    }
}
