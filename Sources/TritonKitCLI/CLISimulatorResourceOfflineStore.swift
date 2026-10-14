import CoreFoundation
import Darwin
import Foundation

/// CoreSimulator's undocumented override store; verify launchctl after boot.
/// All IO uses the same owned device-directory descriptor and atomic publication.
struct SimulatorResourceOfflineStore {
    static var root = "/private/var/tmp"

    static func url(for udid: String) -> URL {
        URL(fileURLWithPath: root)
            .appendingPathComponent("com.apple.CoreSimulator.SimDevice.\(udid)")
            .appendingPathComponent("disabled.plist")
    }

    private static func openDeviceDirectory(_ udid: String, create: Bool) throws -> Int32? {
        guard UUID(uuidString: udid) != nil else { throw SimulatorResourceMutationError.missingUDID }
        let parent = try SimulatorResourceSafeFiles.openDirectory(root)
        defer { close(parent) }
        let name = "com.apple.CoreSimulator.SimDevice.\(udid)"
        if create, mkdirat(parent, name, 0o700) != 0, errno != EEXIST { throw SimulatorResourceOfflineStoreError.invalidFormat }
        let fd = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        if fd < 0, !create, errno == ENOENT { return nil }
        guard fd >= 0 else { throw SimulatorResourceOfflineStoreError.invalidFormat }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_uid == getuid(), info.st_mode & 0o022 == 0 else {
            close(fd); throw SimulatorResourceOfflineStoreError.invalidFormat
        }
        return fd
    }

    private static func read(parent: Int32) throws -> [String: Bool] {
        guard let data = try SimulatorResourceSafeFiles.read(parent: parent, name: "disabled.plist") else { return [:] }
        guard let value = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw SimulatorResourceOfflineStoreError.invalidFormat
        }
        var entries: [String: Bool] = [:]
        for (key, raw) in value {
            guard let number = raw as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else {
                throw SimulatorResourceOfflineStoreError.invalidFormat
            }
            entries[key] = number.boolValue
        }
        return entries
    }

    static func read(_ udid: String) throws -> [String: Bool] {
        guard let fd = try openDeviceDirectory(udid, create: false) else { return [:] }
        defer { close(fd) }
        return try read(parent: fd)
    }

    static func merge(_ udid: String, disable: Set<String>, enable: Set<String>) throws {
        guard disable.isSubset(of: SimulatorResourceCatalog.slimmableLabels),
              enable.isSubset(of: SimulatorResourceCatalog.managedLabels), disable.isDisjoint(with: enable) else {
            throw SimulatorResourceOfflineStoreError.invalidFormat
        }
        guard let parent = try openDeviceDirectory(udid, create: true) else { throw SimulatorResourceOfflineStoreError.invalidFormat }
        defer { close(parent) }
        var entries = try read(parent: parent)
        for label in disable { entries[label] = true }
        for label in enable { entries[label] = false }
        let data = try PropertyListSerialization.data(fromPropertyList: entries, format: .xml, options: 0)
        guard data.count <= 1_048_576 else { throw SimulatorResourceOfflineStoreError.invalidFormat }
        let name = "disabled.plist.\(UUID().uuidString).tmp"
        let fd = openat(parent, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw SimulatorResourceOfflineStoreError.invalidFormat }
        defer { unlinkat(parent, name, 0) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        try handle.write(contentsOf: data)
        guard fsync(fd) == 0, renameat(parent, name, parent, "disabled.plist") == 0, fsync(parent) == 0 else {
            throw SimulatorResourceOfflineStoreError.invalidFormat
        }
    }
}

enum SimulatorResourceOfflineStoreError: Error, Equatable { case invalidFormat }
