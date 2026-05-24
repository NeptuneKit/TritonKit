import Foundation
import Testing
@testable import TritonKitShared

@Suite
struct TKEvidenceModelsTests {
    @Test("evidence manifest carries artifacts, skipped reasons, target, and cli metadata")
    func manifestShape() throws {
        let manifest = TKEvidenceManifest(
            ok: true,
            name: "login-success",
            note: "DEBUG mock disabled",
            createdAt: "2026-05-20T00:00:00Z",
            output: "/tmp/login-success.tritonevidence",
            artifacts: [
                TKEvidenceArtifact(kind: "run.events", path: "run/events.jsonl", contentType: "application/x-ndjson"),
                TKEvidenceArtifact(kind: "run.meta", path: "run/meta.json", contentType: "application/json"),
                TKEvidenceArtifact(
                    kind: "screenshot",
                    path: "run/step-001.png",
                    contentType: "image/png",
                    bytes: 3,
                    freshness: TKEvidenceFreshness(
                        capturedAt: "2026-05-20T00:00:01Z",
                        source: "runtime",
                        hierarchyCacheState: "active",
                        targetConnectionState: "connected"
                    )
                ),
                TKEvidenceArtifact(kind: "status", path: "status.json", contentType: "application/json"),
                TKEvidenceArtifact(
                    kind: "harmony.layout",
                    path: "layout.json",
                    contentType: "application/json",
                    platform: "harmony",
                    riskLevel: "evidence",
                    policy: "automation",
                    redactionStatus: "summary",
                    sourceCommand: "hdc -t <target> shell uitest dumpLayout -p <path> -a",
                    target: "harmony:127.0.0.1:10100"
                ),
            ],
            skipped: [
                TKEvidenceSkippedArtifact(kind: "logs", reason: "unsupported"),
            ],
            target: TKEvidenceTarget(
                connected: true,
                appName: "dxyer",
                bundleIdentifier: "cn.dxy.iDxyer",
                identityState: "current",
                targetConnectionState: "connected",
                hierarchyCacheState: "active"
            ),
            cli: TKEvidenceCLI(version: "0.1.0-dev"),
            run: TKEvidenceRunManifest(
                eventsPath: "run/events.jsonl",
                metaPath: "run/meta.json",
                screenshotPaths: ["run/step-001.png"],
                debugArtifactPaths: ["run/debug/step-001-marked.png"],
                eventCount: 7,
                status: .completed,
                summary: TKEvidenceRunSummary(
                    runID: "run-1",
                    verdict: .success,
                    frictionCount: 1,
                    stepCount: 3
                )
            )
        )

        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(TKEvidenceManifest.self, from: data)

        #expect(decoded.formatVersion == 1)
        #expect(decoded.name == "login-success")
        #expect(decoded.artifacts.map(\.kind) == ["run.events", "run.meta", "screenshot", "status", "harmony.layout"])
        #expect(decoded.artifacts.first { $0.kind == "screenshot" }?.freshness?.source == "runtime")
        #expect(decoded.artifacts.last?.platform == "harmony")
        #expect(decoded.artifacts.last?.riskLevel == "evidence")
        #expect(decoded.artifacts.last?.policy == "automation")
        #expect(decoded.artifacts.last?.redactionStatus == "summary")
        #expect(decoded.artifacts.last?.sourceCommand?.hasPrefix("hdc -t") == true)
        #expect(decoded.artifacts.last?.target == "harmony:127.0.0.1:10100")
        #expect(decoded.run?.eventsPath == "run/events.jsonl")
        #expect(decoded.run?.metaPath == "run/meta.json")
        #expect(decoded.run?.screenshotPaths == ["run/step-001.png"])
        #expect(decoded.run?.debugArtifactPaths == ["run/debug/step-001-marked.png"])
        #expect(decoded.run?.summary?.verdict == .success)
        #expect(decoded.skipped.first?.kind == "logs")
        #expect(decoded.target?.bundleIdentifier == "cn.dxy.iDxyer")
        #expect(decoded.cli.schemaVersion == 1)
    }

    @Test("evidence manifest decodes older JSON without run metadata")
    func oldManifestWithoutRunMetadata() throws {
        let data = Data("""
        {
          "ok": true,
          "formatVersion": 1,
          "createdAt": "2026-05-20T00:00:00Z",
          "output": "/tmp/case.tritonevidence",
          "artifacts": [],
          "skipped": [],
          "cli": { "version": "0.1.0-dev", "schemaVersion": 1 }
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(TKEvidenceManifest.self, from: data)

        #expect(decoded.run == nil)
        #expect(decoded.artifacts.isEmpty)
    }
}
