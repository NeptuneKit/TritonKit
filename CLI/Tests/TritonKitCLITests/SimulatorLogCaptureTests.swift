import ArgumentParser
import Darwin
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct SimulatorLogCaptureTests {
    private func withOutput(_ body: (String) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("sim-log-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory.appendingPathComponent("output").path)
    }

    @Test("one partial envelope retains signal and timeout provenance without log content", arguments: ["signal", "timeout", "exit", "limit", "success"])
    func envelopes(_ scenario: String) throws {
        try withOutput { path in
            let tail = switch scenario {
            case "signal": "kill -9 $$"
            case "timeout": "exec /bin/sleep 10"
            case "exit": "exit 7"
            default: "exit 0"
            }
            let command = TKHostCommand(executable: "/bin/sh", arguments: ["-c", "printf PRIVATE-LOG; printf PRIVATE-ERROR >&2; \(tail)"], defaultTimeoutSeconds: scenario == "timeout" ? 0.15 : 3)
            let pipe = Pipe()
            let original = dup(STDOUT_FILENO)
            defer { close(original) }
            fflush(stdout)
            dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
            var caught: Error?
            do {
                try runHostCommandCapturingStdoutArtifact(
                    action: "sim.logs", target: "sim:fixture", command: command,
                    outputPath: path, outputFormat: .json, sourceType: "unified-log",
                    sourcesCaptured: ["unified-log"], streamLayout: "compact", artifactSensitive: true,
                    preserveArtifactOnFailure: true, maximumArtifactBytes: scenario == "limit" ? 4 : 1024,
                    note: "Fixture capture"
                )
            } catch { caught = error }
            fflush(stdout)
            dup2(original, STDOUT_FILENO)
            try pipe.fileHandleForWriting.close()
            let encoded = pipe.fileHandleForReading.readDataToEndOfFile()
            try pipe.fileHandleForReading.close()
            // Parsing the whole output rejects a second JSON error envelope.
            let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
            #expect(object["ok"] as? Bool == (scenario == "success"))
            #expect(object["partial"] as? Bool == (scenario != "success"))
            #expect(object["artifact"] as? String == path)
            #expect(object["stdoutBytes"] as? Int == 11)
            #expect(object["artifactBytes"] as? Int == (scenario == "limit" ? 4 : 11))
            #expect(object["artifactTruncated"] as? Bool == (scenario == "limit"))
            #expect(object["stderr"] == nil && object["stdout"] == nil)
            #expect(object["sourcesCaptured"] as? [String] == ["unified-log"])
            if scenario == "success" { #expect(caught == nil && object["error"] == nil) }
            else {
                #expect(caught is ExitCode)
                let error = try #require(object["error"] as? [String: Any])
                #expect(error["code"] as? String == (scenario == "timeout" ? "host_command_timeout" : "sim_logs_failed"))
                #expect(!(error["message"] as? String ?? "").contains("PRIVATE-"))
                if scenario == "signal" {
                    #expect(object["terminationReason"] as? String == "uncaught-signal")
                    #expect(object["exitCode"] as? Int == Int(SIGKILL))
                }
                if scenario == "timeout" { #expect(object["captureEndedBy"] as? String == "timeout") }
                if scenario == "limit" { #expect(object["captureEndedBy"] as? String == "byte-limit") }
            }
            #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == Data((scenario == "limit" ? "PRIV" : "PRIVATE-LOG").utf8))
            let permissions = try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? NSNumber
            #expect(permissions?.intValue == 0o600)
        }
    }

    @Test("exclusive output rejects existing files and symlinks before launching", arguments: [false, true])
    func existingArtifact(_ symlink: Bool) throws {
        try withOutput { path in
            let protected = path + ".protected"
            try Data("keep".utf8).write(to: URL(fileURLWithPath: protected))
            if symlink { try FileManager.default.createSymbolicLink(atPath: path, withDestinationPath: protected) }
            else { try Data("keep".utf8).write(to: URL(fileURLWithPath: path)) }
            let marker = path + ".launched"
            let command = TKHostCommand(executable: "/usr/bin/touch", arguments: [marker], defaultTimeoutSeconds: 2)
            #expect(throws: HostArtifactOutputError.self) {
                try runHostCommandWritingStdoutArtifact(command, outputPath: path, preserveArtifactOnFailure: true)
            }
            #expect(!FileManager.default.fileExists(atPath: marker))
            #expect(try String(contentsOfFile: path) == "keep")
            #expect(try String(contentsOfFile: protected) == "keep")
        }
    }

    @Test("log limit defaults and overrides parse and invalid limit fails before launching")
    func limits() async throws {
        let command = try SimLogs.parse(["--output", "/unused", "--max-bytes", "32"])
        #expect(command.maximumBytes == 32)
        #expect(try SimLogs.parse(["--output", "/unused"]).maximumBytes == 10_485_760)
        #expect(throws: (any Error).self) { try SimLogs.parse(["--output", "/unused", "--max-bytes", "invalid"]) }
    }
    @Test("captured stdout reaches disk before the child exits")
    func incrementalArtifact() throws {
        try withOutput { path in
            let script = "printf first; i=0; while ! /usr/bin/grep -q first \(shellEscaped(path)); do i=$((i+1)); [ $i -lt 30 ] || exit 8; sleep 0.02; done; printf tail; exit 7"
            let command = TKHostCommand(executable: "/bin/sh", arguments: ["-c", script], defaultTimeoutSeconds: 3)
            var caught: Error?
            do { _ = try runHostCommandWritingStdoutArtifact(command, outputPath: path, preserveArtifactOnFailure: true) } catch { caught = error }
            let failure = try #require(caught as? HostArtifactCaptureFailure)
            #expect(failure.result.exitCode == 7)
            #expect(failure.artifactBytes == 9)
            #expect(try String(contentsOfFile: path) == "firsttail")
        }
    }

    @Test("large output is drained without growing the artifact beyond its limit")
    func largeCapture() throws {
        try withOutput { path in
            let command = TKHostCommand(executable: "/usr/bin/perl", arguments: ["-e", "print 'x' x 1200000; print STDERR 'y' x 1200000; exit 7"], defaultTimeoutSeconds: 5)
            var caught: Error?
            do { _ = try runHostCommandWritingStdoutArtifact(command, outputPath: path, preserveArtifactOnFailure: true, maximumArtifactBytes: 13) } catch { caught = error }
            let failure = try #require(caught as? HostArtifactCaptureFailure)
            #expect(failure.artifactBytes == 13)
            #expect(failure.result.stdoutBytes == 1_200_000)
            #expect(failure.result.stderrBytes == 1_200_000)
            #expect(failure.result.stderrData.isEmpty)
            #expect(failure.artifactTruncated)
            #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == Data(repeating: 120, count: 13))
        }
    }

}
