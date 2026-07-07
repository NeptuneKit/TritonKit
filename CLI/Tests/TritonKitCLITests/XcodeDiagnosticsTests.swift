import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct XcodeDiagnosticsTests {
    @Test("derived data cache state reports warm and missing paths without cleanup")
    func derivedDataCacheStateReportsWarmAndMissingPaths() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-xcode-cache-state-\(UUID().uuidString)", isDirectory: true)
        let warm = root.appendingPathComponent("DerivedData", isDirectory: true)
        try FileManager.default.createDirectory(at: warm, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let warmState = xcodeDerivedDataCacheState(path: warm.path)
        #expect(warmState.derivedDataPath == warm.path)
        #expect(warmState.exists == true)
        #expect(warmState.cacheState == "warm")
        #expect(warmState.incrementalExpected == true)

        let missingState = xcodeDerivedDataCacheState(path: root.appendingPathComponent("Missing").path)
        #expect(missingState.exists == false)
        #expect(missingState.cacheState == "missing-derived-data")
        #expect(missingState.incrementalExpected == true)
    }

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
        #expect(diagnostic.nextAction.category == "project")
    }

    @Test("xcodebuild Swift macro malformed response output is parsed into actionable diagnostics")
    func parsesSwiftMacroMalformedResponseDiagnostics() throws {
        let output = """
        /repo/App/AppNavigator.swift:89:17: error: external macro implementation type 'NavigatorMacros.RoutePlaceholdMacro' could not be found for macro 'Route(_:redirect:)'; '/repo/.triton/DerivedData/Build/Products/Debug-iphonesimulator/NavigatorMacros' produced malformed response
        /repo/App/AppNavigator.swift:89:17: error: external macro implementation type 'NavigatorMacros.RouteMacro' could not be found for macro 'Route(_:redirect:)'; '/repo/.triton/DerivedData/Build/Products/Debug-iphonesimulator/NavigatorMacros' produced malformed response
        ** BUILD FAILED **
        """

        let diagnostic = try #require(XcodeBuildOutputDiagnosticsParser.parse(stdout: "", stderr: output))

        #expect(diagnostic.kind == "swift-macro-plugin-malformed-response")
        #expect(diagnostic.matchCount == 2)
        #expect(diagnostic.samples.count == 2)
        #expect(diagnostic.samples[0].path == "/repo/.triton/DerivedData/Build/Products/Debug-iphonesimulator/NavigatorMacros")
        #expect(diagnostic.samples[0].message.contains("NavigatorMacros.RoutePlaceholdMacro"))
        #expect(diagnostic.recovery.contains("Swift macro"))
        #expect(diagnostic.recovery.contains("repeating fresh DerivedData retries"))
        #expect(diagnostic.recovery.contains("macro plugin executable"))
        #expect(diagnostic.recovery.contains("triton xcode status --json"))
        #expect(diagnostic.nextAction.command == "xcode")
        #expect(diagnostic.nextAction.args == ["status", "--json"])
        #expect(diagnostic.nextAction.category == "project")
    }

    @Test("xcodebuild Swift macro malformed response maps to specialized failure code")
    func swiftMacroMalformedResponseMapsToSpecializedFailureCode() throws {
        let output = """
        /repo/App/AppNavigator.swift:89:17: error: external macro implementation type 'NavigatorMacros.RouteMacro' could not be found for macro 'Route(_:redirect:)'; '/repo/.triton/DerivedData/Build/Products/Debug-iphonesimulator/NavigatorMacros' produced malformed response
        """
        let diagnostic = try #require(XcodeBuildOutputDiagnosticsParser.parse(stdout: output, stderr: ""))

        #expect(xcodeBuildFailureCode(ok: false, diagnostics: [diagnostic]) == "swift_macro_plugin_malformed_response")
        #expect(xcodeBuildFailureCode(ok: false, diagnostics: nil) == "xcodebuild_failed")
        #expect(xcodeBuildFailureCode(ok: true, diagnostics: [diagnostic]) == nil)
    }

    @Test("xcodebuild interrupted output with active matching process maps to orphaned xcodebuild")
    func interruptedBuildWithActiveMatchingProcessMapsToOrphanedXcodebuild() throws {
        let result = HostProcessResult(
            stdoutData: Data("CompileSwift normal arm64 HomeView.swift\n".utf8),
            stderrData: Data("** BUILD INTERRUPTED **\n".utf8),
            exitCode: 15,
            sourceCommand: "xcodebuild -workspace App.xcworkspace -scheme App build",
            stdoutTruncated: false,
            stderrTruncated: false,
            stdoutLogPath: "/tmp/triton-xcode-artifacts/build/stdout.log",
            stderrLogPath: "/tmp/triton-xcode-artifacts/build/stderr.log",
            stdoutBytes: 40,
            stderrBytes: 24
        )
        let status = activeXcodeStatus(workspace: "App.xcworkspace")

        let postActionStatus = xcodePostActionProcessStatusIfInterrupted(
            ok: false,
            result: result,
            workspaceFilter: "App.xcworkspace",
            statusProvider: { filter in
                #expect(filter == "App.xcworkspace")
                return status
            }
        )
        let failureCode = xcodeBuildFailureCode(
            ok: false,
            diagnostics: nil,
            result: result,
            postActionProcessStatus: postActionStatus
        )
        let actions = xcodeBuildRecoveryActions(
            failureCode: failureCode,
            workspaceFilter: "App.xcworkspace"
        )

        #expect(failureCode == "orphaned_xcodebuild")
        #expect(postActionStatus?.active == true)
        #expect(postActionStatus?.processes.first?.pid == 222)
        #expect(postActionStatus?.processes.first?.scheme == "App")
        #expect(actions?.contains { $0.command == "xcode" && $0.args == ["status", "--json"] } == true)
        #expect(actions?.contains {
            $0.command == "xcode" &&
                $0.args == ["wait-idle", "--workspace", "App.xcworkspace", "--timeout", "120", "--json"]
        } == true)
    }

    @Test("xcodebuild interrupted output without active matching process maps to interrupted")
    func interruptedBuildWithoutActiveMatchingProcessMapsToInterrupted() throws {
        let result = HostProcessResult(
            stdoutData: Data(),
            stderrData: Data("** BUILD INTERRUPTED **\n".utf8),
            exitCode: 15,
            sourceCommand: "xcodebuild -workspace App.xcworkspace -scheme App build",
            stdoutTruncated: false,
            stderrTruncated: false,
            stdoutLogPath: nil,
            stderrLogPath: nil,
            stdoutBytes: 0,
            stderrBytes: 24
        )

        #expect(xcodeBuildFailureCode(ok: false, diagnostics: nil, result: result) == "xcodebuild_interrupted")
    }

    @Test("xcodebuild exit 15 with build failed marker remains generic xcodebuild failure")
    func exit15WithBuildFailedMarkerRemainsGenericFailure() throws {
        let result = HostProcessResult(
            stdoutData: Data("PhaseScriptExecution failed with exit code 15\n** BUILD FAILED **\n".utf8),
            stderrData: Data(),
            exitCode: 15,
            sourceCommand: "xcodebuild -workspace App.xcworkspace -scheme App build",
            stdoutTruncated: false,
            stderrTruncated: false,
            stdoutLogPath: nil,
            stderrLogPath: nil,
            stdoutBytes: 65,
            stderrBytes: 0
        )

        #expect(xcodeBuildFailureCode(ok: false, diagnostics: nil, result: result) == "xcodebuild_failed")
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

    @Test("xcode action summary carries orphaned process status and recovery actions")
    func actionSummaryCarriesOrphanedProcessStatusAndRecoveryActions() throws {
        let status = activeXcodeStatus(workspace: "App.xcworkspace").sharedPostActionStatus()
        let actions = try #require(xcodeBuildRecoveryActions(
            failureCode: "orphaned_xcodebuild",
            workspaceFilter: "App.xcworkspace"
        ))
        let summary = TKXcodeActionSummary(
            ok: false,
            action: "xcode.build",
            failureCode: "orphaned_xcodebuild",
            workspace: "App.xcworkspace",
            project: nil,
            scheme: "App",
            configuration: "Debug",
            sdk: nil,
            destination: "platform=iOS Simulator,id=SIM-1",
            derivedDataPath: ".triton/DerivedData",
            durationMs: 151442,
            sourceCommand: "xcodebuild -workspace App.xcworkspace -scheme App build",
            exitCode: 15,
            stdoutTruncated: false,
            stderrTruncated: false,
            stdoutLogPath: "/tmp/triton-xcode-artifacts/build/stdout.log",
            stderrLogPath: "/tmp/triton-xcode-artifacts/build/stderr.log",
            stdoutBytes: 73424,
            stderrBytes: 24,
            postActionProcessStatus: status,
            nextActions: actions,
            note: "xcodebuild was interrupted while matching processes are still active."
        )

        let decoded = try JSONDecoder().decode(TKXcodeActionSummary.self, from: JSONEncoder().encode(summary))

        #expect(decoded.failureCode == "orphaned_xcodebuild")
        #expect(decoded.postActionProcessStatus?.active == true)
        #expect(decoded.postActionProcessStatus?.processes.first?.pid == 222)
        #expect(decoded.nextActions?.first?.args == ["status", "--json"])
        #expect(decoded.nextActions?.last?.args == ["wait-idle", "--workspace", "App.xcworkspace", "--timeout", "120", "--json"])
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

    @Test("xcode status ignores unrelated SwiftPM swift-build provider processes")
    func statusIgnoresUnrelatedSwiftBuildProviderProcesses() throws {
        let output = """
          333 /usr/bin/swift-build 00:30 swift-build --package-path Tools/TritonMLXProvider -c release --product triton-mlx-provider
          444 /Applications/Xcode.app/Contents/SharedFrameworks/XCBBuildService.framework/XCBBuildService 00:10 /Applications/Xcode.app/Contents/SharedFrameworks/XCBBuildService.framework/XCBBuildService
        """

        let status = try XcodeProcessDiagnosticsParser.parse(psOutput: output)

        #expect(status.active)
        #expect(status.processes.map(\.pid) == [444])
        #expect(status.processes.allSatisfy { $0.name != "swift-build" })
        #expect(status.summary.xcodebuildCount == 0)
        #expect(status.summary.buildServiceCount == 1)
    }

    @Test("xcode status is idle when only unrelated swift-build is running")
    func statusIsIdleWhenOnlyUnrelatedSwiftBuildIsRunning() throws {
        let output = """
          333 /usr/bin/swift-build 00:30 swift-build --package-path Tools/TritonMLXProvider -c release --product triton-mlx-provider
        """

        let status = try XcodeProcessDiagnosticsParser.parse(psOutput: output)

        #expect(!status.active)
        #expect(status.processes.isEmpty)
        #expect(status.summary.xcodebuildCount == 0)
        #expect(status.summary.buildServiceCount == 0)
        #expect(status.summary.xctestCount == 0)
    }

    @Test("xcode status exposes latest stdout and stderr artifact log progress")
    func statusExposesLatestArtifactLogProgress() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("triton-xcode-status-logs-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let older = root.appendingPathComponent("1000-xcode-build-old", isDirectory: true)
        let latest = root.appendingPathComponent("2000-xcode-build-new", isDirectory: true)
        try FileManager.default.createDirectory(at: older, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: latest, withIntermediateDirectories: true)
        try Data("old\n".utf8).write(to: older.appendingPathComponent("stdout.log"))
        try Data("warning\n".utf8).write(to: latest.appendingPathComponent("stdout.log"))
        try Data("error text\n".utf8).write(to: latest.appendingPathComponent("stderr.log"))

        let logs = try #require(latestXcodeArtifactLogStatus(artifactsRoot: root))
        let status = try XcodeProcessDiagnosticsParser.parse(psOutput: "", latestLogs: logs)

        #expect(status.stdoutLogPath.map { URL(fileURLWithPath: $0).standardizedFileURL.path } == latest.appendingPathComponent("stdout.log").standardizedFileURL.path)
        #expect(status.stderrLogPath.map { URL(fileURLWithPath: $0).standardizedFileURL.path } == latest.appendingPathComponent("stderr.log").standardizedFileURL.path)
        #expect(status.stdoutBytes == 8)
        #expect(status.stderrBytes == 11)
        #expect(status.lastOutputAt != nil)
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

    @Test("wait idle treats process lookup timeout as transient while build remains active")
    func waitIdleTreatsProcessLookupTimeoutAsTransientWhileBuildRemainsActive() async throws {
        let pgrep = TKHostCommand(
            executable: "pgrep",
            arguments: ["-f", "xcodebuild|swift-build|SwiftBuildService|XCBBuildService|xctest"],
            defaultTimeoutSeconds: 5
        )
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
        var polls = 0

        await #expect(throws: XcodeDiagnosticsError.notIdle(status: active)) {
            try await waitForXcodeIdle(
                workspace: "App.xcworkspace",
                timeout: 0.3,
                interval: 0.01,
                statusProvider: {
                    polls += 1
                    if polls == 1 {
                        throw HostCommandRunError.timeout(command: pgrep, timeoutSeconds: 5, stdoutLogPath: nil, stderrLogPath: nil)
                    }
                    return active
                }
            )
        }
        #expect(polls >= 2)
    }

    private func activeXcodeStatus(workspace: String) -> XcodeProcessStatusOutput {
        XcodeProcessStatusOutput(
            ok: true,
            active: true,
            workspaceFilter: workspace,
            processes: [
                XcodeProcessSummary(
                    pid: 222,
                    name: "xcodebuild",
                    commandLine: "xcodebuild -workspace \(workspace) -scheme App -destination platform=iOS\\ Simulator,id=SIM-1 -derivedDataPath .triton/DerivedData build",
                    elapsed: "00:22",
                    elapsedSeconds: 22,
                    workspace: workspace,
                    project: nil,
                    scheme: "App",
                    destination: "platform=iOS Simulator,id=SIM-1",
                    derivedDataPath: ".triton/DerivedData",
                    confidence: "medium"
                )
            ],
            summary: XcodeProcessStatusSummary(
                xcodebuildCount: 1,
                buildServiceCount: 0,
                xctestCount: 0,
                matchingWorkspaceCount: 1
            ),
            sourceCommand: "ps -p 222 -o pid=,comm=,etime=,args="
        )
    }
}
