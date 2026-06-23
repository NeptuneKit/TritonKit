import Darwin
import Foundation

func currentTritonExecutablePath() -> String {
    var size = UInt32(0)
    _NSGetExecutablePath(nil, &size)
    var buffer = [CChar](repeating: 0, count: Int(size))
    if _NSGetExecutablePath(&buffer, &size) == 0 {
        return String(cString: buffer)
    }
    return CommandLine.arguments.first ?? "triton"
}

func makeCLIUpdatePlan(
    currentVersion: String,
    requestedVersion: String?,
    currentExecutable: String,
    architecture: String,
    checkOnly: Bool,
    dryRun: Bool,
    confirm: Bool,
    includeSkills: Bool,
    skillsDirectory: String?,
    repository: String,
    environment: [String: String]
) throws -> CLIUpdateResponse {
    let target = normalizedReleaseTarget(requestedVersion)
    let installSource = detectCLIUpdateInstallSource(currentExecutable: currentExecutable, environment: environment)
    let assetName = cliUpdateAssetName(forArchitecture: architecture)
    let updateAvailable = target.version.map { versionIsNewer($0, than: currentVersion) } ?? true
    let checksumManifestName = "tritonkit_checksums.txt"
    let mutating = !checkOnly && !dryRun
    let requiresConfirmation = mutating && !confirm && updateAvailable
    var actions: [CLIUpdateAction] = []
    var manualInstructions: [String] = []

    if requestedVersion == nil && installSource != .homebrew && installSource != .sourceCheckout {
        actions.append(CLIUpdateAction(
            id: "resolve-release",
            kind: .resolveRelease,
            description: "Resolve latest GitHub Release for \(repository)",
            command: nil,
            args: [],
            path: nil,
            destructive: false
        ))
    }

    switch installSource {
    case .homebrew:
        actions.append(CLIUpdateAction(
            id: "brew-update",
            kind: .homebrewUpdate,
            description: "Refresh Homebrew tap metadata",
            command: "brew",
            args: ["update"],
            path: nil,
            destructive: false
        ))
        actions.append(CLIUpdateAction(
            id: "brew-upgrade-triton",
            kind: .homebrewUpgrade,
            description: "Upgrade TritonKit CLI through Homebrew",
            command: "brew",
            args: ["upgrade", "neptunekit/tap/triton"],
            path: nil,
            destructive: true
        ))
    case .manual, .unknown:
        actions.append(CLIUpdateAction(
            id: "download-cli-asset",
            kind: .downloadCLIAsset,
            description: "Download \(assetName) from the TritonKit GitHub Release",
            command: nil,
            args: [],
            path: nil,
            destructive: false
        ))
        actions.append(CLIUpdateAction(
            id: "download-checksum-manifest",
            kind: .downloadChecksumManifest,
            description: "Download \(checksumManifestName) from the same GitHub Release",
            command: nil,
            args: [],
            path: nil,
            destructive: false
        ))
        actions.append(CLIUpdateAction(
            id: "verify-checksum",
            kind: .verifyChecksum,
            description: "Verify downloaded CLI asset SHA-256 before installation",
            command: nil,
            args: [],
            path: nil,
            destructive: false
        ))
        actions.append(CLIUpdateAction(
            id: "extract-cli-asset",
            kind: .extractCLIAsset,
            description: "Extract the release archive into a temporary directory",
            command: "tar",
            args: ["-xzf", assetName],
            path: nil,
            destructive: false
        ))
        actions.append(CLIUpdateAction(
            id: "replace-binary",
            kind: .replaceBinary,
            description: "Atomically replace the current triton binary",
            command: nil,
            args: [],
            path: currentExecutable,
            destructive: true
        ))
        if installSource == .unknown {
            manualInstructions.append("Install source is unknown; use --dry-run first and verify the current executable path before running with --yes.")
        }
    case .sourceCheckout:
        manualInstructions.append("Current executable appears to be a source checkout build. Build locally with: swift build --package-path CLI --scratch-path .build/cli -c release --product triton")
    }

    if includeSkills {
        actions.append(CLIUpdateAction(
            id: "download-skills-bundle",
            kind: .downloadSkillsBundle,
            description: "Download tritonkit-skills.tar.gz from the same GitHub Release",
            command: nil,
            args: [],
            path: nil,
            destructive: false
        ))
        actions.append(CLIUpdateAction(
            id: "install-skills-bundle",
            kind: .installSkillsBundle,
            description: "Replace TritonKit.skills in the configured agent skills directory",
            command: nil,
            args: [],
            path: skillsDirectory,
            destructive: true
        ))
    }

    return CLIUpdateResponse(
        ok: true,
        currentVersion: currentVersion,
        latestVersion: target.version,
        targetVersion: target.version,
        releaseTag: target.tag,
        updateAvailable: updateAvailable,
        checkOnly: checkOnly,
        dryRun: dryRun,
        requiresConfirmation: requiresConfirmation,
        updated: false,
        skillsUpdated: false,
        installSource: installSource,
        currentExecutable: currentExecutable,
        repository: repository,
        assetName: assetName,
        checksumManifestName: checksumManifestName,
        actions: actions,
        manualInstructions: manualInstructions,
        error: nil
    )
}

func detectCLIUpdateInstallSource(currentExecutable: String, environment: [String: String]) -> CLIUpdateInstallSource {
    let resolved = URL(fileURLWithPath: currentExecutable).resolvingSymlinksInPath().path
    if resolved.contains("/Cellar/triton/") || resolved.contains("/Homebrew/Cellar/triton/") {
        return .homebrew
    }
    if currentExecutable.contains("/.build/") || resolved.contains("/.build/") {
        return .sourceCheckout
    }
    if currentExecutable.hasSuffix("/triton") || resolved.hasSuffix("/triton") {
        return .manual
    }
    if environment["HOMEBREW_PREFIX"].map({ resolved.hasPrefix($0 + "/Cellar/triton/") }) == true {
        return .homebrew
    }
    return .unknown
}

func cliUpdateAssetName(forArchitecture architecture: String) -> String {
    architecture == "x86_64" ? "triton-macos-x86_64.tar.gz" : "triton-macos-arm64.tar.gz"
}

func parseTritonReleaseChecksums(_ manifest: String) throws -> [String: String] {
    var checksums: [String: String] = [:]
    for rawLine in manifest.split(whereSeparator: \.isNewline) {
        let parts = rawLine.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        guard parts.count >= 2 else {
            continue
        }
        let hash = parts[0]
        let fileName = parts[1].replacingOccurrences(of: "*", with: "")
        guard hash.count == 64, hash.allSatisfy({ $0.isHexDigit }) else {
            throw CLIUpdateErrorDetail(code: "invalid_checksum_manifest", message: "Invalid checksum line: \(rawLine)", hint: "Verify the GitHub Release checksum manifest.")
        }
        checksums[fileName] = hash.lowercased()
    }
    return checksums
}

func normalizedReleaseTarget(_ requestedVersion: String?) -> (tag: String?, version: String?) {
    guard let requestedVersion, !requestedVersion.isEmpty else {
        return (nil, nil)
    }
    if requestedVersion.hasPrefix("v") {
        return (requestedVersion, String(requestedVersion.dropFirst()))
    }
    return ("v\(requestedVersion)", requestedVersion)
}

func versionIsNewer(_ candidate: String, than current: String) -> Bool {
    let candidateParts = semanticVersionParts(candidate)
    let currentParts = semanticVersionParts(current)
    for index in 0..<max(candidateParts.count, currentParts.count) {
        let lhs = index < candidateParts.count ? candidateParts[index] : 0
        let rhs = index < currentParts.count ? currentParts[index] : 0
        if lhs != rhs {
            return lhs > rhs
        }
    }
    return false
}

private func semanticVersionParts(_ version: String) -> [Int] {
    version
        .trimmingCharacters(in: CharacterSet(charactersIn: "v"))
        .split(separator: ".", omittingEmptySubsequences: true)
        .map { part in
            let numericPrefix = part.prefix(while: { $0.isNumber })
            return Int(numericPrefix) ?? 0
        }
}

func runCLIUpdate(
    requestedVersion: String?,
    currentExecutable: String,
    architecture: String,
    checkOnly: Bool,
    dryRun: Bool,
    confirm: Bool,
    includeSkills: Bool,
    skillsDirectory: String?,
    repository: String,
    latestReleaseTagResolver: ((String) async throws -> String) = fetchLatestTritonReleaseTag
) async throws -> CLIUpdateResponse {
    let installSource = detectCLIUpdateInstallSource(
        currentExecutable: currentExecutable,
        environment: ProcessInfo.processInfo.environment
    )
    let releaseTarget: (tag: String?, version: String?)
    if let requestedVersion {
        releaseTarget = normalizedReleaseTarget(requestedVersion)
    } else if installSource == .homebrew && !includeSkills {
        releaseTarget = (nil, nil)
    } else if installSource == .sourceCheckout {
        releaseTarget = (nil, nil)
    } else {
        let tag = try await latestReleaseTagResolver(repository)
        releaseTarget = normalizedReleaseTarget(tag)
    }
    let plan = try makeCLIUpdatePlan(
        currentVersion: TritonKitBuildInfo.cliVersion,
        requestedVersion: releaseTarget.tag,
        currentExecutable: currentExecutable,
        architecture: architecture,
        checkOnly: checkOnly,
        dryRun: dryRun,
        confirm: confirm,
        includeSkills: includeSkills,
        skillsDirectory: skillsDirectory,
        repository: repository,
        environment: ProcessInfo.processInfo.environment
    )
    if plan.checkOnly || plan.dryRun || !plan.updateAvailable {
        return plan
    }
    if includeSkills && skillsDirectory == nil {
        throw CLIUpdateErrorDetail(code: "skills_dir_required", message: "--include-skills requires --skills-dir.", hint: "Pass the agent skills root directory or omit --include-skills.")
    }
    guard !plan.requiresConfirmation else {
        throw CLIUpdateErrorDetail(
            code: "confirmation_required",
            message: "Updating TritonKit modifies local files and requires --yes.",
            hint: "Run triton update --dry-run --json to inspect the plan, then rerun with --yes."
        )
    }

    switch plan.installSource {
    case .homebrew:
        try runProcess("brew", ["update"])
        try runProcess("brew", ["upgrade", "neptunekit/tap/triton"])
    case .manual, .unknown:
        guard let tag = plan.releaseTag else {
            throw CLIUpdateErrorDetail(code: "release_resolution_failed", message: "Unable to resolve release tag.", hint: "Pass --version vX.Y.Z explicitly.")
        }
        try await installManualCLIUpdate(plan: plan, tag: tag, repository: repository)
    case .sourceCheckout:
        throw CLIUpdateErrorDetail(
            code: "source_checkout_update_unsupported",
            message: "The active triton binary appears to be built from a source checkout.",
            hint: "Use swift build --package-path CLI --scratch-path .build/cli -c release --product triton."
        )
    }

    var skillsUpdated = false
    if includeSkills {
        guard let tag = plan.releaseTag else {
            throw CLIUpdateErrorDetail(code: "release_resolution_failed", message: "Unable to resolve release tag for skills bundle.", hint: "Pass --version vX.Y.Z explicitly.")
        }
        guard let skillsDirectory else {
            throw CLIUpdateErrorDetail(code: "skills_dir_required", message: "--include-skills requires --skills-dir.", hint: "Pass the agent skills root directory.")
        }
        try await installSkillsBundle(repository: repository, tag: tag, skillsDirectory: skillsDirectory)
        skillsUpdated = true
    }

    return CLIUpdateResponse(
        ok: true,
        currentVersion: plan.currentVersion,
        latestVersion: plan.latestVersion,
        targetVersion: plan.targetVersion,
        releaseTag: plan.releaseTag,
        updateAvailable: plan.updateAvailable,
        checkOnly: plan.checkOnly,
        dryRun: plan.dryRun,
        requiresConfirmation: false,
        updated: true,
        skillsUpdated: skillsUpdated,
        installSource: plan.installSource,
        currentExecutable: plan.currentExecutable,
        repository: plan.repository,
        assetName: plan.assetName,
        checksumManifestName: plan.checksumManifestName,
        actions: plan.actions,
        manualInstructions: plan.manualInstructions,
        error: nil
    )
}

private func fetchLatestTritonReleaseTag(repository: String) async throws -> String {
    let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    let (data, response) = try await URLSession.shared.data(from: url)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        throw CLIUpdateErrorDetail(code: "release_resolution_failed", message: "GitHub latest release request failed.", hint: "Pass --version vX.Y.Z or check network access.")
    }
    return try JSONDecoder().decode(GitHubLatestReleaseResponse.self, from: data).tagName
}

private func installManualCLIUpdate(plan: CLIUpdateResponse, tag: String, repository: String) async throws {
    guard let assetName = plan.assetName else {
        throw CLIUpdateErrorDetail(code: "unsupported_architecture", message: "No CLI release asset for this architecture.", hint: "Use Homebrew or build from source.")
    }
    let temp = FileManager.default.temporaryDirectory.appendingPathComponent("triton-update-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temp) }

    let assetURL = URL(string: "https://github.com/\(repository)/releases/download/\(tag)/\(assetName)")!
    let checksumsURL = URL(string: "https://github.com/\(repository)/releases/download/\(tag)/tritonkit_checksums.txt")!
    let asset = temp.appendingPathComponent(assetName)
    let checksums = temp.appendingPathComponent("tritonkit_checksums.txt")
    try await downloadFile(assetURL, to: asset)
    try await downloadFile(checksumsURL, to: checksums)
    let manifest = try String(contentsOf: checksums, encoding: .utf8)
    let expected = try parseTritonReleaseChecksums(manifest)[assetName]
    guard let expected else {
        throw CLIUpdateErrorDetail(code: "checksum_missing", message: "Checksum manifest does not contain \(assetName).", hint: "Verify the release assets.")
    }
    let actual = try sha256(path: asset.path)
    guard actual == expected else {
        throw CLIUpdateErrorDetail(code: "checksum_mismatch", message: "Downloaded CLI asset checksum mismatch.", hint: "Do not install this asset; verify the GitHub Release.")
    }
    try runProcess("/usr/bin/tar", ["-xzf", asset.path, "-C", temp.path])
    let extracted = try findExtractedTritonBinary(in: temp)
    try replaceCurrentBinary(with: extracted, destinationPath: plan.currentExecutable)
}

private func installSkillsBundle(repository: String, tag: String, skillsDirectory: String) async throws {
    let temp = FileManager.default.temporaryDirectory.appendingPathComponent("triton-skills-update-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temp) }
    let archive = temp.appendingPathComponent("tritonkit-skills.tar.gz")
    let url = URL(string: "https://github.com/\(repository)/releases/download/\(tag)/tritonkit-skills.tar.gz")!
    try await downloadFile(url, to: archive)
    try runProcess("/usr/bin/tar", ["-xzf", archive.path, "-C", temp.path])
    let source = temp.appendingPathComponent("TritonKit.skills", isDirectory: true)
    let destinationRoot = URL(fileURLWithPath: skillsDirectory, isDirectory: true)
    let destination = destinationRoot.appendingPathComponent("TritonKit.skills", isDirectory: true)
    if FileManager.default.fileExists(atPath: destination.path) {
        try FileManager.default.removeItem(at: destination)
    }
    try FileManager.default.createDirectory(at: destinationRoot, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: source, to: destination)
}

private func downloadFile(_ url: URL, to destination: URL) async throws {
    let (temporary, response) = try await URLSession.shared.download(from: url)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        throw CLIUpdateErrorDetail(code: "download_failed", message: "Failed to download \(url.lastPathComponent).", hint: "Check network access and release asset availability.")
    }
    if FileManager.default.fileExists(atPath: destination.path) {
        try FileManager.default.removeItem(at: destination)
    }
    try FileManager.default.moveItem(at: temporary, to: destination)
}

private func sha256(path: String) throws -> String {
    let output = try captureProcess("/usr/bin/shasum", ["-a", "256", path])
    guard let hash = output.split(whereSeparator: { $0 == " " || $0 == "\t" }).first else {
        throw CLIUpdateErrorDetail(code: "checksum_failed", message: "Unable to compute SHA-256 for \(path).", hint: nil)
    }
    return String(hash).lowercased()
}

private func findExtractedTritonBinary(in directory: URL) throws -> URL {
    guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]) else {
        throw CLIUpdateErrorDetail(code: "extract_failed", message: "Unable to inspect extracted release archive.", hint: nil)
    }
    for case let file as URL in enumerator where file.lastPathComponent == "triton" {
        return file
    }
    throw CLIUpdateErrorDetail(code: "extract_failed", message: "Release archive did not contain a triton binary.", hint: "Verify the GitHub Release asset.")
}

private func replaceCurrentBinary(with source: URL, destinationPath: String) throws {
    let destination = URL(fileURLWithPath: destinationPath)
    let parent = destination.deletingLastPathComponent()
    let staged = parent.appendingPathComponent(".triton-update-\(UUID().uuidString)")
    try FileManager.default.copyItem(at: source, to: staged)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: staged.path)
    try runProcess("/bin/mv", ["-f", staged.path, destination.path])
}

private func runProcess(_ executable: String, _ arguments: [String]) throws {
    _ = try captureProcess(executable, arguments)
}

private func captureProcess(_ executable: String, _ arguments: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr
    try process.run()
    process.waitUntilExit()
    let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    if process.terminationStatus != 0 {
        let error = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        throw CLIUpdateErrorDetail(code: "host_command_failed", message: error.isEmpty ? "Command failed: \(executable)" : error, hint: nil)
    }
    return output
}
