import Foundation
import Darwin
import TritonKitShared

/// Preserve bounded native logs even on timeout. stdout is never action proof.
func runApplePlatformRunnerProcess(_ command: TKHostCommand, logPrefix: String) throws -> HostProcessResult {
    let stdoutPath = logPrefix + ".stdout.log"
    let stderrPath = logPrefix + ".stderr.log"
    func createLog(_ path: String) throws -> FileHandle {
        let fd = open(path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw runnerError("runner_log_failed", "Cannot create private native command log.") }
        return FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    }
    let stdoutLog = try createLog(stdoutPath)
    let stderrLog = try createLog(stderrPath)
    defer { try? stdoutLog.close(); try? stderrLog.close() }
    let process = Process()
    configureHostProcessExecutable(process, command: command)
    let stdout = Pipe(), stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr
    process.standardInput = FileHandle.nullDevice
    let finished = DispatchSemaphore(value: 0)
    process.terminationHandler = { _ in finished.signal() }
    do { try process.run() } catch { throw HostCommandRunError.launchFailed(error.localizedDescription) }
    final class Capture: @unchecked Sendable {
        var data = Data()
        var bytes = 0
        var failure: Error?
    }
    let out = Capture(), err = Capture()
    let group = DispatchGroup()
    for (pipe, file, capture) in [(stdout, stdoutLog, out), (stderr, stderrLog, err)] {
        group.enter()
        DispatchQueue.global().async {
            defer { group.leave() }
            do {
                while let chunk = try pipe.fileHandleForReading.read(upToCount: 65536), !chunk.isEmpty {
                    capture.bytes += chunk.count
                    let bounded = chunk.prefix(max(0, 1_048_576 - capture.data.count))
                    if !bounded.isEmpty {
                        try file.write(contentsOf: bounded)
                        capture.data.append(bounded)
                    }
                }
                try file.synchronize()
            } catch { capture.failure = error }
        }
    }
    let timedOut = finished.wait(timeout: .now() + command.defaultTimeoutSeconds) == .timedOut
    if timedOut {
        if process.isRunning { process.terminate() }
        if finished.wait(timeout: .now() + 2) == .timedOut {
            kill(process.processIdentifier, SIGKILL)
            _ = finished.wait(timeout: .now() + 2)
        }
    }
    if group.wait(timeout: .now() + 3) == .timedOut {
        try? stdout.fileHandleForReading.close(); try? stderr.fileHandleForReading.close()
        guard group.wait(timeout: .now() + 2) == .success else {
            throw runnerError("runner_log_incomplete", "Native log pipes did not close; input delivery remains unknown.")
        }
    }
    if timedOut { throw HostCommandRunError.timeout(command: command, timeoutSeconds: command.defaultTimeoutSeconds, stdoutLogPath: stdoutPath, stderrLogPath: stderrPath) }
    guard out.failure == nil, err.failure == nil else { throw runnerError("runner_log_failed", "Native logs could not be persisted completely.") }
    let result = HostProcessResult(stdoutData: out.data, stderrData: err.data, exitCode: process.terminationStatus, sourceCommand: hostSourceCommand(command), stdoutTruncated: out.bytes > out.data.count, stderrTruncated: err.bytes > err.data.count, stdoutLogPath: stdoutPath, stderrLogPath: stderrPath, stdoutBytes: out.bytes, stderrBytes: err.bytes)
    try writeApplePlatformRunnerAudit(["stdoutBytes": out.bytes, "stderrBytes": err.bytes, "stdoutTruncated": result.stdoutTruncated, "stderrTruncated": result.stderrTruncated], to: logPrefix + ".log-metadata.json")
    if result.exitCode != 0 { throw HostCommandRunError.nonZeroExit(command: command, result: result) }
    return result
}
