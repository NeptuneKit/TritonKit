import CryptoKit
import Foundation

struct IOSRunnerResourceManifest: Codable, Equatable {
    struct File: Codable, Equatable {
        let path: String
        let size: Int
        let sha256: String
    }
    let schemaVersion: Int
    let sourceVersion: String
    let project: String
    let scheme: String
    let files: [File]
}

struct IOSRunnerResourceError: LocalizedError {
    let reason: String
    var errorDescription: String? { "Bundled iOS Runner resources: \(reason)" }
}

private let iosRunnerManifestName = "RUNNER_MANIFEST.json"
private let iosRunnerAllowedPaths: Set<String> = [
    "README.md", "Package.swift", "project.yml",
    "FixtureApp/RunnerFixtureApp.swift", "RunnerTests/TritonIOSRunnerTests.swift",
    "RunnerTests/HTTPProtocol.swift", "RunnerTests/SecureChannel.swift", "RunnerTests/RunnerServer.swift", "ProtocolTests/HTTPProtocolTests.swift", "ProtocolTests/RunnerServerTests.swift",
    "TritonIOSRunner.xcodeproj/project.pbxproj",
    "TritonIOSRunner.xcodeproj/xcshareddata/xcschemes/TritonIOSRunner.xcscheme",
    "TritonIOSRunner.xcodeproj/project.xcworkspace/contents.xcworkspacedata",
]
private let iosRunnerRequiredPaths: Set<String> = [
    "FixtureApp/RunnerFixtureApp.swift", "RunnerTests/TritonIOSRunnerTests.swift",
    "RunnerTests/HTTPProtocol.swift", "RunnerTests/SecureChannel.swift", "RunnerTests/RunnerServer.swift", "TritonIOSRunner.xcodeproj/project.pbxproj",
    "TritonIOSRunner.xcodeproj/xcshareddata/xcschemes/TritonIOSRunner.xcscheme",
]

/// Resolve resources without accessing Bundle.module, whose generated accessor can
/// terminate a portable executable when its SwiftPM bundle was not installed.
func iosRunnerResourceCandidates(executableURL: URL) -> [URL] {
    let executable = executableURL.standardizedFileURL.resolvingSymlinksInPath()
    let directory = executable.deletingLastPathComponent()
    return [
        directory.appendingPathComponent("resources/ios-runner"),
        directory.appendingPathComponent("TritonKitCLI_TritonKitCLI.bundle/Contents/Resources/ios-runner"),
        directory.appendingPathComponent("TritonKitCLI_TritonKitCLI.bundle/ios-runner"),
        directory.appendingPathComponent("TritonKitCLI_TritonKitCLI.resources/ios-runner"),
        directory.deletingLastPathComponent().appendingPathComponent("share/triton/ios-runner"),
    ]
}

func bundledIOSRunnerProjectURL() throws -> URL {
    let executable = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
    return try bundledIOSRunnerProjectURL(candidates: iosRunnerResourceCandidates(executableURL: executable), expectedVersion: TritonKitBuildInfo.cliVersion)
}

func bundledIOSRunnerProjectURL(candidates: [URL], expectedVersion: String? = nil) throws -> URL {
    for root in candidates where FileManager.default.fileExists(atPath: root.path) {
        _ = try validateIOSRunnerResources(at: root, expectedVersion: expectedVersion)
        return root
    }
    throw IOSRunnerResourceError(reason: "not installed; reinstall the complete TritonKit CLI package")
}

@discardableResult
func validateIOSRunnerResources(at root: URL, expectedVersion: String? = nil) throws -> IOSRunnerResourceManifest {
    let manager = FileManager.default
    let rootValues = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    guard rootValues.isDirectory == true, rootValues.isSymbolicLink != true else {
        throw IOSRunnerResourceError(reason: "resource root is not a regular directory")
    }
    // Foundation enumeration canonicalizes macOS /var -> /private/var. Match
    // canonical path components rather than slicing the original URL's spelling.
    let rootURL = root.standardizedFileURL.resolvingSymlinksInPath()
    let rootComponents = rootURL.pathComponents
    let manifestURL = rootURL.appendingPathComponent(iosRunnerManifestName)
    guard (try manifestURL.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink != true else {
        throw IOSRunnerResourceError(reason: "manifest symlinks are prohibited")
    }
    let manifestAttributes = try manager.attributesOfItem(atPath: manifestURL.path)
    guard let manifestSize = (manifestAttributes[.size] as? NSNumber)?.intValue, manifestSize <= 64 * 1024 else {
        throw IOSRunnerResourceError(reason: "manifest exceeds size budget")
    }
    let manifestData = try Data(contentsOf: manifestURL)
    guard manifestData.count <= 64 * 1024,
          let raw = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
          Set(raw.keys) == Set(["schemaVersion", "sourceVersion", "project", "scheme", "files"]) else {
        throw IOSRunnerResourceError(reason: "invalid manifest fields or size")
    }
    let manifest = try JSONDecoder().decode(IOSRunnerResourceManifest.self, from: manifestData)
    guard manifest.schemaVersion == 1, manifest.project == "TritonIOSRunner.xcodeproj",
          manifest.scheme == "TritonIOSRunner", !manifest.sourceVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          manifest.sourceVersion.count <= 128, expectedVersion == nil || manifest.sourceVersion == expectedVersion else {
        throw IOSRunnerResourceError(reason: "manifest contract or source version mismatch")
    }
    let paths = manifest.files.map(\.path)
    guard Set(paths).count == paths.count, iosRunnerRequiredPaths.isSubset(of: Set(paths)),
          Set(paths).isSubset(of: iosRunnerAllowedPaths) else {
        throw IOSRunnerResourceError(reason: "manifest contains missing, duplicate, or unapproved files")
    }
    var actual: Set<String> = []
    guard let enumerator = manager.enumerator(at: rootURL, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey]) else {
        throw IOSRunnerResourceError(reason: "cannot enumerate resource files")
    }
    for case let file as URL in enumerator {
        let values = try file.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey])
        guard values.isSymbolicLink != true else { throw IOSRunnerResourceError(reason: "resource symlinks are prohibited") }
        let components = file.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        guard Array(components.prefix(rootComponents.count)) == rootComponents else {
            throw IOSRunnerResourceError(reason: "resource escaped its package root")
        }
        let relative = components.dropFirst(rootComponents.count).joined(separator: "/")
        if values.isDirectory == true {
            guard iosRunnerAllowedPaths.contains(where: { $0.hasPrefix(relative + "/") }) else {
                throw IOSRunnerResourceError(reason: "unexpected resource directory")
            }
        } else if relative != iosRunnerManifestName {
            guard values.isRegularFile == true, iosRunnerAllowedPaths.contains(relative) else {
                throw IOSRunnerResourceError(reason: "unexpected resource file")
            }
            actual.insert(relative)
        }
    }
    guard actual == Set(paths) else { throw IOSRunnerResourceError(reason: "resource inventory mismatch") }
    for file in manifest.files {
        guard file.size >= 0, file.size <= 2 * 1024 * 1024, file.sha256.count == 64,
              file.sha256.allSatisfy({ "0123456789abcdef".contains($0) }) else {
            throw IOSRunnerResourceError(reason: "invalid file digest or size")
        }
        let url = rootURL.appendingPathComponent(file.path)
        let attributes = try manager.attributesOfItem(atPath: url.path)
        guard (attributes[.size] as? NSNumber)?.intValue == file.size else {
            throw IOSRunnerResourceError(reason: "resource size mismatch")
        }
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard digest == file.sha256 else { throw IOSRunnerResourceError(reason: "resource SHA-256 mismatch") }
    }
    return manifest
}
