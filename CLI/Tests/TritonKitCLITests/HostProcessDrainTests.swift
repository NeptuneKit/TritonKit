import ArgumentParser
import Darwin
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized)
struct HostProcessDrainTests {
    private func invoke(_ runner: String, _ command: TKHostCommand, output: String) throws -> (Data, Int) {
        switch runner {
        case "stdout":
            let result = try runHostCommandWritingStdoutArtifact(command, outputPath: output)
            return (try Data(contentsOf: URL(fileURLWithPath: output)), result.stdoutBytes)
        case "combined":
            let result = try runHostCommandWritingCombinedOutputArtifact(command, outputPath: output, interruptAfter: 5, maximumBytes: 2_000_000)
            return (try Data(contentsOf: URL(fileURLWithPath: output)), result.observedBytes)
        default:
            let result = try runHostCommand(command, maximumOutputBytes: nil)
            return (result.stdoutData, result.stdoutBytes)
        }
    }

    @Test("all production runners bound inherited stdout and stderr without killing their holder", arguments: ["memory", "stdout", "combined"], ["stdout", "stderr"])
    func inheritedDescriptor(_ runner: String, _ stream: String) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("triton-drain-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let pidPath = directory.appendingPathComponent("holder.pid").path
        defer {
            if let text = try? String(contentsOfFile: pidPath), let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)), pid > 1 {
                _ = kill(pid, SIGKILL) // Only the exact fixture PID recorded by our shell.
            }
            try? FileManager.default.removeItem(at: directory)
        }
        let redirect = stream == "stdout" ? "2>/dev/null" : ">/dev/null"
        let script = "(/bin/sleep 3) \(redirect) & echo $! > \(shellEscaped(pidPath)); printf tail; printf err >&2; exit 0"
        let command = TKHostCommand(executable: "/bin/sh", arguments: ["-c", script], defaultTimeoutSeconds: 1)
        let start = Date()
        var failure: Error?
        do { _ = try invoke(runner, command, output: directory.appendingPathComponent("output").path) }
        catch { failure = error }
        #expect(Date().timeIntervalSince(start) < 1.5)
        let incomplete = try #require(failure as? HostProcessOutputFailure)
        #expect(incomplete.cause.code == "host_output_incomplete")
        let pid = try #require(Int32(try String(contentsOfFile: pidPath).trimmingCharacters(in: .whitespacesAndNewlines)))
        #expect(kill(pid, 0) == 0, "Runner must not kill the descendant holding the pipe")
    }

    @Test("all runners retain large output and final bytes", arguments: ["memory", "stdout", "combined"])
    func completeOutput(_ runner: String) throws {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("triton-drain-output-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: output) }
        let command = TKHostCommand(executable: "/usr/bin/perl", arguments: ["-e", "print 'x' x 1200000; print 'TAIL';"], defaultTimeoutSeconds: 5)
        let (data, bytes) = try invoke(runner, command, output: output)
        #expect(bytes == 1_200_004)
        #expect(data == Data((String(repeating: "x", count: 1_200_000) + "TAIL").utf8))
    }

    @Test("all runners preserve nonzero exit", arguments: ["memory", "stdout", "combined"])
    func nonzeroExit(_ runner: String) throws {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("triton-drain-nonzero-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: output) }
        let command = TKHostCommand(executable: "/bin/sh", arguments: ["-c", "printf tail; printf error >&2; exit 7"], defaultTimeoutSeconds: 1)
        do {
            _ = try invoke(runner, command, output: output)
            Issue.record("nonzero exit succeeded")
        } catch HostCommandRunError.nonZeroExit(_, let result) {
            #expect(result.exitCode == 7)
            #expect(result.stdoutBytes + result.stderrBytes == 9)
        }
    }

    @Test("short-lived inherited writers reach real EOF and retain delayed tail", arguments: ["memory", "stdout", "combined"])
    func delayedTail(_ runner: String) throws {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("triton-drain-tail-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: output) }
        let command = TKHostCommand(executable: "/bin/sh", arguments: ["-c", "(sleep 0.05; printf TAIL) & printf head; exit 0"], defaultTimeoutSeconds: 1)
        let (data, bytes) = try invoke(runner, command, output: output)
        #expect(data == Data("headTAIL".utf8))
        #expect(bytes == 8)
    }

    @Test("bounded captures drain every byte while reporting truncation")
    func boundedOutput() throws {
        let command = TKHostCommand(executable: "/usr/bin/perl", arguments: ["-e", "print 'a' x 100000; print STDERR 'b' x 100000;"], defaultTimeoutSeconds: 2)
        let result = try runHostCommand(command, maximumOutputBytes: 19)
        #expect(result.stdoutBytes == 100_000 && result.stderrBytes == 100_000)
        #expect(result.stdoutData == Data(repeating: 97, count: 19))
        #expect(result.stderrData == Data(repeating: 98, count: 19))
        #expect(result.stdoutTruncated && result.stderrTruncated)
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("triton-drain-bounded-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: output) }
        let artifact = try runHostCommandWritingCombinedOutputArtifact(command, outputPath: output, interruptAfter: 1, maximumBytes: 19)
        #expect(artifact.observedBytes == 200_000)
        #expect(artifact.artifactBytes == 19 && artifact.artifactTruncated)
        #expect(try Data(contentsOf: URL(fileURLWithPath: output)).count == 19)
    }

    @Test("execution timeout stays a failure for every runner", arguments: ["memory", "stdout", "combined"])
    func executionTimeout(_ runner: String) throws {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("triton-drain-timeout-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: output) }
        // exec replaces the shell, so the runner owns the only long-lived PID.
        let command = TKHostCommand(executable: "/bin/sh", arguments: ["-c", "trap '' INT TERM; exec /bin/sleep 20"], defaultTimeoutSeconds: 0.05)
        do {
            if runner == "combined" {
                _ = try runHostCommandWritingCombinedOutputArtifact(command, outputPath: output, interruptAfter: 0.01, maximumBytes: 100)
            } else {
                _ = try invoke(runner, command, output: output)
            }
            Issue.record("execution timeout succeeded")
        } catch HostCommandRunError.timeout { }
    }

    @Test("intentional combined capture interruption retains its explicit status")
    func interruptionStatus() throws {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("triton-drain-interrupt-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: output) }
        let command = TKHostCommand(executable: "/bin/sleep", arguments: ["20"], defaultTimeoutSeconds: 1)
        let result = try runHostCommandWritingCombinedOutputArtifact(command, outputPath: output, interruptAfter: 0.05, maximumBytes: 100)
        #expect(result.interruptionRequested)
        #expect(result.captureEndedBy == "duration")
        #expect(result.terminationReason == "uncaught-signal")
    }

    @Test("read setup and sink write failures cannot become EOF success")
    func readAndSinkFailures() throws {
        // A closed Foundation FileHandle raises an Objective-C exception on
        // fileDescriptor access. Exercise the POSIX error paths directly instead.
        for descriptor in [Int32(-1), open(FileManager.default.temporaryDirectory.path, O_RDONLY)] {
            defer { if descriptor >= 0 { close(descriptor) } }
            do {
                try drainHostDescriptor(descriptor, deadline: HostPipeDrainDeadline()) { _ in }
                Issue.record("invalid input succeeded")
            } catch let error as HostProcessOutputError {
                #expect(error.code == "host_output_read_failed")
            }
        }
        let pipe = Pipe()
        try pipe.fileHandleForWriting.write(contentsOf: Data("bytes".utf8))
        try pipe.fileHandleForWriting.close()
        do {
            try drainHostPipe(pipe, deadline: HostPipeDrainDeadline()) { _ in
                throw NSError(domain: "unknown-sink-fixture", code: 867)
            }
            Issue.record("unknown sink failure succeeded")
        } catch {
            #expect((error as NSError).domain == "unknown-sink-fixture")
            #expect((error as NSError).code == 867)
        }
    }

    @Test("output failure uses one JSON error envelope", arguments: ["incomplete", "read", "unknown"])
    func errorEnvelope(_ kind: String) throws {
        let sourceError: Error
        let expectedCode: String
        switch kind {
        case "incomplete":
            sourceError = HostProcessOutputFailure(
                cause: .incomplete(observedBytes: 4),
                result: HostProcessResult(stdoutData: Data("tail".utf8), stderrData: Data(), exitCode: 7, sourceCommand: "fixture", stdoutTruncated: false, stderrTruncated: false, stdoutLogPath: nil, stderrLogPath: nil, stdoutBytes: 4, stderrBytes: 0)
            )
            expectedCode = "host_output_incomplete"
        case "read":
            sourceError = HostProcessOutputError.readFailed(code: EIO)
            expectedCode = "host_output_read_failed"
        default:
            sourceError = NSError(domain: "unknown-sink-fixture", code: 867)
            expectedCode = "host_action_failed"
        }
        let pipe = Pipe()
        let original = dup(STDOUT_FILENO)
        #expect(original >= 0)
        fflush(stdout)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        var failure: Error?
        do { try failHostCommand(sourceError, outputFormat: .json) }
        catch { failure = error }
        fflush(stdout)
        dup2(original, STDOUT_FILENO)
        close(original)
        try pipe.fileHandleForWriting.close()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        try pipe.fileHandleForReading.close()
        #expect(failure is ExitCode)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let error = try #require(object["error"] as? [String: Any])
        #expect(error["code"] as? String == expectedCode)
        if kind == "incomplete" {
            #expect((error["message"] as? String)?.contains("exitCode: 7") == true)
            #expect((error["message"] as? String)?.contains("stdoutBytes: 4") == true)
        }
    }

    private func withWriterFixture(_ body: (String, String) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("triton-drain-writer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let pidPath = directory.appendingPathComponent("holder.pid").path
        defer {
            if let text = try? String(contentsOfFile: pidPath), let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)), pid > 1 {
                _ = kill(pid, SIGKILL)
            }
            try? FileManager.default.removeItem(at: directory)
        }
        try body(pidPath, directory.appendingPathComponent("output").path)
    }

    @Test("incomplete capture preserves exit 7 and both stream facts", arguments: ["memory", "stdout", "combined"])
    func incompleteNonzero(_ runner: String) throws {
        try withWriterFixture { pidPath, output in
            let script = "(/bin/sleep 3) 2>/dev/null & echo $! > \(shellEscaped(pidPath)); printf tail; printf err >&2; exit 7"
            let command = TKHostCommand(executable: "/bin/sh", arguments: ["-c", script], defaultTimeoutSeconds: 1)
            var caught: Error?
            do { _ = try invoke(runner, command, output: output) } catch { caught = error }
            let failure = try #require(caught as? HostProcessOutputFailure)
            #expect(failure.cause.code == "host_output_incomplete")
            #expect(failure.result.exitCode == 7)
            #expect(failure.result.stdoutBytes + failure.result.stderrBytes == 7)
            if runner == "memory" {
                #expect(failure.result.stdoutData == Data("tail".utf8))
                #expect(failure.result.stderrData == Data("err".utf8))
            } else if runner == "stdout" {
                #expect(failure.artifactBytes == 4)
                #expect(failure.result.stderrData == Data("err".utf8))
            } else {
                #expect(failure.artifactBytes == 7)
            }
        }
    }

    @Test("continuously readable descendants cannot extend the post-exit budget", arguments: ["memory", "stdout", "combined"])
    func continuousWriter(_ runner: String) throws {
        try withWriterFixture { pidPath, output in
            let script = "(trap '' PIPE; while :; do printf 0123456789abcdef || exit; done) 2>/dev/null & echo $! > \(shellEscaped(pidPath)); exit 7"
            let command = TKHostCommand(executable: "/bin/sh", arguments: ["-c", script], defaultTimeoutSeconds: 1)
            let start = Date()
            var caught: Error?
            do {
                if runner == "memory" { _ = try runHostCommand(command, maximumOutputBytes: 32) }
                else { _ = try invoke(runner, command, output: output) }
            } catch { caught = error }
            #expect(Date().timeIntervalSince(start) < 1.5)
            let failure = try #require(caught as? HostProcessOutputFailure)
            #expect(failure.cause.code == "host_output_incomplete")
            #expect(failure.result.exitCode == 7)
            #expect(failure.result.stdoutBytes > 0)
            if runner == "memory" {
                #expect(failure.result.stdoutData.count == 32)
                #expect(failure.result.stdoutTruncated)
            }
        }
    }

    @Test("all runners preserve raw non-UTF8 tail bytes", arguments: ["memory", "stdout", "combined"])
    func binaryTail(_ runner: String) throws {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("triton-drain-binary-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: output) }
        let command = TKHostCommand(executable: "/usr/bin/perl", arguments: ["-e", "binmode STDOUT; print pack('C*', 0, 255, 128, 10);"], defaultTimeoutSeconds: 1)
        let (data, bytes) = try invoke(runner, command, output: output)
        #expect(data == Data([0, 255, 128, 10]))
        #expect(bytes == 4)
    }
}
