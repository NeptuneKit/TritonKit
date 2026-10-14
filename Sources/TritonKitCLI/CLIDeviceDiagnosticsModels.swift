import Foundation

struct DeviceDiagnosticsEntry: Encodable, Equatable {
    let name: String
    let source: String
    let sizeBytes: UInt64?
}
struct DeviceDiagnosticsOutput: Encodable {
    var ok = true
    let action: String
    let target: HostDeviceTarget
    let source: String
    let sourceCommands: [String]
    let artifacts: [String]
    let bytes: Int
    let maximumBytes: Int
    let partial: Bool
    let limitations: [String]
    let entries: [DeviceDiagnosticsEntry]
    let content: String?
}
enum DeviceDiagnosticsError: Error, CustomStringConvertible {
    case invalidRequest, unavailable(String), invalidReceipt, unsafeArtifact
    var description: String {
        switch self {
        case .invalidRequest: "Invalid diagnostics limits or report name; no device operation submitted."
        case .unavailable(let reason): "Device diagnostics unavailable: \(reason)"
        case .invalidReceipt: "Crash copy did not provide an exact successful CoreDevice command receipt."
        case .unsafeArtifact: "Diagnostic body is missing, oversized, or not an owner-only regular file."
        }
    }
}
