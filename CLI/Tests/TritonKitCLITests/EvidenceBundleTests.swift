import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct EvidenceBundleTests {
    @Test("schema exposes explicit xcode summary evidence import option")
    func schemaExposesExplicitXcodeSummaryEvidenceImportOption() throws {
        let evidence = try #require(commandSchemas().first { $0.name == "evidence" })
        let capture = try #require(commandSchemas().first { $0.name == "capture" })

        #expect(evidence.options.map { $0.name }.contains("--xcode-summary"))
        #expect(capture.options.map { $0.name }.contains("--xcode-summary"))
        #expect(evidence.examples.contains { $0.contains("--xcode-summary") })
    }

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
        #expect(manifest.primaryArtifacts.map(\.kind) == [
            "host.defaults",
            "host.simulators",
            "xcode.status",
            "xcode.discovery",
            "xcode.defaults",
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
        #expect(summary.primaryArtifacts.map(\.kind) == manifest.primaryArtifacts.map(\.kind))
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

    @Test("evidence capture imports explicit xcode action summary without copying logs")
    func captureImportsExplicitXcodeActionSummaryWithoutCopyingLogs() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("evidence-xcode-summary-\(UUID().uuidString)", isDirectory: true)
        let summaryURL = FileManager.default.temporaryDirectory.appendingPathComponent("xcode-action-summary-\(UUID().uuidString).json")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: summaryURL)
        }

        let actionSummary = TKXcodeActionSummary(
            ok: false,
            action: "xcode.test",
            workspace: "App.xcworkspace",
            project: nil,
            scheme: "App",
            configuration: "Debug",
            sdk: "iphonesimulator",
            destination: "platform=iOS Simulator,id=SIM-1",
            derivedDataPath: ".triton/DerivedData",
            resultBundlePath: "/tmp/App.xcresult",
            simulatorUDID: "SIM-1",
            durationMs: 42,
            sourceCommand: "xcodebuild test -workspace App.xcworkspace",
            exitCode: 65,
            stdoutTruncated: false,
            stderrTruncated: false,
            stdoutLogPath: "/tmp/triton-xcode-artifacts/stdout.log",
            stderrLogPath: "/tmp/triton-xcode-artifacts/stderr.log",
            stdoutBytes: 123,
            stderrBytes: 456,
            note: "Test failed."
        )
        try prettyEncodedData(actionSummary).write(to: summaryURL, options: .atomic)

        let providers = EvidenceHostXcodeArtifactProviders(
            loadDefaults: { nil },
            simulatorList: { throw RuntimeError("not used") },
            xcodeStatus: { throw RuntimeError("not available") },
            xcodeDiscovery: { throw RuntimeError("not available") }
        )

        let manifest = try await captureEvidenceBundle(
            output: root.path,
            includes: ["xcode"],
            name: "xcode-summary-import",
            note: nil,
            target: "triton:local",
            host: "127.0.0.1",
            port: 1,
            refresh: false,
            xcodeSummaryPath: summaryURL.path,
            hostXcodeProviders: providers
        )

        let artifact = try #require(manifest.artifacts.first { $0.kind == "xcode.action-summary" })
        #expect(artifact.path == "artifacts/xcode/action-summary.json")
        #expect(artifact.riskLevel == "readonly")
        #expect(artifact.policy == "explicit-xcode-summary")
        #expect(artifact.redactionStatus == "sensitive")
        #expect(artifact.sourceCommand == "read --xcode-summary")
        #expect(manifest.artifacts.count == 1)
        #expect(manifest.primaryArtifacts.map(\.kind) == ["xcode.action-summary"])
        #expect(manifest.skipped.map { $0.kind } == ["xcode.defaults", "xcode.status", "xcode.discovery"])
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/xcode/action-summary.json").path))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/xcode/stdout.log").path))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/xcode/stderr.log").path))

        let importedData = try Data(contentsOf: root.appendingPathComponent("artifacts/xcode/action-summary.json"))
        let imported = try JSONDecoder().decode(TKXcodeActionSummary.self, from: importedData)
        #expect(imported.stdoutLogPath == "/tmp/triton-xcode-artifacts/stdout.log")
        #expect(try summarizeEvidenceBundle(input: root.path).sensitiveArtifactCount == 1)
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
            cli: TKEvidenceCLI(version: "test"),
            run: TKEvidenceRunManifest(
                eventsPath: "run/events.jsonl",
                metaPath: "run/meta.json",
                screenshotPaths: ["screenshot.png"],
                eventCount: 2,
                status: .completed,
                summary: TKEvidenceRunSummary(
                    runID: "run-1",
                    verdict: .success,
                    frictionCount: 0,
                    stepCount: 1
                )
            )
        )
        try prettyEncodedData(manifest).write(to: root.appendingPathComponent("manifest.json"), options: .atomic)

        let summary = try summarizeEvidenceBundle(input: root.path)

        #expect(summary.artifactCount == 2)
        #expect(summary.sensitiveArtifactCount == 1)
        #expect(summary.artifacts.map(\.kind) == ["status", "screenshot"])
        #expect(summary.primaryArtifacts.map(\.kind) == ["screenshot", "status"])
        #expect(summary.suggestedCommands.count == 1)

        let output = try redactEvidenceBundle(input: root.path, output: redacted.path, profile: "ios-private")

        #expect(output.redactedArtifactCount == 1)
        #expect(output.keptArtifactCount == 1)
        #expect(output.manifest.artifacts.map(\.kind) == ["status", "screenshot"])
        #expect(output.manifest.artifacts.first { $0.kind == "status" }?.redactionStatus == "included")
        #expect(output.manifest.artifacts.first { $0.kind == "screenshot" }?.redactionStatus == "redacted")
        #expect(output.manifest.artifacts.first { $0.kind == "screenshot" }?.sourceCommand == nil)
        #expect(output.manifest.artifacts.first { $0.kind == "screenshot" }?.path.hasPrefix("redacted/") == true)
        #expect(output.primaryArtifacts.map(\.kind) == ["screenshot", "status"])
        #expect(output.suggestedCommands.contains("triton evidence inspect '\(redacted.path)' --json"))
        #expect(output.manifest.run?.eventsPath == "run/events.jsonl")
        #expect(output.manifest.run?.metaPath == "run/meta.json")
        #expect(output.manifest.run?.summary?.verdict == .success)
        #expect(FileManager.default.fileExists(atPath: redacted.appendingPathComponent("manifest.json").path))
        #expect(FileManager.default.fileExists(atPath: redacted.appendingPathComponent("summary.json").path))
    }
}
