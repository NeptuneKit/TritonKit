import CryptoKit
import Foundation
import TritonKitShared
import Testing
@testable import TritonKitCLI

@Suite struct ReleaseInstallTests {
    @Test(arguments: [false, true])
    func standalonePlanDoesNotRunBrewOrInstaller(check: Bool) async throws {
        var called = false
        let result = try await runCLIUpdate(requestedVersion: "v0.2.46", currentExecutable: "/opt/homebrew/Cellar/triton/0.2.45/bin/triton", architecture: "arm64", checkOnly: check, dryRun: !check, confirm: false, includeSkills: false, skillsDirectory: nil, repository: "NeptuneKit/TritonKit", releaseInstallDirectory: "/tmp/triton-release-test-unique", releaseInstaller: { _, _, _ in called = true }, hostCommandRunner: { _, _ in Issue.record("No process in plan"); return "" }, currentVersion: "0.2.45")
        #expect(!called)
        #expect(result.installSource == .homebrew)
        #expect(result.installedExecutable == "/tmp/triton-release-test-unique/triton")
        #expect(!result.actions.contains { $0.command == "brew" })
    }
    @Test func portableInstallRequiresNewDirectoryForUpgrade() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let files = ["triton", "web/index.html", "resources/ios-runner/RUNNER_MANIFEST.json"]
        for name in files {
            let file = root.appendingPathComponent(name)
            try fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(name.utf8).write(to: file)
        }
        func update(checkOnly: Bool, dryRun: Bool, confirm: Bool, destination: String? = nil) async throws -> CLIUpdateResponse {
            try await runCLIUpdate(requestedVersion: "v0.2.47", currentExecutable: root.appendingPathComponent("triton").path,
                architecture: "arm64", checkOnly: checkOnly, dryRun: dryRun, confirm: confirm, includeSkills: false,
                skillsDirectory: nil, repository: "NeptuneKit/TritonKit", releaseInstallDirectory: destination,
                releaseInstaller: { plan, _, _ in #expect(plan.releaseInstallDirectory == destination) },
                hostCommandRunner: { executable, _ in
                    #expect(executable == destination.map { $0 + "/triton" })
                    return "{\"ok\":true,\"version\":\"0.2.47\"}"
                }, currentVersion: "0.2.46")
        }
        for check in [true, false] {
            let plan = try await update(checkOnly: check, dryRun: !check, confirm: false)
            #expect(plan.updateAvailable && !plan.requiresConfirmation)
            #expect(!plan.actions.contains { $0.kind == .replaceBinary })
            #expect(plan.manualInstructions.contains { $0.contains("--release-install-dir") })
        }
        do {
            _ = try await update(checkOnly: false, dryRun: false, confirm: false)
            Issue.record("Expected to preserve the existing portable release")
        } catch let failure as CLIUpdateExecutionFailure {
            #expect(failure.response.error?.code == "release_install_directory_required")
            #expect(!failure.response.updated && !failure.response.cliUpdateAttempted)
        }
        let destination = root.appendingPathComponent("next").path
        let installed = try await update(checkOnly: false, dryRun: false, confirm: true, destination: destination)
        #expect(installed.updated && installed.installedExecutable == destination + "/triton")
        for name in files { #expect(try Data(contentsOf: root.appendingPathComponent(name)) == Data(name.utf8)) }
    }
    @Test func sameVersionRecoveryVerifiesNewBinary() async throws {
        var installed = false
        let result = try await runCLIUpdate(requestedVersion: "v0.2.46", currentExecutable: "/opt/homebrew/Cellar/triton/0.2.46/bin/triton", architecture: "arm64", checkOnly: false, dryRun: false, confirm: true, includeSkills: false, skillsDirectory: nil, repository: "NeptuneKit/TritonKit", releaseInstallDirectory: "/tmp/triton-release-test-unique", releaseInstaller: { plan, _, _ in installed = true; #expect(plan.installSource == .homebrew) }, hostCommandRunner: { executable, args in
            #expect(executable == "/tmp/triton-release-test-unique/triton")
            #expect(args == ["version", "--json"])
            return "{\"ok\":true,\"version\":\"0.2.46\"}"
        }, currentVersion: "0.2.46")
        #expect(installed && result.updated && result.cliUpdateAttempted)
        #expect(!result.updateAvailable)
    }
    @Test(arguments: ["relative", "/opt/homebrew/Cellar/triton/side", "/tmp/a/../b"])
    func unsafeDestinationsRejected(path: String) {
        #expect(throws: CLIUpdateErrorDetail.self) { try validateReleaseInstallDestination(path) }
    }
    @Test func existingDirectoryPreserved() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("keep".utf8).write(to: root.appendingPathComponent("sentinel"))
        #expect(throws: CLIUpdateErrorDetail.self) { try validateReleaseInstallDestination(root.path) }
        #expect(try String(contentsOf: root.appendingPathComponent("sentinel"), encoding: .utf8) == "keep")
    }
    @Test(arguments: ["triton-macos-arm64/../escape", "/absolute", "triton-macos-arm64/./bad"])
    func unsafeArchivesRejected(name: String) {
        #expect(throws: CLIUpdateErrorDetail.self) {
            try validateCLIReleaseArchiveListing(names: name, types: "-rwxr-xr-x  0 user group 0 Nov 16 00:00 file", rootName: "triton-macos-arm64")
        }
    }
}


@Suite struct ReleaseArchiveInstallTests {
    @Test(arguments: ["complete", "web", "web-shell", "web-js", "web-css", "runner", "bundle", "version", "checksum"])
    func realArchiveInstallation(kind: String) throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: temp) }
        let root = temp.appendingPathComponent("source/triton-macos-arm64")
        let content = Data("public fixture".utf8)
        func write(_ path: String, _ data: Data = Data("public fixture".utf8)) throws {
            let url = root.appendingPathComponent(path)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
        }
        try write("triton")
        if kind == "web-shell" {
            try write("web/index.html", Data("<html></html>".utf8))
        } else if kind != "web" {
            try write("web/index.html", Data("""
            <html><head>
              <script type="module" crossorigin src="/assets/index-test.js"></script>
              <link rel="stylesheet" crossorigin href="/assets/index-test.css">
            </head></html>
            """.utf8))
        }
        if kind != "web-js" { try write("web/assets/index-test.js") }
        if kind != "web-css" { try write("web/assets/index-test.css") }
        if kind != "bundle" { try write("TritonKitCLI_TritonKitCLI.bundle/TritonSimCameraHook.m") }
        let runnerPaths = ["FixtureApp/RunnerFixtureApp.swift", "RunnerTests/TritonIOSRunnerTests.swift", "RunnerTests/HTTPProtocol.swift", "RunnerTests/SecureChannel.swift", "RunnerTests/RunnerServer.swift", "TritonIOSRunner.xcodeproj/project.pbxproj", "TritonIOSRunner.xcodeproj/xcshareddata/xcschemes/TritonIOSRunner.xcscheme"]
        if kind != "runner" {
            let hash = SHA256.hash(data: content).map { String(format: "%02x", $0) }.joined()
            for path in runnerPaths { try write("resources/ios-runner/" + path) }
            let manifest = IOSRunnerResourceManifest(schemaVersion: 1, sourceVersion: "0.2.46", project: "TritonIOSRunner.xcodeproj", scheme: "TritonIOSRunner", files: runnerPaths.map { .init(path: $0, size: content.count, sha256: hash) })
            try write("resources/ios-runner/RUNNER_MANIFEST.json", JSONEncoder().encode(manifest))
        }
        let archive = temp.appendingPathComponent("triton-macos-arm64.tar.gz")
        _ = try runHostCommand(TKHostCommand(executable: "/usr/bin/tar", arguments: ["-czf", archive.path, "-C", root.deletingLastPathComponent().path, "triton-macos-arm64"], defaultTimeoutSeconds: 10))
        let checksum = kind == "checksum" ? String(repeating: "0", count: 64) : try sha256(path: archive.path)
        let destination = temp.appendingPathComponent("installed")
        let install = {
            try installStandaloneCLIReleaseArchive(archive: archive, expectedChecksum: checksum, version: "0.2.46", directory: destination.path, versionReader: { _ in
                "{\"ok\":true,\"version\":\"" + (kind == "version" ? "0.2.45" : "0.2.46") + "\"}"
            })
        }
        if kind == "complete" {
            try install()
            #expect(fm.fileExists(atPath: destination.appendingPathComponent("triton").path))
            #expect(fm.fileExists(atPath: destination.appendingPathComponent("web/index.html").path))
            #expect(try validateIOSRunnerResources(at: destination.appendingPathComponent("resources/ios-runner"), expectedVersion: "0.2.46").files.count == 7)
            #expect(throws: (any Error).self) { try install() }
            #expect(try Data(contentsOf: destination.appendingPathComponent("triton")) == content)
        } else if ["web", "web-shell", "web-js", "web-css"].contains(kind) {
            do {
                try install()
                Issue.record("Expected incomplete Web resources to reject installation")
            } catch let detail as CLIUpdateErrorDetail {
                #expect(detail.code == "release_install_invalid")
            }
            #expect(!fm.fileExists(atPath: destination.path))
        } else {
            #expect(throws: (any Error).self) { try install() }
            #expect(!fm.fileExists(atPath: destination.path))
        }
    }
}
