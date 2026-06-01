import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct SimulatorAdvancedControlsTests {
    @Test("host command forwards stdin into child process")
    func runHostCommandForwardsStdin() throws {
        let command = TKHostCommand(executable: "/bin/cat", arguments: [], stdinData: Data("hello\n".utf8))

        let result = try runHostCommand(command)

        #expect(result.exitCode == 0)
        #expect(result.stdout == "hello\n")
        #expect(result.sourceCommand == "/bin/cat")
    }

    @Test("host artifact capture writes full stdout without truncating the artifact")
    func hostArtifactCaptureWritesFullStdout() throws {
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-large-artifact-\(UUID().uuidString).txt")
            .path
        defer { try? FileManager.default.removeItem(atPath: output) }
        let expectedBytes = 1_048_576 + 128
        let command = TKHostCommand(
            executable: "/usr/bin/perl",
            arguments: ["-e", "print \"a\" x \(expectedBytes)"]
        )

        try runHostCommandCapturingStdoutArtifact(
            action: "test.large-artifact",
            target: "host",
            command: command,
            outputPath: output,
            outputFormat: .text
        )

        let data = try Data(contentsOf: URL(fileURLWithPath: output))
        #expect(data.count == expectedBytes)
        #expect(data.last == Character("a").asciiValue)
    }

    @Test("host artifact capture refuses to overwrite an existing output file")
    func hostArtifactCaptureRefusesExistingOutputFile() throws {
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-existing-artifact-\(UUID().uuidString).txt")
        try Data("existing".utf8).write(to: output)
        defer { try? FileManager.default.removeItem(at: output) }
        let command = TKHostCommand(executable: "/bin/echo", arguments: ["new"])

        #expect(throws: (any Error).self) {
            try runHostCommandWritingStdoutArtifact(command, outputPath: output.path)
        }

        #expect(try String(contentsOf: output, encoding: .utf8) == "existing")
    }

    @Test("host artifact capture refuses symlink output paths")
    func hostArtifactCaptureRefusesSymlinkOutputPath() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-artifact-symlink-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = directory.appendingPathComponent("target.txt")
        let symlink = directory.appendingPathComponent("link.txt")
        try Data("target".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: target)
        let command = TKHostCommand(executable: "/bin/echo", arguments: ["new"])

        #expect(throws: (any Error).self) {
            try runHostCommandWritingStdoutArtifact(command, outputPath: symlink.path)
        }

        #expect(try String(contentsOf: target, encoding: .utf8) == "target")
    }

    @Test("xctrace output path rejects accidental overwrite but allows explicit append")
    func xctraceOutputPathRejectsOverwriteButAllowsExplicitAppend() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-xctrace-output-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let trace = directory.appendingPathComponent("App.trace")
        let target = directory.appendingPathComponent("target.trace")
        let symlink = directory.appendingPathComponent("link.trace")
        try FileManager.default.createDirectory(at: trace, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: target)

        #expect(throws: HostArtifactOutputError.self) {
            try prepareXctraceArtifactOutputPath(trace.path, appendRun: false)
        }
        #expect(throws: HostArtifactOutputError.self) {
            try prepareXctraceArtifactOutputPath(symlink.path, appendRun: true)
        }
        #expect(throws: HostArtifactOutputError.self) {
            try prepareXctraceArtifactOutputPath(directory.appendingPathComponent("missing.trace").path, appendRun: true)
        }

        try prepareXctraceArtifactOutputPath(trace.path, appendRun: true)
        try prepareXctraceArtifactOutputPath(directory.appendingPathComponent("new.trace").path, appendRun: false)
    }

    @Test("host artifact capture removes partial output when command fails")
    func hostArtifactCaptureRemovesPartialOutputOnFailure() throws {
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-partial-artifact-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: output) }
        let command = TKHostCommand(
            executable: "/bin/sh",
            arguments: ["-c", "printf partial; exit 7"]
        )

        #expect(throws: HostCommandRunError.self) {
            try runHostCommandWritingStdoutArtifact(command, outputPath: output.path)
        }

        #expect(!FileManager.default.fileExists(atPath: output.path))
    }

    @Test("host command drains large stdout while keeping only a bounded sample")
    func runHostCommandBoundsLargeStdoutSample() throws {
        let expectedBytes = 1_048_576 + 128
        let command = TKHostCommand(
            executable: "/usr/bin/perl",
            arguments: ["-e", "print \"b\" x \(expectedBytes)"]
        )

        let result = try runHostCommand(command)

        #expect(result.stdoutBytes == expectedBytes)
        #expect(result.stdoutData.count == 1_048_576)
        #expect(result.stdoutTruncated)
    }

    @Test("host command timeout terminates process and leaves later commands usable")
    func runHostCommandTimeoutCleansUpProcess() throws {
        let command = TKHostCommand(
            executable: "/bin/sh",
            arguments: ["-c", "trap '' TERM; while true; do printf x; sleep 0.01; done"],
            defaultTimeoutSeconds: 0.2
        )

        #expect(throws: HostCommandRunError.self) {
            try runHostCommand(command)
        }

        let result = try runHostCommand(TKHostCommand(executable: "/bin/echo", arguments: ["ok"]))
        #expect(result.stdout == "ok\n")
    }

    @Test("sim schema exposes advanced simulator maintenance commands")
    func simSchemaExposesAdvancedCommands() throws {
        let sim = try #require(commandSchemas().first { $0.name == "sim" })
        let usageForms = sim.usageForms.map(\.form)

        #expect(usageForms.contains(where: { $0.hasPrefix("status-bar") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("privacy") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("location") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("ui ") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("pasteboard") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("push ") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("record") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("logs") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("diagnose") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("logverbose") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("runtime ") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("pair ") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("unpair ") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("clone ") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("erase ") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("upgrade ") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("personalization ") }))
        #expect(sim.providedCapabilities.contains("host-simulator"))
        #expect(sim.providedCapabilities.contains("sim-video"))
        #expect(sim.providedCapabilities.contains("sim-logs"))
        #expect(sim.providedCapabilities.contains("sim-diagnostics"))
        #expect(sim.providedCapabilities.contains("sim-runtime"))
        #expect(sim.providedCapabilities.contains("sim-device-maintenance"))
        #expect(sim.providedCapabilities.contains("sim-runtime-maintenance"))
        #expect(sim.providedCapabilities.contains("sim-personalization"))
        #expect(sim.providedCapabilities.contains("sim-push"))
    }

    @Test("schema exposes xctrace and coverage artifact commands")
    func schemaExposesXctraceAndCoverageCommands() throws {
        let xcode = try #require(commandSchemas().first { $0.name == "xcode" })
        let xctrace = try #require(commandSchemas().first { $0.name == "xctrace" })
        let coverage = try #require(commandSchemas().first { $0.name == "coverage" })
        let xcresult = try #require(commandSchemas().first { $0.name == "xcresult" })

        #expect(xcode.inheritsDefaultsFrom.contains("triton xcode use"))
        #expect(xcode.jsonlEvents.contains("xcode.<action>.summary"))
        #expect(xcode.outputContracts.map(\.selector).contains("xcode.progress"))
        #expect(xcode.outputContracts.map(\.selector).contains("xcode.final"))
        #expect(xcode.failureCodes.contains("xcodebuild_failed"))
        let xcodeProgress = try #require(xcode.outputContracts.first { $0.selector == "xcode.progress" })
        #expect(xcodeProgress.fields.first { $0.name == "message" }?.required == true)
        #expect(xcodeProgress.fields.first { $0.name == "elapsedMs" }?.type == "Int?")
        let xcodeFinal = try #require(xcode.outputContracts.first { $0.selector == "xcode.final" })
        #expect(xcodeFinal.fields.first { $0.name == "stdoutBytes" }?.type == "Int?")
        let xcodeRun = try #require(xcode.subcommands.first { $0.name == "run" })
        #expect(xcodeRun.inheritsDefaultsFrom.contains("triton xcode use"))
        #expect(xcodeRun.defaultProviders.contains("triton xcode use"))
        #expect(xcodeRun.outputSelectors == ["xcode.progress", "xcode.final"])
        #expect(xcodeRun.nextCommands.contains("triton assert text-exists <text> --json"))
        let xcodeUse = try #require(xcode.subcommands.first { $0.name == "use" })
        #expect(xcodeUse.requiredOptions == ["--scheme"])
        #expect(xcodeUse.oneOfRequiredOptions == [["--workspace"], ["--project"]])
        let xcodeTest = try #require(xcode.subcommands.first { $0.name == "test" })
        #expect(xcodeTest.artifacts.contains("result-bundle"))
        #expect(xcodeTest.nextCommands.contains("triton xcresult failures --path <result.xcresult> --json"))
        #expect(xctrace.usageForms.map(\.form).contains(where: { $0.hasPrefix("record") }))
        #expect(xctrace.providedCapabilities.contains("xctrace-record"))
        #expect(xctrace.outputContracts.map(\.selector).contains("xctrace.record"))
        #expect(xctrace.failureCodes.contains("xctrace_record_failed"))
        #expect(xctrace.failureCodes.contains("artifact_output_rejected"))
        #expect(xctrace.failureShape?.contains("artifact_output_rejected") == true)
        let xctraceRecord = try #require(xctrace.outputContracts.first { $0.selector == "xctrace.record" })
        #expect(xctraceRecord.fields.map(\.name).contains("runtimeScope"))
        #expect(xctraceRecord.fields.map(\.name).contains("artifacts"))
        #expect(xctrace.subcommands.first { $0.name == "record" }?.requiredOptions == ["--template", "--output"])
        #expect(xctrace.subcommands.first { $0.name == "record" }?.failureCodes.contains("artifact_output_rejected") == true)
        #expect(coverage.usageForms.map(\.form).contains(where: { $0.hasPrefix("report") }))
        #expect(coverage.providedCapabilities.contains("coverage-report"))
        #expect(coverage.failureShape?.contains("validation_failed") == true)
        #expect(coverage.failureShape?.contains("artifact_output_rejected") == true)
        #expect(xcresult.usageForms.map(\.form).contains(where: { $0.hasPrefix("summary") }))
        #expect(xcresult.usageForms.map(\.form).contains(where: { $0.hasPrefix("failures") }))
        #expect(xcresult.options.map(\.name).contains("--include-sensitive"))
        #expect(xcresult.successShape?.contains("redaction") == true)
        #expect(xcresult.requiredOptions == [])
        #expect(xcresult.nextCommands.contains("triton evidence --output <dir.tritonevidence> --json"))
        #expect(xcresult.outputContracts.map(\.selector).contains("xcresult.summary"))
        #expect(xcresult.outputContracts.map(\.selector).contains("xcresult.failures"))
        #expect(xcresult.failureCodes.contains("xcresult_parse_failed"))
        #expect(xcresult.subcommands.first { $0.name == "summary" }?.requiredOptions == ["--path"])
        #expect(xcresult.subcommands.first { $0.name == "failures" }?.outputSelectors == ["xcresult.failures"])
        #expect(coverage.requiredOptions == [])
        #expect(coverage.artifacts == ["coverage-json"])
        #expect(coverage.outputContracts.map(\.selector).contains("coverage.report"))
        #expect(coverage.failureCodes.contains("artifact_output_rejected"))
        #expect(coverage.subcommands.first { $0.name == "report" }?.requiredOptions == ["--xcresult", "--output"])
        #expect(xcresult.providedCapabilities.contains("xcresult-summary"))
        #expect(xcresult.providedCapabilities.contains("xcresult-failures"))
        #expect(xcresult.failureShape?.contains("xcresult_parse_failed") == true)
        #expect(xcresult.failureShape?.contains("xcresult_output_too_large") == true)
    }
}
