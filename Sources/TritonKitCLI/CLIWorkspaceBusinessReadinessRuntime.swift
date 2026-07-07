import Foundation
import TritonKitShared

typealias TKWorkspaceBusinessWaitProvider = (TKWorkspaceBusinessWaitRequest) async throws -> TKWaitResult

struct TKWorkspaceBusinessWaitRequest: Equatable {
    let target: String
    let host: String
    let port: Int
    let query: String
    let timeout: Double
    let interval: Double
}

struct TKWorkspaceBusinessCheckpoint {
    let readiness: TKWorkspaceBusinessReadiness
    let matchedTexts: [String]
    let observationRef: String
    let evidenceRefs: [String]
    let source: String
    let wait: TKWaitResult?

    var ready: Bool { readiness.ready }
    var eventStatus: TKTestRunStatus { ready ? .passed : .failed }
}

func workspaceBusinessWaitRequest(for request: TKWorkspaceRunRequest) throws -> TKWorkspaceBusinessWaitRequest {
    guard let query = normalizedWorkspaceBusinessReadyText(request.businessReadyText) else {
        throw RuntimeError("--business-ready-live-wait requires --business-ready-text.")
    }
    guard request.businessReadyTimeout > 0 else {
        throw RuntimeError("--business-ready-timeout must be greater than 0.")
    }
    guard request.businessReadyInterval > 0 else {
        throw RuntimeError("--business-ready-interval must be greater than 0.")
    }
    return TKWorkspaceBusinessWaitRequest(
        target: request.target,
        host: request.observeHost,
        port: request.observePort,
        query: query,
        timeout: request.businessReadyTimeout,
        interval: request.businessReadyInterval
    )
}

func workspaceDefaultBusinessWaitProvider(_ request: TKWorkspaceBusinessWaitRequest) async throws -> TKWaitResult {
    let (_, client) = try await resolveRuntimeClient(
        target: request.target,
        host: request.host,
        port: request.port,
        jsonError: true
    )
    return try await performWait(
        WaitRequest(
            condition: .text,
            query: request.query,
            predicate: nil,
            role: nil,
            timeout: request.timeout,
            interval: request.interval
        ),
        client: client
    )
}

func workspaceBusinessCheckpoint(
    for request: TKWorkspaceRunRequest,
    observation: TKWorkspaceObservationSeed,
    appReady: TKWorkspaceAppReadyEvidence,
    waitResult: TKWaitResult?
) -> TKWorkspaceBusinessCheckpoint? {
    guard let query = normalizedWorkspaceBusinessReadyText(request.businessReadyText) else {
        return nil
    }
    if request.businessReadyLiveWait, let waitResult {
        return workspaceBusinessWaitCheckpoint(
            query: query,
            observation: observation,
            appReady: appReady,
            waitResult: waitResult
        )
    }
    return workspaceBusinessVisibleTextCheckpoint(
        query: query,
        observation: observation,
        appReady: appReady
    )
}

func workspaceBusinessReadyArtifact(_ checkpoint: TKWorkspaceBusinessCheckpoint) -> [String: Any] {
    var artifact: [String: Any] = [
        "schemaVersion": 1,
        "kind": "triton.workspace.business-ready",
        "ready": checkpoint.ready,
        "businessReady": checkpoint.ready,
        "status": checkpoint.readiness.status,
        "check": checkpoint.readiness.check,
        "query": checkpoint.readiness.query,
        "match": "exact",
        "phase": checkpoint.readiness.phase,
        "source": checkpoint.source,
        "matchedTexts": checkpoint.matchedTexts,
        "observationRef": checkpoint.observationRef,
        "evidenceRefs": checkpoint.evidenceRefs,
    ]
    if let wait = checkpoint.wait {
        artifact["wait"] = workspaceBusinessWaitArtifact(wait)
    }
    return artifact
}

private func workspaceBusinessVisibleTextCheckpoint(
    query: String,
    observation: TKWorkspaceObservationSeed,
    appReady: TKWorkspaceAppReadyEvidence
) -> TKWorkspaceBusinessCheckpoint {
    let visibleTexts = observation.screenCandidate.visibleTexts
    let matchedTexts = visibleTexts.filter { normalizedWorkspaceBusinessText($0) == query }
    let ready = !matchedTexts.isEmpty
    return TKWorkspaceBusinessCheckpoint(
        readiness: TKWorkspaceBusinessReadiness(
            ready: ready,
            status: ready ? "passed" : "failed",
            check: "visible_text",
            query: query,
            phase: ready ? "text_matched" : "text_missing"
        ),
        matchedTexts: matchedTexts,
        observationRef: "events.jsonl#observation.captured",
        evidenceRefs: workspaceBusinessEvidenceRefs(observation: observation, appReady: appReady),
        source: "observation.visibleTexts",
        wait: nil
    )
}

private func workspaceBusinessWaitCheckpoint(
    query: String,
    observation: TKWorkspaceObservationSeed,
    appReady: TKWorkspaceAppReadyEvidence,
    waitResult: TKWaitResult
) -> TKWorkspaceBusinessCheckpoint {
    let ready = waitResult.ok
    let phase: String
    if ready {
        phase = "wait_matched"
    } else if waitResult.timedOut {
        phase = "wait_timeout"
    } else {
        phase = "wait_unmatched"
    }
    return TKWorkspaceBusinessCheckpoint(
        readiness: TKWorkspaceBusinessReadiness(
            ready: ready,
            status: ready ? "passed" : "failed",
            check: "runtime_wait",
            query: query,
            phase: phase
        ),
        matchedTexts: workspaceBusinessWaitMatchedTexts(query: query, waitResult: waitResult),
        observationRef: "events.jsonl#observation.captured",
        evidenceRefs: workspaceBusinessEvidenceRefs(observation: observation, appReady: appReady),
        source: "runtime.wait",
        wait: waitResult
    )
}

private func workspaceBusinessEvidenceRefs(
    observation: TKWorkspaceObservationSeed,
    appReady: TKWorkspaceAppReadyEvidence
) -> [String] {
    let refs = ([
        "events.jsonl#observation.captured",
        "events.jsonl#app.ready",
        "evidence/actions/app-ready.json",
        observation.fixtureRef,
        observation.artifacts.screenshot,
        observation.artifacts.hierarchy,
        observation.artifacts.ax,
    ] as [String?]).compactMap { $0 }
    return uniqueWorkspaceEvidenceRefs(appReady.observationRef.map { refs + [$0] } ?? refs)
}

private func workspaceBusinessWaitMatchedTexts(query: String, waitResult: TKWaitResult) -> [String] {
    if let text = waitResult.match?.text, !text.isEmpty {
        return [text]
    }
    let matchedSamples = waitResult.lastObservedTextSample.filter { normalizedWorkspaceBusinessText($0) == query }
    if !matchedSamples.isEmpty {
        return matchedSamples
    }
    return waitResult.ok ? [query] : []
}

private func workspaceBusinessWaitArtifact(_ result: TKWaitResult) -> [String: Any] {
    var artifact: [String: Any] = [
        "ok": result.ok,
        "matched": result.matched,
        "condition": result.condition,
        "timedOut": result.timedOut,
        "elapsedMs": result.elapsedMs,
        "pollCount": result.pollCount,
        "timeoutSeconds": result.timeoutSeconds,
        "intervalSeconds": result.intervalSeconds,
        "lastObservedTextSample": result.lastObservedTextSample,
    ]
    if let query = result.query { artifact["query"] = query }
    if let predicate = result.predicate { artifact["predicate"] = predicate }
    if let role = result.role { artifact["role"] = role }
    if let state = result.targetConnectionState { artifact["targetConnectionState"] = state }
    if let state = result.hierarchyCacheState { artifact["hierarchyCacheState"] = state }
    if let count = result.lastObservedNodeCount { artifact["lastObservedNodeCount"] = count }
    if let hash = result.lastObservedHierarchyHash { artifact["lastObservedHierarchyHash"] = hash }
    if let match = result.match { artifact["match"] = workspaceBusinessWaitMatchArtifact(match) }
    return artifact
}

private func workspaceBusinessWaitMatchArtifact(_ match: TKWaitMatch) -> [String: Any] {
    var artifact: [String: Any] = [
        "text": match.text,
        "source": match.source,
    ]
    if let role = match.role { artifact["role"] = role }
    if let label = match.label { artifact["label"] = label }
    if let value = match.value { artifact["value"] = value }
    if let identifier = match.identifier { artifact["identifier"] = identifier }
    if let title = match.title { artifact["title"] = title }
    if let targetOID = match.targetOID { artifact["targetOID"] = targetOID }
    if let viewOID = match.viewOID { artifact["viewOID"] = viewOID }
    if let className = match.className { artifact["className"] = className }
    if let frame = match.frame {
        artifact["frame"] = [
            "x": frame.x,
            "y": frame.y,
            "width": frame.width,
            "height": frame.height,
        ]
    }
    return artifact
}

private func uniqueWorkspaceEvidenceRefs(_ refs: [String]) -> [String] {
    var seen = Set<String>()
    var result: [String] = []
    for ref in refs where !seen.contains(ref) {
        seen.insert(ref)
        result.append(ref)
    }
    return result
}

private func normalizedWorkspaceBusinessReadyText(_ raw: String?) -> String? {
    let value = normalizedWorkspaceBusinessText(raw ?? "")
    return value.isEmpty ? nil : value
}

private func normalizedWorkspaceBusinessText(_ raw: String) -> String {
    raw.trimmingCharacters(in: .whitespacesAndNewlines)
}
