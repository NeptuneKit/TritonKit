import Foundation
import Testing

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
    }

    @Test("retired state root suggests current debug and observation commands")
    func retiredStateRootSuggestsCurrentDebugAndObservationCommands() throws {
        let result = try runTritonHelp(["state", "route", "--json"])

        #expect(result.exitCode != 0)
        #expect(result.stderr.contains("Unknown subcommand 'state'"))
        #expect(result.stderr.contains("triton debug state route --json"))
        #expect(result.stderr.contains("triton observe current --json"))
    }

    @Test("workflow act command help can drill into tap")
    func workflowActCommandHelpCanDrillIntoTap() throws {
        let result = try runTritonHelp(["act", "tap", "--help"])

        #expect(result.exitCode == 0)
        #expect(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(result.stdout.contains("USAGE: triton act tap"))
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

        let buildRoot = packageRoot.appendingPathComponent(".build", isDirectory: true)
        guard let enumerator = fileManager.enumerator(
            at: buildRoot,
            includingPropertiesForKeys: [.isExecutableKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw NSError(
                domain: "TritonKitCLITests.CLIHelpTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing triton executable for CLI help test"]
            )
        }
        for case let candidate as URL in enumerator where candidate.lastPathComponent == "triton" {
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        throw NSError(
            domain: "TritonKitCLITests.CLIHelpTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Missing triton executable for CLI help test"]
        )
    }
}

private struct CLIHelpRunResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}
