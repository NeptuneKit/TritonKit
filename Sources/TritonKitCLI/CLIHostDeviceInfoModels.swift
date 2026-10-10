import Foundation
import TritonKitShared

struct HostDeviceLockStateOutput: Encodable {
    let requested: Bool
    let verification: String
    let passcodeRequired: Bool?
    let unlockedSinceBoot: Bool?
}

struct HostDeviceInfoOutput: Encodable {
    let ok: Bool
    let action: String = "device.info"
    let runtimeScope: String = "host-device"
    let riskLevel: String = "readonly"
    let target: HostDeviceTarget
    let hardware: TKDevicectlHardwareInfo
    let lockState: HostDeviceLockStateOutput
    let sourceCommands: [String]
    let artifacts: [String]
    let verification: String = "executed-file-json"
    let businessReadinessVerified: Bool = false
}

enum HostDeviceInfoError: Error, Equatable {
    case unsupportedPlatform
    case identityMismatch
    case queryFailed(String)
    case queryUnsupported(String)
    case queryTimedOut(String)
    case jsonMissing
    case invalidJSON

    var detail: TKCLIErrorDetail {
        switch self {
        case .unsupportedPlatform:
            TKCLIErrorDetail(code: "unsupported_device_info_platform", message: "Device Hub information currently requires --platform ios and simulator or real scope.", hint: "Use device list for Android or Harmony discovery.")
        case .identityMismatch:
            TKCLIErrorDetail(code: "device_info_identity_mismatch", message: "Device information did not match the selected target.", hint: "Refresh device list and resolve the selector; do not trust this snapshot.")
        case .queryFailed(let phase):
            TKCLIErrorDetail(code: "device_info_query_failed", message: "The readonly \(phase) query failed; no successful information envelope was produced.", hint: "Inspect private CoreDevice artifacts. Simulators must already be started; physical devices must be paired. No automatic boot, pair or alternate-backend retry was performed.")
        case .queryUnsupported(let phase):
            TKCLIErrorDetail(code: "unsupported_device_info_query", message: "The selected device does not support the readonly \(phase) query.", hint: "For device details without a lock query, omit --lock-state. This is a device capability restriction, not evidence that the device is unlocked or ready.")
        case .queryTimedOut(let phase):
            TKCLIErrorDetail(code: "host_command_timeout", message: "The readonly \(phase) query timed out.", hint: "Inspect private artifacts and device connectivity before repeating the readonly query.")
        case .jsonMissing:
            TKCLIErrorDetail(code: "devicectl_json_missing", message: "Device information JSON output is missing or unreadable.", hint: "Inspect the private CoreDevice log and verify the artifact directory is writable.")
        case .invalidJSON:
            TKCLIErrorDetail(code: "devicectl_json_parse_failed", message: "Device information JSON was malformed, unsuccessful, or unsupported.", hint: "Keep a sanitized fixture for parser compatibility review; never parse the human-readable output instead.")
        }
    }
}
