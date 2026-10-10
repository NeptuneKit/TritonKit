import Foundation

// Explicit native scope, not verified bundle/group identity. Never normalize/URL-decode bytes or auto-select.
func deviceFSRelativeDirectory(view: DeviceFSView, containerIdentifier: String?, subdirectory: String? = nil) throws -> String? {
    let failure = HostDeviceSelectionError.parameterConflict("DeviceFS container/subdirectory selection requires an app-data/app-group view and an explicit one-component container (1...255 UTF8 bytes). Relative subdirectory: 1...32 components, each 1...255 UTF8 bytes, total at most 4096; no empty/dot/dotdot/slash-empty segments or controls.")
    guard let identifier = containerIdentifier else {
        guard subdirectory == nil else { throw failure }
        return view.relativeDirectory
    }
    func component(_ value: String) throws {
        guard !value.isEmpty, value.utf8.count <= 255, value != ".", value != ".." else { throw failure }
        do { _ = try decodedDeviceFSName(Data(value.utf8)) }
        catch { throw failure }
    }
    guard let namespace = view.relativeDirectory else { throw failure }
    try component(identifier)
    if let subdirectory {
        guard !subdirectory.isEmpty, subdirectory.utf8.count <= 4096 else { throw failure }
        let parts = subdirectory.split(separator: "/", omittingEmptySubsequences: false)
        guard (1...32).contains(parts.count) else { throw failure }
        for part in parts { try component(String(part)) }
    }
    return namespace + "/" + identifier + (subdirectory.map { "/" + $0 } ?? "")
}
