import Foundation
import TritonKitShared

typealias TKWorkspaceBusinessWaitProvider = (TKWorkspaceBusinessWaitRequest) async throws -> TKWaitResult
typealias TKWorkspaceBusinessAssertProvider = (TKWorkspaceBusinessAssertRequest) async throws -> TKUIAssertResult

struct TKWorkspaceBusinessWaitRequest: Equatable {
    let target: String
    let host: String
    let port: Int
    let query: String
    let timeout: Double
    let interval: Double
}

struct TKWorkspaceBusinessAssertRequest: Equatable {
    let target: String
    let host: String
    let port: Int
    let condition: TKUIAssertCondition
    let query: String
}

func workspaceUsesRuntimeBusinessCheck(_ request: TKWorkspaceRunRequest) -> Bool {
    request.businessReadyLiveWait || request.businessReadyAssert
}

enum TKWorkspaceBusinessCheckpointStage: String {
    case initial
    case postAction = "post_action"
}

struct TKWorkspaceBusinessCheckpoint {
    let readiness: TKWorkspaceBusinessReadiness
    let matchedTexts: [String]
    let observationRef: String
    let evidenceRefs: [String]
    let source: String
    let wait: TKWaitResult?
    let assertion: TKUIAssertResult?
    let stage: TKWorkspaceBusinessCheckpointStage

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

func workspaceBusinessAssertRequest(for request: TKWorkspaceRunRequest) throws -> TKWorkspaceBusinessAssertRequest {
    guard let query = normalizedWorkspaceBusinessReadyText(request.businessReadyText) else {
        throw RuntimeError("--business-ready-assert requires --business-ready-text.")
    }
    return TKWorkspaceBusinessAssertRequest(
        target: request.target,
        host: request.observeHost,
        port: request.observePort,
        condition: .textExists,
        query: query
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

func workspaceDefaultBusinessAssertProvider(_ request: TKWorkspaceBusinessAssertRequest) async throws -> TKUIAssertResult {
    let (_, client) = try await resolveRuntimeClient(
        target: request.target,
        host: request.host,
        port: request.port,
        jsonError: true
    )
    let status: TKStatusResponse = try await client.getJSON("/status")
    let accessibilityData = try await client.request(type: "accessibility")
    let nodes = try JSONDecoder().decode([TKAXNode].self, from: accessibilityData)
    return TKUIAssertEvaluate(
        TKUIAssertRequest(condition: request.condition, query: request.query),
        nodes: nodes,
        targetConnectionState: status.targetConnectionState,
        hierarchyCacheState: status.hierarchyCacheState
    )
}

func workspaceBusinessCheckpoint(
    for request: TKWorkspaceRunRequest,
    observation: TKWorkspaceObservationSeed,
    appReady: TKWorkspaceAppReadyEvidence,
    waitResult: TKWaitResult?,
    stage: TKWorkspaceBusinessCheckpointStage = .initial
) -> TKWorkspaceBusinessCheckpoint? {
    guard let query = normalizedWorkspaceBusinessReadyText(request.businessReadyText) else {
        return nil
    }
    if request.businessReadyLiveWait, let waitResult {
        return workspaceBusinessWaitCheckpoint(
            query: query,
            observation: observation,
            appReady: appReady,
            waitResult: waitResult,
            stage: stage
        )
    }
    return workspaceBusinessVisibleTextCheckpoint(
        query: query,
        observation: observation,
        appReady: appReady,
        stage: stage
    )
}

func workspaceBusinessVisibleTextCheckpoint(
    for request: TKWorkspaceRunRequest,
    observation: TKWorkspaceObservationSeed,
    appReady: TKWorkspaceAppReadyEvidence,
    stage: TKWorkspaceBusinessCheckpointStage = .initial
) -> TKWorkspaceBusinessCheckpoint? {
    guard let query = normalizedWorkspaceBusinessReadyText(request.businessReadyText) else {
        return nil
    }
    return workspaceBusinessVisibleTextCheckpoint(
        query: query,
        observation: observation,
        appReady: appReady,
        stage: stage
    )
}

func workspaceBusinessAssertCheckpoint(
    for request: TKWorkspaceRunRequest,
    observation: TKWorkspaceObservationSeed,
    appReady: TKWorkspaceAppReadyEvidence,
    assertionResult: TKUIAssertResult,
    stage: TKWorkspaceBusinessCheckpointStage = .initial
) -> TKWorkspaceBusinessCheckpoint? {
    guard let query = normalizedWorkspaceBusinessReadyText(request.businessReadyText) else {
        return nil
    }
    return workspaceBusinessAssertCheckpoint(
        query: query,
        observation: observation,
        appReady: appReady,
        assertionResult: assertionResult,
        stage: stage
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
        "stage": checkpoint.stage.rawValue,
    ]
    if let wait = checkpoint.wait {
        artifact["wait"] = workspaceBusinessWaitArtifact(wait)
    }
    if let assertion = checkpoint.assertion {
        artifact["assertion"] = workspaceBusinessAssertArtifact(assertion)
    }
    return artifact
}

private func workspaceBusinessVisibleTextCheckpoint(
    query: String,
    observation: TKWorkspaceObservationSeed,
    appReady: TKWorkspaceAppReadyEvidence,
    stage: TKWorkspaceBusinessCheckpointStage
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
        evidenceRefs: workspaceBusinessEvidenceRefs(observation: observation, appReady: appReady, stage: stage),
        source: "observation.visibleTexts",
        wait: nil,
        assertion: nil,
        stage: stage
    )
}

private func workspaceBusinessWaitCheckpoint(
    query: String,
    observation: TKWorkspaceObservationSeed,
    appReady: TKWorkspaceAppReadyEvidence,
    waitResult: TKWaitResult,
    stage: TKWorkspaceBusinessCheckpointStage
) -> TKWorkspaceBusinessCheckpoint {
    let ready = waitResult.ok
    let basePhase: String
    if ready {
        basePhase = "wait_matched"
    } else if waitResult.timedOut {
        basePhase = "wait_timeout"
    } else {
        basePhase = "wait_unmatched"
    }
    let phase = stage == .postAction ? "post_action_\(basePhase)" : basePhase
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
        evidenceRefs: workspaceBusinessEvidenceRefs(observation: observation, appReady: appReady, stage: stage),
        source: "runtime.wait",
        wait: waitResult,
        assertion: nil,
        stage: stage
    )
}

private func workspaceBusinessAssertCheckpoint(
    query: String,
    observation: TKWorkspaceObservationSeed,
    appReady: TKWorkspaceAppReadyEvidence,
    assertionResult: TKUIAssertResult,
    stage: TKWorkspaceBusinessCheckpointStage
) -> TKWorkspaceBusinessCheckpoint {
    let ready = assertionResult.ok
    let basePhase = ready ? "assertion_passed" : "assertion_failed"
    let phase = stage == .postAction ? "post_action_\(basePhase)" : basePhase
    return TKWorkspaceBusinessCheckpoint(
        readiness: TKWorkspaceBusinessReadiness(
            ready: ready,
            status: ready ? "passed" : "failed",
            check: "runtime_assert",
            query: query,
            phase: phase
        ),
        matchedTexts: assertionResult.matches.map(\.text),
        observationRef: "events.jsonl#observation.captured",
        evidenceRefs: workspaceBusinessEvidenceRefs(observation: observation, appReady: appReady, stage: stage),
        source: "runtime.assert",
        wait: nil,
        assertion: assertionResult,
        stage: stage
    )
}

private func workspaceBusinessEvidenceRefs(
    observation: TKWorkspaceObservationSeed,
    appReady: TKWorkspaceAppReadyEvidence,
    stage: TKWorkspaceBusinessCheckpointStage
) -> [String] {
    var refs = ([
        "events.jsonl#observation.captured",
        "events.jsonl#app.ready",
        "evidence/actions/app-ready.json",
        observation.fixtureRef,
        observation.artifacts.screenshot,
        observation.artifacts.hierarchy,
        observation.artifacts.ax,
    ] as [String?]).compactMap { $0 }
    if stage == .postAction {
        refs += [
            "events.jsonl#action.executed",
            "evidence/actions/action-000.json",
        ]
    }
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

private func workspaceBusinessAssertArtifact(_ result: TKUIAssertResult) -> Any {
    do {
        let data = try JSONEncoder().encode(result)
        return try JSONSerialization.jsonObject(with: data)
    } catch {
        var fallback: [String: Any] = [
            "ok": result.ok,
            "condition": result.condition,
            "query": result.query,
            "count": result.count,
        ]
        if let message = result.message {
            fallback["message"] = message
        }
        return fallback
    }
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
