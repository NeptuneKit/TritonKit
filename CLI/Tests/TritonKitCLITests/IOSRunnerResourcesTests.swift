import CryptoKit
import Foundation
import Testing
@testable import TritonKitCLI

@Suite
struct IOSRunnerResourcesTests {
    @Test("CLI and bundled Runner use the identical authenticated channel implementation")
    func secureChannelSourceParity() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let client = root.appendingPathComponent("Sources/TritonKitCLI/CLIIOSRunnerSecureChannel.swift")
        let runner = root.appendingPathComponent("Sources/TritonKitCLI/Resources/ios-runner/RunnerTests/SecureChannel.swift")
        #expect(try Data(contentsOf: client) == Data(contentsOf: runner))
    }

    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let paths = [
            "FixtureApp/RunnerFixtureApp.swift", "RunnerTests/TritonIOSRunnerTests.swift", "RunnerTests/HTTPProtocol.swift", "RunnerTests/SecureChannel.swift", "RunnerTests/RunnerServer.swift",
            "TritonIOSRunner.xcodeproj/project.pbxproj",
            "TritonIOSRunner.xcodeproj/xcshareddata/xcschemes/TritonIOSRunner.xcscheme",
        ]
        let data = Data("unsigned fixture".utf8)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        for path in paths {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
        }
        let manifest = IOSRunnerResourceManifest(schemaVersion: 1, sourceVersion: "test-version", project: "TritonIOSRunner.xcodeproj", scheme: "TritonIOSRunner", files: paths.map {
            .init(path: $0, size: data.count, sha256: digest)
        })
        try JSONEncoder().encode(manifest).write(to: root.appendingPathComponent("RUNNER_MANIFEST.json"))
        return root
    }

    @Test("portable Runner project validates without a source checkout")
    func portableProject() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(try bundledIOSRunnerProjectURL(candidates: [root]) == root)
        #expect(try validateIOSRunnerResources(at: root, expectedVersion: "test-version").files.count == 7)
    }

    @Test("macOS SwiftPM Contents Resources bundle resolves without source fallback")
    func macOSBundleLayout() throws {
        let sourceRoot = try fixture()
        defer { try? FileManager.default.removeItem(at: sourceRoot) }
        let install = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: install) }
        let executable = install.appendingPathComponent("triton")
        let bundled = install.appendingPathComponent("TritonKitCLI_TritonKitCLI.bundle/Contents/Resources/ios-runner")
        try FileManager.default.createDirectory(at: bundled.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: sourceRoot, to: bundled)
        try Data().write(to: executable)
        let resolved = try bundledIOSRunnerProjectURL(candidates: iosRunnerResourceCandidates(executableURL: executable), expectedVersion: "test-version")
        #expect(resolved.standardizedFileURL.resolvingSymlinksInPath() == bundled.standardizedFileURL.resolvingSymlinksInPath())
    }

    @Test("resource validation handles directory URLs with a trailing slash")
    func trailingSlashRoot() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let directoryURL = URL(fileURLWithPath: root.path + "/", isDirectory: true)
        #expect(try validateIOSRunnerResources(at: directoryURL).files.count == 7)
        #expect(try validateIOSRunnerResources(at: root.resolvingSymlinksInPath()).files.count == 7)
    }

    @Test("missing package reports an error without Bundle.module fatal")
    func missingPackage() {
        #expect(throws: (any Error).self) { try bundledIOSRunnerProjectURL(candidates: []) }
    }

    @Test("tampered and private Runner resources are rejected")
    func damagedPackage() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("RunnerTests/HTTPProtocol.swift")
        try Data("tampered fixture".utf8).write(to: file)
        #expect(throws: (any Error).self) { try validateIOSRunnerResources(at: root) }
        try Data("private".utf8).write(to: root.appendingPathComponent("token.json"))
        #expect(throws: (any Error).self) { try validateIOSRunnerResources(at: root) }
    }

    @Test("Homebrew symlink resolves to the Cellar package share")
    func homebrewSymlink() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let executable = root.appendingPathComponent("Cellar/triton/1.0/bin/triton")
        try FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: executable)
        let link = root.appendingPathComponent("bin/triton")
        try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: executable)
        let candidates = iosRunnerResourceCandidates(executableURL: link)
        #expect(candidates.last == root.appendingPathComponent("Cellar/triton/1.0/share/triton/ios-runner"))
        #expect(candidates.first == executable.deletingLastPathComponent().appendingPathComponent("resources/ios-runner"))
    }

    @Test("symlinked resource and source version mismatch are rejected")
    func symlinkAndVersion() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(throws: (any Error).self) { try validateIOSRunnerResources(at: root, expectedVersion: "different") }
        let file = root.appendingPathComponent("RunnerTests/HTTPProtocol.swift")
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createSymbolicLink(at: file, withDestinationURL: root.appendingPathComponent("RunnerTests/TritonIOSRunnerTests.swift"))
        #expect(throws: (any Error).self) { try validateIOSRunnerResources(at: root) }
    }
}
