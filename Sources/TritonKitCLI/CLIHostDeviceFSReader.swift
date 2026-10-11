import Darwin
import Foundation

/// Internal private metadata only. Public device/domain/root binding is a separate integration gate.
struct DeviceFSMetadataEntry {
    let name: String
    let kind: String
    let sizeBytes: UInt64?
}
enum DeviceFSReaderError: Error, Equatable { case invalidPath, invalidLimit, directoryUnavailable, unsafeDirectory, enumerationFailed, limitExceeded }
func deviceFSEntryIdentityAccepted(directoryInode: UInt64, first: stat, second: stat, filesystemType: String) -> Bool {
    // Observed DeviceFS provides different synthetic IDs for readdir vs stat. Never apply this exception to other FS types.
    (filesystemType == "devicefs" || directoryInode == first.st_ino) && first.st_ino == second.st_ino && first.st_dev == second.st_dev && first.st_mode & S_IFMT == second.st_mode & S_IFMT
}
func decodedDeviceFSName(_ bytes: Data) throws -> String {
    guard let name = String(data: bytes, encoding: .utf8), !name.isEmpty,
          !name.contains("/"), name.rangeOfCharacter(from: .controlCharacters) == nil else { throw DeviceFSReaderError.enumerationFailed }
    return name
}
func decodedDeviceFSDirent(_ entry: UnsafePointer<dirent>) throws -> String {
    let count = Int(entry.pointee.d_namlen)
    guard let offset = MemoryLayout<dirent>.offset(of: \.d_name), count > 0,
          count < MemoryLayout.size(ofValue: dirent().d_name),
          Int(entry.pointee.d_reclen) >= offset + count + 1 else { throw DeviceFSReaderError.enumerationFailed }
    // Darwin readdir returns variable-length records: never load the entire fixed-width tuple.
    let bytes = UnsafeRawPointer(entry).advanced(by: offset)
    guard bytes.load(fromByteOffset: count, as: UInt8.self) == 0 else { throw DeviceFSReaderError.enumerationFailed }
    return try decodedDeviceFSName(Data(bytes: bytes, count: count))
}
func validatedDeviceFSComponents(root: String, relativeDirectory: String? = nil) throws -> [String] {
    func components(_ value: String, absolute: Bool) throws -> [String] {
        guard value.utf8.count <= 16_384, value.rangeOfCharacter(from: .controlCharacters) == nil,
              absolute == value.hasPrefix("/") else { throw DeviceFSReaderError.invalidPath }
        let parts = value.split(separator: "/", omittingEmptySubsequences: false)
        let segments = absolute ? Array(parts.dropFirst()) : parts
        guard !segments.isEmpty, segments.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else { throw DeviceFSReaderError.invalidPath }
        return segments.map(String.init)
    }
    let rootParts = try components(root, absolute: true)
    let relative = try relativeDirectory.map { try components($0, absolute: false) } ?? []
    guard rootParts.count + relative.count <= 64, root.utf8.count + (relativeDirectory.map { $0.utf8.count + 1 } ?? 0) <= 16_384 else { throw DeviceFSReaderError.invalidPath }
    return rootParts + relative
}
func readDeviceFSShallowMetadata(root: String, relativeDirectory: String? = nil, maximumEntries: Int = 1000, requiredOwner: uid_t? = nil) throws -> [DeviceFSMetadataEntry] {
    guard (1...10_000).contains(maximumEntries) else { throw DeviceFSReaderError.invalidLimit }
    let segments = try validatedDeviceFSComponents(root: root, relativeDirectory: relativeDirectory)
    var descriptor = open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard descriptor >= 0 else { throw DeviceFSReaderError.unsafeDirectory }
    defer { close(descriptor) }
    let rootCount = try validatedDeviceFSComponents(root: root).count
    func checkOwner() throws {
        if let requiredOwner {
            var rootInfo = stat()
            guard fstat(descriptor, &rootInfo) == 0, rootInfo.st_mode & S_IFMT == S_IFDIR,
                  rootInfo.st_uid == requiredOwner else { throw DeviceFSReaderError.unsafeDirectory }
        }
    }
    for (index, segment) in segments.enumerated() {
        let child = openat(descriptor, segment, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard child >= 0 else { throw errno == ENOENT ? DeviceFSReaderError.directoryUnavailable : DeviceFSReaderError.unsafeDirectory }
        close(descriptor)
        descriptor = child
        // Verify device root and every relative directory before continuing, on this same FD chain.
        if index + 1 >= rootCount { try checkOwner() }
    }
    var filesystem = statfs()
    guard fstatfs(descriptor, &filesystem) == 0 else { throw DeviceFSReaderError.enumerationFailed }
    let filesystemType = withUnsafeBytes(of: filesystem.f_fstypename) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    let duplicate = fcntl(descriptor, F_DUPFD_CLOEXEC, 0)
    guard duplicate >= 0 else { throw DeviceFSReaderError.enumerationFailed }
    guard let stream = fdopendir(duplicate) else { close(duplicate); throw DeviceFSReaderError.enumerationFailed }
    defer { closedir(stream) }
    var results: [DeviceFSMetadataEntry] = []
    while true {
        errno = 0
        guard let entry = readdir(stream) else {
            guard errno == 0 else { throw DeviceFSReaderError.enumerationFailed }
            break
        }
        let name = try decodedDeviceFSDirent(UnsafePointer(entry))
        if name == "." || name == ".." { continue }
        // Detect over-budget before additional stat/metadata reads, never silently truncate.
        guard results.count < maximumEntries else { throw DeviceFSReaderError.limitExceeded }
        var info = stat()
        var confirmed = stat()
        guard fstatat(descriptor, name, &info, AT_SYMLINK_NOFOLLOW) == 0,
              fstatat(descriptor, name, &confirmed, AT_SYMLINK_NOFOLLOW) == 0,
              deviceFSEntryIdentityAccepted(directoryInode: entry.pointee.d_ino, first: info, second: confirmed, filesystemType: filesystemType) else { throw DeviceFSReaderError.enumerationFailed }
        let type = info.st_mode & S_IFMT
        let kind: String
        switch type {
        case S_IFDIR: kind = "directory"
        case S_IFLNK: kind = "symbolic-link"
        case S_IFREG: kind = "regular-file"
        default: kind = "other"
        }
        guard info.st_size >= 0 else { throw DeviceFSReaderError.enumerationFailed }
        results.append(DeviceFSMetadataEntry(name: name, kind: kind, sizeBytes: type == S_IFREG ? UInt64(info.st_size) : nil))
    }
    return results.sorted { $0.name < $1.name }
}
