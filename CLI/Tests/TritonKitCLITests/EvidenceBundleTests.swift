import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct EvidenceBundleTests {
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
                TKEvidenceArtifact(kind: "screenshot", path: "screenshot.png", contentType: "image/png", bytes: 18),
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
        #expect(output.manifest.artifacts.first { $0.kind == "screenshot" }?.path.hasPrefix("redacted/") == true)
        #expect(FileManager.default.fileExists(atPath: redacted.appendingPathComponent("manifest.json").path))
        #expect(FileManager.default.fileExists(atPath: redacted.appendingPathComponent("summary.json").path))
    }
}
