import Foundation
import TritonKitShared

// Only stable codes cross this boundary. Never retain/encode raw backend error,
// logs, artifact paths, selectors or candidate records in plan failures.
struct HostDeviceAdministrationDiscoveryFailure: Error, CustomStringConvertible {
    let detail: TKCLIErrorDetail
    init(_ error: Error) {
        let code: String
        switch error {
        case let selection as HostDeviceSelectionError: code = hostDeviceSelectionErrorDetail(selection).detail.code
        case IOSDevicectlRunError.jsonMissing: code = "devicectl_json_missing"
        case IOSDevicectlRunError.jsonParseFailed: code = "devicectl_json_parse_failed"
        case HostCommandRunError.timeout(let command, _, _, _): code = hostCommandTimeoutErrorDetail(command: command, message: "").code
        case HostCommandRunError.nonZeroExit(let command, let result): code = hostCommandNonZeroExitErrorDetail(command: command, result: result).code
        default: code = "host_action_failed"
        }
        detail = TKCLIErrorDetail(code: code, message: "Fresh real-device metadata discovery failed. No administration action executed.", hint: "Inspect private discovery evidence locally; retry readonly device doctor/list. Do not publish backend logs, identifiers or paths.")
    }
    var description: String { detail.message }
}
