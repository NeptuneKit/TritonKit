import ArgumentParser
import Foundation
import TritonKitShared

enum XcodeProgressMode: String, CaseIterable, ExpressibleByArgument {
    case compact
    case full
}

let xcodeCompactDiagnosticsPerKindLimit = 20

func runXcodeHostCommand(
    _ command: TKHostCommand,
    event: String,
    jsonl: Bool,
    allowNonZeroExit: Bool = false,
    progress: XcodeProgressMode = .full,
    heartbeatInterval: TimeInterval = 10,
    maximumCompactDiagnosticsPerKind: Int = xcodeCompactDiagnosticsPerKindLimit
) throws -> (HostProcessResult, Int) {
    let startedAt = Date()
    let artifactPaths = try createXcodeArtifactPaths(event: event)
    let emitsLifecycleProgress = jsonl || progress == .compact
    if emitsLifecycleProgress {
        try writeXcodeProgressEvent(
            TKXcodeProgressEvent(
                event: "\(event).invocation",
                message: "started",
                sourceCommand: hostSourceCommand(command),
                elapsedMs: 0,
                stdoutLogPath: artifactPaths.stdout.path,
                stderrLogPath: artifactPaths.stderr.path,
                stdoutBytes: 0,
                stderrBytes: 0
            ),
            jsonl: jsonl
        )
    }
    let result = try runStreamingHostCommand(
        command,
        event: event,
        jsonl: jsonl,
        progress: progress,
        startedAt: startedAt,
        artifactPaths: artifactPaths,
        allowNonZeroExit: allowNonZeroExit,
        heartbeatInterval: heartbeatInterval,
        maximumCompactDiagnosticsPerKind: maximumCompactDiagnosticsPerKind
    )
    let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
    if emitsLifecycleProgress {
        try writeXcodeProgressEvent(
            TKXcodeProgressEvent(
                event: "\(event).summary",
                message: "finished",
                sourceCommand: result.sourceCommand,
                elapsedMs: durationMs,
                stdoutLogPath: result.stdoutLogPath,
                stderrLogPath: result.stderrLogPath,
                stdoutBytes: result.stdoutBytes,
                stderrBytes: result.stderrBytes
            ),
            jsonl: jsonl
        )
    }
    return (result, durationMs)
}

func writeJSONLLine(_ line: String) {
    FileHandle.standardOutput.write(Data((line + "\n").utf8))
}

private func writeXcodeProgressEvent(_ progress: TKXcodeProgressEvent, jsonl: Bool) throws {
    let line = try encodeCompactJSON(progress)
    if jsonl {
        writeJSONLLine(line)
    } else {
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }
}

struct XcodeArtifactPaths {
    let directory: URL
    let stdout: URL
    let stderr: URL
}

final class HostStreamAccumulator {
    private let maximumBytes: Int
    private let lock = NSLock()
    private var storage = Data()
    private var didTruncate = false
    private var total = 0

    init(maximumBytes: Int = 1_048_576) {
        self.maximumBytes = maximumBytes
    }

    func append(_ data: Data) {
        lock.lock()
        total += data.count
        if storage.count < maximumBytes {
            let remaining = maximumBytes - storage.count
            storage.append(data.prefix(remaining))
        }
        if total > maximumBytes {
            didTruncate = true
        }
        lock.unlock()
    }

    func snapshot() -> (data: Data, truncated: Bool, bytes: Int) {
        lock.lock()
        let value = (storage, didTruncate, total)
        lock.unlock()
        return value
    }
}

private enum XcodeCompactDiagnosticKind: String {
    case warning
    case error
}

private struct XcodeCompactDiagnostic {
    let stream: String
    let kind: XcodeCompactDiagnosticKind
    let line: String
}

private final class XcodeCompactDiagnosticCollector {
    private let maximumPerKind: Int
    private let maximumPendingCharacters = 4_000
    private let lock = NSLock()
    private var pending: [String: String] = [:]
    private var warningCount = 0
    private var errorCount = 0

    init(maximumPerKind: Int) {
        self.maximumPerKind = max(0, maximumPerKind)
    }

    func append(_ data: Data, stream: String) -> [XcodeCompactDiagnostic] {
        guard !data.isEmpty else { return [] }
        lock.lock()
        defer { lock.unlock() }

        var text = (pending[stream] ?? "") + String(decoding: data, as: UTF8.self)
        let terminatesLine = text.last?.isNewline == true
        var lines = text.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline }).map(String.init)
        if terminatesLine {
            pending[stream] = ""
            if lines.last?.isEmpty == true {
                lines.removeLast()
            }
        } else if let remainder = lines.popLast() {
            pending[stream] = String(remainder.suffix(maximumPendingCharacters))
        } else {
            pending[stream] = String(text.suffix(maximumPendingCharacters))
            lines = []
        }
        text.removeAll(keepingCapacity: false)
        return lines.compactMap { diagnostic(for: $0, stream: stream) }
    }

    func flush() -> [XcodeCompactDiagnostic] {
        lock.lock()
        defer { lock.unlock() }
        let diagnostics = pending.compactMap { stream, line in
            diagnostic(for: line, stream: stream)
        }
        pending.removeAll()
        return diagnostics
    }

    private func diagnostic(for line: String, stream: String) -> XcodeCompactDiagnostic? {
        let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        let lowercased = normalized.lowercased()
        let kind: XcodeCompactDiagnosticKind
        if lowercased.contains("error:") {
            guard errorCount < maximumPerKind else { return nil }
            errorCount += 1
            kind = .error
        } else if lowercased.contains("warning:") {
            guard warningCount < maximumPerKind else { return nil }
            warningCount += 1
            kind = .warning
        } else {
            return nil
        }
        return XcodeCompactDiagnostic(stream: stream, kind: kind, line: normalized)
    }
}

func createXcodeArtifactPaths(event: String) throws -> XcodeArtifactPaths {
    let safeEvent = event.unicodeScalars.map { scalar in
        CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : "-"
    }.joined()
    let directoryName = "\(Int(Date().timeIntervalSince1970 * 1000))-\(String(safeEvent))-\(UUID().uuidString)"
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("triton-xcode-artifacts", isDirectory: true)
        .appendingPathComponent(directoryName, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return XcodeArtifactPaths(
        directory: directory,
        stdout: directory.appendingPathComponent("stdout.log"),
        stderr: directory.appendingPathComponent("stderr.log")
    )
}

func runStreamingHostCommand(
    _ command: TKHostCommand,
    event: String,
    jsonl: Bool,
    progress: XcodeProgressMode,
    startedAt: Date,
    artifactPaths: XcodeArtifactPaths,
    allowNonZeroExit: Bool = false,
    heartbeatInterval: TimeInterval = 10,
    maximumCompactDiagnosticsPerKind: Int = xcodeCompactDiagnosticsPerKindLimit
) throws -> HostProcessResult {
    let timeoutSeconds = command.defaultTimeoutSeconds
    let process = Process()
    configureHostProcessExecutable(process, command: command)

    FileManager.default.createFile(atPath: artifactPaths.stdout.path, contents: nil)
    FileManager.default.createFile(atPath: artifactPaths.stderr.path, contents: nil)
    let stdoutLog = try FileHandle(forWritingTo: artifactPaths.stdout)
    let stderrLog = try FileHandle(forWritingTo: artifactPaths.stderr)
    defer {
        try? stdoutLog.close()
        try? stderrLog.close()
    }

    let stdout = Pipe()
    let stderr = Pipe()
    let stdoutAccumulator = HostStreamAccumulator()
    let stderrAccumulator = HostStreamAccumulator()
    let compactDiagnostics = XcodeCompactDiagnosticCollector(
        maximumPerKind: maximumCompactDiagnosticsPerKind
    )
    let printLock = NSLock()
    process.standardOutput = stdout
    process.standardError = stderr

    func emitProgress(_ progressEvent: TKXcodeProgressEvent) {
        printLock.lock()
        try? writeXcodeProgressEvent(progressEvent, jsonl: jsonl)
        printLock.unlock()
    }

    func emitCompactDiagnostics(_ diagnostics: [XcodeCompactDiagnostic]) {
        for diagnostic in diagnostics {
            emitProgress(TKXcodeProgressEvent(
                event: "\(event).\(diagnostic.kind.rawValue)",
                message: streamingSample(
                    stream: diagnostic.stream,
                    data: Data(diagnostic.line.utf8),
                    redacting: command
                ),
                sourceCommand: hostSourceCommand(command),
                elapsedMs: Int(Date().timeIntervalSince(startedAt) * 1000),
                stdoutLogPath: artifactPaths.stdout.path,
                stderrLogPath: artifactPaths.stderr.path,
                stdoutBytes: stdoutAccumulator.snapshot().bytes,
                stderrBytes: stderrAccumulator.snapshot().bytes
            ))
        }
    }

    func handleChunk(_ data: Data, stream: String, log: FileHandle, accumulator: HostStreamAccumulator) {
        guard !data.isEmpty else { return }
        log.write(data)
        accumulator.append(data)
        switch progress {
        case .compact:
            emitCompactDiagnostics(compactDiagnostics.append(data, stream: stream))
        case .full:
            emitProgress(TKXcodeProgressEvent(
                event: "\(event).\(stream)",
                message: streamingSample(stream: stream, data: data, redacting: command),
                sourceCommand: hostSourceCommand(command),
                elapsedMs: Int(Date().timeIntervalSince(startedAt) * 1000),
                stdoutLogPath: artifactPaths.stdout.path,
                stderrLogPath: artifactPaths.stderr.path,
                stdoutBytes: stdoutAccumulator.snapshot().bytes,
                stderrBytes: stderrAccumulator.snapshot().bytes
            ))
        }
    }

    stdout.fileHandleForReading.readabilityHandler = { handle in
        handleChunk(handle.availableData, stream: "stdout", log: stdoutLog, accumulator: stdoutAccumulator)
    }
    stderr.fileHandleForReading.readabilityHandler = { handle in
        handleChunk(handle.availableData, stream: "stderr", log: stderrLog, accumulator: stderrAccumulator)
    }

    let semaphore = DispatchSemaphore(value: 0)
    process.terminationHandler = { _ in
        semaphore.signal()
    }

    do {
        try process.run()
    } catch {
        throw HostCommandRunError.launchFailed(error.localizedDescription)
    }

    let deadline = Date().addingTimeInterval(timeoutSeconds)
    let heartbeatInterval = max(0.01, heartbeatInterval)
    var nextHeartbeat = Date().addingTimeInterval(heartbeatInterval)
    while true {
        let now = Date()
        if now >= deadline {
            process.terminate()
            _ = semaphore.wait(timeout: .now() + 2)
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            emitProgress(TKXcodeProgressEvent(
                event: "\(event).summary",
                message: "timeout after \(timeoutSeconds)s",
                sourceCommand: hostSourceCommand(command),
                elapsedMs: Int(Date().timeIntervalSince(startedAt) * 1000),
                stdoutLogPath: artifactPaths.stdout.path,
                stderrLogPath: artifactPaths.stderr.path,
                stdoutBytes: stdoutAccumulator.snapshot().bytes,
                stderrBytes: stderrAccumulator.snapshot().bytes
            ))
            throw HostCommandRunError.timeout(
                command: command,
                timeoutSeconds: timeoutSeconds,
                stdoutLogPath: artifactPaths.stdout.path,
                stderrLogPath: artifactPaths.stderr.path
            )
        }
        let waitSeconds = min(1.0, max(0.01, min(deadline.timeIntervalSince(now), nextHeartbeat.timeIntervalSince(now))))
        if semaphore.wait(timeout: .now() + waitSeconds) == .success {
            break
        }
        if Date() >= nextHeartbeat {
            emitProgress(TKXcodeProgressEvent(
                event: "\(event).heartbeat",
                message: "running",
                sourceCommand: hostSourceCommand(command),
                elapsedMs: Int(Date().timeIntervalSince(startedAt) * 1000),
                stdoutLogPath: artifactPaths.stdout.path,
                stderrLogPath: artifactPaths.stderr.path,
                stdoutBytes: stdoutAccumulator.snapshot().bytes,
                stderrBytes: stderrAccumulator.snapshot().bytes
            ))
            nextHeartbeat = Date().addingTimeInterval(heartbeatInterval)
        }
    }

    stdout.fileHandleForReading.readabilityHandler = nil
    stderr.fileHandleForReading.readabilityHandler = nil
    handleChunk(stdout.fileHandleForReading.availableData, stream: "stdout", log: stdoutLog, accumulator: stdoutAccumulator)
    handleChunk(stderr.fileHandleForReading.availableData, stream: "stderr", log: stderrLog, accumulator: stderrAccumulator)
    if progress == .compact {
        emitCompactDiagnostics(compactDiagnostics.flush())
    }

    let stdoutSnapshot = stdoutAccumulator.snapshot()
    let stderrSnapshot = stderrAccumulator.snapshot()
    let result = HostProcessResult(
        stdoutData: stdoutSnapshot.data,
        stderrData: stderrSnapshot.data,
        exitCode: process.terminationStatus,
        sourceCommand: hostSourceCommand(command),
        stdoutTruncated: stdoutSnapshot.truncated,
        stderrTruncated: stderrSnapshot.truncated,
        stdoutLogPath: artifactPaths.stdout.path,
        stderrLogPath: artifactPaths.stderr.path,
        stdoutBytes: stdoutSnapshot.bytes,
        stderrBytes: stderrSnapshot.bytes
    )
    if result.exitCode != 0, !allowNonZeroExit {
        throw HostCommandRunError.nonZeroExit(command: command, result: result)
    }
    return result
}

func streamingSample(
    stream: String,
    data: Data,
    maximumBytes: Int = 2_000,
    redacting command: TKHostCommand? = nil
) -> String {
    let prefix = data.prefix(maximumBytes)
    let text = String(data: prefix, encoding: .utf8) ?? "<\(data.count) bytes>"
    let suffix = data.count > maximumBytes ? " ...<truncated>" : ""
    let sample = "\(stream): \(text)\(suffix)"
    return command.map { redactedXcodePublicText(sample, command: $0) } ?? sample
}
