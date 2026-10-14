import Foundation
import TritonKitShared

func appArchiveErrorDetail(_ error: AppArchiveError) -> TKCLIErrorDetail {
    let code: String
    switch error {
    case .unsafeArchive: code = "app_archive_unsafe"
    case .budgetExceeded: code = "app_archive_budget_exceeded"
    case .extractionFailed: code = "app_archive_extraction_failed"
    case .ambiguousApp: code = "app_archive_ambiguous"
    case .platformMismatch: code = "app_archive_platform_mismatch"
    }
    return TKCLIErrorDetail(code: code, message: error.description, hint: "The archive was not installed. Fix the archive or selected target scope; existing apps and files were preserved.")
}
func deviceDiagnosticsErrorDetail(_ error: DeviceDiagnosticsError) -> TKCLIErrorDetail {
    let code: String
    switch error {
    case .invalidRequest: code = "device_diagnostics_invalid_request"
    case .unavailable: code = "device_diagnostics_unavailable"
    case .invalidReceipt: code = "device_crash_receipt_invalid"
    case .unsafeArtifact: code = "device_diagnostics_artifact_unsafe"
    }
    return TKCLIErrorDetail(code: code, message: error.description, hint: "Inspect the private bounded artifact and target selection. No alternate backend, root escalation, log clearing, or device mutation was attempted.")
}
