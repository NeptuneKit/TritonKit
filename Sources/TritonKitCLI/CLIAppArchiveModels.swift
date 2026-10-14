import Foundation

struct AppArchiveBudget {
    var maximumArchiveBytes = 268_435_456
    var maximumExpandedBytes = 1_073_741_824
    var maximumFileBytes = 134_217_728
    var maximumEntries = 10_000
    var timeout: Double = 120
}
struct AppArchiveZIPEntry {
    let name: String
    let expandedBytes: Int
    let compressedBytes: Int
    let executable: Bool
    let directory: Bool
}
struct PreparedHostIOSAppArchive {
    let appPath: String
    let workspace: String?
    /// Installation must complete before cleanup; archive staging is never retained as an installed artifact.
    func cleanup() { if let workspace { try? FileManager.default.removeItem(atPath: workspace) } }
}
enum AppArchiveError: Error, CustomStringConvertible {
    case unsafeArchive, budgetExceeded, extractionFailed, ambiguousApp, platformMismatch
    var description: String {
        switch self {
        case .unsafeArchive: "Unsafe ZIP/IPA: traversal, links, special files, unsupported ZIP structure or invalid metadata."
        case .budgetExceeded: "ZIP/IPA exceeds compressed/expanded/file-count/time budget."
        case .extractionFailed: "ZIP/IPA extraction or CRC validation failed."
        case .ambiguousApp: "ZIP/IPA must contain exactly one top-level installable .app with a valid Info.plist and executable."
        case .platformMismatch: "Archived .app supported platform does not match selected iOS simulator/real-device scope."
        }
    }
}
