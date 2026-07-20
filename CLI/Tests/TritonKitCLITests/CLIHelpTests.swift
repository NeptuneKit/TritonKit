import Foundation
import Testing
@testable import TritonKitCLI

@Suite
struct CLIHelpTests {
    @Test("act help shows workflow action group instead of provider parse help")
    func actHelpShowsWorkflowActionGroupInsteadOfProviderParseHelp() throws {
        let result = try runTritonHelp(["act", "--help"])

        #expect(result.exitCode == 0)
        #expect(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(result.stdout.contains("USAGE: triton act"))
        #expect(result.stdout.contains("tap"))
        #expect(result.stdout.contains("swipe"))
        #expect(result.stdout.contains("type"))
        #expect(result.stdout.contains("paste"))
        #expect(result.stdout.contains("clear"))
        #expect(result.stdout.contains("focus"))
        #expect(result.stdout.contains("set-text"))
        #expect(!result.stdout.contains("USAGE: triton list"))
    }

    @Test("top-level tap command is not exposed after P23 surface cut")
    func topLevelTapCommandIsNotExposedAfterP23SurfaceCut() throws {
        let result = try runTritonHelp(["tap", "--help"])

        #expect(result.exitCode != 0)
        #expect(result.stderr.contains("Unknown subcommand 'tap'"))
        #expect(result.stderr.contains("triton act tap"))
    }

    @Test("action discovery text does not promise retired top-level aliases")
    func actionDiscoveryTextDoesNotPromiseRetiredTopLevelAliases() {
        #expect(Action.configuration.discussion.contains("triton tap remain supported") == false)
        #expect(Action.configuration.discussion.contains("triton act") == true)
    }

    @Test("retired state root suggests current debug and observation commands")
    func retiredStateRootSuggestsCurrentDebugAndObservationCommands() throws {
        let result = try runTritonHelp(["state", "route", "--json"])

        #expect(result.exitCode != 0)
        #expect(result.stderr.contains("Unknown subcommand 'state'"))
        #expect(result.stderr.contains("triton debug state route --json"))
        #expect(result.stderr.contains("triton observe current --json"))
    }

    @Test("root node command exposes current UI resolve workflow")
    func rootNodeCommandExposesCurrentUIResolveWorkflow() throws {
        let result = try runTritonHelp(["node", "--help"])

        #expect(result.exitCode == 0)
        #expect(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(result.stdout.contains("USAGE: triton node"))
        #expect(result.stdout.contains("resolve"))
    }

    @Test("workflow act command help can drill into tap")
    func workflowActCommandHelpCanDrillIntoTap() throws {
        let result = try runTritonHelp(["act", "tap", "--help"])

        #expect(result.exitCode == 0)
        #expect(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(result.stdout.contains("USAGE: triton act tap"))
    }

    @Test("workflow act swipe help documents iOS runtime targets")
    func workflowActSwipeHelpDocumentsIOSRuntimeTargets() throws {
        let result = try runTritonHelp(["act", "swipe", "--help"])

        #expect(result.exitCode == 0)
        #expect(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(result.stdout.contains("iOS embedded runtime"))
        #expect(result.stdout.contains("triton list --json"))
        #expect(result.stdout.contains("sim:<udid>"))
    }

    @Test("sim app-console help exposes bounded sensitive artifact controls")
    func simAppConsoleHelpExposesBoundedArtifactControls() throws {
        let result = try runTritonHelp(["sim", "app-console", "--help"])

        #expect(result.exitCode == 0)
        #expect(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(result.stdout.contains("USAGE: triton sim app-console"))
        #expect(result.stdout.contains("--bundle-id"))
        #expect(result.stdout.contains("--duration"))
        #expect(result.stdout.contains("--max-bytes"))
        #expect(result.stdout.contains("stdout/stderr"))
        #expect(result.stdout.contains("merged PTY"))
    }

    @Test("sim app-console rejects invalid duration as one JSON failure")
    func simAppConsoleRejectsInvalidDurationAsJSON() throws {
        let result = try runTritonHelp([
            "sim", "app-console",
            "--bundle-id", "com.example.app",
            "--output", "/tmp/triton-invalid-console.log",
            "--duration", "0",
            "--json",
        ])

        #expect(result.exitCode != 0)
        #expect(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        let object = try #require(JSONSerialization.jsonObject(with: Data(result.stdout.utf8)) as? [String: Any])
        let error = try #require(object["error"] as? [String: Any])
        #expect(object["ok"] as? Bool == false)
        #expect(error["code"] as? String == "invalid_duration")
    }

    private func runTritonHelp(_ arguments: [String]) throws -> CLIHelpRunResult {
        let process = Process()
        process.executableURL = try tritonExecutableURL()
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        return CLIHelpRunResult(
            exitCode: process.terminationStatus,
            stdout: String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            stderr: String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        )
    }

    private func tritonExecutableURL() throws -> URL {
        let fileManager = FileManager.default
        if let override = ProcessInfo.processInfo.environment["TRITON_CLI_PATH"],
           fileManager.isExecutableFile(atPath: override) {
            return URL(fileURLWithPath: override)
        }
        let testBundleCandidate = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("triton")
        if fileManager.isExecutableFile(atPath: testBundleCandidate.path) {
            return testBundleCandidate
        }
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let debugCandidate = packageRoot
            .appendingPathComponent(".build", isDirectory: true)
            .appendingPathComponent("debug", isDirectory: true)
            .appendingPathComponent("triton")
        if fileManager.isExecutableFile(atPath: debugCandidate.path) {
            return debugCandidate
        }

        let packageBuildRoot = packageRoot.appendingPathComponent(".build", isDirectory: true)
        if let candidate = try findTritonExecutable(under: packageBuildRoot, fileManager: fileManager) {
            return candidate
        }

        let repositoryRoot = packageRoot.deletingLastPathComponent()
        for scratchPath in [".build/cli-test", ".build/cli"] {
            let buildRoot = repositoryRoot.appendingPathComponent(scratchPath, isDirectory: true)
            if let candidate = try findTritonExecutable(under: buildRoot, fileManager: fileManager) {
                return candidate
            }
        }
        throw NSError(
            domain: "TritonKitCLITests.CLIHelpTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Missing triton executable for CLI help test"]
        )
    }

    private func findTritonExecutable(under buildRoot: URL, fileManager: FileManager) throws -> URL? {
        guard let enumerator = fileManager.enumerator(
            at: buildRoot,
            includingPropertiesForKeys: [.isExecutableKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        for case let candidate as URL in enumerator where candidate.lastPathComponent == "triton" {
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }
}

private struct CLIHelpRunResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}
