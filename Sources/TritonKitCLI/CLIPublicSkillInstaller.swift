import CryptoKit
import Darwin
import Foundation
import TritonKitShared

let publicSkillBundleNames = ["tritonkit-dev-feedback", "tritonkit-emulator-cli-takeover", "tritonkit-real-project-regression", "tritonkit-update"]
private let skillInstallManifest = ".triton-install.json"
private struct PublicSkillInstallReceipt: Codable { let schemaVersion: Int; let files: [String: String] }
private func skillInstallError(_ message: String, code: String = "skills_bundle_invalid") -> CLIUpdateErrorDetail {
    CLIUpdateErrorDetail(code: code, message: message, hint: "Existing skills were preserved. Resolve local changes before retrying.")
}

func validatePublicSkillArchiveListing(names: String, types: String) throws {
    let entries = names.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    let typeRows = types.split(separator: "\n", omittingEmptySubsequences: true)
    guard !entries.isEmpty, entries.count <= 10_000, entries.count == typeRows.count, Set(entries).count == entries.count else {
        throw skillInstallError("Invalid or oversized skill archive listing.")
    }
    let sizePattern = try NSRegularExpression(pattern: "^[d-]\\S+\\s+\\d+\\s+\\S+\\s+\\S+\\s+(\\d+)\\s")
    var expandedBytes = 0
    for (name, row) in zip(entries, typeRows) {
        let line = String(row)
        guard let match = sizePattern.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line), let size = Int(line[range]),
              size <= 100 * 1024 * 1024, expandedBytes <= 100 * 1024 * 1024 - size else {
            throw skillInstallError("Skill archive expanded size is invalid or exceeds bounds.")
        }
        expandedBytes += size
        let parts = name.split(separator: "/", omittingEmptySubsequences: true)
        guard !name.hasPrefix("/"), parts.first == "TritonKit.skills", !parts.contains(".."),
              name.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-/").contains($0) }),
              row.first == "-" || row.first == "d" else {
            throw skillInstallError("Skill archive contains an unsafe path, link or special file.")
        }
    }
}

func extractValidatedPublicSkillArchive(archive: URL, into directory: URL) throws -> URL {
    let size = try archive.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
    guard size <= 100 * 1024 * 1024 else { throw skillInstallError("Skill archive exceeds the download limit.") }
    func listing(_ option: String) throws -> String {
        let result = try runHostCommand(TKHostCommand(executable: "/usr/bin/tar", arguments: [option, archive.path], defaultTimeoutSeconds: 20), maximumOutputBytes: 4 * 1024 * 1024)
        guard !result.stdoutTruncated else { throw skillInstallError("Skill archive listing exceeds bounds.") }
        return result.stdout
    }
    try validatePublicSkillArchiveListing(names: listing("-tzf"), types: listing("-tvzf"))
    _ = try runHostCommand(TKHostCommand(executable: "/usr/bin/tar", arguments: ["-xzf", archive.path, "-C", directory.path, "--no-same-owner", "--no-same-permissions"], defaultTimeoutSeconds: 30))
    let source = directory.appendingPathComponent("TritonKit.skills")
    _ = try publicSkillFileHashes(source)
    return source
}

private func rejectSkillSymlinks(_ path: URL) throws {
    guard !path.path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }) else {
        throw skillInstallError("Skill paths must not contain relative traversal components.")
    }
    var cursor = path
    while cursor.path != "/" {
        var info = stat()
        let status = cursor.path.withCString { lstat($0, &info) }
        if status == 0 && (info.st_mode & S_IFMT) == S_IFLNK {
            // Platform-owned aliases are not caller-controlled install directories.
            guard cursor.path == "/var" || cursor.path == "/tmp" else { throw skillInstallError("Skill path contains a symbolic link.") }
        }
        cursor.deleteLastPathComponent()
    }
}

private func publicSkillFileHashes(_ root: URL) throws -> [String: String] {
    try rejectSkillSymlinks(root)
    // After rejecting caller-controlled links, use one physical path for both
    // enumeration and relative names (Foundation may expand /var to /private/var).
    guard let physicalPath = realpath(root.path, nil) else { throw skillInstallError("Skill source is not a readable directory.") }
    defer { free(physicalPath) }
    let physicalRoot = URL(fileURLWithFileSystemRepresentation: physicalPath, isDirectory: true, relativeTo: nil)
    guard let files = FileManager.default.enumerator(at: physicalRoot, includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey, .fileSizeKey]) else {
        throw skillInstallError("Skill source is not a readable directory.")
    }
    var hashes: [String: String] = [:]; var totalBytes = 0
    for case let item as URL in files {
        let values = try item.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey, .fileSizeKey])
        guard values.isSymbolicLink != true else { throw skillInstallError("Skill bundle contains a symbolic link.") }
        if values.isDirectory == true { continue }
        guard values.isRegularFile == true else { throw skillInstallError("Skill bundle contains a special file.") }
        let relative = String(item.path.dropFirst(physicalRoot.path.count + 1))
        totalBytes += values.fileSize ?? 0
        guard totalBytes <= 100 * 1024 * 1024 else { throw skillInstallError("Skill bundle exceeds bounds.") }
        if relative == skillInstallManifest { continue }
        guard hashes.count < 10_000, totalBytes <= 100 * 1024 * 1024 else { throw skillInstallError("Skill bundle exceeds bounds.") }
        hashes[relative] = SHA256.hash(data: try Data(contentsOf: item)).map { String(format: "%02x", $0) }.joined()
    }
    return hashes
}

private func checkSkillInstallation(_ destination: URL, incoming: [String: String]) throws {
    guard FileManager.default.fileExists(atPath: destination.path) else { try rejectSkillSymlinks(destination); return }
    let current = try publicSkillFileHashes(destination)
    let receipt = destination.appendingPathComponent(skillInstallManifest)
    if FileManager.default.fileExists(atPath: receipt.path) {
        guard (try receipt.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 4 * 1024 * 1024 else { throw skillInstallError("Installation baseline exceeds bounds.") }
        let installed = try JSONDecoder().decode(PublicSkillInstallReceipt.self, from: Data(contentsOf: receipt))
        guard installed.schemaVersion == 1, installed.files == current else { throw skillInstallError("Local skill modifications detected.", code: "skills_update_conflict") }
    } else if current != incoming {
        throw skillInstallError("Existing installation has no baseline; automatic replacement refused.", code: "skills_update_conflict")
    }
}

func installValidatedPublicSkillDirectory(source: URL, destinationRoot: URL) throws {
    let manager = FileManager.default
    let incoming = try publicSkillFileHashes(source)
    for name in publicSkillBundleNames {
        guard incoming["\(name)/SKILL.md"] != nil else { throw skillInstallError("Missing required public skill: \(name).") }
    }
    let buildInfo = source.appendingPathComponent("BUILD_INFO.json")
    if manager.fileExists(atPath: buildInfo.path) {
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: buildInfo)) as? [String: Any]
        guard object?["name"] as? String == "tritonkit-skills", object?["bundlePath"] as? String == "TritonKit.skills/" else { throw skillInstallError("Invalid BUILD_INFO metadata.") }
    }
    try rejectSkillSymlinks(destinationRoot)
    let destination = destinationRoot.appendingPathComponent("TritonKit.skills")
    try checkSkillInstallation(destination, incoming: incoming)
    var legacy: [URL] = []
    for name in publicSkillBundleNames {
        let old = destinationRoot.appendingPathComponent(name)
        try rejectSkillSymlinks(old)
        if manager.fileExists(atPath: old.path) {
            let oldFiles = try publicSkillFileHashes(old)
            let referenceFiles = try publicSkillFileHashes(source.appendingPathComponent(name))
            guard oldFiles.isEmpty || oldFiles == referenceFiles else {
                throw skillInstallError("Legacy skill has local changes: \(name).", code: "skills_update_conflict")
            }
            legacy.append(old)
        }
    }
    try manager.createDirectory(at: destinationRoot, withIntermediateDirectories: true)
    let lock = destinationRoot.appendingPathComponent(".triton-skills-update.lock")
    let acquired = lock.path.withCString { mkdir($0, 0o700) == 0 }
    guard acquired else { throw skillInstallError("Another skill update is active.", code: "skills_update_busy") }
    defer { try? manager.removeItem(at: lock) }
    let staged = destinationRoot.appendingPathComponent(".triton-skills-stage-\(UUID().uuidString)")
    var stagedContainsBackup = false
    defer { if !stagedContainsBackup { try? manager.removeItem(at: staged) } }
    try manager.copyItem(at: source, to: staged)
    guard try publicSkillFileHashes(staged) == incoming else {
        try? manager.removeItem(at: staged)
        throw skillInstallError("Skill source changed during staging.")
    }
    for file in [staged] + (manager.enumerator(at: staged, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? []) {
        let attributes = try manager.attributesOfItem(atPath: file.path)
        let directory = attributes[.type] as? FileAttributeType == .typeDirectory
        let executable = ((attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0) & 0o111 != 0
        try manager.setAttributes([.posixPermissions: directory || executable ? 0o700 : 0o600], ofItemAtPath: file.path)
    }
    let receipt = staged.appendingPathComponent(skillInstallManifest)
    try JSONEncoder().encode(PublicSkillInstallReceipt(schemaVersion: 1, files: incoming)).write(to: receipt, options: .atomic)
    try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: receipt.path)
    try checkSkillInstallation(destination, incoming: incoming)
    // Recheck legacy files after the lock. Never remove local edits.
    for old in legacy {
        let oldFiles = try publicSkillFileHashes(old)
        let referenceFiles = try publicSkillFileHashes(source.appendingPathComponent(old.lastPathComponent))
        guard oldFiles.isEmpty || oldFiles == referenceFiles else {
            throw skillInstallError("Legacy skill changed during update.", code: "skills_update_conflict")
        }
    }
    if manager.fileExists(atPath: destination.path) {
        let status = staged.path.withCString { left in destination.path.withCString { right in renamex_np(left, right, UInt32(RENAME_SWAP)) } }
        guard status == 0 else { throw skillInstallError("Atomic skill bundle exchange failed.") }
        stagedContainsBackup = true // never delete the previous installation, including backup rename failure
        let backup = destinationRoot.appendingPathComponent(".triton-skills-backup-\(UUID().uuidString)")
        try manager.moveItem(at: staged, to: backup)
    } else { try manager.moveItem(at: staged, to: destination) }
    for old in legacy {
        try manager.moveItem(at: old, to: destinationRoot.appendingPathComponent(".triton-skills-legacy-\(old.lastPathComponent)-\(UUID().uuidString)"))
    }
}
