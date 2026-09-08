import Foundation
import TritonKitShared

func observedXcodeDerivedDataCache(_ cache: TKXcodeDerivedDataCacheInfo, result: HostProcessResult) -> TKXcodeDerivedDataCacheInfo {
    TKXcodeDerivedDataCacheInfo(
        path: cache.path, exists: cache.exists, cacheState: cache.cacheState,
        incrementalExpected: false, cleanupPolicy: cache.cleanupPolicy, guidance: cache.guidance,
        reuseVerification: "unknown", observedBuild: observeXcodeBuild(result)
    )
}

/// Read artifacts incrementally: retained output can omit most of a large compilation.
/// A bounded scan never claims that unseen work did not happen.
func observeXcodeBuild(_ result: HostProcessResult, maximumBytesPerStream: Int = 128 * 1024 * 1024) -> TKXcodeBuildObservation {
    var scanner = XcodeBuildLogScanner()
    var sources = Set<String>()
    for (path, fallback, truncated, expectedBytes) in [
        (result.stdoutLogPath, result.stdoutData, result.stdoutTruncated, result.stdoutBytes),
        (result.stderrLogPath, result.stderrData, result.stderrTruncated, result.stderrBytes),
    ] {
        scanner.beginStream()
        if let path, let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) {
            sources.insert("raw-logs")
            defer { try? handle.close() }
            var readBytes = 0
            do {
                while readBytes < max(0, maximumBytesPerStream) {
                    let chunk = try handle.read(upToCount: min(64 * 1024, maximumBytesPerStream - readBytes)) ?? Data()
                    if chunk.isEmpty { break }
                    readBytes += chunk.count
                    scanner.consume(chunk)
                }
                if readBytes == max(0, maximumBytesPerStream), !(try handle.read(upToCount: 1) ?? Data()).isEmpty {
                    scanner.partial = true
                    scanner.discardPendingLine()
                }
                if readBytes < expectedBytes {
                    scanner.partial = true
                    scanner.discardPendingLine()
                }
            } catch {
                scanner.partial = true
                scanner.discardPendingLine()
            }
        } else {
            sources.insert("captured-output")
            let limit = max(0, maximumBytesPerStream)
            scanner.consume(Data(fallback.prefix(limit)))
            if truncated || fallback.count > limit || fallback.count < expectedBytes {
                scanner.partial = true
                if truncated || fallback.count > limit || fallback.count < expectedBytes { scanner.discardPendingLine() }
            }
        }
        scanner.endStream()
    }
    let compilation = ["CompileC", "CompileSwift", "SwiftCompile", "SwiftEmitModule"].reduce(0) { $0 + (scanner.tasks[$1] ?? 0) }
    let classification: String
    if compilation > 0 {
        classification = "compilation-observed"
    } else if !scanner.partial && scanner.succeeded && result.exitCode == 0 {
        classification = "no-compilation-observed"
    } else {
        classification = "unknown"
    }
    return TKXcodeBuildObservation(
        classification: classification,
        source: sources.contains("raw-logs") ? (sources.contains("captured-output") ? "raw-logs+captured-output" : "raw-logs") : "captured-output",
        logCoverage: scanner.partial ? "partial" : "complete",
        taskLogCounts: scanner.tasks,
        diagnosticCounts: scanner.diagnostics,
        stdoutLogPath: result.stdoutLogPath,
        stderrLogPath: result.stderrLogPath,
        note: "Counts are recognized Xcode task log headers, not unique executed tasks; Swift batch and per-file headers may overlap. No baseline or verified cache-hit evidence is available, so incremental reuse and broad/full rebuild classification remain unknown. Build-description presence does not prove a change."
    )
}

private struct XcodeBuildLogScanner {
    var tasks = Dictionary(uniqueKeysWithValues: ["CompileC", "CompileSwift", "SwiftCompile", "SwiftEmitModule", "Ld", "PhaseScriptExecution"].map { ($0, 0) })
    var diagnostics: [String: Int] = [:]
    var partial = false
    var succeeded = false
    private var line = Data()
    private var droppingLine = false
    private let maximumLineBytes = 16 * 1024

    mutating func beginStream() {
        line.removeAll(keepingCapacity: true)
        droppingLine = false
    }

    mutating func consume(_ data: Data) {
        for byte in data {
            if byte == 10 || byte == 13 {
                endStream()
            } else if !droppingLine {
                if line.count < maximumLineBytes {
                    line.append(byte)
                } else {
                    partial = true
                    discardPendingLine()
                }
            }
        }
    }

    mutating func discardPendingLine() {
        line.removeAll(keepingCapacity: true)
        droppingLine = true
    }

    mutating func endStream() {
        if !droppingLine && !line.isEmpty {
            if let text = String(data: line, encoding: .utf8) {
                observe(text)
            } else {
                partial = true
            }
        }
        line.removeAll(keepingCapacity: true)
        droppingLine = false
    }

    private mutating func observe(_ text: String) {
        // Only unindented task headers count; shell commands and diagnostic quotations do not.
        if let token = text.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false).first,
           tasks[String(token)] != nil {
            tasks[String(token), default: 0] += 1
            return
        }
        if ["** BUILD SUCCEEDED **", "** TEST SUCCEEDED **", "** ARCHIVE SUCCEEDED **"].contains(text) {
            succeeded = true
        }
        let lower = text.lowercased()
        let code: String?
        if text.hasPrefix("Build description signature:") {
            code = "build-description-signature"
        } else if text.hasPrefix("Build description path:") {
            code = "build-description-path"
        } else if lower.contains("database is locked") {
            code = "build-database-locked"
        } else if lower.contains("stale file") && lower.contains("outside of the allowed root") {
            code = "stale-derived-data-outside-root"
        } else if lower.contains("malformed") && lower.contains("build database") {
            code = "build-database-malformed"
        } else {
            code = nil
        }
        if let code { diagnostics[code, default: 0] += 1 }
    }
}
