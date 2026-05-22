import Foundation
import Testing
@testable import TritonKitCLI

@Suite
struct XcodeDiagnosticsTests {
    @Test("xcode process parser extracts build metadata from ps output")
    func processParserExtractsMetadata() throws {
        let output = """
          123 /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild 01:02 xcodebuild -workspace App.xcworkspace -scheme App -destination platform=iOS\\ Simulator,id=SIM-1 -derivedDataPath .triton/DerivedData build
          124 /Applications/Xcode.app/Contents/SharedFrameworks/XCBBuildService.framework/XCBBuildService 00:10 /Applications/Xcode.app/Contents/SharedFrameworks/XCBBuildService.framework/XCBBuildService
          125 /usr/bin/grep 00:01 grep xcodebuild
        """

        let status = try XcodeProcessDiagnosticsParser.parse(psOutput: output)

        #expect(status.active)
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
