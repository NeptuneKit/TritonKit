import Foundation

/// Best-effort adapter for CoreSimulator's per-device launchd override store.
/// This is an undocumented host detail; callers must always verify after boot
/// and fall back to launchctl when the runtime ignores or rejects it.
struct SimulatorResourceOfflineStore {
    static var root = "/private/var/tmp"

    static func url(for udid: String) -> URL {
        URL(fileURLWithPath: root)
            .appendingPathComponent("com.apple.CoreSimulator.SimDevice.\(udid)")
            .appendingPathComponent("disabled.plist")
    }

    static func read(_ udid: String) throws -> [String: Bool] {
        let url = url(for: udid)
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        guard let value = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw SimulatorResourceOfflineStoreError.invalidFormat
        }
        var entries: [String: Bool] = [:]
        for (key, raw) in value {
            guard let bool = raw as? Bool else { continue }
            entries[key] = bool
        }
        return entries
    }

    static func merge(_ udid: String, disable: Set<String>, enable: Set<String>) throws {
        var entries = try read(udid)
        for label in disable { entries[label] = true }
        for label in enable { entries[label] = false }
        let directory = url(for: udid).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let data = try PropertyListSerialization.data(fromPropertyList: entries, format: .xml, options: 0)
        let temporary = directory.appendingPathComponent("disabled.plist.\(UUID().uuidString).tmp")
        try data.write(to: temporary, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let destination = url(for: udid)
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary, backupItemName: nil, options: .usingNewMetadataOnly)
        } else {
            try FileManager.default.moveItem(at: temporary, to: destination)
        }
    }
}

enum SimulatorResourceOfflineStoreError: Error, Equatable {
    case invalidFormat
}
