import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct EvidenceBundleTests {
    @Test("evidence capture writes host and xcode read-only artifacts without runtime")
    func captureWritesHostAndXcodeReadOnlyArtifactsWithoutRuntime() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("evidence-host-xcode-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(try parseEvidenceIncludes("host,xcode") == ["host", "xcode"])

        let providers = EvidenceHostXcodeArtifactProviders(
            loadDefaults: {
                TKHostWorkspaceDefaults(
                    defaultSimulatorUDID: "SIM-1",
                    xcode: TKXcodeWorkspaceDefaults(
                        workspace: "App.xcworkspace",
                        project: nil,
                        scheme: "App",
                        configuration: "Debug",
                        sdk: "iphonesimulator",
                        destination: "platform=iOS Simulator,id=SIM-1",
                        derivedDataPath: ".triton/DerivedData"
                    )
                )
            },
            simulatorList: {
                EvidenceArtifactPayload(
                    data: Data(#"{"devices":{}}"#.utf8),
                    sourceCommand: "xcrun simctl list devices available --json"
                )
            },
            xcodeStatus: {
                EvidenceArtifactPayload(
                    data: try prettyEncodedData(XcodeProcessStatusOutput(
                        ok: true,
                        active: false,
                        workspaceFilter: nil,
                        processes: [],
                        summary: XcodeProcessStatusSummary(
                            xcodebuildCount: 0,
                            buildServiceCount: 0,
                            xctestCount: 0,
                            matchingWorkspaceCount: 0
                        ),
                        sourceCommand: "pgrep -f xcodebuild"
                    )),
                    sourceCommand: "pgrep -f xcodebuild"
                )
            },
            xcodeDiscovery: {
                EvidenceArtifactPayload(
                    data: Data(#"{"ok":true,"workspaces":[],"projects":[],"packages":[]}"#.utf8),
                    sourceCommand: "triton xcode discover --path . --json"
                )
            }
        )

        let manifest = try await captureEvidenceBundle(
            output: root.path,
            includes: ["host", "xcode"],
            name: "host-xcode-contract",
            note: nil,
            target: "triton:local",
            host: "127.0.0.1",
            port: 1,
            refresh: false,
            hostXcodeProviders: providers
        )

        #expect(manifest.artifacts.map(\.kind) == [
            "host.defaults",
            "host.simulators",
            "xcode.defaults",
            "xcode.status",
            "xcode.discovery",
        ])
        #expect(manifest.artifacts.allSatisfy { !$0.path.hasPrefix("/") && !$0.path.contains("..") })
        #expect(manifest.artifacts.allSatisfy { $0.riskLevel == "readonly" })
        #expect(manifest.artifacts.allSatisfy { $0.policy == "read-only-small-artifact" })
        #expect(manifest.artifacts.allSatisfy { $0.redactionStatus == "sensitive" })
        #expect(manifest.skipped.isEmpty)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/host/defaults.json").path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/xcode/status.json").path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/xcode/discovery.json").path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("manifest.json").path))

        let summary = try summarizeEvidenceBundle(input: root.path)
        #expect(summary.sensitiveArtifactCount == 5)
    }

    @Test("evidence capture records skipped host and xcode sources when unavailable")
    func captureRecordsSkippedHostAndXcodeSourcesWhenUnavailable() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("evidence-host-xcode-skipped-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let providers = EvidenceHostXcodeArtifactProviders(
            loadDefaults: { nil },
            simulatorList: { throw RuntimeError("simulator list unavailable") },
            xcodeStatus: { throw RuntimeError("xcode status unavailable") },
            xcodeDiscovery: { throw RuntimeError("xcode discovery unavailable") }
        )

        let manifest = try await captureEvidenceBundle(
            output: root.path,
            includes: ["host", "xcode"],
            name: "host-xcode-skipped",
            note: nil,
            target: "triton:local",
            host: "127.0.0.1",
            port: 1,
            refresh: false,
            hostXcodeProviders: providers
        )

        #expect(manifest.artifacts.isEmpty)
        #expect(manifest.skipped.map(\.kind) == [
            "host.defaults",
            "host.simulators",
            "xcode.defaults",
            "xcode.status",
            "xcode.discovery",
        ])
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("manifest.json").path))
    }

    @Test("evidence summary and redact exclude sensitive artifacts")
    func summaryAndRedactExcludeSensitiveArtifacts() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("evidence-\(UUID().uuidString)", isDirectory: true)
        let redacted = FileManager.default.temporaryDirectory.appendingPathComponent("evidence-redacted-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: redacted)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data(#"{"ok":true}"#.utf8).write(to: root.appendingPathComponent("status.json"), options: .atomic)
        try Data("private screenshot".utf8).write(to: root.appendingPathComponent("screenshot.png"), options: .atomic)

        let manifest = TKEvidenceManifest(
            ok: true,
            name: "case",
            note: "note",
            createdAt: "2026-05-23T00:00:00Z",
            output: root.path,
            artifacts: [
                TKEvidenceArtifact(kind: "status", path: "status.json", contentType: "application/json", bytes: 11),
                TKEvidenceArtifact(
                    kind: "screenshot",
                    path: "screenshot.png",
                    contentType: "image/png",
                    bytes: 18,
                    sourceCommand: "xcrun simctl io /Users/private/App screenshot"
                ),
            ],
            target: TKEvidenceTarget(
                connected: true,
                appName: "App",
                bundleIdentifier: "com.example.app",
                deviceDescription: "sim",
                osDescription: "iOS",
                identityState: "debug"
            ),
            cli: TKEvidenceCLI(version: "test")
        )
        try prettyEncodedData(manifest).write(to: root.appendingPathComponent("manifest.json"), options: .atomic)

        let summary = try summarizeEvidenceBundle(input: root.path)

        #expect(summary.artifactCount == 2)
        #expect(summary.sensitiveArtifactCount == 1)
        #expect(summary.artifacts.map(\.kind) == ["status", "screenshot"])

        let output = try redactEvidenceBundle(input: root.path, output: redacted.path, profile: "ios-private")

        #expect(output.redactedArtifactCount == 1)
        #expect(output.keptArtifactCount == 1)
        #expect(output.manifest.artifacts.map(\.kind) == ["status", "screenshot"])
        #expect(output.manifest.artifacts.first { $0.kind == "status" }?.redactionStatus == "included")
        #expect(output.manifest.artifacts.first { $0.kind == "screenshot" }?.redactionStatus == "redacted")
        #expect(output.manifest.artifacts.first { $0.kind == "screenshot" }?.sourceCommand == nil)
        #expect(output.manifest.artifacts.first { $0.kind == "screenshot" }?.path.hasPrefix("redacted/") == true)
        #expect(FileManager.default.fileExists(atPath: redacted.appendingPathComponent("manifest.json").path))
        #expect(FileManager.default.fileExists(atPath: redacted.appendingPathComponent("summary.json").path))
    }
}
