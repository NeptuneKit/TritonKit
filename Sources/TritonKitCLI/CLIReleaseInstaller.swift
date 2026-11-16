import Darwin
import Foundation
import TritonKitShared

private func releaseInstallError(_ message: String) -> CLIUpdateErrorDetail {
    .init(code: "release_install_invalid", message: message, hint: "Choose a new absolute directory outside Homebrew Cellar; existing installations are preserved.")
}

func isStandaloneCLIRelease(source: CLIUpdateInstallSource, executable: String) -> Bool {
    guard source == .manual || source == .unknown else { return false }
    let root = URL(fileURLWithPath: executable).resolvingSymlinksInPath().deletingLastPathComponent()
    let fm = FileManager.default
    return fm.fileExists(atPath: root.appendingPathComponent("web/index.html").path)
        && fm.fileExists(atPath: root.appendingPathComponent("resources/ios-runner/RUNNER_MANIFEST.json").path)
}

private func validateStandaloneWebEntrypoints(at root: URL) throws {
    let index = root.appendingPathComponent("index.html")
    guard (try? index.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
          let handle = try? FileHandle(forReadingFrom: index) else {
        throw releaseInstallError("Bundled Web index is missing.")
    }
    defer { try? handle.close() }
    let limit = 1_048_576
    guard let data = try handle.read(upToCount: limit + 1), data.count <= limit,
          let html = String(data: data, encoding: .utf8) else {
        throw releaseInstallError("Bundled Web index is oversized or invalid.")
    }
    let scriptPattern = #"(?is)<script\b[^>]*\ssrc\s*=\s*["'](?:/|\./)?assets/([a-z0-9][a-z0-9._-]*\.m?js)["'][^>]*>"#
    let stylePattern = #"(?is)<link\b(?=[^>]*\srel\s*=\s*["']stylesheet["'])[^>]*\shref\s*=\s*["'](?:/|\./)?assets/([a-z0-9][a-z0-9._-]*\.css)["'][^>]*>"#
    for pattern in [scriptPattern, stylePattern] {
        let regex = try NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        guard !matches.isEmpty else { throw releaseInstallError("Bundled Web JS or CSS entrypoint is missing.") }
        for match in matches {
            guard let range = Range(match.range(at: 1), in: html) else { throw releaseInstallError("Bundled Web entrypoint is invalid.") }
            let asset = root.appendingPathComponent("assets").appendingPathComponent(String(html[range]))
            guard let values = try? asset.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
                  values.isRegularFile == true, values.isSymbolicLink != true, (values.fileSize ?? 0) > 0 else {
                throw releaseInstallError("Bundled Web entrypoint is missing or invalid.")
            }
        }
    }
}

func validateReleaseInstallDestination(_ path: String) throws {
    guard path.hasPrefix("/"), path != "/", !path.contains("\n"),
          !path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." || $0 == "Cellar" }) else {
        throw releaseInstallError("Invalid release installation directory.")
    }
    var cursor = URL(fileURLWithPath: path)
    var first = true
    while cursor.path != "/" {
        var info = stat()
        if lstat(cursor.path, &info) == 0 {
            if first { throw releaseInstallError("Installation destination already exists.") }
            if info.st_mode & S_IFMT == S_IFLNK, cursor.path != "/tmp", cursor.path != "/var" {
                throw releaseInstallError("Installation parent contains a symbolic link.")
            }
            guard info.st_mode & S_IFMT == S_IFDIR || info.st_mode & S_IFMT == S_IFLNK else { throw releaseInstallError("Installation parent is not a directory.") }
        } else if errno != ENOENT { throw releaseInstallError("Unable to inspect installation path.") }
        first = false
        cursor.deleteLastPathComponent()
    }
}

func standaloneCLIUpdatePlan(_ plan: CLIUpdateResponse, directory: String, confirm: Bool) -> CLIUpdateResponse {
    var result = CLIUpdateResponse(ok: true, currentVersion: plan.currentVersion, latestVersion: plan.latestVersion,
        targetVersion: plan.targetVersion, releaseTag: plan.releaseTag, updateAvailable: plan.updateAvailable,
        checkOnly: plan.checkOnly, dryRun: plan.dryRun, requiresConfirmation: !plan.checkOnly && !plan.dryRun && !confirm,
        updated: false, skillsUpdated: false, installSource: plan.installSource, currentExecutable: plan.currentExecutable,
        repository: plan.repository, assetName: plan.assetName, checksumManifestName: plan.checksumManifestName,
        actions: [
            .init(id: "download-release", kind: .downloadCLIAsset, description: "Download complete release and same-tag checksums", command: nil, args: [], path: nil, destructive: false),
            .init(id: "verify-release", kind: .verifyChecksum, description: "Verify checksum, archive paths, binary version, Web and Runner resources", command: nil, args: [], path: nil, destructive: false),
            .init(id: "install-release-directory", kind: .installReleaseDirectory, description: "Publish complete payload to a new directory without replacing Homebrew or PATH", command: nil, args: [], path: directory, destructive: true),
            .init(id: "verify-installed-version", kind: .verifyInstalledVersion, description: "Verify the newly installed executable", command: nil, args: ["version", "--json"], path: directory + "/triton", destructive: false)
        ] + plan.actions.filter { $0.kind == .downloadSkillsBundle || $0.kind == .installSkillsBundle },
        manualInstructions: ["Run \(directory)/triton explicitly. Homebrew, its symlinks and PATH are unchanged."], error: nil)
    result.releaseInstallDirectory = directory
    result.installedExecutable = directory + "/triton"
    return result
}

func validateCLIReleaseArchiveListing(names: String, types: String, rootName: String) throws {
    let names = names.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    let rows = types.split(separator: "\n", omittingEmptySubsequences: true)
    guard !names.isEmpty, names.count <= 20_000, names.count == rows.count,
          Set(names.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "/")) }).count == names.count else { throw releaseInstallError("Invalid release archive listing.") }
    let regex = try NSRegularExpression(pattern: "^[d-]\\S+\\s+\\d+\\s+\\S+\\s+\\S+\\s+(\\d+)\\s")
    var total = 0
    for (name, row) in zip(names, rows) {
        let parts = name.split(separator: "/", omittingEmptySubsequences: true)
        let line = String(row)
        guard !name.hasPrefix("/"), parts.first.map(String.init) == rootName,
              !parts.contains(".."), !parts.contains("."),
              name.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-/").contains($0) }),
              row.first == "d" || row.first == "-",
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line), let size = Int(line[range]),
              size <= 512 * 1024 * 1024, total <= 512 * 1024 * 1024 - size else { throw releaseInstallError("Release archive has an unsafe path, link, special file or excessive size.") }
        total += size
    }
}

func installStandaloneCLIRelease(plan: CLIUpdateResponse, tag: String, repository: String) async throws {
    guard let directory = plan.releaseInstallDirectory, let assetName = plan.assetName, let version = plan.targetVersion,
          repository.range(of: #"\A[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\z"#, options: .regularExpression) != nil else { throw releaseInstallError("Invalid release installation plan.") }
    try validateReleaseInstallDestination(directory)
    let downloads = FileManager.default.temporaryDirectory.appendingPathComponent("triton-release-download-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: downloads) }
    let archive = downloads.appendingPathComponent(assetName)
    let manifest = downloads.appendingPathComponent("tritonkit_checksums.txt")
    let base = "https://github.com/\(repository)/releases/download/\(tag)/"
    try await downloadFile(URL(string: base + assetName)!, to: archive)
    try await downloadFile(URL(string: base + "tritonkit_checksums.txt")!, to: manifest)
    guard (try manifest.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 64 * 1024,
          let expected = try parseTritonReleaseChecksums(String(contentsOf: manifest, encoding: .utf8))[assetName] else { throw releaseInstallError("Invalid checksum manifest.") }
    try installStandaloneCLIReleaseArchive(archive: archive, expectedChecksum: expected, version: version, directory: directory)
}

func installStandaloneCLIReleaseArchive(archive: URL, expectedChecksum: String, version: String, directory: String,
    versionReader: (URL) throws -> String = { binary in
        try runHostCommand(TKHostCommand(executable: binary.path, arguments: ["version", "--json"], defaultTimeoutSeconds: 15)).stdout
    }
) throws {
    try validateReleaseInstallDestination(directory)
    guard (try archive.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 256 * 1024 * 1024,
          try sha256(path: archive.path) == expectedChecksum else { throw CLIUpdateErrorDetail(code: "checksum_mismatch", message: "Complete release checksum is mismatched.", hint: nil) }
    let fm = FileManager.default
    let destination = URL(fileURLWithPath: directory, isDirectory: true)
    let parent = destination.deletingLastPathComponent()
    try fm.createDirectory(at: parent, withIntermediateDirectories: true)
    let staging = parent.appendingPathComponent(".triton-release-\(UUID().uuidString)", isDirectory: true)
    try fm.createDirectory(at: staging, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    defer { try? fm.removeItem(at: staging) }
    let assetName = archive.lastPathComponent
    func listing(_ option: String) throws -> String {
        let result = try runHostCommand(TKHostCommand(executable: "/usr/bin/tar", arguments: [option, archive.path], defaultTimeoutSeconds: 30), maximumOutputBytes: 4 * 1024 * 1024)
        guard !result.stdoutTruncated else { throw releaseInstallError("Archive listing exceeds budget.") }
        return result.stdout
    }
    let rootName = String(assetName.dropLast(".tar.gz".count))
    try validateCLIReleaseArchiveListing(names: listing("-tzf"), types: listing("-tvzf"), rootName: rootName)
    _ = try runHostCommand(TKHostCommand(executable: "/usr/bin/tar", arguments: ["-xzf", archive.path, "-C", staging.path, "--no-same-owner", "--no-same-permissions"], defaultTimeoutSeconds: 60))
    let root = staging.appendingPathComponent(rootName)
    guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]) else { throw releaseInstallError("Release payload is missing.") }
    for case let item as URL in enumerator {
        let values = try item.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true, values.isDirectory == true || values.isRegularFile == true else { throw releaseInstallError("Extracted payload contains links or special files.") }
    }
    let bundle = root.appendingPathComponent("TritonKitCLI_TritonKitCLI.bundle")
    let hookCandidates = ["TritonSimCameraHook.m", "Contents/Resources/TritonSimCameraHook.m", "Contents/Resources/sim-camera/TritonSimCameraHook.m"]
    guard hookCandidates.contains(where: { (try? bundle.appendingPathComponent($0).resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }) else {
        throw releaseInstallError("SwiftPM resources are missing.")
    }
    try validateStandaloneWebEntrypoints(at: root.appendingPathComponent("web"))
    _ = try validateIOSRunnerResources(at: root.appendingPathComponent("resources/ios-runner"), expectedVersion: version)
    let binary = root.appendingPathComponent("triton")
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)
    guard try binary.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { throw releaseInstallError("CLI is not a regular file.") }
    let object = try JSONSerialization.jsonObject(with: Data(versionReader(binary).utf8)) as? [String: Any]
    guard object?["ok"] as? Bool == true, object?["version"] as? String == version else { throw releaseInstallError("Release binary version does not match target.") }
    try validateReleaseInstallDestination(directory)
    // Same filesystem exclusive rename: never replace a directory created concurrently.
    guard renamex_np(root.path, destination.path, UInt32(RENAME_EXCL)) == 0 else { throw releaseInstallError("Unable to publish release without replacing an existing destination.") }
}
