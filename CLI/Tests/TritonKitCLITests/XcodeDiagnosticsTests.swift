import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct XcodeDiagnosticsTests {
    @Test("xcodebuild stale DerivedData outside-root output is parsed into actionable diagnostics")
    func parsesStaleDerivedDataOutsideRootDiagnostics() throws {
        let output = """
        warning: Stale file '/Users/old/repo/.triton/DerivedData/Build/Intermediates.noindex/App.build/Debug-iphonesimulator/App.build/Objects-normal/arm64/HomeView.o' is located outside of the allowed root paths.
        warning: Stale file '/Users/old/repo/.triton/DerivedData/Build/Products/Debug-iphonesimulator/App.app/App' is located outside of the allowed root paths.
        ** BUILD FAILED **
        """

        let diagnostic = try #require(XcodeBuildOutputDiagnosticsParser.parse(stdout: "", stderr: output))

        #expect(diagnostic.kind == "stale-derived-data-outside-root")
        #expect(diagnostic.matchCount == 2)
        #expect(diagnostic.samples.count == 2)
        #expect(diagnostic.samples[0].path == "/Users/old/repo/.triton/DerivedData/Build/Intermediates.noindex/App.build/Debug-iphonesimulator/App.build/Objects-normal/arm64/HomeView.o")
        #expect(diagnostic.samples[0].message.contains("allowed root paths"))
        #expect(diagnostic.recovery.contains("--derived-data-path"))
        #expect(diagnostic.recovery.contains(".triton/DerivedData"))
        #expect(diagnostic.nextAction.command == "xcode")
        #expect(diagnostic.nextAction.args == ["build", "--derived-data-path", "<fresh-derived-data-path>", "--jsonl"])
        #expect(diagnostic.nextAction.category == "recover")
    }

    @Test("xcodebuild stale DerivedData diagnostics are exposed on action summaries")
    func actionSummaryCarriesStaleDerivedDataDiagnostics() throws {
        let output = """
        Stale file '/tmp/old/.triton/DerivedData/Build/Products/Debug-iphonesimulator/App.app/App' is located outside of the allowed root paths.
        """
        let diagnostic = try #require(XcodeBuildOutputDiagnosticsParser.parse(stdout: output, stderr: ""))
        let summary = TKXcodeActionSummary(
            ok: false,
            action: "xcode.build",
            failureCode: "xcodebuild_failed",
            workspace: "App.xcworkspace",
            project: nil,
            scheme: "App",
            configuration: "Debug",
            sdk: "iphonesimulator",
            destination: "platform=iOS Simulator,id=SIM-1",
            derivedDataPath: ".triton/DerivedData",
            durationMs: 1200,
            sourceCommand: "xcodebuild -workspace App.xcworkspace -scheme App build",
            exitCode: 65,
            stdoutTruncated: false,
            stderrTruncated: false,
            xcodeDiagnostics: [diagnostic],
            note: "Build failed."
        )

        let decoded = try JSONDecoder().decode(TKXcodeActionSummary.self, from: JSONEncoder().encode(summary))

        #expect(decoded.ok == false)
        #expect(decoded.failureCode == "xcodebuild_failed")
        #expect(decoded.xcodeDiagnostics?.first?.kind == "stale-derived-data-outside-root")
        #expect(decoded.xcodeDiagnostics?.first?.nextAction.args.contains("<fresh-derived-data-path>") == true)
    }

    @Test("DerivedData cache state is derived from path existence")
    func derivedDataCacheStateUsesPathExistence() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-derived-data-cache-\(UUID().uuidString)", isDirectory: true)
        let warmPath = root.appendingPathComponent("DerivedData", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let empty = makeXcodeDerivedDataCacheInfo(path: warmPath.path)
        #expect(empty.path == warmPath.path)
        #expect(empty.exists == false)
        #expect(empty.cacheState == "empty")
        #expect(empty.incrementalExpected == false)
        #expect(empty.cleanupPolicy == "preserve-by-default")
        #expect(empty.guidance.contains("cleanup should not delete"))

        try FileManager.default.createDirectory(at: warmPath, withIntermediateDirectories: true)
        let warm = makeXcodeDerivedDataCacheInfo(path: warmPath.path)
        #expect(warm.exists)
        #expect(warm.cacheState == "warm")
        #expect(warm.incrementalExpected)
    }

    @Test("xcode action summary carries DerivedData cache guidance")
    func actionSummaryCarriesDerivedDataCacheGuidance() throws {
        let cache = TKXcodeDerivedDataCacheInfo(
            path: ".triton/DerivedData",
            exists: true,
            cacheState: "warm",
            incrementalExpected: true,
            cleanupPolicy: "preserve-by-default",
            guidance: "Keep .triton/DerivedData to preserve Xcode incremental build cache; cleanup should not delete it by default."
        )
        let summary = TKXcodeActionSummary(
            ok: true,
            action: "xcode.build",
            workspace: "App.xcworkspace",
            project: nil,
            scheme: "App",
            configuration: "Debug",
            sdk: "iphonesimulator",
            destination: "platform=iOS Simulator,id=SIM-1",
            derivedDataPath: ".triton/DerivedData",
            derivedDataCache: cache,
            durationMs: 1200,
            sourceCommand: "xcodebuild -workspace App.xcworkspace -scheme App build",
            exitCode: 0,
            stdoutTruncated: false,
            stderrTruncated: false,
            note: "Build finished."
        )

        let decoded = try JSONDecoder().decode(TKXcodeActionSummary.self, from: JSONEncoder().encode(summary))

        #expect(decoded.derivedDataCache?.path == ".triton/DerivedData")
        #expect(decoded.derivedDataCache?.cacheState == "warm")
        #expect(decoded.derivedDataCache?.incrementalExpected == true)
    }

    @Test("xcodebuild output diagnostics ignore generic build failures")
    func outputDiagnosticsIgnoreGenericBuildFailures() {
        let output = """
        CompileSwift normal arm64 HomeView.swift
        /repo/App/HomeView.swift:10:8: error: no such module 'Missing'
        ** BUILD FAILED **
        """

        #expect(XcodeBuildOutputDiagnosticsParser.parse(stdout: output, stderr: "") == nil)
    }

    @Test("xcode process parser extracts build metadata from ps output")
    func processParserExtractsMetadata() throws {
        let output = """
          123 /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild 01:02 xcodebuild -workspace App.xcworkspace -scheme App -destination platform=iOS\\ Simulator,id=SIM-1 -derivedDataPath .triton/DerivedData build
          124 /Applications/Xcode.app/Contents/SharedFrameworks/XCBBuildService.framework/XCBBuildService 00:10 /Applications/Xcode.app/Contents/SharedFrameworks/XCBBuildService.framework/XCBBuildService
          125 /usr/bin/grep 00:01 grep xcodebuild
        """

        let status = try XcodeProcessDiagnosticsParser.parse(psOutput: output)

        #expect(status.active)
        #expect(status.derivedDataCache.path == ".triton/DerivedData")
        #expect(status.derivedDataCache.cleanupPolicy == "preserve-by-default")
        #expect(status.processes.count == 2)
        #expect(status.summary.xcodebuildCount == 1)
        #expect(status.summary.buildServiceCount == 1)
        let build = try #require(status.processes.first { $0.name == "xcodebuild" })
        #expect(build.pid == 123)
        #expect(build.workspace == "App.xcworkspace")
        #expect(build.scheme == "App")
        #expect(build.destination == "platform=iOS Simulator,id=SIM-1")
        #expect(build.derivedDataPath == ".triton/DerivedData")
        #expect(build.elapsedSeconds == 62)
        #expect(build.confidence == "medium")
    }

    @Test("xcode status filters active processes by workspace")
    func statusFiltersByWorkspace() throws {
        let output = """
          111 /usr/bin/xcodebuild 00:30 xcodebuild -workspace Other.xcworkspace -scheme Other build
          222 /usr/bin/xcodebuild 00:45 xcodebuild -workspace App.xcworkspace -scheme App build
        """

        let status = try XcodeProcessDiagnosticsParser.parse(psOutput: output, workspace: "App.xcworkspace")

        #expect(status.active)
        #expect(status.processes.map(\.pid) == [222])
        #expect(status.summary.matchingWorkspaceCount == 1)
    }

    @Test("wait idle reports timeout while matching workspace remains active")
    func waitIdleTimesOutWhenWorkspaceRemainsActive() async throws {
        let active = XcodeProcessStatusOutput(
            ok: true,
            active: true,
            workspaceFilter: "App.xcworkspace",
            processes: [
                XcodeProcessSummary(
                    pid: 222,
                    name: "xcodebuild",
                    commandLine: "xcodebuild -workspace App.xcworkspace build",
                    elapsed: "00:45",
                    elapsedSeconds: 45,
                    workspace: "App.xcworkspace",
                    project: nil,
                    scheme: nil,
                    destination: nil,
                    derivedDataPath: nil,
                    confidence: "medium"
                )
            ],
            summary: XcodeProcessStatusSummary(
                xcodebuildCount: 1,
                buildServiceCount: 0,
                xctestCount: 0,
                matchingWorkspaceCount: 1
            ),
            sourceCommand: "ps -axo pid=,comm=,etime=,args="
        )

        await #expect(throws: XcodeDiagnosticsError.notIdle(status: active)) {
            try await waitForXcodeIdle(
                workspace: "App.xcworkspace",
                timeout: 0.02,
                interval: 0.01,
                statusProvider: { active }
            )
        }
    }
}
