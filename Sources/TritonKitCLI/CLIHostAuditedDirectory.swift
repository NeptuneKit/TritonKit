import Darwin
import Foundation

/// A private audit directory anchored by an open directory descriptor.
/// Path identity is rechecked around externally running operations; the FD keeps
/// audit writes on the originally accepted directory if its pathname is replaced.
final class DeviceAuditDirectory {
    let path: String
    private let descriptor: Int32
    private let device: dev_t
    private let inode: ino_t

    init(path: String) throws {
        self.path = path
        let fd = try openDeviceAdministrationPrivateDirectory(path)
        var info = stat()
        guard fstat(fd, &info) == 0 else { close(fd); throw HostDeviceAdministrationError.auditFailed }
        self.descriptor = fd
        self.device = info.st_dev
        self.inode = info.st_ino
    }

    deinit { close(descriptor) }

    func verifyPathIdentity() throws {
        let current = try openDeviceAdministrationPrivateDirectory(path)
        defer { close(current) }
        var info = stat()
        guard fstat(current, &info) == 0,
              info.st_dev == device, info.st_ino == inode,
              info.st_uid == getuid(), info.st_mode & 0o077 == 0 else {
            throw HostDeviceAdministrationError.auditFailed
        }
    }

    func write(name: String, payload: [String: Any]) throws {
        guard name.utf8.count > 0, name.utf8.count <= 255,
              !name.contains("/"), name != ".", name != "..",
              name.rangeOfCharacter(from: .controlCharacters) == nil else {
            throw HostDeviceAdministrationError.auditFailed
        }
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let fd = openat(descriptor, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw HostDeviceAdministrationError.auditFailed }
        defer { close(fd) }
        let success = data.withUnsafeBytes { bytes -> Bool in
            var offset = 0
            while offset < bytes.count {
                let result = Darwin.write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                if result < 0 && errno == EINTR { continue }
                guard result > 0 else { return false }
                offset += result
            }
            return true
        }
        guard success, fsync(fd) == 0, fsync(descriptor) == 0 else {
            throw HostDeviceAdministrationError.auditFailed
        }
    }
}

/// Apply private permissions through an O_NOFOLLOW descriptor. A path-based
/// chmod would follow a replaced symlink and could mutate an unrelated file.
func hardenPrivateArtifact(path: String, mode: mode_t = 0o600) {
    let fd = open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
    guard fd >= 0 else { return }
    defer { close(fd) }
    _ = fchmod(fd, mode)
}
