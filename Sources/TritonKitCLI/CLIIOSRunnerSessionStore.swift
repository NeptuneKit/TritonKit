import Foundation
import Darwin

/// Shared by independent CLI processes and the HTTP service. Never a process-local mutex.
final class IOSRunnerSessionStore {
    let root: URL
    let targetDirectory: URL
    init(root: URL, device: String) throws {
        self.root = root.standardizedFileURL
        self.targetDirectory = self.root.appendingPathComponent(iosRunnerKey(device), isDirectory: true)
        try Self.privateDirectory(self.root)
        try Self.privateDirectory(targetDirectory)
    }
    static func privateDirectory(_ url: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            let attrs = try fm.attributesOfItem(atPath: url.path)
            guard attrs[.type] as? FileAttributeType == .typeDirectory,
                  (attrs[.ownerAccountID] as? NSNumber)?.uint32Value == getuid() else {
                throw IOSRunnerFailure("ios_runner_unsafe_store", "Runner store must be an owned directory, without symbolic links.")
            }
        } else { try fm.createDirectory(at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]) }
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }
    func locked<T>(_ name: String = "target", _ operation: () throws -> T) throws -> T {
        let url = targetDirectory.appendingPathComponent(name + ".lock")
        let fd = Darwin.open(url.path, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw IOSRunnerFailure("ios_runner_lock_failed", "Runner lock could not be opened.") }
        defer { Darwin.close(fd) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            throw IOSRunnerFailure("ios_runner_busy", "Another Runner operation owns this target; retry after it completes.")
        }
        defer { flock(fd, LOCK_UN) }
        return try operation()
    }
    func read<T: Decodable>(_ name: String, as type: T.Type) throws -> T? {
        let url = targetDirectory.appendingPathComponent(name + ".json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let fd = Darwin.open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw IOSRunnerFailure("ios_runner_unsafe_store", "Runner configuration cannot be followed through a symbolic link.") }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        return try JSONDecoder().decode(type, from: handle.readToEnd() ?? Data())
    }
    func write<T: Encodable>(_ value: T, name: String) throws {
        let data = try JSONEncoder().encode(value)
        let temp = targetDirectory.appendingPathComponent(".write-" + UUID().uuidString)
        try Self.writeExclusive(data, to: temp)
        let destination = targetDirectory.appendingPathComponent(name + ".json")
        guard Darwin.rename(temp.path, destination.path) == 0 else {
            try? FileManager.default.removeItem(at: temp)
            throw IOSRunnerFailure("ios_runner_store_failed", "Runner state could not be saved.")
        }
    }
    static func writeExclusive(_ data: Data, to url: URL) throws {
        let fd = Darwin.open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw IOSRunnerFailure("ios_runner_artifact_exists", "Output must be a new file in an existing owned directory.") }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        do { try handle.write(contentsOf: data); try handle.synchronize(); try handle.close() }
        catch { try? FileManager.default.removeItem(at: url); throw error }
    }
    static func validateArtifactOutput(_ url: URL) throws {
        var info = stat()
        guard lstat(url.path, &info) != 0, errno == ENOENT else { throw IOSRunnerFailure("ios_runner_artifact_exists", "Screenshot output must be a new file.") }
        let parent = url.deletingLastPathComponent()
        let attributes = try FileManager.default.attributesOfItem(atPath: parent.path)
        guard attributes[.type] as? FileAttributeType == .typeDirectory,
              (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid(),
              Darwin.access(parent.path, W_OK) == 0 else { throw IOSRunnerFailure("ios_runner_artifact_unwritable", "Screenshot output parent must be an existing owned writable directory.") }
    }
    static func writeArtifactExclusive(_ data: Data, to url: URL) throws {
        try validateArtifactOutput(url)
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".triton-image-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try writeExclusive(data, to: temporary)
        guard Darwin.link(temporary.path, url.path) == 0 else { throw IOSRunnerFailure("ios_runner_artifact_exists", "Screenshot output could not be created exclusively.") }
    }
    func newDirectory() throws -> URL {
        let url = targetDirectory.appendingPathComponent("session-" + UUID().uuidString, isDirectory: true)
        try Self.privateDirectory(url)
        return url
    }
}
