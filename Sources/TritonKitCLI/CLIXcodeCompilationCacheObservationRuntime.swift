import Darwin
import Foundation
import TritonKitShared

func observeXcodeCompilationCache(
    _ result: HostProcessResult, version: String, maximumBytesPerStream: Int = 64 * 1024 * 1024,
    artifactReadObserver: ((String) -> Void)? = nil
) -> TKXcodeCompilationCacheObservation {
    var counts: [String: TKXcodeCASReplayCounts] = [:]
    var complete = result.exitCode == 0
    var successMarker = false
    for (path, inline, truncated, observed) in [
        (result.stdoutLogPath, result.stdoutData, result.stdoutTruncated, result.stdoutBytes),
        (result.stderrLogPath, result.stderrData, result.stderrTruncated, result.stderrBytes),
    ] {
        let limit = max(0, maximumBytesPerStream)
        var scan = XcodeCASLogScanner()
        var bytes = 0
        if let path {
            do {
                let original = try XcodeDiagnosticFileIdentity(path: path)
                guard original.size == observed else { throw CASLogError.unavailable }
                let fd = path.withCString { Darwin.open($0, O_RDONLY | O_NOFOLLOW | O_NONBLOCK) }
                guard fd >= 0 else { throw CASLogError.unavailable }
                let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
                defer { try? handle.close() }
                guard try XcodeDiagnosticFileIdentity(descriptor: fd) == original else { throw CASLogError.unavailable }
                while bytes < min(limit, observed) {
                    let chunk = try handle.read(upToCount: min(64 * 1024, min(limit, observed) - bytes)) ?? Data()
                    guard !chunk.isEmpty else { break }
                    bytes += chunk.count
                    scan.append(chunk)
                    artifactReadObserver?(path)
                }
                guard try XcodeDiagnosticFileIdentity(descriptor: fd) == original,
                      try XcodeDiagnosticFileIdentity(path: path) == original else { throw CASLogError.unavailable }
            } catch {
                // Never let a replaced stream contribute counts. A bounded inline prefix is independent evidence.
                complete = false
                scan = XcodeCASLogScanner()
                bytes = min(inline.count, limit)
                scan.append(Data(inline.prefix(bytes)))
            }
        } else {
            bytes = min(inline.count, limit)
            scan.append(Data(inline.prefix(bytes)))
            if truncated { complete = false }
        }
        scan.finish(incomplete: bytes != observed || (path == nil && truncated))
        complete = complete && !scan.partial
        successMarker = successMarker || scan.succeeded
        for (task, count) in scan.counts {
            let previous = counts[task]
            counts[task] = TKXcodeCASReplayCounts(hits: (previous?.hits ?? 0) + count.hits, misses: (previous?.misses ?? 0) + count.misses)
        }
    }
    return TKXcodeCompilationCacheObservation(xcodeVersion: version, logCoverage: complete && successMarker ? "complete" : "partial", byTask: counts)
}

private enum CASLogError: Error { case unavailable }

private struct XcodeCASLogScanner {
    private static let key = #/(?i)^note: local cache (found|miss) for key: llvmcas://[0-9a-f]{64}( \(in target '[^\r\n]+' from project '[^\r\n]+'\))?$/#
    private static let replay = #/(?i)^note: replay cache (hit|miss)( \(in target '[^\r\n]+' from project '[^\r\n]+'\))?$/#
    private var line = Data()
    private var droppingLine = false
    private var task: String?
    private var scope: String?
    private var found = 0
    private var missed = 0
    private(set) var counts: [String: TKXcodeCASReplayCounts] = [:]
    private(set) var partial = false
    private(set) var succeeded = false

    mutating func append(_ data: Data) {
        let parts = data.split(omittingEmptySubsequences: false, whereSeparator: { $0 == 10 || $0 == 13 })
        for index in parts.indices {
            if !droppingLine {
                let part = parts[index]
                if part.count <= 128 * 1024 - line.count { line.append(part) }
                else { droppingLine = true; partial = true; task = nil; clearGroup() }
            }
            if index != parts.index(before: parts.endIndex) { completeLine() }
        }
    }

    mutating func finish(incomplete: Bool) {
        if incomplete { partial = true }
        else { completeLine() }
        clearGroup()
    }

    private mutating func completeLine() {
        defer { line.removeAll(keepingCapacity: true); droppingLine = false }
        guard !droppingLine, !line.isEmpty else { return }
        guard let text = String(data: line, encoding: .utf8) else { partial = true; task = nil; clearGroup(); return }
        guard let first = text.first, !first.isWhitespace else { return }
        if text == "** BUILD SUCCEEDED **" { succeeded = true }
        if let match = text.wholeMatch(of: Self.key) {
            guard task != nil else { partial = true; return }
            let scope = match.output.2.map(String.init)
            guard found + missed == 0 || scope == self.scope else { clearGroup(); task = nil; return }
            self.scope = scope
            if match.output.1.lowercased() == "found" { found += 1 } else { missed += 1 }
        } else if let match = text.wholeMatch(of: Self.replay) {
            let hit = match.output.1.lowercased() == "hit"
            guard let task, scope == match.output.2.map(String.init),
                  hit ? found > 0 && missed == 0 : missed > 0 else { partial = true; clearGroup(); return }
            let prior = counts[task]
            counts[task] = TKXcodeCASReplayCounts(hits: (prior?.hits ?? 0) + (hit ? 1 : 0), misses: (prior?.misses ?? 0) + (hit ? 0 : 1))
            found = 0; missed = 0; scope = nil
        } else if !text.hasPrefix("note:"), !text.hasPrefix("warning:"), !text.hasPrefix("error:") {
            clearGroup()
            let token = text.prefix { !$0.isWhitespace }
            switch token {
            case "SwiftCompile", "CompileSwift", "CompileC", "ClangCompile": task = "compile"
            case "SwiftEmitModule", "EmitSwiftModule": task = "emitModule"
            default: task = token.hasPrefix("SwiftExplicitDependency") ? "explicitDependency" : nil
            }
        }
    }

    private mutating func clearGroup() {
        if found + missed != 0 { partial = true }
        found = 0; missed = 0; scope = nil
    }
}
