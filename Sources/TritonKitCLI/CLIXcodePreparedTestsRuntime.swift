import CryptoKit
import Darwin
import Foundation
import TritonKitShared

private let preparedTestsPolicy = "sha256-tree-v2;source-excludes=.git,.build,.triton,DerivedData,node_modules;max-files=20000;max-bytes=1073741824;source-and-xctestrun-no-symlinks;testproducts-internal-relative-links-v1"

final class PreparedTestsDigestBudget {
    var count = 0
    var bytes = 0
}

func validatePreparedTestsPath(_ path: String, mustBeFresh: Bool = false) throws {
    guard !path.isEmpty, !path.contains("\0") else { throw PreparedTestsError.invalid("Invalid prepared test path.") }
    let url = URL(fileURLWithPath: path).standardizedFileURL
    var ancestor = url
    while ancestor.path != "/" {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: ancestor.path), attrs[.type] as? FileAttributeType == .typeSymbolicLink {
            // macOS's fixed OS aliases are part of normal FileManager temporary paths.
            let expectedOSAlias = ["/tmp": "/private/tmp", "/var": "/private/var"][ancestor.path]
            guard let expectedOSAlias,
                  let target = try? FileManager.default.destinationOfSymbolicLink(atPath: ancestor.path),
                  target == expectedOSAlias || target == String(expectedOSAlias.dropFirst()) else {
                throw PreparedTestsError.invalid("Prepared tests never follow user-controlled symbolic links.")
            }
        }
        ancestor.deleteLastPathComponent()
    }
    if mustBeFresh, FileManager.default.fileExists(atPath: url.path) {
        throw PreparedTestsError(code: "artifact_output_rejected", message: "Choose a fresh prepared manifest, test artifact or xcresult path.")
    }
}

func preparedTestsTreeDigest(_ path: String, source: Bool, budget: PreparedTestsDigestBudget = PreparedTestsDigestBudget()) throws -> String {
    do { return try hashPreparedTestsTree(path, source: source, budget: budget) }
    catch let error as PreparedTestsError { throw error }
    catch { throw PreparedTestsError.invalid("Prepared snapshot could not be read completely.") }
}

private func hashPreparedTestsTree(_ path: String, source: Bool, budget: PreparedTestsDigestBudget, productLinks: Bool = false) throws -> String {
    try validatePreparedTestsPath(path)
    let root = productLinks ? URL(fileURLWithPath: try preparedTestsPhysicalPath(path)) : URL(fileURLWithPath: path).standardizedFileURL
    guard FileManager.default.fileExists(atPath: root.path) else { throw PreparedTestsError.invalid("Prepared snapshot file or source root is missing.") }
    let excluded: Set<String> = source ? [".git", ".build", ".triton", "DerivedData", "node_modules"] : []
    var hasher = SHA256()
    var directoryEdges: [String: [String]] = [:]
    if productLinks {
        hasher.update(data: Data("testproducts-physical-root-v1\0\(root.path)\0internal-relative-links-v1\0".utf8))
    }
    func visit(_ url: URL, relative: String) throws {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let type = attrs[.type] as? FileAttributeType,
              type == .typeRegular || type == .typeDirectory || (productLinks && type == .typeSymbolicLink) else {
            throw PreparedTestsError.invalid("Prepared snapshots require regular files and directories without symlinks.")
        }
        budget.count += 1
        guard budget.count <= 20_000 else { throw PreparedTestsError.invalid("Prepared snapshot exceeds its 20000 file bound.") }
        let permissions = (attrs[.posixPermissions] as? NSNumber)?.intValue ?? 0
        hasher.update(data: Data("\(type.rawValue)\0\(relative)\0\(permissions)\0".utf8))
        if type == .typeSymbolicLink {
            let (targetBytes, targetDirectory) = try preparedTestsProductLinkBytes(url, physicalRoot: root.path)
            if let targetDirectory { directoryEdges[url.deletingLastPathComponent().path, default: []].append(targetDirectory) }
            guard targetBytes.count <= 1_073_741_824 - budget.bytes else { throw PreparedTestsError.invalid("Prepared snapshot exceeds its 1 GiB byte bound.") }
            budget.bytes += targetBytes.count
            hasher.update(data: Data("\(targetBytes.count)\0".utf8))
            hasher.update(data: targetBytes)
            // Do not traverse links. Every physical target is hashed by the package's normal tree walk.
        } else if type == .typeDirectory {
            if productLinks {
                if directoryEdges[url.path] == nil { directoryEdges[url.path] = [] }
                if url.path != root.path { directoryEdges[url.deletingLastPathComponent().path, default: []].append(url.path) }
            }
            let children = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil).sorted { $0.lastPathComponent < $1.lastPathComponent }
            for child in children where !excluded.contains(child.lastPathComponent) {
                try visit(child, relative: relative + "/" + child.lastPathComponent)
            }
        } else {
            let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
            guard size <= 1_073_741_824 - budget.bytes else { throw PreparedTestsError.invalid("Prepared snapshot exceeds its 1 GiB byte bound.") }
            budget.bytes += size
            hasher.update(data: Data("\(size)\0".utf8))
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var observed = 0
            while let block = try handle.read(upToCount: 1_048_576), !block.isEmpty {
                observed += block.count
                guard observed <= size else { throw PreparedTestsError.invalid("Snapshot changed while hashing.") }
                hasher.update(data: block)
            }
            guard observed == size else { throw PreparedTestsError.invalid("Snapshot changed while hashing.") }
        }
    }
    try visit(root, relative: ".")
    if productLinks { try validatePreparedTestsProductDirectoryGraph(directoryEdges) }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
}

private func validatePreparedTestsProductDirectoryGraph(_ edges: [String: [String]]) throws {
    // Inspect alias topology without following links. Acyclic directory aliases are safe to hash once.
    var incoming = Dictionary(uniqueKeysWithValues: edges.keys.map { ($0, 0) })
    for targets in edges.values { for target in targets { incoming[target, default: 0] += 1 } }
    var queue = incoming.filter { $0.value == 0 }.map(\.key)
    var index = 0
    while index < queue.count {
        let directory = queue[index]
        index += 1
        for target in edges[directory] ?? [] {
            incoming[target]! -= 1
            if incoming[target] == 0 { queue.append(target) }
        }
    }
    guard index == incoming.count else { throw PreparedTestsError.invalid("Test product directory links contain a traversal cycle.") }
}

private func preparedTestsPhysicalPath(_ path: String) throws -> String {
    guard let resolved = realpath(path, nil) else { throw PreparedTestsError.invalid("Prepared test product physical root is unavailable.") }
    defer { free(resolved) }
    return String(cString: resolved)
}

private func preparedTestsProductLinkBytes(_ link: URL, physicalRoot: String) throws -> (Data, String?) {
    var bytes = [UInt8](repeating: 0, count: 4096)
    let count = bytes.withUnsafeMutableBytes { readlink(link.path, $0.baseAddress!, $0.count) }
    guard count > 0, count < bytes.count else { throw PreparedTestsError.invalid("Invalid or oversized test product link.") }
    let data = Data(bytes.prefix(count))
    guard let target = String(data: data, encoding: .utf8), !target.hasPrefix("/"), !target.contains("\0") else {
        throw PreparedTestsError.invalid("Test product links must have relative UTF-8 targets.")
    }
    let rootComponents = physicalRoot.split(separator: "/").map(String.init)
    var components = link.deletingLastPathComponent().path.split(separator: "/").map(String.init)
    guard components.starts(with: rootComponents) else { throw PreparedTestsError.invalid("Test product link is outside its physical package root.") }
    var currentType: FileAttributeType = .typeDirectory
    for component in target.split(separator: "/", omittingEmptySubsequences: true) {
        guard currentType == .typeDirectory else { throw PreparedTestsError.invalid("Test product link has a non-directory parent.") }
        if component == "." { continue }
        if component == ".." {
            guard components.count > rootComponents.count else { throw PreparedTestsError.invalid("Test product link escapes its physical package root.") }
            components.removeLast()
        } else { components.append(String(component)) }
        let candidate = "/" + components.joined(separator: "/")
        let attrs = try FileManager.default.attributesOfItem(atPath: candidate)
        guard let type = attrs[.type] as? FileAttributeType, type == .typeRegular || type == .typeDirectory else {
            throw PreparedTestsError.invalid("Test product links cannot reference another link or special file.")
        }
        currentType = type
    }
    let resolved = "/" + components.joined(separator: "/")
    guard resolved != physicalRoot,
          resolved.hasPrefix(physicalRoot + "/"),
          link.path != resolved, !link.path.hasPrefix(resolved + "/"),
          try preparedTestsPhysicalPath(resolved) == resolved else {
        throw PreparedTestsError.invalid("Test product link is dangling, cyclic or outside its physical package root.")
    }
    return (data, currentType == .typeDirectory ? resolved : nil)
}

func preparedTestsArtifactDigest(_ path: String, toolchain: PreparedTestsToolchain) throws -> String {
    do { return try hashPreparedTestsArtifact(path, toolchain: toolchain) }
    catch let error as PreparedTestsError { throw error }
    catch { throw PreparedTestsError.invalid("Prepared test artifact could not be parsed or read completely.") }
}

private func hashPreparedTestsArtifact(_ path: String, toolchain: PreparedTestsToolchain) throws -> String {
    try validatePreparedTestsPath(path)
    guard path.hasSuffix(".xctestrun") || path.hasSuffix(".xctestproducts") else { throw PreparedTestsError.invalid("Expected .xctestrun or .xctestproducts.") }
    if path.hasSuffix(".xctestproducts") {
        guard toolchain.supportsTestProducts else { throw PreparedTestsError(code: "prepared_tests_unsupported", message: "Selected xcodebuild does not advertise -testProductsPath.") }
        return try hashPreparedTestsTree(path, source: false, budget: PreparedTestsDigestBudget(), productLinks: true)
    }
    let url = URL(fileURLWithPath: path)
    let attrs = try FileManager.default.attributesOfItem(atPath: path)
    guard ((attrs[.size] as? NSNumber)?.intValue ?? Int.max) <= 4_194_304 else { throw PreparedTestsError.invalid("Oversized xctestrun plist.") }
    let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), options: [], format: nil)
    guard plist is [String: Any] else { throw PreparedTestsError.invalid("Invalid xctestrun plist.") }
    var bundles = Set<String>()
    var testBundleCount = 0
    func collect(_ node: Any) throws {
        if let dictionary = node as? [String: Any] {
            func expand(_ raw: String) -> String {
                raw.replacingOccurrences(of: "__TESTROOT__", with: url.deletingLastPathComponent().path)
                    .replacingOccurrences(of: "__PLATFORMS__", with: toolchain.developerDirectory + "/Platforms")
            }
            let host = (dictionary["TestHostPath"] as? String).map(expand)
            for (key, value) in dictionary {
                if key == "DependentProductPaths", let paths = value as? [String] {
                    for raw in paths {
                        let expanded = expand(raw).replacingOccurrences(of: "__TESTHOST__", with: host ?? "__TESTHOST__")
                        guard !expanded.contains("__"), expanded.hasPrefix("/") else { throw PreparedTestsError.invalid("Unresolved dependent test product path.") }
                        bundles.insert(URL(fileURLWithPath: expanded).standardizedFileURL.path)
                    }
                }
                if ["TestBundlePath", "TestHostPath", "UITargetAppPath"].contains(key), let raw = value as? String {
                    if key == "TestBundlePath" { testBundleCount += 1 }
                    var expanded = expand(raw)
                    if let host { expanded = expanded.replacingOccurrences(of: "__TESTHOST__", with: host) }
                    guard !expanded.contains("__"), expanded.hasPrefix("/") else { throw PreparedTestsError.invalid("Unresolved xctestrun artifact path; use a self-contained explicit snapshot.") }
                    if key == "TestHostPath" {
                        var candidate = URL(fileURLWithPath: expanded)
                        while candidate.path != "/", !candidate.pathExtension.hasSuffix("app") { candidate.deleteLastPathComponent() }
                        if candidate.pathExtension == "app" { expanded = candidate.path }
                    }
                    bundles.insert(URL(fileURLWithPath: expanded).standardizedFileURL.path)
                } else { try collect(value) }
            }
        } else if let array = node as? [Any] { for child in array { try collect(child) } }
    }
    try collect(plist)
    guard testBundleCount > 0 else { throw PreparedTestsError.invalid("xctestrun has no test bundle.") }
    let budget = PreparedTestsDigestBudget()
    var digests = [try preparedTestsTreeDigest(path, source: false, budget: budget)]
    let roots = bundles.filter { path in !bundles.contains(where: { $0 != path && path.hasPrefix($0 + "/") }) }
    for bundle in roots.sorted() { digests.append(bundle + ":" + (try preparedTestsTreeDigest(bundle, source: false, budget: budget))) }
    return SHA256.hash(data: Data(digests.joined(separator: "\0").utf8)).map { String(format: "%02x", $0) }.joined()
}

func preparedTestsIdentity(_ invocation: ResolvedXcodeInvocation, toolchain: PreparedTestsToolchain) throws -> PreparedTestsIdentity {
    guard let destination = invocation.xcodebuildDestination, !destination.isEmpty else { throw PreparedTestsError.invalid("Prepared tests require an explicit resolved destination.") }
    func absolute(_ path: String?) -> String? { path.map { URL(fileURLWithPath: $0).standardizedFileURL.path } }
    return PreparedTestsIdentity(workspace: absolute(invocation.workspace), project: absolute(invocation.project), package: absolute(invocation.package), scheme: invocation.scheme, configuration: invocation.configuration, sdk: invocation.sdk, destination: destination, buildSettings: invocation.buildSettings, toolchain: toolchain)
}

func makePreparedTestsManifest(invocation: ResolvedXcodeInvocation, artifact: String, sourceRoot: String, toolchain: PreparedTestsToolchain) throws -> PreparedTestsManifest {
    let root = URL(fileURLWithPath: sourceRoot).standardizedFileURL.path
    let artifact = URL(fileURLWithPath: artifact).standardizedFileURL.path
    try validatePreparedTestsSourceRoot(root, invocation: invocation)
    return PreparedTestsManifest(version: 1, policy: preparedTestsPolicy, identity: try preparedTestsIdentity(invocation, toolchain: toolchain), sourceRoot: root, sourceDigest: try preparedTestsTreeDigest(root, source: true), artifact: artifact, artifactDigest: try preparedTestsArtifactDigest(artifact, toolchain: toolchain))
}

func validatePreparedTestsManifest(_ manifest: PreparedTestsManifest, invocation: ResolvedXcodeInvocation, toolchain: PreparedTestsToolchain) throws {
    try validatePreparedTestsSourceRoot(manifest.sourceRoot, invocation: invocation)
    guard manifest.version == 1, manifest.policy == preparedTestsPolicy else { throw PreparedTestsError(code: "prepared_tests_manifest_invalid", message: "Unsupported prepared manifest version or fingerprint policy.") }
    guard manifest.identity == (try preparedTestsIdentity(invocation, toolchain: toolchain)),
          manifest.sourceDigest == (try preparedTestsTreeDigest(manifest.sourceRoot, source: true)),
          manifest.artifactDigest == (try preparedTestsArtifactDigest(manifest.artifact, toolchain: toolchain)) else { throw PreparedTestsError.mismatch() }
}

private func validatePreparedTestsSourceRoot(_ root: String, invocation: ResolvedXcodeInvocation) throws {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: root, isDirectory: &isDirectory), isDirectory.boolValue else { throw PreparedTestsError.invalid("Source fingerprint root must be an existing directory.") }
    guard let container = invocation.package ?? invocation.workspace ?? invocation.project else { throw PreparedTestsError.invalid("Prepared source root requires one container.") }
    let path = URL(fileURLWithPath: container).standardizedFileURL.path
    guard path == root || path.hasPrefix(root + "/") else { throw PreparedTestsError.invalid("Source fingerprint root must contain the selected container.") }
}

func currentPreparedTestsToolchain() throws -> PreparedTestsToolchain {
    let developer: String
    if let selected = ProcessInfo.processInfo.environment["DEVELOPER_DIR"] { developer = selected }
    else { developer = try runHostCommand(TKHostCommand(executable: "/usr/bin/xcode-select", arguments: ["-p"], defaultTimeoutSeconds: 10)).stdout.trimmingCharacters(in: .whitespacesAndNewlines) }
    let version = try runHostCommand(TKHostCommand(executable: "/usr/bin/xcrun", arguments: ["xcodebuild", "-version"], defaultTimeoutSeconds: 15)).stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    let help = try runHostCommand(TKHostCommand(executable: "/usr/bin/xcrun", arguments: ["xcodebuild", "-help"], defaultTimeoutSeconds: 15))
    guard !developer.isEmpty, !version.isEmpty else { throw PreparedTestsError.invalid("Selected Xcode identity is unavailable.") }
    let directory = URL(fileURLWithPath: developer).standardizedFileURL
    let resolvedDirectory = directory.pathExtension == "app" ? directory.appendingPathComponent("Contents/Developer").path : directory.path
    return PreparedTestsToolchain(developerDirectory: resolvedDirectory, version: version, supportsTestProducts: (help.stdout + help.stderr).contains("-testProductsPath"))
}

func freshPreparedTestsResultPath(_ path: String?, package: String?) throws -> String {
    let resolved = xcodePackageArtifactPath(path ?? ".triton/prepared-tests/\(UUID().uuidString).xcresult", package: package)!
    guard resolved.hasSuffix(".xcresult") else { throw PreparedTestsError.invalid("Prepared test results require a fresh .xcresult path.") }
    try validatePreparedTestsPath(resolved, mustBeFresh: true)
    try FileManager.default.createDirectory(at: URL(fileURLWithPath: resolved).deletingLastPathComponent(), withIntermediateDirectories: true)
    return URL(fileURLWithPath: resolved).standardizedFileURL.path
}

func validatePreparedTestsBuildOptions(forTesting: Bool, artifact: String?, sourceRoot: String?, manifest: String?) throws {
    let supplied = [artifact, sourceRoot, manifest].compactMap { $0 }
    guard (forTesting && supplied.count == 3 && supplied.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) || (!forTesting && supplied.isEmpty) else {
        throw PreparedTestsError(code: "validation_failed", message: "--for-testing requires --test-artifact, --source-root and --prepared-tests-manifest together.")
    }
}

func readPreparedTestsManifest(_ path: String) throws -> PreparedTestsManifest {
    do {
        try validatePreparedTestsPath(path)
        let attrs = try FileManager.default.attributesOfItem(atPath: path)
        guard attrs[.type] as? FileAttributeType == .typeRegular, ((attrs[.size] as? NSNumber)?.intValue ?? Int.max) <= 65_536 else {
            throw PreparedTestsError(code: "prepared_tests_manifest_invalid", message: "Prepared manifest must be a regular file under 64 KiB.")
        }
        return try JSONDecoder().decode(PreparedTestsManifest.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    } catch let error as PreparedTestsError { throw error }
    catch { throw PreparedTestsError(code: "prepared_tests_manifest_invalid", message: "Cannot read prepared test identity manifest.") }
}

func writePreparedTestsManifest(_ manifest: PreparedTestsManifest, path: String) throws {
    try validatePreparedTestsPath(path, mustBeFresh: true)
    try FileManager.default.createDirectory(at: URL(fileURLWithPath: path).deletingLastPathComponent(), withIntermediateDirectories: true)
    let fd = open(path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
    guard fd >= 0 else { throw PreparedTestsError(code: "artifact_output_rejected", message: "Could not exclusively create prepared manifest.") }
    let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    defer { try? handle.close() }
    try handle.write(contentsOf: JSONEncoder().encode(manifest))
}

func runPreparedTestsBuild(invocation: ResolvedXcodeInvocation, artifact: String, sourceRoot: String, manifestPath: String,
    jsonl: Bool, timeout: Double?, allowProvisioningUpdates: Bool, progress: XcodeProgressMode) throws -> TKXcodeActionSummary {
    let invocation = try preparedXcodeInvocationForExecution(invocation)
    let artifact = URL(fileURLWithPath: xcodePackageArtifactPath(artifact, package: invocation.package)!).standardizedFileURL.path
    let manifestPath = URL(fileURLWithPath: xcodePackageArtifactPath(manifestPath, package: invocation.package)!).standardizedFileURL.path
    let sourceRoot = URL(fileURLWithPath: sourceRoot).standardizedFileURL.path
    guard manifestPath != artifact, !manifestPath.hasPrefix(artifact + "/"), !sourceRoot.hasPrefix(artifact + "/") else {
        throw PreparedTestsError.invalid("Prepared manifest, source root and artifact must not overlap their output identity.")
    }
    guard let container = invocation.package ?? invocation.workspace ?? invocation.project,
          URL(fileURLWithPath: container).standardizedFileURL.path.hasPrefix(sourceRoot + "/") || URL(fileURLWithPath: container).standardizedFileURL.path == sourceRoot else {
        throw PreparedTestsError.invalid("Source fingerprint root must contain the selected container.")
    }
    guard artifact.hasSuffix(".xctestrun") || artifact.hasSuffix(".xctestproducts") else { throw PreparedTestsError.invalid("Expected a .xctestrun or .xctestproducts output.") }
    try validatePreparedTestsPath(artifact, mustBeFresh: true)
    try validatePreparedTestsPath(manifestPath, mustBeFresh: true)
    for output in [artifact, manifestPath] where output.hasPrefix(sourceRoot + "/") {
        let relative = String(output.dropFirst(sourceRoot.count + 1))
        guard relative.split(separator: "/").contains(where: { [".build", ".triton", "DerivedData"].contains(String($0)) }) else {
            throw PreparedTestsError.invalid("Prepared outputs inside the source root must be under an excluded .triton, .build or DerivedData directory.")
        }
    }
    let toolchain = try currentPreparedTestsToolchain()
    if artifact.hasSuffix(".xctestproducts"), !toolchain.supportsTestProducts {
        throw PreparedTestsError(code: "prepared_tests_unsupported", message: "Selected Xcode does not advertise -testProductsPath.")
    }
    let sourceDigest = try preparedTestsTreeDigest(sourceRoot, source: true)
    let summary = try runXcodeBuild(invocation: invocation, jsonl: jsonl, timeout: timeout,
        allowProvisioningUpdates: allowProvisioningUpdates, buildForTesting: true,
        testProductsPath: artifact.hasSuffix(".xctestproducts") ? artifact : nil,
        preparedTestsManifestPath: manifestPath, progress: progress)
    guard summary.ok else { return summary }
    let manifest = try makePreparedTestsManifest(invocation: invocation, artifact: artifact, sourceRoot: sourceRoot, toolchain: toolchain)
    guard manifest.sourceDigest == sourceDigest, (try currentPreparedTestsToolchain()) == toolchain else { throw PreparedTestsError.mismatch() }
    try writePreparedTestsManifest(manifest, path: manifestPath)
    return summary
}
