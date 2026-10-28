import Darwin
import Foundation
import TritonKitShared

private struct PartialLogDrain {
    var observed = 0
    var retained = 0
    var error: Error?
}

/// The sim.logs opt-in path owns a private, exclusive artifact before starting
/// the child. Every accepted stdout chunk is written immediately; no full log
/// accumulates in memory and failures never delete this owned evidence.
func runHostPartialLogCapture(
    _ command: TKHostCommand,
    outputPath: String,
    maximumBytes: Int
) throws -> HostProcessResult {
    guard maximumBytes > 0 else {
        throw HostArtifactOutputError.rejected(path: outputPath, reason: "maximum bytes must be positive")
    }
    try prepareHostArtifactOutputPath(outputPath)
    let fd = open(outputPath, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR)
    guard fd >= 0 else {
        throw HostArtifactOutputError.rejected(path: outputPath, reason: "exclusive private artifact creation failed")
    }
    let output = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    defer { try? output.close() }
    let process = Process()
    configureHostProcessExecutable(process, command: command)
    let stdout = Pipe(), stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr
    process.standardInput = FileHandle.nullDevice
    let finished = DispatchSemaphore(value: 0)
    process.terminationHandler = { _ in finished.signal() }
    let started = DispatchTime.now().uptimeNanoseconds
    do { try process.run() }
    catch {
        // No child started and no captured bytes exist. Do not claim a partial
        // capture; the empty owned file remains available for inspection.
        throw HostCommandRunError.launchFailed("Simulator log process could not be started; an empty private artifact may remain at the requested output path.")
    }

    let deadline = HostPipeDrainDeadline()
    let queue = DispatchQueue(label: "triton.sim-logs.drain", attributes: .concurrent)
    let stdoutDrain = HostPipeDrainTask(queue: queue) {
        var state = PartialLogDrain()
        do {
            try drainHostPipe(stdout, deadline: deadline) { chunk in
                state.observed += chunk.count
                let kept = chunk.prefix(max(0, maximumBytes - state.retained))
                try output.write(contentsOf: kept)
                state.retained += kept.count
            }
        } catch { state.error = error }
        return state
    }
    let stderrDrain = HostPipeDrainTask(queue: queue) {
        var state = PartialLogDrain()
        do {
            // Keep only counts: native stderr can contain private log lines.
            try drainHostPipe(stderr, deadline: deadline) { state.observed += $0.count }
        } catch { state.error = error }
        return state
    }
    let timedOut = finished.wait(timeout: .now() + command.defaultTimeoutSeconds) == .timedOut
    if timedOut {
        if process.isRunning { process.terminate() }
        if finished.wait(timeout: .now() + 2) == .timedOut {
            if process.isRunning { _ = kill(process.processIdentifier, SIGKILL) }
            _ = finished.wait(timeout: .now() + 2)
        }
    }
    deadline.finish()
    let out = stdoutDrain.wait(), err = stderrDrain.wait()
    var info = stat()
    let retainedBytes = fstat(fd, &info) == 0 ? max(0, Int(info.st_size)) : out.retained
    var closeFailed = false
    do { try output.close() } catch { closeFailed = true }
    let truncated = out.observed > retainedBytes
    let result = HostProcessResult(
        stdoutData: Data(), stderrData: Data(), exitCode: process.terminationStatus,
        sourceCommand: hostSourceCommand(command), stdoutTruncated: truncated,
        stderrTruncated: err.observed > 0, stdoutLogPath: outputPath,
        stderrLogPath: nil, stdoutBytes: out.observed, stderrBytes: err.observed
    )
    let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000_000
    let termination = process.terminationReason == .uncaughtSignal ? "uncaught-signal" : "exit"
    let drainError = out.error ?? err.error
    if timedOut || drainError != nil || closeFailed || result.exitCode != 0 || truncated {
        let code: String
        let reason: String
        let message: String
        if timedOut {
            code = "host_command_timeout"; reason = "timeout"
            message = "Simulator log capture exceeded its execution timeout."
        } else if result.exitCode != 0 {
            code = "sim_logs_failed"; reason = "process-failure"
            message = "Native simulator log stream failed; partial evidence was retained."
        } else if let error = drainError as? HostProcessOutputError {
            code = error.code; reason = "output-failure"
            message = "Simulator log output was incomplete or unreadable."
        } else if drainError != nil || closeFailed {
            code = "sim_logs_failed"; reason = "artifact-write-failure"
            message = "Simulator log artifact could not be fully written."
        } else {
            code = "sim_logs_failed"; reason = "byte-limit"
            message = "Simulator log capture exceeded the artifact byte limit; only the bounded prefix was retained."
        }
        throw HostArtifactCaptureFailure(
            command: command, result: result, outputPath: outputPath,
            artifactBytes: retainedBytes, artifactTruncated: truncated,
            failureCode: code, failureMessage: message,
            captureEndedBy: reason, terminationReason: termination,
            elapsedDurationSeconds: elapsed, maximumBytes: maximumBytes
        )
    }
    return result
}
