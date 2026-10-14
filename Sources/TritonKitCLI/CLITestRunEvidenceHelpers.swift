import CryptoKit
import Foundation
import TritonKitShared

func testRunVisibleTexts(from nodes: [TKAXNode]) -> [String] {
    var seen = Set<String>()
    var result: [String] = []
    for match in TKWaitVisibleTexts(from: nodes) {
        guard seen.insert(match.text).inserted else { continue }
        result.append(match.text)
        if result.count >= 50 { break }
    }
    return result
}

func testRunSHA256(_ data: Data) -> String {
    SHA256.hash(data: data)
        .map { String(format: "%02x", $0) }
        .joined()
}

func testRunArtifactKey(_ artifact: TKEvidenceArtifact) -> String {
    "\(artifact.kind)\u{0}\(artifact.path)"
}

func testRunVLMArtifacts(
    from grounding: TKVLMGroundResponse,
    evidenceDirectory: URL,
    target: String
) -> [TKEvidenceArtifact] {
    [
        TKEvidenceArtifact(
            kind: "vlm.overlay",
            path: testRunRelativePath(grounding.artifacts.overlay, evidenceDirectory: evidenceDirectory),
            contentType: "image/png",
            bytes: testRunFileSize(grounding.artifacts.overlay),
            target: target
        ),
        TKEvidenceArtifact(
            kind: "vlm.request",
            path: testRunRelativePath(grounding.artifacts.request, evidenceDirectory: evidenceDirectory),
            contentType: "application/json",
            bytes: testRunFileSize(grounding.artifacts.request),
            target: target
        ),
        TKEvidenceArtifact(
            kind: "vlm.response",
            path: testRunRelativePath(grounding.artifacts.response, evidenceDirectory: evidenceDirectory),
            contentType: "application/json",
            bytes: testRunFileSize(grounding.artifacts.response),
            target: target
        ),
    ]
}

func testRunRelativePath(_ path: String, evidenceDirectory: URL) -> String {
    let evidencePath = evidenceDirectory.standardizedFileURL.path
    let artifactPath = URL(fileURLWithPath: path).standardizedFileURL.path
    guard artifactPath.hasPrefix(evidencePath + "/") else {
        return path
    }
    return String(artifactPath.dropFirst(evidencePath.count + 1))
}

func testRunFileSize(_ path: String) -> Int? {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
          let size = attributes[.size] as? NSNumber else {
        return nil
    }
    return size.intValue
}

extension TKTestRunObservationOutcome {
    func withChanged(_ changed: Bool?) -> TKTestRunObservationOutcome {
        TKTestRunObservationOutcome(
            phase: phase,
            artifacts: artifacts,
            screenCandidate: screenCandidate,
            changed: changed,
            evidenceArtifacts: evidenceArtifacts
        )
    }
}

func testRunTimestamp(_ date: Date = Date()) -> String {
    ISO8601DateFormatter().string(from: date)
}

func testRunElapsedMilliseconds(since start: Date) -> Int {
    max(0, Int(Date().timeIntervalSince(start) * 1_000))
}

func testRunEventRef(for artifactPath: String) -> String {
    "../\(artifactPath)"
}

func formatTestRunNumber(_ value: Double) -> String {
    value.rounded() == value ? String(Int(value)) : String(value)
}
