import ArgumentParser
import TritonKitShared

enum DeviceFSView: String, ExpressibleByArgument, CaseIterable {
    case mountRoot = "mount-root"
    case diagnosticReports = "diagnostic-reports"
    case appDataContainers = "app-data-containers"
    case appGroupContainers = "app-group-containers"
    var relativeDirectory: String? {
        switch self {
        case .mountRoot: return nil
        case .diagnosticReports: return "DiagnosticReports"
        case .appDataContainers: return "AppDataContainers"
        case .appGroupContainers: return "AppGroupContainers"
        }
    }
}

struct HostDeviceFSListOutput: Encodable {
    let ok: Bool = true
    let action: String = "device.fs.list"
    let runtimeScope: String = "host-device"
    let riskLevel: String = "automation"
    let backend: String = "devicefs"
    let view: String
    var directoryToken: String? = nil
    let target: HostDeviceTarget
    let mountpointToken: String
    let entries: [HostDeviceFileEntryOutput]
    let count: Int
    let sensitiveMetadataIncluded: Bool
    let maximumJSONBytes: Int
    let maximumEntries: Int
    let recursive: Bool = false
    let hostFilesystemInspected: Bool = true
    let contentsRead: Bool = false
    let mountStateVerified: Bool = false
    let mountCreated: String = "unknown"
    let readWriteAuthorizationVerified: Bool = false
    let businessReadinessVerified: Bool = false
    let entryIdentityVerification: String = "same-directory nofollow double-stat inode/device/kind; DeviceFS synthetic readdir/stat IDs are not comparable; other filesystem dirent IDs remain bound. Not an atomic snapshot or mount provenance proof."
    let verification: String = "executed-file-json-and-descriptor-metadata"
    let limitSemantics: String = "local-acceptance-only; query timeout is not a FUSE syscall deadline, remote disk/transport bound or atomic snapshot guarantee"
    let sourceCommands: [String]
    let artifacts: [String]
}
enum HostDeviceFSError: Error, Equatable {
    case directoryUnavailable, rootMismatch, unsafeRoot, readFailed, limitExceeded, unsupportedPlatform
    var detail: TKCLIErrorDetail {
        let code: String
        switch self {
        case .directoryUnavailable: code = "device_fs_directory_unavailable"
        case .rootMismatch: code = "device_fs_root_mismatch"
        case .unsafeRoot: code = "device_fs_unsafe_root"
        case .readFailed: code = "device_fs_read_failed"
        case .limitExceeded: code = "device_fs_limit_exceeded"
        case .unsupportedPlatform: code = "unsupported_device_fs_platform"
        }
        return TKCLIErrorDetail(code: code, message: "No accepted DeviceFS directory metadata listing (\(code)).", hint: "Refresh current device discovery and inspect private artifacts locally. This explicit backend lists only the selected fixed namespace or bounded explicitly selected native container-relative directory; no verified bundle/group identity or arbitrary domain/path mapping, content read, symlink target opening, recursion, temporary creation, Finder, explicit mount/unmount or automatic boot/pair/unlock/fallback. Directory metadata access may have occurred. Limits are local acceptance only, not FUSE cancellation or atomic snapshot; do not publish private path/identity/error text.")
    }
}
