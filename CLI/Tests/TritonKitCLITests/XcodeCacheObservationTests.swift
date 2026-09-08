import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct XcodeCacheObservationTests {
    @Test("existing regular file is not DerivedData and reuse remains unknown")
    func regularFileIsNotDirectory() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data().write(to: path)
        defer { try? FileManager.default.removeItem(at: path) }
        let cache = makeXcodeDerivedDataCacheInfo(path: path.path)
        #expect(!cache.exists)
        #expect(cache.cacheState == "missing-derived-data")
        #expect(cache.reuseVerification == "unknown")
        #expect(!cache.incrementalExpected)
        #expect(!xcodeDerivedDataCacheState(path: path.path).exists)
    }

    @Test("task headers are counted without equating workload size with incremental reuse")
    func countsTaskHeaders() throws {
        let output = """
        CompileC /private/App/a.o /private/App/a.m normal arm64
            /Applications/Xcode.app/clang -c a.m
        SwiftCompile normal arm64 Compiling A.swift, B.swift
        SwiftCompile normal arm64 /private/App/A.swift
        SwiftDriver Compilation App normal arm64
        SwiftEmitModule normal arm64 Emitting module for App
        Ld /private/App/App normal arm64
        PhaseScriptExecution Generate /private/App/script.sh
        Build description signature: PRIVATE_SIGNATURE
        Build description path: /private/App/description
        error: accessing build database: database is locked
        warning: Stale file '/private/App/a.o' is located outside of the allowed root paths.
        ** BUILD SUCCEEDED **
        """
        let observed = observeXcodeBuild(cacheResult(output))
        #expect(observed.classification == "compilation-observed")
        #expect(observed.logCoverage == "complete")
        #expect(observed.taskLogCounts["CompileC"] == 1)
        #expect(observed.taskLogCounts["SwiftCompile"] == 2)
        #expect(observed.taskLogCounts["SwiftEmitModule"] == 1)
        #expect(observed.taskLogCounts["Ld"] == 1)
        #expect(observed.taskLogCounts["PhaseScriptExecution"] == 1)
        #expect(observed.diagnosticCounts["build-description-signature"] == 1)
        #expect(observed.diagnosticCounts["build-database-locked"] == 1)
        #expect(observed.diagnosticCounts["stale-derived-data-outside-root"] == 1)
        let json = String(decoding: try JSONEncoder().encode(observed), as: UTF8.self)
        #expect(!json.contains("PRIVATE_SIGNATURE"))
        #expect(!json.contains("/private/App"))
        #expect(observed.note.contains("not unique executed tasks"))
    }

    @Test("raw artifacts win over truncated inline capture, including final unterminated line")
    func rawArtifactsWin() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let full = String(repeating: "noise\n", count: 70_000) + String(repeating: "CompileC fixture\n", count: 178) + "SwiftCompile normal arm64 fixture"
        try Data(full.utf8).write(to: path)
        defer { try? FileManager.default.removeItem(at: path) }
        let observed = observeXcodeBuild(cacheResult("truncated", truncated: true, stdoutLogPath: path.path))
        #expect(observed.taskLogCounts["CompileC"] == 178)
        #expect(observed.taskLogCounts["SwiftCompile"] == 1)
        #expect(observed.logCoverage == "complete")
        #expect(observed.source == "raw-logs+captured-output")
    }

    @Test("missing artifact, bounded reads and oversized lines remain partial")
    func incompleteEvidence() throws {
        let missing = observeXcodeBuild(cacheResult("** BUILD SUCCEEDED **", truncated: true, stdoutLogPath: "/not-found/fixture"))
        #expect(missing.classification == "unknown")
        #expect(missing.logCoverage == "partial")
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data(("** BUILD SUCCEEDED **\n" + String(repeating: "x", count: 200) + "\nCompileC fixture\n").utf8).write(to: path)
        defer { try? FileManager.default.removeItem(at: path) }
        let limited = observeXcodeBuild(cacheResult("", stdoutLogPath: path.path), maximumBytesPerStream: 32)
        #expect(limited.classification == "unknown")
        #expect(limited.logCoverage == "partial")
        let longLine = observeXcodeBuild(cacheResult(String(repeating: "x", count: 20_000) + "\n** BUILD SUCCEEDED **"))
        #expect(longLine.classification == "unknown")
        #expect(longLine.logCoverage == "partial")
    }

    @Test("zero observed compilation requires complete successful build evidence")
    func noCompilationRequiresEvidence() {
        #expect(observeXcodeBuild(cacheResult("** BUILD SUCCEEDED **")).classification == "no-compilation-observed")
        #expect(observeXcodeBuild(cacheResult("")).classification == "unknown")
        #expect(observeXcodeBuild(cacheResult("** BUILD FAILED **", exitCode: 65)).classification == "unknown")
        #expect(observeXcodeBuild(cacheResult("** BUILD SUCCEEDED **", exitCode: 65)).classification == "unknown")
    }

    @Test("run success and failure preserve build observations and artifact provenance", arguments: [true, false])
    func runPreservesBuildObservation(buildSucceeds: Bool) throws {
        let simulator = "60667794-96F8-40E6-8664-85538EC4663E"
        let cache = makeXcodeDerivedDataCacheInfo(path: "/fixture/DerivedData")
        let observedCache = observedXcodeDerivedDataCache(cache, result: cacheResult("CompileC fixture", stdoutLogPath: "/fixture/build.log"))
        let invocation = ResolvedXcodeInvocation(
            workspace: "/fixture/App.xcworkspace", project: nil, package: nil, scheme: "App", configuration: "Debug",
            sdk: "iphonesimulator", destination: "platform=iOS Simulator,id=\(simulator)",
            derivedDataPath: cache.path, buildSettings: [], derivedDataCache: cache,
            simulatorUDID: simulator, device: nil
        )
        let result = try runXcodeBuildInstallLaunch(
            invocation: invocation, jsonl: false,
            simulatorBuild: { _, _, _ in
                TKXcodeActionSummary(
                    ok: buildSucceeds, action: "xcode.build", workspace: invocation.workspace, project: nil,
                    scheme: "App", configuration: "Debug", sdk: invocation.sdk, destination: invocation.destination,
                    derivedDataPath: cache.path, derivedDataCache: observedCache, durationMs: 1,
                    sourceCommand: "xcodebuild build", exitCode: buildSucceeds ? 0 : 65,
                    stdoutTruncated: false, stderrTruncated: false
                )
            },
            simulatorProduct: { _, _, _, _ in
                TKXcodeBuiltAppProduct(target: "App", appPath: "/fixture/App.app", bundleID: "com.example.fixture")
            },
            simulatorHostCommand: { _, _, _ in (cacheResult("launch"), 1) }
        )
        #expect(result.ok == buildSucceeds)
        #expect(result.derivedDataCache == observedCache)
        #expect(result.derivedDataCache?.observedBuild?.stdoutLogPath == "/fixture/build.log")
        let decoded = try JSONDecoder().decode(TKXcodeActionSummary.self, from: JSONEncoder().encode(result))
        #expect(decoded.derivedDataCache?.observedBuild?.taskLogCounts["CompileC"] == 1)
        #expect(decoded.derivedDataCache?.reuseVerification == "unknown")
    }

    @Test("cache DTO accepts historical JSON without observation fields")
    func legacyCacheDecode() throws {
        let data = Data(#"{"path":"DerivedData","exists":true,"cacheState":"warm","incrementalExpected":true,"cleanupPolicy":"preserve-by-default","guidance":"legacy"}"#.utf8)
        let decoded = try JSONDecoder().decode(TKXcodeDerivedDataCacheInfo.self, from: data)
        #expect(decoded.observedBuild == nil)
        #expect(decoded.reuseVerification == nil)
    }
}

private func cacheResult(_ stdout: String, truncated: Bool = false, stdoutLogPath: String? = nil, exitCode: Int32 = 0) -> HostProcessResult {
    HostProcessResult(stdoutData: Data(stdout.utf8), stderrData: Data(), exitCode: exitCode,
        sourceCommand: "xcodebuild build", stdoutTruncated: truncated, stderrTruncated: false,
        stdoutLogPath: stdoutLogPath, stderrLogPath: nil, stdoutBytes: stdout.utf8.count, stderrBytes: 0)
}
