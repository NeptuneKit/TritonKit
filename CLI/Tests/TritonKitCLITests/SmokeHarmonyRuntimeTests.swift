import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct SmokeHarmonyRuntimeTests {
    @Test("smoke harmony records host steps, tap, screenshot, and evidence")
    func recordsHostStepsTapScreenshotAndEvidence() async throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("harmony-smoke-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let screenshotPath = temp.appendingPathComponent("smoke.jpeg").path
        let evidencePath = temp.appendingPathComponent("case.tritonevidence").path
        let target = TKHarmonyTarget(target: "HDCREAL001", state: "Connected", transport: "USB")
        let dependencies = HarmonySmokeDependencies(
            resolveTarget: { _, _ in target },
            waitReady: { selected, _, _, _ in
                HostDeviceReadyEvent(
                    ok: true,
                    platform: "harmony",
                    target: hostDeviceTarget(from: selected),
                    ready: true,
                    attempt: 1,
                    sourceCommand: "hdc -t \(selected.target) boot-ready",
                    error: nil
                )
            },
            appInspect: { selected, bundle, _ in
                fakeHarmonyAction(action: "app.inspect", target: "\(selected.id)/app:\(bundle)", source: "hdc -t \(selected.target) bm dump")
            },
            appLaunch: { selected, bundle, _, _ in
                fakeHarmonyAction(action: "app.launch", target: "harmony:\(selected.target)/app:\(bundle)", source: "hdc aa start")
            },
            appOpenURL: { selected, bundle, _, _, _ in
                fakeHarmonyAction(action: "app.open-url", target: "\(selected.id)/app:\(bundle)", source: "hdc -t \(selected.target) aa start -U")
            },
            waitText: { selected, _, text, _, _ in
                HostHarmonyWaitOutput(
                    ok: true,
                    action: "wait",
                    platform: "harmony",
                    target: selected,
                    condition: "text",
                    query: text,
                    matched: true,
                    timedOut: false,
                    elapsedMs: 1,
                    pollCount: 1,
                    match: TKHarmonyLayoutTextMatch(text: text, bounds: TKRect(x: 10, y: 20, width: 30, height: 40)),
                    sourceCommands: ["hdc -t \(selected.target) dumpLayout \(text)"]
                )
            },
            tapText: { selected, _, text in
                HostHarmonyTapOutput(
                    ok: true,
                    action: "tap",
                    platform: "harmony",
                    target: selected,
                    query: text,
                    x: 25,
                    y: 40,
                    match: TKHarmonyLayoutTextMatch(text: text, bounds: TKRect(x: 10, y: 20, width: 30, height: 40)),
                    sourceCommands: ["hdc -t \(selected.target) uiInput click 25 40"],
                    note: "tap submitted"
                )
            },
            captureLayout: { selected, _, output in
                let url = URL(fileURLWithPath: output)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(#"{"attributes":{"text":"Ready"}}"#.utf8).write(to: url, options: .atomic)
                return HostHarmonyArtifactOutput(
                    ok: true,
                    action: "ax",
                    platform: "harmony",
                    target: selected,
                    artifact: output,
                    sourceCommands: ["hdc -t \(selected.target) dumpLayout recv"],
                    note: "layout captured"
                )
            },
            captureScreenshot: { selected, _, output in
                let url = URL(fileURLWithPath: output)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data("jpeg".utf8).write(to: url, options: .atomic)
                return HostHarmonyArtifactOutput(
                    ok: true,
                    action: "screenshot",
                    platform: "harmony",
                    target: selected,
                    artifact: output,
                    sourceCommands: ["hdc -t \(selected.target) snapshot_display"],
                    note: "screenshot captured"
                )
            },
            captureEvidence: { output, target, artifacts, sourceCommands, name, note in
                try captureHarmonyEvidenceBundle(
                    output: output,
                    target: target,
                    artifacts: artifacts,
                    sourceCommands: sourceCommands,
                    name: name,
                    note: note
                )
            }
        )

        let summary = try await runHarmonySmoke(
            options: HarmonySmokeOptions(
                target: "HDCREAL001",
                hdc: "hdc",
                bundle: "com.example.app",
                ability: "EntryAbility",
                openURL: "example://home",
                waitText: "Ready",
                tapText: "Next",
                postTapWaitText: "Done",
                screenshot: screenshotPath,
                evidence: evidencePath,
                evidenceName: "case",
                evidenceNote: "note",
                timeout: 1,
                interval: 0.01
            ),
            dependencies: dependencies
        )

        #expect(summary.ok)
        #expect(summary.status == .pass)
        #expect(summary.steps.map(\.name) == [
            "device.wait-ready",
            "app.inspect",
            "app.open-url",
            "harmony.wait",
            "harmony.tap",
            "harmony.post-tap-wait",
            "harmony.layout",
            "harmony.screenshot",
            "evidence.capture",
        ])
        #expect(summary.assertions.map(\.query) == ["Ready", "Done"])
        #expect(summary.steps.first { $0.name == "app.open-url" }?.proofSource == .hostAction)
        #expect(summary.steps.first { $0.name == "app.open-url" }?.businessReady == false)
        #expect(summary.steps.first { $0.name == "harmony.wait" }?.proofSource == .hostLayout)
        #expect(summary.steps.first { $0.name == "harmony.wait" }?.businessReady == true)
        #expect(summary.assertions.allSatisfy { $0.proofSource == .hostLayout })
        #expect(summary.evidence?.artifacts.map(\.kind).contains("real-device.diagnostics") == true)
        #expect(summary.evidence?.artifacts.map(\.kind).contains("host.app-action") == true)
        #expect(summary.evidence?.artifacts.map(\.kind).contains("host.layout") == true)
        #expect(summary.evidence?.artifacts.map(\.kind).contains("screenshot") == true)
        let primaryKinds = summary.evidence?.primaryArtifacts.map(\.kind) ?? []
        #expect(Array(primaryKinds.prefix(4)) == [
            "real-device.diagnostics",
            "host.app-action",
            "host.layout",
            "screenshot",
        ])
        #expect(summary.evidence?.skipped.map(\.kind) == ["runtime.snapshot", "logs"])
        let emittedCommands = summary.steps.flatMap(\.sourceCommand).joined(separator: "\n")
        #expect(!emittedCommands.contains("HDCREAL001"))
        #expect(emittedCommands.contains(target.id))
        #expect(FileManager.default.fileExists(atPath: evidencePath + "/manifest.json"))
    }
}

private func fakeHarmonyAction(action: String, target: String, source: String) -> HostActionOutput {
    HostActionOutput(
        ok: true,
        action: action,
        runtimeScope: "host-harmony",
        target: target,
        tool: "hdc",
        exitCode: 0,
        riskLevel: "automation",
        sourceCommand: source,
        stdoutTruncated: false,
        stderrTruncated: false,
        stdout: nil,
        stderr: nil,
        artifacts: [],
        note: "ok"
    )
}
