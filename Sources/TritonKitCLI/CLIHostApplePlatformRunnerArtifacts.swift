import Foundation
import Darwin

func runnerError(_ code: String, _ message: String) -> HostApplePlatformControlError {
    HostApplePlatformControlError(code: code, message: message, hint: "Inspect private runner evidence. Never retry device input automatically.")
}

/// The request is copied, never written into the caller's build products.
/// Both XCTest plist layouts are supported; only one target/configuration survives.
func prepareApplePlatformXCTestRun(_ input: Data, request: HostApplePlatformRunnerRequest, originalRoot: String) throws -> Data {
    guard input.count <= 4_194_304, var root = try PropertyListSerialization.propertyList(from: input, options: [], format: nil) as? [String: Any] else {
        throw runnerError("runner_bundle_invalid", "Invalid or oversized xctestrun plist.")
    }
    let components = request.testIdentifier.split(separator: "/").map(String.init)
    let targetName = components[0]
    var payload: [String: Any] = ["version": 1, "platform": request.platform.rawValue, "action": request.action.rawValue, "device": request.device, "nonce": request.nonce]
    if let delta = request.crownDelta { payload["crownDelta"] = delta }
    let encoded = String(decoding: try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]), as: UTF8.self)
    func configure(_ original: [String: Any]) -> [String: Any] {
        var target = original
        for key in ["EnvironmentVariables", "TestingEnvironmentVariables"] {
            var environment = target[key] as? [String: String] ?? [:]
            environment["TRITON_PLATFORM_REQUEST"] = encoded
            target[key] = environment
        }
        target["OnlyTestIdentifiers"] = [components.dropFirst().joined(separator: "/")]
        target["SkipTestIdentifiers"] = []
        target["ParallelizationEnabled"] = false
        return target
    }
    if let configurations = root["TestConfigurations"] as? [[String: Any]] {
        var selected: [[String: Any]] = []
        for var configuration in configurations {
            let targets = (configuration["TestTargets"] as? [[String: Any]] ?? []).filter { ($0["BlueprintName"] as? String) == targetName }
            for target in targets {
                configuration["TestTargets"] = [configure(target)]
                configuration["IsEnabled"] = true
                selected.append(configuration)
            }
        }
        guard selected.count == 1 else { throw runnerError("runner_test_target_ambiguous", "Expected exactly one matching XCTest target/configuration.") }
        root["TestConfigurations"] = selected
    } else {
        guard let selected = root[targetName] as? [String: Any] else { throw runnerError("runner_test_target_missing", "The requested target is absent from xctestrun.") }
        root = root.filter { $0.key.hasPrefix("__") }
        root[targetName] = configure(selected)
    }
    func rewrite(_ value: Any) -> Any {
        if let string = value as? String { return string.replacingOccurrences(of: "__TESTROOT__", with: originalRoot) }
        if let array = value as? [Any] { return array.map(rewrite) }
        if let dictionary = value as? [String: Any] {
            return dictionary.filter { key, _ in
                let lower = key.lowercased()
                return !lower.contains("repetition") && !lower.contains("retry") && lower != "testiterations"
            }.mapValues(rewrite)
        }
        return value
    }
    return try PropertyListSerialization.data(fromPropertyList: rewrite(root), format: .xml, options: 0)
}

private func checkNoSymlinkAncestors(_ path: String) throws {
    guard path.hasPrefix("/"), !path.contains("//"), !path.contains("\0"), !path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }) else { throw runnerError("runner_artifact_path_unsafe", "Artifact paths must be canonical absolute paths.") }
    var cursor = ""
    for component in path.split(separator: "/") {
        cursor += "/" + component
        var info = stat()
        guard lstat(cursor, &info) == 0, (info.st_mode & S_IFMT) != S_IFLNK else { throw runnerError("runner_artifact_path_unsafe", "Artifact paths must exist without symbolic links.") }
    }
}

func readApplePlatformRunnerFile(_ path: String, limit: Int) throws -> Data {
    try checkNoSymlinkAncestors(path)
    let descriptor = open(path, O_RDONLY | O_NOFOLLOW)
    guard descriptor >= 0 else { throw runnerError("runner_artifact_unavailable", "Cannot open runner artifact.") }
    defer { close(descriptor) }
    var info = stat()
    guard fstat(descriptor, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG, info.st_size >= 0, info.st_size <= limit else { throw runnerError("runner_artifact_size_limit", "Runner artifact is not a bounded regular file.") }
    var result = Data()
    var bytes = [UInt8](repeating: 0, count: min(limit + 1, 65536))
    while true {
        let count = read(descriptor, &bytes, bytes.count)
        guard count >= 0 else { throw runnerError("runner_artifact_read_failed", "Cannot read runner artifact.") }
        if count == 0 { break }
        result.append(contentsOf: bytes.prefix(count))
        guard result.count <= limit else { throw runnerError("runner_artifact_size_limit", "Runner artifact exceeded the read budget.") }
    }
    return result
}

func writeApplePlatformRunnerAudit(_ value: [String: Any], to path: String) throws {
    try writeApplePlatformRunnerAuditData(JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]), to: path)
}

func writeApplePlatformRunnerAuditData(_ data: Data, to path: String) throws {
    let descriptor = open(path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
    guard descriptor >= 0 else { throw runnerError("runner_audit_failed", "Cannot exclusively create private audit artifact.") }
    defer { close(descriptor) }
    try data.withUnsafeBytes { buffer in
        var written = 0
        while written < buffer.count {
            let count = write(descriptor, buffer.baseAddress!.advanced(by: written), buffer.count - written)
            guard count > 0 else { throw runnerError("runner_audit_failed", "Cannot persist complete audit artifact.") }
            written += count
        }
    }
    guard fsync(descriptor) == 0 else { throw runnerError("runner_audit_failed", "Cannot synchronize audit artifact.") }
}

func prepareApplePlatformRunnerWorkspace(_ request: HostApplePlatformRunnerRequest) throws -> String {
    guard request.xctestrun.hasSuffix(".xctestrun"), let result = request.resultBundle, result.hasSuffix(".xcresult") else { throw runnerError("runner_artifact_path_unsafe", "Expected .xctestrun and .xcresult paths.") }
    let parent = URL(fileURLWithPath: result).deletingLastPathComponent().path
    try checkNoSymlinkAncestors(parent)
    var info = stat()
    guard lstat(parent, &info) == 0, (info.st_mode & S_IFMT) == S_IFDIR, info.st_uid == getuid(), (info.st_mode & 0o077) == 0 else {
        throw runnerError("runner_artifact_parent_unsafe", "Result parent must be an owned private directory (0700).")
    }
    guard lstat(result, &info) != 0, errno == ENOENT else { throw runnerError("runner_result_path_exists", "Result bundle path already exists or cannot be checked.") }
    let source = try readApplePlatformRunnerFile(request.xctestrun, limit: 4_194_304)
    let prepared = try prepareApplePlatformXCTestRun(source, request: request, originalRoot: URL(fileURLWithPath: request.xctestrun).deletingLastPathComponent().path)
    let workspace = result + ".triton-audit"
    guard mkdir(workspace, 0o700) == 0 else { throw runnerError("runner_audit_path_exists", "Audit directory must be new and private.") }
    try writeApplePlatformRunnerAuditData(prepared, to: workspace + "/request.xctestrun")
    return workspace
}

/// Bounds the stored result before exporting; this is a post-run limit, not a disk quota.
func validateApplePlatformResultTree(_ path: String) throws {
    try checkNoSymlinkAncestors(path)
    var info = stat()
    guard lstat(path, &info) == 0, (info.st_mode & S_IFMT) == S_IFDIR else { throw runnerError("runner_result_bundle_invalid", "Expected a result bundle directory.") }
    guard let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: path), includingPropertiesForKeys: nil) else { throw runnerError("runner_result_bundle_invalid", "Cannot enumerate result bundle.") }
    var size: Int64 = 0
    var count = 0
    for case let url as URL in enumerator {
        count += 1
        guard count <= 20000, lstat(url.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG || (info.st_mode & S_IFMT) == S_IFDIR else { throw runnerError("runner_result_bundle_unsafe", "Result contains unsupported entries or exceeds entry budget.") }
        size += Int64(info.st_size)
        guard size <= 268_435_456 else { throw runnerError("runner_result_bundle_size_limit", "Result exceeds 256 MiB acceptance budget.") }
    }
}

func applePlatformResultAttachmentName(_ manifest: Data, request: HostApplePlatformRunnerRequest) throws -> String {
    guard manifest.count <= 1_048_576, let tests = try JSONSerialization.jsonObject(with: manifest) as? [[String: Any]] else { throw runnerError("runner_attachment_invalid", "Invalid attachment manifest.") }
    let method = request.testIdentifier.split(separator: "/").dropFirst().joined(separator: "/")
    let allowed = [method, method + "()", request.testIdentifier, request.testIdentifier + "()"]
    var names: [String] = []
    for test in tests {
        guard let identifier = test["testIdentifier"] as? String, allowed.contains(identifier) else { throw runnerError("runner_attachment_test_mismatch", "Attachment manifest includes a different test method.") }
        guard let identifierURL = test["testIdentifierURL"] as? String,
              let url = URL(string: identifierURL), url.scheme == "test", url.host == "com.apple.xcode",
              url.path.split(separator: "/").suffix(3).joined(separator: "/") == request.testIdentifier else {
            throw runnerError("runner_attachment_test_mismatch", "Attachment test URL does not bind the exact target/class/method.")
        }
        for attachment in test["attachments"] as? [[String: Any]] ?? [] {
            guard let name = attachment["suggestedHumanReadableName"] as? String, isApplePlatformResultAttachmentName(name) else { continue }
            guard attachment["deviceId"] as? String == request.device,
                  let filename = attachment["exportedFileName"] as? String,
                  !filename.isEmpty, filename != ".", filename != "..", !filename.contains("/"), !filename.contains("\\"), !filename.contains("\0") else { throw runnerError("runner_attachment_binding_mismatch", "Result attachment is not bound to the exact device or has an unsafe filename.") }
            names.append(filename)
        }
    }
    guard names.count == 1 else { throw runnerError("runner_attachment_count_invalid", "Expected exactly one result attachment for the selected method.") }
    return names[0]
}

private func isApplePlatformResultAttachmentName(_ value: String) -> Bool {
    if value == "triton-platform-result" || value == "triton-platform-result.json" { return true }
    // Observed xcresulttool v0.4 transport: attachmentName_index_UUID.json.
    let prefix = "triton-platform-result_"
    guard value.hasPrefix(prefix), value.hasSuffix(".json") else { return false }
    let parts = value.dropFirst(prefix.count).dropLast(5).split(separator: "_", omittingEmptySubsequences: false)
    guard parts.count == 2, !parts[0].isEmpty, parts[0].count <= 8, parts[0].allSatisfy({ $0.isASCII && $0.isNumber }) else { return false }
    return UUID(uuidString: String(parts[1])) != nil
}
