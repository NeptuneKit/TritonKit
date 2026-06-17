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
                TKEvidenceArtifact(kind: "harmony.webview-snapshot", path: "harmony/webview-snapshot.json", contentType: "application/json", platform: "harmony", riskLevel: "evidence"),
                TKEvidenceArtifact(kind: "harmony.route-warning", path: "harmony/route-warning.json", contentType: "application/json", platform: "harmony", riskLevel: "evidence"),
                TKEvidenceArtifact(kind: "harmony.hdc-recovery-plan", path: "harmony/hdc-recovery-plan.json", contentType: "application/json", platform: "harmony", riskLevel: "readonly"),
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
        #expect(decoded.artifacts.map(\.kind) == ["run.events", "run.meta", "screenshot", "status", "harmony.layout", "harmony.webview-snapshot", "harmony.route-warning", "harmony.hdc-recovery-plan"])
        #expect(decoded.primaryArtifact?.kind == "screenshot")
        #expect(decoded.primaryArtifact?.path == "run/step-001.png")
        #expect(decoded.primaryArtifacts.map(\.kind) == ["screenshot", "run.events", "run.meta", "status", "harmony.layout"])
        #expect(decoded.artifacts.first { $0.kind == "screenshot" }?.freshness?.source == "runtime")
        let harmonyLayout = try #require(decoded.artifacts.first { $0.kind == "harmony.layout" })
        #expect(harmonyLayout.platform == "harmony")
        #expect(harmonyLayout.riskLevel == "evidence")
        #expect(harmonyLayout.policy == "automation")
        #expect(harmonyLayout.redactionStatus == "summary")
        #expect(harmonyLayout.sourceCommand?.hasPrefix("hdc -t") == true)
        #expect(harmonyLayout.target == "harmony:127.0.0.1:10100")
        #expect(decoded.artifacts.first { $0.kind == "harmony.route-warning" }?.platform == "harmony")
        #expect(decoded.artifacts.first { $0.kind == "harmony.hdc-recovery-plan" }?.riskLevel == "readonly")
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
        #expect(decoded.primaryArtifact == nil)
        #expect(decoded.primaryArtifacts.isEmpty)
    }

    @Test("evidence summary and redaction decode primary artifact from primary artifacts")
    func summaryAndRedactionBackfillPrimaryArtifact() throws {
        let summaryData = Data("""
        {
          "ok": true,
          "action": "evidence.summary",
          "input": "/tmp/case.tritonevidence",
          "profile": "default",
          "createdAt": "2026-05-31T00:00:00Z",
          "output": "/tmp/case.tritonevidence",
          "artifactCount": 2,
          "sensitiveArtifactCount": 1,
          "skippedCount": 0,
          "cli": { "version": "0.1.0-dev", "schemaVersion": 1 },
          "artifacts": [
            { "kind": "screenshot", "path": "run/step-001.png", "contentType": "image/png" },
            { "kind": "status", "path": "status.json", "contentType": "application/json" }
          ],
          "primaryArtifacts": [
            { "kind": "screenshot", "path": "run/step-001.png", "contentType": "image/png" }
          ],
          "skipped": [],
          "suggestedCommands": []
        }
        """.utf8)
        let summary = try JSONDecoder().decode(TKEvidenceSummaryResponse.self, from: summaryData)
        #expect(summary.primaryArtifact?.kind == "screenshot")
        #expect(summary.primaryArtifact?.path == "run/step-001.png")

        let redactionData = Data("""
        {
          "ok": true,
          "action": "evidence.redact",
          "input": "/tmp/case.tritonevidence",
          "output": "/tmp/case-safe.tritonevidence",
          "profile": "default",
          "createdAt": "2026-05-31T00:00:00Z",
          "artifactCount": 2,
          "redactedArtifactCount": 1,
          "keptArtifactCount": 1,
          "manifest": {
            "ok": true,
            "formatVersion": 1,
            "createdAt": "2026-05-31T00:00:00Z",
            "output": "/tmp/case-safe.tritonevidence",
            "artifacts": [
              { "kind": "screenshot", "path": "run/step-001.png", "contentType": "image/png" },
              { "kind": "status", "path": "status.json", "contentType": "application/json" }
            ],
            "primaryArtifacts": [
              { "kind": "screenshot", "path": "run/step-001.png", "contentType": "image/png" }
            ],
            "skipped": [],
            "cli": { "version": "0.1.0-dev", "schemaVersion": 1 }
          },
          "redactedArtifacts": [
            { "kind": "screenshot", "path": "run/step-001.png", "contentType": "image/png" }
          ],
          "keptArtifacts": [
            { "kind": "status", "path": "status.json", "contentType": "application/json" }
          ],
          "primaryArtifacts": [
            { "kind": "screenshot", "path": "run/step-001.png", "contentType": "image/png" }
          ],
          "summaryPath": "summary.json",
          "suggestedCommands": []
        }
        """.utf8)
        let redaction = try JSONDecoder().decode(TKEvidenceRedactionResponse.self, from: redactionData)
        #expect(redaction.primaryArtifact?.kind == "screenshot")
        #expect(redaction.primaryArtifact?.path == "run/step-001.png")
    }
}
