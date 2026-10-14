import Darwin
import Foundation
import TritonKitShared

func validateAppArchivePath(_ name: String) throws -> [String] {
    guard !name.isEmpty, !name.hasPrefix("/"), !name.hasPrefix("-"), name.utf8.count <= 4096,
          name.rangeOfCharacter(from: .controlCharacters) == nil,
          !name.contains("\\"), name.rangeOfCharacter(from: CharacterSet(charactersIn: "*?[]")) == nil else { throw AppArchiveError.unsafeArchive }
    let value = name.hasSuffix("/") ? String(name.dropLast()) : name
    let parts = value.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
    guard parts.count <= 64, parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && $0.utf8.count <= 255 }) else { throw AppArchiveError.unsafeArchive }
    return parts
}
func validateArchivedAppPlatform(_ platforms: [String], scope: String) throws {
    let required = scope == "real" ? "iPhoneOS" : "iPhoneSimulator"
    guard ["real", "simulator"].contains(scope), platforms == [required] else { throw AppArchiveError.platformMismatch }
}

/// Central and local ZIP headers must agree; encrypted, ZIP64, links, duplicate/case-folded paths,
/// overlapping payloads and special files are refused before any extraction.
func parseAppArchiveZIP(_ data: Data, budget: AppArchiveBudget) throws -> [AppArchiveZIPEntry] {
    guard data.count >= 22, data.count <= budget.maximumArchiveBytes else { throw AppArchiveError.budgetExceeded }
    func number(_ offset: Int, _ width: Int) throws -> Int {
        guard offset >= 0, width <= 4, offset <= data.count - width else { throw AppArchiveError.unsafeArchive }
        return (0..<width).reduce(0) { $0 | Int(data[offset + $1]) << (8 * $1) }
    }
    var end: Int?
    for index in stride(from: data.count - 22, through: max(0, data.count - 65_557), by: -1) {
        if try number(index, 4) == 0x06054b50, index + 22 + (try number(index + 20, 2)) == data.count { end = index; break }
    }
    guard let end, try number(end + 4, 2) == 0, try number(end + 6, 2) == 0 else { throw AppArchiveError.unsafeArchive }
    let count = try number(end + 10, 2), centralSize = try number(end + 12, 4), centralStart = try number(end + 16, 4)
    guard count > 0, count < 65_535, count <= budget.maximumEntries, try number(end + 8, 2) == count,
          centralStart + centralSize == end else { throw AppArchiveError.unsafeArchive }
    var cursor = centralStart, expanded = 0, paths: Set<String> = [], entries: [AppArchiveZIPEntry] = [], spans: [Range<Int>] = []
    for _ in 0..<count {
        guard try number(cursor, 4) == 0x02014b50 else { throw AppArchiveError.unsafeArchive }
        let flags = try number(cursor + 8, 2), method = try number(cursor + 10, 2)
        let compressed = try number(cursor + 20, 4), size = try number(cursor + 24, 4)
        let nameLength = try number(cursor + 28, 2), extra = try number(cursor + 30, 2), comment = try number(cursor + 32, 2)
        let attributes = try number(cursor + 38, 4), local = try number(cursor + 42, 4)
        guard flags & ~0x0808 == 0, [0, 8].contains(method), nameLength > 0,
              cursor + 46 + nameLength + extra + comment <= end, try number(cursor + 34, 2) == 0,
              compressed != 0xffffffff, size != 0xffffffff, local != 0xffffffff,
              let name = String(data: data.subdata(in: cursor + 46..<cursor + 46 + nameLength), encoding: .utf8) else { throw AppArchiveError.unsafeArchive }
        _ = try validateAppArchivePath(name)
        let canonical = name.trimmingCharacters(in: CharacterSet(charactersIn: "/")).precomposedStringWithCanonicalMapping.lowercased()
        guard paths.insert(canonical).inserted else { throw AppArchiveError.unsafeArchive }
        let mode = attributes >> 16, type = mode & Int(S_IFMT), directory = name.hasSuffix("/")
        guard type == 0 || type == Int(directory ? S_IFDIR : S_IFREG), !directory || size == 0,
              size <= budget.maximumFileBytes, expanded <= budget.maximumExpandedBytes - size,
              size == 0 || compressed > 0, compressed == 0 || size / compressed <= 1000 else { throw AppArchiveError.budgetExceeded }
        expanded += size
        guard try number(local, 4) == 0x04034b50, try number(local + 6, 2) == flags, try number(local + 8, 2) == method else { throw AppArchiveError.unsafeArchive }
        let localName = try number(local + 26, 2), localExtra = try number(local + 28, 2)
        let payload = local + 30 + localName + localExtra
        guard localName == nameLength, payload <= centralStart, payload + compressed <= centralStart,
              data.subdata(in: local + 30..<local + 30 + localName) == Data(name.utf8) else { throw AppArchiveError.unsafeArchive }
        if flags & 8 == 0 {
            guard try number(local + 18, 4) == compressed, try number(local + 22, 4) == size,
                  try number(local + 14, 4) == number(cursor + 16, 4) else { throw AppArchiveError.unsafeArchive }
        }
        let span = local..<payload + compressed
        guard !spans.contains(where: { $0.overlaps(span) }) else { throw AppArchiveError.unsafeArchive }
        spans.append(span)
        entries.append(AppArchiveZIPEntry(name: name, expandedBytes: size, compressedBytes: compressed, executable: mode & 0o111 != 0, directory: directory))
        cursor += 46 + nameLength + extra + comment
    }
    guard cursor == end else { throw AppArchiveError.unsafeArchive }
    // A directory cannot also be the ancestor of a regular file with the same canonical name.
    let regular = Set(entries.filter { !$0.directory }.map { $0.name.precomposedStringWithCanonicalMapping.lowercased() })
    for entry in entries {
        let parts = try validateAppArchivePath(entry.name)
        for depth in 1..<parts.count {
            guard !regular.contains(parts.prefix(depth).joined(separator: "/").precomposedStringWithCanonicalMapping.lowercased()) else { throw AppArchiveError.unsafeArchive }
        }
    }
    return entries
}

func prepareHostIOSAppArchive(path: String, scope: String, budget: AppArchiveBudget = .init()) throws -> PreparedHostIOSAppArchive {
    guard ["zip", "ipa"].contains(URL(fileURLWithPath: path).pathExtension.lowercased()) else { return .init(appPath: path, workspace: nil) }
    guard (1...1_073_741_824).contains(budget.maximumArchiveBytes), (1...2_147_483_648).contains(budget.maximumExpandedBytes),
          budget.maximumFileBytes > 0, budget.maximumFileBytes <= budget.maximumExpandedBytes,
          (1...10_000).contains(budget.maximumEntries), budget.timeout.isFinite, budget.timeout > 0 else { throw AppArchiveError.budgetExceeded }
    let workspace = try makeDeviceAdministrationWorkspace()
    var succeeded = false
    defer { if !succeeded { try? FileManager.default.removeItem(atPath: workspace) } }
    let fd = open(path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
    guard fd >= 0 else { throw AppArchiveError.unsafeArchive }
    let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    defer { try? handle.close() }
    var before = stat()
    guard fstat(fd, &before) == 0, before.st_mode & S_IFMT == S_IFREG, before.st_size <= budget.maximumArchiveBytes else { throw AppArchiveError.unsafeArchive }
    let data = try handle.read(upToCount: budget.maximumArchiveBytes + 1) ?? Data()
    var after = stat()
    guard fstat(fd, &after) == 0, before.st_size == after.st_size, data.count == before.st_size,
          before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec, before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec else { throw AppArchiveError.unsafeArchive }
    let entries = try parseAppArchiveZIP(data, budget: budget)
    let snapshot = workspace + "/input.zip"
    try data.write(to: URL(fileURLWithPath: snapshot), options: .withoutOverwriting)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: snapshot)
    let root = workspace + "/expanded"
    try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    let deadline = Date().addingTimeInterval(budget.timeout)
    var candidates: Set<String> = []
    for entry in entries {
        let parts = try validateAppArchivePath(entry.name)
        if let index = parts.firstIndex(where: { $0.hasSuffix(".app") }) { candidates.insert(parts.prefix(index + 1).joined(separator: "/")) }
        let target = root + "/" + parts.joined(separator: "/")
        let directory = entry.directory ? target : URL(fileURLWithPath: target).deletingLastPathComponent().path
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        if entry.directory { continue }
        let remaining = deadline.timeIntervalSinceNow
        guard remaining > 0 else { throw AppArchiveError.budgetExceeded }
        // unzip only inflates to stdout. The bounded pipe never writes an untrusted expansion to disk;
        // output size must match the checked central directory and unzip verifies CRC.
        let command = TKHostCommand(executable: "/usr/bin/unzip", arguments: ["-p", snapshot, entry.name], defaultTimeoutSeconds: remaining)
        let result = try runHostCommand(command, maximumOutputBytes: entry.expandedBytes + 1)
        guard result.exitCode == 0, !result.stdoutTruncated, result.stdoutData.count == entry.expandedBytes else { throw AppArchiveError.extractionFailed }
        try result.stdoutData.write(to: URL(fileURLWithPath: target), options: .withoutOverwriting)
        try FileManager.default.setAttributes([.posixPermissions: entry.executable ? 0o700 : 0o600], ofItemAtPath: target)
    }
    guard candidates.count == 1, let candidate = candidates.first else { throw AppArchiveError.ambiguousApp }
    let appPath = root + "/" + candidate
    let plistPath = appPath + "/Info.plist"
    guard let plistEntry = entries.first(where: { $0.name == candidate + "/Info.plist" }), plistEntry.expandedBytes <= 1_048_576,
          let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: URL(fileURLWithPath: plistPath)), format: nil) as? [String: Any],
          let identifier = plist["CFBundleIdentifier"] as? String, !identifier.isEmpty,
          let executable = plist["CFBundleExecutable"] as? String, (try? validateAppArchivePath(executable))?.count == 1,
          entries.contains(where: { $0.name == candidate + "/" + executable && !$0.directory && $0.expandedBytes > 0 }) else { throw AppArchiveError.ambiguousApp }
    try validateArchivedAppPlatform(plist["CFBundleSupportedPlatforms"] as? [String] ?? [], scope: scope)
    try? FileManager.default.removeItem(atPath: snapshot)
    succeeded = true
    return .init(appPath: appPath, workspace: workspace)
}
