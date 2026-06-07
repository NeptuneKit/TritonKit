import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct ObservationOutputTests {
    @Test("observe output prioritizes runtime tree as primary source")
    func observeOutputPrioritizesRuntimeTree() {
        let output = ObserveOutput(
            ok: true,
            action: "observe.current",
            platform: "ios",
            capturedAt: "2026-05-31T00:00:00Z",
            partial: true,
            target: "triton:ios-simulator:demo",
            sources: [
                ObserveSourceOutput(name: "host-layout", available: false, reason: "unsupported", artifact: nil, sourceCommands: []),
                ObserveSourceOutput(name: "runtime-tree", available: true, reason: nil, artifact: nil, sourceCommands: ["triton runtimeSnapshot request"]),
                ObserveSourceOutput(name: "webview-provider", available: false, reason: "provider not registered", artifact: nil, sourceCommands: []),
            ],
            nodes: [],
            artifacts: [],
            sourceCommands: ["triton runtimeSnapshot request"],
            note: "runtime-first"
        )

        #expect(output.primarySource?.name == "runtime-tree")
        #expect(output.primarySource?.available == true)
    }

    @Test("observe output falls back to host layout when runtime tree is unavailable")
    func observeOutputFallsBackToHostLayout() {
        let output = ObserveOutput(
            ok: true,
            action: "observe.current",
            platform: "harmony",
            capturedAt: "2026-05-31T00:00:00Z",
            partial: true,
            target: "harmony:127.0.0.1:10100",
            sources: [
                ObserveSourceOutput(name: "host-layout", available: true, reason: nil, artifact: "/tmp/layout.json", sourceCommands: ["hdc dumpLayout"]),
                ObserveSourceOutput(name: "runtime-tree", available: false, reason: "runtime-base-url not provided", artifact: nil, sourceCommands: []),
                ObserveSourceOutput(name: "webview-provider", available: false, reason: "provider not registered", artifact: nil, sourceCommands: []),
            ],
            nodes: [],
            artifacts: ["/tmp/layout.json"],
            sourceCommands: ["hdc dumpLayout"],
            note: "host-layout-only"
        )

        #expect(output.primarySource?.name == "host-layout")
        #expect(output.primarySource?.artifact == "/tmp/layout.json")
    }

    @Test("observe output preserves explicit primary source override")
    func observeOutputPreservesExplicitPrimarySource() {
        let primary = ObserveSourceOutput(
            name: "webview-provider",
            available: true,
            reason: nil,
            artifact: nil,
            sourceCommands: ["triton webview current --json"]
        )
        let output = ObserveOutput(
            ok: true,
            action: "observe.current",
            platform: "ios",
            capturedAt: "2026-05-31T00:00:00Z",
            partial: false,
            target: "triton:ios-simulator:demo",
            primarySource: primary,
            sources: [
                ObserveSourceOutput(name: "host-layout", available: false, reason: "unsupported", artifact: nil, sourceCommands: []),
                ObserveSourceOutput(name: "runtime-tree", available: true, reason: nil, artifact: nil, sourceCommands: ["triton runtimeSnapshot request"]),
                primary,
            ],
            nodes: [],
            artifacts: [],
            sourceCommands: ["triton runtimeSnapshot request"],
            note: "explicit"
        )

        #expect(output.primarySource?.name == "webview-provider")
        #expect(output.primarySource?.sourceCommands == ["triton webview current --json"])
    }

    @Test("android observe tree decodes UIAutomator XML into host layout nodes")
    func androidObserveTreeDecodesUIAutomatorXML() async throws {
        let target = HostDeviceTarget(
            platform: "android",
            id: "android:emulator-5554",
            target: "emulator-5554",
            state: "device",
            ready: true,
            source: "adb",
            name: "Pixel_8",
            runtime: "sdk_gphone64_arm64",
            transport: "1"
        )
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("android-observe-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let artifactPath = temp.appendingPathComponent("window.xml").path

        let output = try observeAndroid(
            action: "observe.tree",
            selected: target,
            output: artifactPath,
            runner: { command in
                let fixture = try TKAndroidADBFakeRunner(fixtures: [
                    .uiautomatorDump(serial: "emulator-5554", remotePath: "/sdcard/window_dump.xml"),
                    .readFileXML(serial: "emulator-5554", remotePath: "/sdcard/window_dump.xml")
                ]).run(command)
                return HostProcessResult(
                    stdoutData: fixture.stdout,
                    stderrData: fixture.stderr,
                    exitCode: fixture.exitCode,
                    sourceCommand: hostSourceCommand(command),
                    stdoutTruncated: false,
                    stderrTruncated: false,
                    stdoutLogPath: nil,
                    stderrLogPath: nil,
                    stdoutBytes: fixture.stdout.count,
                    stderrBytes: fixture.stderr.count
                )
            }
        )

        #expect(output.ok)
        #expect(output.platform == "android")
        #expect(output.primarySource?.name == "host-layout")
        #expect(output.sources.first?.artifact == artifactPath)
        #expect(output.artifacts == [artifactPath])
        #expect(output.nodes.count == 2)
        #expect(output.nodes[1].text == "Login")
        #expect(output.nodes[1].identifier == "com.example.demo:id/login")
        #expect(output.nodes[1].role == "android.widget.Button")
        #expect(output.nodes[1].capabilities.contains("tap"))
        #expect(FileManager.default.fileExists(atPath: artifactPath))
    }
}
