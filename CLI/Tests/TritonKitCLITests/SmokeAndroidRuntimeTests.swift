import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct SmokeAndroidRuntimeTests {
    @Test("smoke android records host steps, tap, screenshot, and evidence")
    func recordsHostStepsTapScreenshotAndEvidence() async throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("android-smoke-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let screenshotPath = temp.appendingPathComponent("smoke.png").path
        let evidencePath = temp.appendingPathComponent("case.tritonevidence").path
        let target = HostDeviceTarget(platform: "android", id: "android-real:abc123", target: "android-real:abc123", state: "device", ready: true, source: "adb", name: "Pixel_8", runtime: "sdk_gphone64_arm64", transport: "usb", scope: "real", kind: "real-device", sensitive: true, rawTarget: "R58M123456")
        let dependencies = AndroidSmokeDependencies(
            waitReady: { selected, _, _, _ in
                HostDeviceReadyEvent(ok: true, platform: "android", target: selected, ready: true, attempt: 1, sourceCommand: "adb -s \(selected.rawTarget) getprop", error: nil)
            },
            appLaunch: { selected, package, _, _ in
                HostActionOutput(ok: true, action: "app.launch", runtimeScope: "host-android", target: "android:\(selected.target)/app:\(package)", tool: "adb", exitCode: 0, riskLevel: "automation", sourceCommand: "adb shell monkey", stdoutTruncated: false, stderrTruncated: false, stdout: nil, stderr: nil, artifacts: [], note: "ok")
            },
            appOpenURL: { selected, package, _, _, _ in
                HostActionOutput(ok: true, action: "app.open-url", runtimeScope: "host-android", target: "\(selected.id)/app:\(package)", tool: "adb", exitCode: 0, riskLevel: "automation", sourceCommand: "adb -s \(selected.rawTarget) shell am start", stdoutTruncated: false, stderrTruncated: false, stdout: nil, stderr: nil, artifacts: [], note: "ok")
            },
            waitText: { selected, _, text, _, _ in
                HostAndroidWaitOutput(ok: true, action: "wait", platform: "android", target: selected, condition: "text", query: text, matched: true, timedOut: false, elapsedMs: 1, pollCount: 1, match: HostAndroidTapMatch(text: text, identifier: "com.example:id/ready", label: nil, role: "android.widget.TextView", bounds: TKRect(x: 10, y: 20, width: 30, height: 40)), sourceCommands: ["adb -s \(selected.rawTarget) uiautomator dump"])
            },
            tapText: { selected, _, text in
                HostAndroidTapOutput(ok: true, action: "tap", platform: "android", target: selected, query: text, x: 25, y: 40, match: HostAndroidTapMatch(text: text, identifier: "com.example:id/next", label: nil, role: "android.widget.Button", bounds: TKRect(x: 10, y: 20, width: 30, height: 40)), sourceCommands: ["adb -s \(selected.rawTarget) input tap 25 40"], note: "tap submitted")
            },
            captureLayout: { selected, _, output in
                let url = URL(fileURLWithPath: output)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(#"<?xml version="1.0"?><hierarchy />"#.utf8).write(to: url, options: .atomic)
                return HostAndroidArtifactOutput(ok: true, action: "ax", platform: "android", target: selected, artifact: output, sourceCommands: ["adb -s \(selected.rawTarget) uiautomator dump"], note: "layout captured")
            },
            captureScreenshot: { selected, _, output in
                let url = URL(fileURLWithPath: output)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data("png".utf8).write(to: url, options: .atomic)
                return HostAndroidArtifactOutput(ok: true, action: "screenshot", platform: "android", target: selected, artifact: output, sourceCommands: ["adb -s \(selected.rawTarget) screencap"], note: "screenshot captured")
            },
            captureEvidence: { output, target, artifacts, sourceCommands, name, note in
                try captureAndroidEvidenceBundle(output: output, target: target, artifacts: artifacts, sourceCommands: sourceCommands, name: name, note: note)
            }
        )

        let summary = try await runAndroidSmoke(
            options: AndroidSmokeOptions(
                target: target,
                adb: "adb",
                package: "com.example.app",
                activity: ".MainActivity",
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
            "app.open-url",
            "android.wait",
            "android.tap",
            "android.post-tap-wait",
            "android.layout",
            "android.screenshot",
            "evidence.capture",
        ])
        #expect(summary.assertions.map(\.query) == ["Ready", "Done"])
        #expect(summary.steps.first { $0.name == "app.open-url" }?.proofSource == .hostAction)
        #expect(summary.steps.first { $0.name == "app.open-url" }?.businessReady == false)
        #expect(summary.steps.first { $0.name == "android.wait" }?.proofSource == .hostLayout)
        #expect(summary.steps.first { $0.name == "android.wait" }?.businessReady == true)
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
        #expect(!emittedCommands.contains("R58M123456"))
        #expect(emittedCommands.contains("android-real:abc123"))
        #expect(FileManager.default.fileExists(atPath: evidencePath + "/manifest.json"))
    }
}
