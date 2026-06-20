import Foundation
import TritonKitShared

protocol SmokeRuntimeClient {
    func wait(_ request: WaitRequest) async throws -> TKWaitResult
    func assert(_ query: String) async throws -> TKUIAssertResult
}


struct LiveSmokeRuntimeClient: SmokeRuntimeClient {
    let client: TritonKitHTTPClient

    func wait(_ request: WaitRequest) async throws -> TKWaitResult {
        try await performWait(request, client: client)
    }

    func assert(_ query: String) async throws -> TKUIAssertResult {
        let status: TKStatusResponse = try await client.getJSON("/status")
        let accessibilityData = try await client.request(type: "accessibility")
        let nodes = try JSONDecoder().decode([TKAXNode].self, from: accessibilityData)
        let request = TKUIAssertRequest(condition: .textExists, query: query)
        return TKUIAssertEvaluate(
            request,
            nodes: nodes,
            targetConnectionState: status.targetConnectionState,
            hierarchyCacheState: status.hierarchyCacheState
        )
    }
}

func redactedSmokeSourceCommands(_ commands: [String], target: HostDeviceTarget) -> [String] {
    guard target.sensitive || target.scope == HostDeviceScope.real.rawValue else {
        return commands
    }
    guard !target.rawTarget.isEmpty, target.rawTarget != target.target else {
        return commands
    }
    return commands.map { $0.replacingOccurrences(of: target.rawTarget, with: target.target) }
}

func redactedSmokeSourceCommands(_ commands: [String], target: TKHarmonyTarget) -> [String] {
    guard target.scope == .real else {
        return commands
    }
    return commands.map { $0.replacingOccurrences(of: target.target, with: target.id) }
}

struct SmokeRealDeviceDiagnosticsPayload: Codable {
    let platform: String
    let scope: String?
    let kind: String?
    let id: String
    let state: String
    let ready: Bool
    let source: String
    let blockedReasons: [String]
    let redactionStatus: String
}

struct SmokeHostActionEvidencePayload: Codable {
    let proofSource: String
    let businessReady: Bool
    let sourceCommandCount: Int
    let actions: [String]
    let note: String
}

func appendSmokeRealDeviceDiagnostics(
    outputURL: URL,
    platform: String,
    id: String,
    state: String,
    ready: Bool,
    source: String,
    scope: String?,
    kind: String?,
    blockedReasons: [String],
    artifacts: inout [TKEvidenceArtifact]
) throws {
    let payload = SmokeRealDeviceDiagnosticsPayload(
        platform: platform,
        scope: scope,
        kind: kind,
        id: id,
        state: state,
        ready: ready,
        source: source,
        blockedReasons: blockedReasons,
        redactionStatus: "redacted"
    )
    let data = try prettyEncodedData(payload)
    try appendEvidenceArtifact(
        kind: "real-device.diagnostics",
        relativePath: "artifacts/real-device/diagnostics.json",
        data: data,
        contentType: "application/json",
        directory: outputURL,
        freshness: TKEvidenceFreshness(capturedAt: ISO8601DateFormatter().string(from: Date()), source: "host"),
        artifacts: &artifacts,
        platform: platform,
        riskLevel: "summary",
        policy: "\(platform)-real-device-private",
        redactionStatus: "redacted",
        sourceCommand: nil,
        target: id
    )
}

func appendSmokeHostActionEvidence(
    outputURL: URL,
    platform: String,
    target: String,
    sourceCommands: [String],
    actions: [String],
    artifacts: inout [TKEvidenceArtifact]
) throws {
    let payload = SmokeHostActionEvidencePayload(
        proofSource: SmokeProofSource.hostAction.rawValue,
        businessReady: false,
        sourceCommandCount: sourceCommands.count,
        actions: actions,
        note: "Host action success only proves command submission; wait/assert/evidence must prove business readiness."
    )
    let data = try prettyEncodedData(payload)
    try appendEvidenceArtifact(
        kind: "host.app-action",
        relativePath: "artifacts/host/app-action.json",
        data: data,
        contentType: "application/json",
        directory: outputURL,
        freshness: TKEvidenceFreshness(capturedAt: ISO8601DateFormatter().string(from: Date()), source: "host"),
        artifacts: &artifacts,
        platform: platform,
        riskLevel: "summary",
        policy: "\(platform)-real-device-private",
        redactionStatus: "redacted",
        sourceCommand: nil,
        target: target
    )
}

func summarizeEvidenceManifest(_ manifest: TKEvidenceManifest, input: String, profile: String) -> TKEvidenceSummaryResponse {
    TKEvidenceSummaryResponse(
        action: "evidence.summary",
        input: input,
        profile: profile,
        createdAt: manifest.createdAt,
        name: manifest.name,
        note: manifest.note,
        output: manifest.output,
        artifactCount: manifest.artifacts.count,
        sensitiveArtifactCount: manifest.artifacts.filter(evidenceArtifactIsSensitive).count,
        skippedCount: manifest.skipped.count,
        target: manifest.target,
        cli: manifest.cli,
        artifacts: manifest.artifacts.map(evidenceArtifactSummary),
        skipped: manifest.skipped,
        run: manifest.run,
        suggestedCommands: []
    )
}
