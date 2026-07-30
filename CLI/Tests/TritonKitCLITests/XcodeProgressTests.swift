import Darwin
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct XcodeProgressTests {
    @Test("xcode build defaults to compact progress while preserving raw logs")
    func xcodeBuildDefaultsToCompactProgress() throws {
        let command = TKHostCommand(
            executable: "/bin/sh",
            arguments: [
                "-c",
                "for i in 1 2 3 4 5; do echo ordinary-$i; done; echo 'App.swift:7: warning: fixture warning'; echo 'App.swift:9: error: fixture error' >&2",
            ]
        )

        let captured = try captureXcodeProgressOutput {
            try runXcodeHostCommand(
                command,
                event: "xcode.build",
                jsonl: true,
                progress: .compact
            ).0
        }
        defer { removeXcodeProgressArtifacts(captured.result) }

        let events = try decodeXcodeProgressLines(captured.stdout)
        #expect(events.map(\.event).contains("xcode.build.invocation"))
        #expect(events.map(\.event).contains("xcode.build.warning"))
        #expect(events.map(\.event).contains("xcode.build.error"))
        #expect(!events.map(\.event).contains("xcode.build.stdout"))
        #expect(!events.map(\.event).contains("xcode.build.stderr"))
        #expect(events.map(\.event).last == "xcode.build.summary")

        let stdoutLogPath = try #require(captured.result.stdoutLogPath)
        let stderrLogPath = try #require(captured.result.stderrLogPath)
        let stdoutLog = try String(contentsOfFile: stdoutLogPath, encoding: .utf8)
        let stderrLog = try String(contentsOfFile: stderrLogPath, encoding: .utf8)
        #expect(stdoutLog.contains("ordinary-1"))
        #expect(stdoutLog.contains("ordinary-5"))
        #expect(stdoutLog.contains("fixture warning"))
        #expect(stderrLog.contains("fixture error"))
    }

    @Test("compact progress bounds warning and error events independently")
    func compactProgressBoundsDiagnostics() throws {
        let command = TKHostCommand(
            executable: "/bin/sh",
            arguments: [
                "-c",
                "for i in 1 2 3 4; do echo \"File.swift:$i: warning: warning-$i\"; echo \"File.swift:$i: error: error-$i\" >&2; done; echo ordinary-output",
            ]
        )

        let captured = try captureXcodeProgressOutput {
            try runXcodeHostCommand(
                command,
                event: "xcode.build",
                jsonl: true,
                progress: .compact,
                maximumCompactDiagnosticsPerKind: 2
            ).0
        }
        defer { removeXcodeProgressArtifacts(captured.result) }

        let events = try decodeXcodeProgressLines(captured.stdout)
        let warnings = events.filter { $0.event == "xcode.build.warning" }
        let errors = events.filter { $0.event == "xcode.build.error" }
        #expect(warnings.count == 2)
        #expect(errors.count == 2)
        #expect(warnings.allSatisfy { $0.message.contains("warning-") })
        #expect(errors.allSatisfy { $0.message.contains("error-") })
        #expect(events.allSatisfy { !$0.message.contains("ordinary-output") })
    }

    @Test("full progress preserves stdout and stderr chunk events")
    func fullProgressPreservesLegacyStream() throws {
        let command = TKHostCommand(
            executable: "/bin/sh",
            arguments: ["-c", "echo ordinary-full; echo diagnostic-full >&2"]
        )

        let captured = try captureXcodeProgressOutput {
            try runXcodeHostCommand(
                command,
                event: "xcode.build",
                jsonl: true,
                progress: .full
            ).0
        }
        defer { removeXcodeProgressArtifacts(captured.result) }

        let events = try decodeXcodeProgressLines(captured.stdout)
        #expect(events.contains { $0.event == "xcode.build.stdout" && $0.message.contains("ordinary-full") })
        #expect(events.contains { $0.event == "xcode.build.stderr" && $0.message.contains("diagnostic-full") })
        #expect(!events.map(\.event).contains("xcode.build.warning"))
        #expect(!events.map(\.event).contains("xcode.build.error"))
    }

    @Test("full non-JSONL progress preserves legacy lifecycle routing")
    func fullNonJSONLPreservesLegacyLifecycleRouting() throws {
        let command = TKHostCommand(
            executable: "/bin/sh",
            arguments: ["-c", "echo ordinary-full; echo diagnostic-full >&2"]
        )

        let captured = try captureXcodeProgressOutput {
            try runXcodeHostCommand(
                command,
                event: "xcode.settings",
                jsonl: false,
                progress: .full
            ).0
        }
        defer { removeXcodeProgressArtifacts(captured.result) }

        let events = try decodeXcodeProgressLines(captured.stderr)
        #expect(events.contains { $0.event == "xcode.settings.stdout" })
        #expect(events.contains { $0.event == "xcode.settings.stderr" })
        #expect(!events.map(\.event).contains("xcode.settings.invocation"))
        #expect(!events.map(\.event).contains("xcode.settings.summary"))
        #expect(captured.stdout.isEmpty)
    }

    @Test("compact progress preserves heartbeat and routes JSON progress to stderr")
    func compactProgressPreservesHeartbeatAndJSONRouting() throws {
        let command = TKHostCommand(
            executable: "/bin/sh",
            arguments: ["-c", "echo ordinary-json; sleep 0.15"]
        )

        let captured = try captureXcodeProgressOutput {
            let (result, _) = try runXcodeHostCommand(
                command,
                event: "xcode.build",
                jsonl: false,
                progress: .compact,
                heartbeatInterval: 0.02
            )
            try printXcodeSummary(
                xcodeProgressFixtureSummary(result),
                jsonl: false,
                outputFormat: .json
            )
            return result
        }
        defer { removeXcodeProgressArtifacts(captured.result) }

        let final = try JSONSerialization.jsonObject(with: Data(captured.stdout.utf8)) as? [String: Any]
        #expect(final?["action"] as? String == "xcode.build")
        let progress = try decodeXcodeProgressLines(captured.stderr)
        #expect(progress.map(\.event).first == "xcode.build.invocation")
        #expect(progress.map(\.event).contains("xcode.build.heartbeat"))
        #expect(progress.map(\.event).last == "xcode.build.summary")
        #expect(!progress.map(\.event).contains("xcode.build.stdout"))
        #expect(progress.allSatisfy { !$0.message.contains("ordinary-json") })
    }

    @Test("compact JSONL keeps progress on stdout and final summary last")
    func compactJSONLRoutesFinalSummaryLast() throws {
        let command = TKHostCommand(
            executable: "/bin/sh",
            arguments: ["-c", "echo ordinary-jsonl"]
        )

        let captured = try captureXcodeProgressOutput {
            let (result, _) = try runXcodeHostCommand(
                command,
                event: "xcode.build",
                jsonl: true,
                progress: .compact
            )
            try printXcodeSummary(
                xcodeProgressFixtureSummary(result),
                jsonl: true,
                outputFormat: .json
            )
            return result
        }
        defer { removeXcodeProgressArtifacts(captured.result) }

        let objects = try decodeJSONObjects(captured.stdout)
        #expect(objects.first?["event"] as? String == "xcode.build.invocation")
        #expect(objects.dropLast().last?["event"] as? String == "xcode.build.summary")
        #expect(objects.last?["action"] as? String == "xcode.build")
        #expect(captured.stderr.isEmpty)
        #expect(objects.dropLast().allSatisfy { object in
            !(object["message"] as? String ?? "").contains("ordinary-jsonl")
        })
    }

    @Test("compact text output keeps final result on stdout and progress on stderr")
    func compactTextOutputRouting() throws {
        let command = TKHostCommand(
            executable: "/bin/sh",
            arguments: ["-c", "echo ordinary-text; echo 'File.swift:3: warning: text-warning'"]
        )

        let captured = try captureXcodeProgressOutput {
            let (result, _) = try runXcodeHostCommand(
                command,
                event: "xcode.build",
                jsonl: false,
                progress: .compact
            )
            try printXcodeSummary(
                xcodeProgressFixtureSummary(result),
                jsonl: false,
                outputFormat: .text
            )
            return result
        }
        defer { removeXcodeProgressArtifacts(captured.result) }

        #expect(captured.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "xcode.build")
        let progress = try decodeXcodeProgressLines(captured.stderr)
        #expect(progress.map(\.event).first == "xcode.build.invocation")
        #expect(progress.map(\.event).contains("xcode.build.warning"))
        #expect(progress.map(\.event).last == "xcode.build.summary")
        #expect(progress.allSatisfy { !$0.message.contains("ordinary-text") })
    }

    @Test("xcode build progress option defaults compact and schema exposes routing")
    func xcodeBuildProgressOptionAndSchema() throws {
        let defaultBuild = try XcodeBuild.parse([
            "--project", "App.xcodeproj",
            "--scheme", "App",
            "--jsonl",
        ])
        let fullBuild = try XcodeBuild.parse([
            "--project", "App.xcodeproj",
            "--scheme", "App",
            "--progress", "full",
            "--jsonl",
        ])

        #expect(defaultBuild.progress == .compact)
        #expect(fullBuild.progress == .full)
        #expect(throws: Error.self) {
            _ = try XcodeBuild.parse([
                "--project", "App.xcodeproj",
                "--scheme", "App",
                "--progress", "verbose",
            ])
        }
        for command in [
            { try XcodeSettings.parse(["--project", "App.xcodeproj", "--scheme", "App", "--progress", "compact"]) as Any },
            { try XcodeTest.parse(["--project", "App.xcodeproj", "--scheme", "App", "--progress", "compact"]) as Any },
            { try XcodeRun.parse(["--project", "App.xcodeproj", "--scheme", "App", "--progress", "compact"]) as Any },
        ] {
            #expect(throws: Error.self) {
                _ = try command()
            }
        }

        let xcode = try #require(commandSchemas().first { $0.name == "xcode" })
        let progress = try #require(xcode.options.first { $0.name == "--progress" })
        let build = try #require(xcode.subcommands.first { $0.name == "build" })
        #expect(progress.type == "compact|full")
        #expect(progress.defaultValue == "compact")
        #expect(progress.description.contains("stderr"))
        #expect(build.optionalOptions.contains("--progress"))
        #expect(build.jsonlEvents.contains("xcode.build.warning"))
        #expect(build.jsonlEvents.contains("xcode.build.error"))
        #expect(build.jsonlEvents.contains("xcode.build.stdout"))
        #expect(build.jsonlEvents.contains("xcode.build.stderr"))
        #expect(build.finalEventKind == "xcode.build.summary")
        for action in ["settings", "test", "run"] {
            let subcommand = try #require(xcode.subcommands.first { $0.name == action })
            #expect(!subcommand.optionalOptions.contains("--progress"))
        }
    }
}

private func decodeXcodeProgressLines(_ output: String) throws -> [TKXcodeProgressEvent] {
    try output.split(whereSeparator: { $0.isNewline }).map {
        try JSONDecoder().decode(TKXcodeProgressEvent.self, from: Data($0.utf8))
    }
}

private func decodeJSONObjects(_ output: String) throws -> [[String: Any]] {
    try output.split(whereSeparator: { $0.isNewline }).map {
        let object = try JSONSerialization.jsonObject(with: Data($0.utf8))
        return try #require(object as? [String: Any])
    }
}

private func xcodeProgressFixtureSummary(_ result: HostProcessResult) -> TKXcodeActionSummary {
    TKXcodeActionSummary(
        ok: true,
        action: "xcode.build",
        workspace: "App.xcworkspace",
        project: nil,
        scheme: "App",
        configuration: "Debug",
        sdk: nil,
        destination: nil,
        derivedDataPath: ".triton/DerivedData",
        durationMs: 1,
        sourceCommand: result.sourceCommand,
        exitCode: result.exitCode,
        stdoutTruncated: result.stdoutTruncated,
        stderrTruncated: result.stderrTruncated,
        stdoutLogPath: result.stdoutLogPath,
        stderrLogPath: result.stderrLogPath,
        stdoutBytes: result.stdoutBytes,
        stderrBytes: result.stderrBytes
    )
}

private func captureXcodeProgressOutput(
    _ body: () throws -> HostProcessResult
) throws -> (stdout: String, stderr: String, result: HostProcessResult) {
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    let originalStdout = dup(STDOUT_FILENO)
    let originalStderr = dup(STDERR_FILENO)

    fflush(stdout)
    fflush(stderr)
    dup2(stdoutPipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
    dup2(stderrPipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
    let result: Result<HostProcessResult, Error>
    do {
        result = .success(try body())
    } catch {
        result = .failure(error)
    }
    fflush(stdout)
    fflush(stderr)
    dup2(originalStdout, STDOUT_FILENO)
    dup2(originalStderr, STDERR_FILENO)
    close(originalStdout)
    close(originalStderr)
    stdoutPipe.fileHandleForWriting.closeFile()
    stderrPipe.fileHandleForWriting.closeFile()
    let capturedStdout = String(decoding: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    let capturedStderr = String(decoding: stderrPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    return (capturedStdout, capturedStderr, try result.get())
}

private func removeXcodeProgressArtifacts(_ result: HostProcessResult) {
    guard let stdoutLogPath = result.stdoutLogPath else { return }
    let directory = URL(fileURLWithPath: stdoutLogPath).deletingLastPathComponent()
    try? FileManager.default.removeItem(at: directory)
}
