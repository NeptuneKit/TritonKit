import Darwin
import Foundation

/// Hold the checked destination parent open throughout collection/publication.
/// No extraction: accepts ordinary single-disk ZIP structural metadata, not archive content semantics.
final class DeviceDiagnosticArchive {
    private let parent: Int32
    private let name: String
    private let maximumBytes: Int
    private let parentPath: String
    private let parentDevice: dev_t
    private let parentInode: ino_t

    init(destination: String, maximumBytes: Int) throws {
        guard (1...1_073_741_824).contains(maximumBytes), destination.hasPrefix("/"),
              destination.utf8.count <= 16384, destination.rangeOfCharacter(from: .controlCharacters) == nil,
              destination.lowercased().hasSuffix(".zip") else { throw HostDeviceAdministrationError.unsafeArtifact }
        let parts = destination.dropFirst().split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard (2...64).contains(parts.count), parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && $0.utf8.count <= 255 }) else { throw HostDeviceAdministrationError.unsafeArtifact }
        var fd = open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw HostDeviceAdministrationError.unsafeArtifact }
        do {
            for part in parts.dropLast() {
                let child = openat(fd, part, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                guard child >= 0 else { throw HostDeviceAdministrationError.unsafeArtifact }
                close(fd); fd = child
                var st = stat()
                guard fstat(fd, &st) == 0, st.st_uid == 0 || st.st_uid == getuid(),
                      st.st_mode & 0o022 == 0 else { throw HostDeviceAdministrationError.unsafeArtifact }
            }
            var st = stat()
            guard fstat(fd, &st) == 0, st.st_uid == getuid(), st.st_mode & 0o077 == 0 else { throw HostDeviceAdministrationError.unsafeArtifact }
            let name = parts.last!
            guard fstatat(fd, name, &st, AT_SYMLINK_NOFOLLOW) != 0, errno == ENOENT else { throw HostDeviceAdministrationError.unsafeArtifact }
            self.parent = fd; self.name = name; self.maximumBytes = maximumBytes
            self.parentPath = URL(fileURLWithPath: destination).deletingLastPathComponent().path
            self.parentDevice = st.st_dev
            self.parentInode = st.st_ino
        } catch { close(fd); throw error }
    }
    deinit { close(parent) }

    private func verifyDestinationParent() throws {
        let current = try openDeviceAdministrationPrivateDirectory(parentPath)
        defer { close(current) }
        var info = stat()
        guard fstat(current, &info) == 0,
              info.st_dev == parentDevice, info.st_ino == parentInode,
              info.st_uid == getuid(), info.st_mode & 0o077 == 0 else {
            throw HostDeviceAdministrationError.unsafeArtifact
        }
    }

    func publish(source: String) throws -> Int {
        try verifyDestinationParent()
        let sourceURL = URL(fileURLWithPath: source)
        let sourceParent = try openDeviceAdministrationPrivateDirectory(sourceURL.deletingLastPathComponent().path)
        defer { close(sourceParent) }
        let input = openat(sourceParent, sourceURL.lastPathComponent, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        guard input >= 0 else { throw HostDeviceAdministrationError.unsafeArtifact }
        defer { close(input) }
        var initial = stat()
        guard fstat(input, &initial) == 0, initial.st_mode & S_IFMT == S_IFREG,
              initial.st_uid == getuid(), initial.st_nlink == 1,
              fchmod(input, 0o600) == 0 else { throw HostDeviceAdministrationError.unsafeArtifact }
        guard initial.st_size >= 22, initial.st_size <= maximumBytes else { throw HostDeviceAdministrationError.artifactLimit }
        try validateZIP(input, size: Int(initial.st_size))
        try verifyDestinationParent()
        let output = openat(parent, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard output >= 0 else { throw HostDeviceAdministrationError.unsafeArtifact }
        var succeeded = false
        defer { close(output); if !succeeded { _ = unlinkat(parent, name, 0) } }
        var total = 0, buffer = [UInt8](repeating: 0, count: 65536)
        while true {
            let count = buffer.withUnsafeMutableBytes { read(input, $0.baseAddress, $0.count) }
            if count < 0 && errno == EINTR { continue }
            guard count >= 0 else { throw HostDeviceAdministrationError.unsafeArtifact }
            if count == 0 { break }
            guard total <= maximumBytes - count else { throw HostDeviceAdministrationError.artifactLimit }
            var offset = 0
            while offset < count {
                let written = buffer.withUnsafeBytes { write(output, $0.baseAddress!.advanced(by: offset), count - offset) }
                if written < 0 && errno == EINTR { continue }
                guard written > 0 else { throw HostDeviceAdministrationError.unsafeArtifact }; offset += written
            }
            total += count
        }
        var final = stat()
        guard fstat(input, &final) == 0, final.st_size == initial.st_size, total == initial.st_size,
              final.st_mtimespec.tv_sec == initial.st_mtimespec.tv_sec,
              final.st_mtimespec.tv_nsec == initial.st_mtimespec.tv_nsec,
              fsync(output) == 0, fsync(parent) == 0 else { throw HostDeviceAdministrationError.unsafeArtifact }
        try verifyDestinationParent()
        succeeded = true
        return total
    }

    private func validateZIP(_ fd: Int32, size: Int) throws {
        let length = min(size, 65_557), start = size - length
        var tail = [UInt8](repeating: 0, count: length)
        let readCount = tail.withUnsafeMutableBytes { pread(fd, $0.baseAddress, length, off_t(start)) }
        guard readCount == length else { throw HostDeviceAdministrationError.unsafeArtifact }
        func u16(_ p: Int) -> Int { Int(tail[p]) | Int(tail[p + 1]) << 8 }
        func u32(_ p: Int) -> Int { u16(p) | u16(p + 2) << 16 }
        guard let end = stride(from: length - 22, through: 0, by: -1).first(where: { p in
            tail[p] == 0x50 && tail[p + 1] == 0x4b && tail[p + 2] == 0x05 && tail[p + 3] == 0x06 && p + 22 + u16(p + 20) == length
        }), u16(end + 4) == 0, u16(end + 6) == 0,
        u16(end + 8) == u16(end + 10), u16(end + 10) < 65535,
        u32(end + 12) + u32(end + 16) == start + end else { throw HostDeviceAdministrationError.unsafeArtifact }
        let count = u16(end + 10), centralSize = u32(end + 12), offset = u32(end + 16)
        guard count <= 100_000, centralSize <= 16_777_216, offset <= size else { throw HostDeviceAdministrationError.artifactLimit }
        if count == 0 { guard offset == 0 && centralSize == 0 else { throw HostDeviceAdministrationError.unsafeArtifact }; return }
        var central = [UInt8](repeating: 0, count: centralSize)
        guard central.withUnsafeMutableBytes({ pread(fd, $0.baseAddress, centralSize, off_t(offset)) }) == centralSize else { throw HostDeviceAdministrationError.unsafeArtifact }
        func word(_ p: Int) -> Int { Int(central[p]) | Int(central[p + 1]) << 8 }
        var cursor = 0
        for _ in 0..<count {
            guard cursor + 46 <= centralSize, Array(central[cursor..<cursor + 4]) == [0x50,0x4b,0x01,0x02], word(cursor + 34) == 0 else { throw HostDeviceAdministrationError.unsafeArtifact }
            let nameLength = word(cursor + 28)
            let next = cursor + 46 + nameLength + word(cursor + 30) + word(cursor + 32)
            guard next <= centralSize, nameLength > 0 else { throw HostDeviceAdministrationError.unsafeArtifact }
            func dword(_ p: Int) -> Int { word(p) | word(p + 2) << 16 }
            let localOffset = dword(cursor + 42), compressedSize = dword(cursor + 20)
            let uncompressedSize = dword(cursor + 24), flags = word(cursor + 8)
            guard localOffset < offset, localOffset <= offset - 30,
                  compressedSize != 0xffff_ffff, uncompressedSize != 0xffff_ffff else { throw HostDeviceAdministrationError.unsafeArtifact }
            var local = [UInt8](repeating: 0, count: 30)
            guard local.withUnsafeMutableBytes({ pread(fd, $0.baseAddress, 30, off_t(localOffset)) }) == 30,
                  Array(local[0..<4]) == [0x50,0x4b,0x03,0x04] else { throw HostDeviceAdministrationError.unsafeArtifact }
            func localWord(_ p: Int) -> Int { Int(local[p]) | Int(local[p + 1]) << 8 }
            func localDword(_ p: Int) -> Int { localWord(p) | localWord(p + 2) << 16 }
            guard localWord(6) == flags, localWord(8) == word(cursor + 10),
                  localWord(26) == nameLength else { throw HostDeviceAdministrationError.unsafeArtifact }
            let payloadStart = localOffset + 30 + nameLength + localWord(28)
            guard payloadStart <= offset, compressedSize <= offset - payloadStart else { throw HostDeviceAdministrationError.unsafeArtifact }
            var localName = [UInt8](repeating: 0, count: nameLength)
            guard localName.withUnsafeMutableBytes({ pread(fd, $0.baseAddress, nameLength, off_t(localOffset + 30)) }) == nameLength,
                  localName == Array(central[cursor + 46..<cursor + 46 + nameLength]) else { throw HostDeviceAdministrationError.unsafeArtifact }
            if flags & 8 == 0 {
                guard localDword(14) == dword(cursor + 16), localDword(18) == compressedSize,
                      localDword(22) == uncompressedSize else { throw HostDeviceAdministrationError.unsafeArtifact }
            } else {
                // ZIP bit 3 requires a data descriptor after the compressed payload.
                let descriptorStart = payloadStart + compressedSize
                guard descriptorStart <= offset - 12 else { throw HostDeviceAdministrationError.unsafeArtifact }
                var descriptor = [UInt8](repeating: 0, count: min(16, offset - descriptorStart))
                let descriptorSize = descriptor.count
                guard descriptor.withUnsafeMutableBytes({ pread(fd, $0.baseAddress, descriptorSize, off_t(descriptorStart)) }) == descriptorSize else { throw HostDeviceAdministrationError.unsafeArtifact }
                func descriptorDword(_ p: Int) -> Int { Int(descriptor[p]) | Int(descriptor[p + 1]) << 8 | Int(descriptor[p + 2]) << 16 | Int(descriptor[p + 3]) << 24 }
                let skip = Array(descriptor.prefix(4)) == [0x50,0x4b,0x07,0x08] ? 4 : 0
                guard descriptorSize >= skip + 12, descriptorDword(skip) == dword(cursor + 16),
                      descriptorDword(skip + 4) == compressedSize,
                      descriptorDword(skip + 8) == uncompressedSize else { throw HostDeviceAdministrationError.unsafeArtifact }
            }
            cursor = next
        }
        guard cursor == centralSize else { throw HostDeviceAdministrationError.unsafeArtifact }
    }
}
