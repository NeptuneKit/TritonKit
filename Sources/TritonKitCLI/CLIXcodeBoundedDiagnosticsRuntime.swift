import Foundation
import Darwin
import TritonKitShared

/// Scans only this process result's streams. Artifact reads are bounded and are
/// never interpreted as complete when bytes, lines, or provenance are missing.
func xcodeBoundedBuildOutputDiagnostics(
    _ result: HostProcessResult,
    redacting command: TKHostCommand? = nil,
    maximumBytesPerStream: Int = 64 * 1024 * 1024,
    artifactReadObserver: ((String) -> Void)? = nil
) -> [TKXcodeOutputDiagnostic]? {
    let limit = max(0, maximumBytesPerStream)
    let collector = XcodeDiagnosticLineCollector(command: command)
    var sources: [String] = []
    var unavailable: [String] = []
    var complete = true
    var scanned = 0
    let streams = [
        ("stdout", result.stdoutData, result.stdoutTruncated, result.stdoutLogPath, result.stdoutBytes),
        ("stderr", result.stderrData, result.stderrTruncated, result.stderrLogPath, result.stderrBytes),
    ]
    for (name, inline, truncated, path, observed) in streams {
        var streamBytes = 0
        var usedArtifact = false
        if truncated, let path {
            do {
                let originalPath = try XcodeDiagnosticFileIdentity(path: path)
                guard originalPath.size == observed else {
                    throw XcodeDiagnosticArtifactError.changed
                }
                // O_NOFOLLOW/O_NONBLOCK prevents an intervening symlink/FIFO
                // replacement from turning a regular log read into another source.
                let descriptor = path.withCString { Darwin.open($0, O_RDONLY | O_NOFOLLOW | O_NONBLOCK) }
                guard descriptor >= 0 else { throw XcodeDiagnosticArtifactError.changed }
                let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
                defer { try? handle.close() }
                let originalDescriptor = try XcodeDiagnosticFileIdentity(descriptor: descriptor)
                guard originalPath == originalDescriptor else { throw XcodeDiagnosticArtifactError.changed }
                usedArtifact = true
                sources.append("\(name):artifact")
                while streamBytes < min(limit, observed) {
                    let count = min(64 * 1024, min(limit, observed) - streamBytes)
                    guard let chunk = try handle.read(upToCount: count), !chunk.isEmpty else { break }
                    streamBytes += chunk.count
                    collector.append(chunk)
                    artifactReadObserver?(path)
                }
                guard try XcodeDiagnosticFileIdentity(descriptor: descriptor) == originalDescriptor,
                      try XcodeDiagnosticFileIdentity(path: path) == originalPath else {
                    throw XcodeDiagnosticArtifactError.changed
                }
            } catch {
                // Do not leak raw OS errors or artifact paths into diagnostic text.
                unavailable.append(name)
                complete = false
            }
        }
        if !usedArtifact {
            sources.append("\(name):inline")
            let data = inline.prefix(limit)
            streamBytes = data.count
            // Keep the same chunk boundary behavior for inline and disk input.
            var start = data.startIndex
            while start < data.endIndex {
                let end = min(start + 64 * 1024, data.endIndex)
                collector.append(Data(data[start..<end]))
                start = end
            }
            if truncated { complete = false }
        }
        if streamBytes != observed { complete = false }
        scanned += streamBytes
        collector.finishStream(incomplete: streamBytes != observed)
    }
    complete = complete && !collector.linesTruncated
    let coverage = TKXcodeDiagnosticCoverage(
        sources: sources, bytesScanned: scanned,
        observedBytes: result.stdoutBytes + result.stderrBytes,
        scanLimitBytesPerStream: limit, complete: complete,
        truncated: !complete || collector.samplesTruncated,
        linesTruncated: collector.linesTruncated,
        samplesTruncated: collector.samplesTruncated, unavailableStreams: unavailable
    )
    let diagnostics = collector.diagnostics(coverage: coverage)
    if !diagnostics.isEmpty { return diagnostics }
    guard result.exitCode != 0 else { return nil }
    return [TKXcodeOutputDiagnostic(
        kind: "diagnostics-unavailable",
        message: "No supported diagnostic was extracted from the observed build output. Inspect coverage before treating this as an absence of compiler errors.",
        matchCount: 0, samples: [],
        recovery: "Preserve the stdout/stderr artifacts and inspect their bounded diagnostic regions; unavailable or partial coverage does not identify the original failure cause.",
        nextAction: TKCLINextAction(command: "schema", args: ["--command", "xcode.build", "--json"], category: "project"),
        coverage: coverage
    )]
}

private enum XcodeDiagnosticArtifactError: Error { case changed }

private struct XcodeDiagnosticFileIdentity: Equatable {
    let device: dev_t
    let inode: ino_t
    let size: off_t
    let modifiedSeconds: Int
    let modifiedNanoseconds: Int
    let changedSeconds: Int
    let changedNanoseconds: Int

    init(path: String) throws {
        var info = stat()
        guard path.withCString({ lstat($0, &info) }) == 0 else { throw XcodeDiagnosticArtifactError.changed }
        try self.init(info)
    }

    init(descriptor: Int32) throws {
        var info = stat()
        guard fstat(descriptor, &info) == 0 else { throw XcodeDiagnosticArtifactError.changed }
        try self.init(info)
    }

    private init(_ info: stat) throws {
        guard info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else { throw XcodeDiagnosticArtifactError.changed }
        device = info.st_dev
        inode = info.st_ino
        size = info.st_size
        modifiedSeconds = Int(info.st_mtimespec.tv_sec)
        modifiedNanoseconds = Int(info.st_mtimespec.tv_nsec)
        changedSeconds = Int(info.st_ctimespec.tv_sec)
        changedNanoseconds = Int(info.st_ctimespec.tv_nsec)
    }
}

private final class XcodeDiagnosticLineCollector {
    private let command: TKHostCommand?
    private let sensitiveFragments: [String]
    private let lineLimit = 8_192
    private let sampleLimit = 5
    private var pending = Data()
    private var pendingTruncated = false
    private var prototypes: [String: TKXcodeOutputDiagnostic] = [:]
    private var samples: [String: [TKXcodeOutputDiagnosticSample]] = [:]
    private var counts: [String: Int] = [:]
    private(set) var linesTruncated = false
    private(set) var samplesTruncated = false

    init(command: TKHostCommand?) {
        self.command = command
        // Whole-argv redaction no longer suffices once input is split into lines.
        // Protect every nonempty fragment before any diagnostic sample is formed.
        sensitiveFragments = command.map { command in
            xcodeExecutionSensitiveValues(command: command).flatMap {
                $0.split(whereSeparator: \.isNewline).map(String.init)
            }
        } ?? []
    }

    func append(_ data: Data) {
        let parts = data.split(omittingEmptySubsequences: false, whereSeparator: { (10...13).contains($0) })
        for index in parts.indices {
            let part = parts[index]
            let remaining = lineLimit - pending.count
            pending.append(part.prefix(remaining))
            if part.count > remaining { linesTruncated = true; pendingTruncated = true }
            if index != parts.index(before: parts.endIndex) { finishStream() }
        }
    }

    func finishStream(incomplete: Bool = false) {
        guard !pending.isEmpty else { return }
        defer { pending.removeAll(keepingCapacity: true); pendingTruncated = false }
        let truncated = pendingTruncated || incomplete
        if truncated { linesTruncated = true }
        // Match the parser's Unicode-newline behavior as well as CR/LF streams.
        for logicalLine in String(decoding: pending, as: UTF8.self).split(whereSeparator: \.isNewline) {
            let line = String(logicalLine)
            // Avoid running specific parsers for routine compiler task lines.
            guard line.contains("fatal error:") || line.contains("external macro implementation type")
                    || line.contains("Stale file ") else { continue }
            collect(line, truncated: truncated)
        }
    }

    private func collect(_ line: String, truncated: Bool) {
        let redacted = command.map {
            redactedXcodePublicText(line, command: $0, additionalSensitiveValues: sensitiveFragments)
        } ?? line
        guard let diagnostic = XcodeBuildOutputDiagnosticsParser.parse(stdout: redacted, stderr: "", maximumSamples: 1) else { return }
        prototypes[diagnostic.kind] = diagnostic
        counts[diagnostic.kind, default: 0] += diagnostic.matchCount
        if samples[diagnostic.kind, default: []].count < sampleLimit {
            samples[diagnostic.kind, default: []].append(contentsOf: diagnostic.samples.map {
                // A clipped line may end inside a secret value, so exact-value
                // replacement alone cannot make its raw prefix safe to publish.
                truncated
                    ? TKXcodeOutputDiagnosticSample(path: "<truncated>", message: "Diagnostic line truncated; inspect the preserved raw artifact.")
                    : TKXcodeOutputDiagnosticSample(path: bounded($0.path), message: bounded($0.message))
            })
        } else { samplesTruncated = true }
    }

    private func bounded(_ value: String) -> String {
        if value.utf8.count > lineLimit { samplesTruncated = true }
        var bytes = Data(value.utf8.prefix(lineLimit))
        while String(data: bytes, encoding: .utf8) == nil { bytes.removeLast() }
        return String(decoding: bytes, as: UTF8.self)
    }

    func diagnostics(coverage: TKXcodeDiagnosticCoverage) -> [TKXcodeOutputDiagnostic] {
        ["swift-macro-plugin-malformed-response", "compiler-fatal-error", "stale-derived-data-outside-root"].compactMap { kind in
            guard let diagnostic = prototypes[kind] else { return nil }
            return TKXcodeOutputDiagnostic(kind: kind, message: diagnostic.message,
                matchCount: counts[kind, default: 0], samples: samples[kind, default: []],
                recovery: diagnostic.recovery, nextAction: diagnostic.nextAction, coverage: coverage)
        }
    }
}
