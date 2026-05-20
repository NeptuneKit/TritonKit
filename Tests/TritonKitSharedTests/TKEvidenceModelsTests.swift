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
                TKEvidenceArtifact(
                    kind: "screenshot",
                    path: "screenshot.png",
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
            cli: TKEvidenceCLI(version: "0.1.0-dev")
        )

        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(TKEvidenceManifest.self, from: data)

        #expect(decoded.formatVersion == 1)
        #expect(decoded.name == "login-success")
        #expect(decoded.artifacts.map(\.kind) == ["screenshot", "status"])
        #expect(decoded.artifacts.first?.freshness?.source == "runtime")
        #expect(decoded.skipped.first?.kind == "logs")
        #expect(decoded.target?.bundleIdentifier == "cn.dxy.iDxyer")
        #expect(decoded.cli.schemaVersion == 1)
    }
}
