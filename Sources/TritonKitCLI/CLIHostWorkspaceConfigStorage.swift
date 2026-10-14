import Darwin
import Foundation

/// Fixed workspace configuration storage. Descriptors anchor both reads and
/// atomic publications; no caller-controlled nested path or symlink is accepted.
final class HostWorkspaceConfigStorage {
    private let workspace: String
    private let directory: Int32
    private let device: dev_t
    private let inode: ino_t
    static let maximumBytes = 1024 * 1024

    init(workspace: String, create: Bool) throws {
        self.workspace = workspace
        let directory = try Self.openManagedDirectory(workspace: workspace, create: create)
        var info = stat()
        guard fstat(directory, &info) == 0 else { close(directory); throw RuntimeError("workspace_config_directory_failed") }
        self.directory = directory
        self.device = info.st_dev
        self.inode = info.st_ino
    }

    deinit { close(directory) }

    static func existing(workspace: String) throws -> HostWorkspaceConfigStorage? {
        do { return try HostWorkspaceConfigStorage(workspace: workspace, create: false) }
        catch HostWorkspaceConfigMissing.directory { return nil }
    }

    func read(name: String, maximumBytes: Int = HostWorkspaceConfigStorage.maximumBytes) throws -> Data? {
        try validateName(name)
        try verifyIdentity()
        let data = try readUnlocked(name: name, maximumBytes: maximumBytes)?.data
        if let data { try validateAliasSchema(name: name, data: data) }
        return data
    }

    func save(
        name: String,
        data: Data,
        validate: (Data) throws -> Void,
        beforePublish: () throws -> Void = {}
    ) throws {
        try validateName(name)
        guard data.count <= Self.maximumBytes else { throw RuntimeError("workspace_config_byte_limit") }
        try validate(data)
        try validateAliasSchema(name: name, data: data)
        try verifyIdentity()
        guard flock(directory, LOCK_EX) == 0 else { throw RuntimeError("workspace_config_lock_failed") }
        defer { _ = flock(directory, LOCK_UN) }
        let old = try readUnlocked(name: name, maximumBytes: Self.maximumBytes)
        if let old {
            try validate(old.data)
            try validateAliasSchema(name: name, data: old.data)
            if old.data == data { return }
            let backups = try openPrivateChild(name: "config-backups", create: true)
            defer { close(backups) }
            try atomicWrite(data: old.data, name: "\(name).\(UUID().uuidString).raw", parent: backups)
        }
        try beforePublish()
        try verifyIdentity()
        var current = stat()
        let exists = fstatat(directory, name, &current, AT_SYMLINK_NOFOLLOW) == 0
        if let old {
            guard exists, current.st_dev == old.info.st_dev, current.st_ino == old.info.st_ino,
                  current.st_mode & S_IFMT == S_IFREG,
                  try readUnlocked(name: name, maximumBytes: Self.maximumBytes)?.data == old.data else {
                throw RuntimeError("workspace_config_changed_before_publish")
            }
        } else if exists || errno != ENOENT {
            throw RuntimeError("workspace_config_changed_before_publish")
        }
        try atomicWrite(data: data, name: name, parent: directory)
    }

    private func readUnlocked(name: String, maximumBytes: Int) throws -> (data: Data, info: stat)? {
        guard maximumBytes > 0 else { throw RuntimeError("workspace_config_invalid_limit") }
        let fd = openat(directory, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        if fd < 0 {
            if errno == ENOENT { return nil }
            throw RuntimeError("workspace_config_unreadable")
        }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_uid == getuid(), info.st_nlink == 1,
              info.st_size <= maximumBytes, fchmod(fd, 0o600) == 0 else { throw RuntimeError("workspace_config_invalid_file") }
        var data = Data()
        while let chunk = try handle.read(upToCount: min(32 * 1024, maximumBytes + 1 - data.count)), !chunk.isEmpty {
            data.append(chunk)
            guard data.count <= maximumBytes else { throw RuntimeError("workspace_config_byte_limit") }
        }
        return (data, info)
    }

    private func verifyIdentity() throws {
        let current = try Self.openManagedDirectory(workspace: workspace, create: false)
        defer { close(current) }
        var info = stat()
        guard fstat(current, &info) == 0, info.st_dev == device, info.st_ino == inode else {
            throw RuntimeError("workspace_config_directory_changed")
        }
    }

    private func validateAliasSchema(name: String, data: Data) throws {
        guard name == "host-targets.json" else { return }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RuntimeError("workspace_alias_invalid_schema")
        }
        // Missing schemaVersion is the existing legacy v1 format. No migration
        // is written as a side effect of reading it.
        if let value = object["schemaVersion"] {
            guard let number = value as? NSNumber,
                  String(cString: number.objCType) != "c",
                  number == 1 || number == 2 else {
                throw RuntimeError("workspace_alias_unsupported_schema")
            }
        }
    }

    private func validateName(_ name: String) throws {
        guard ["host-defaults.json", "host-targets.json"].contains(name) else {
            throw RuntimeError("workspace_config_invalid_name")
        }
    }

    private func openPrivateChild(name: String, create: Bool) throws -> Int32 {
        if create, mkdirat(directory, name, 0o700) != 0, errno != EEXIST {
            throw RuntimeError("workspace_config_directory_failed")
        }
        return try Self.privateDirectory(parent: directory, name: name)
    }

    private static func openManagedDirectory(workspace: String, create: Bool) throws -> Int32 {
        guard workspace.hasPrefix("/") else { throw RuntimeError("workspace_config_absolute_workspace_required") }
        var parent = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard parent >= 0 else { throw RuntimeError("workspace_config_directory_failed") }
        for component in workspace.split(separator: "/") {
            guard component != ".", component != ".." else { close(parent); throw RuntimeError("workspace_config_invalid_workspace") }
            let next = openat(parent, String(component), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            close(parent)
            guard next >= 0 else { throw RuntimeError("workspace_config_symlink_or_unreadable_ancestor") }
            parent = next
        }
        defer { close(parent) }
        if create, mkdirat(parent, ".triton", 0o700) != 0, errno != EEXIST {
            throw RuntimeError("workspace_config_directory_failed")
        }
        let fd = openat(parent, ".triton", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        if fd < 0 {
            if !create, errno == ENOENT { throw HostWorkspaceConfigMissing.directory }
            throw RuntimeError("workspace_config_symlink_or_unreadable_directory")
        }
        do { try hardenDirectory(fd) } catch { close(fd); throw error }
        return fd
    }

    private static func privateDirectory(parent: Int32, name: String) throws -> Int32 {
        let fd = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw RuntimeError("workspace_config_symlink_or_unreadable_directory") }
        do { try hardenDirectory(fd) } catch { close(fd); throw error }
        return fd
    }

    private static func hardenDirectory(_ fd: Int32) throws {
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_uid == getuid(), fchmod(fd, 0o700) == 0 else {
            throw RuntimeError("workspace_config_directory_owner_or_permissions")
        }
    }

    private func atomicWrite(data: Data, name: String, parent: Int32) throws {
        let staged = ".config-stage-\(UUID().uuidString)"
        let fd = openat(parent, staged, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw RuntimeError("workspace_config_stage_failed") }
        defer { close(fd); _ = unlinkat(parent, staged, 0) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        try handle.write(contentsOf: data)
        guard fchmod(fd, 0o600) == 0, fsync(fd) == 0 else { throw RuntimeError("workspace_config_sync_failed") }
        guard renameat(parent, staged, parent, name) == 0 else { throw RuntimeError("workspace_config_publish_failed") }
        guard fsync(parent) == 0 else { throw RuntimeError("workspace_config_directory_sync_failed") }
    }
}

private enum HostWorkspaceConfigMissing: Error { case directory }
