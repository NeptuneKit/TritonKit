import Foundation

typealias TKWorkspaceModelDecisionProvider = (TKWorkspaceModelDecisionRequest) async throws -> TKWorkspaceModelDecision

struct TKWorkspaceModelDecisionRequest {
    let mode: String
    let goal: String
    let app: String
    let actionPolicy: String
    let allowedActions: [String]
    let stopConditions: [String]
    let visibleTexts: [String]
    let observationRef: String
    let providerStatus: String
    let llmProvider: String?
    let vlmProvider: String?
}

struct TKWorkspaceModelDecision {
    let candidate: TKWorkspaceActionCandidate
    let confidence: Double
    let summary: String
    let expected: String
    let usedVLM: Bool
    let requestContext: [String: Any]
    let bootstrapResponseText: String
    let decisionResponseText: String
}

func workspaceModelLoopMode(for request: TKWorkspaceRunRequest) -> String {
    request.dryModelFixture ? "dry-fixture" : "mock-provider"
}

func workspaceModelDecisionRequest(
    for request: TKWorkspaceRunRequest,
    observation: TKWorkspaceObservationSeed,
    runner: TKWorkspaceRunRunner,
    providerPreflight: TKWorkspaceProviderPreflight,
    mode: String
) -> TKWorkspaceModelDecisionRequest {
    TKWorkspaceModelDecisionRequest(
        mode: mode,
        goal: request.goal,
        app: request.app,
        actionPolicy: request.actionPolicy,
        allowedActions: runner.allowedActions,
        stopConditions: runner.stopConditions,
        visibleTexts: observation.screenCandidate.visibleTexts,
        observationRef: "events.jsonl#observation.captured",
        providerStatus: providerPreflight.providerStatus,
        llmProvider: providerPreflight.llmProvider,
        vlmProvider: providerPreflight.vlmProvider
    )
}

func workspaceDefaultModelDecisionProvider(
    _ request: TKWorkspaceModelDecisionRequest
) async throws -> TKWorkspaceModelDecision {
    workspaceDefaultModelDecision(request)
}

func workspaceDefaultModelDecision(_ request: TKWorkspaceModelDecisionRequest) -> TKWorkspaceModelDecision {
    let candidate = workspaceModelActionCandidate(fromVisibleTexts: request.visibleTexts)
    return TKWorkspaceModelDecision(
        candidate: candidate,
        confidence: 0.5,
        summary: "Workspace provider selected a single tap candidate.",
        expected: "\(candidate.query) advances the initial screen.",
        usedVLM: true,
        requestContext: workspaceDefaultModelDecisionRequestContext(request),
        bootstrapResponseText: "\(request.mode) bootstrap response: \(candidate.action) \(candidate.query)",
        decisionResponseText: "\(request.mode) decision response: \(candidate.action) \(candidate.query)"
    )
}

func workspaceDefaultModelDecisionRequestContext(
    _ request: TKWorkspaceModelDecisionRequest
) -> [String: Any] {
    var context: [String: Any] = [
        "visibleTexts": request.visibleTexts,
        "providerStatus": request.providerStatus,
        "actionPolicy": request.actionPolicy,
        "stopConditions": request.stopConditions,
    ]
    if let llmProvider = request.llmProvider {
        context["llmProvider"] = llmProvider
    }
    if let vlmProvider = request.vlmProvider {
        context["vlmProvider"] = vlmProvider
    }
    return context
}

func writeWorkspaceModelDecisionArtifacts(
    run: TKWorkspaceRunResponse,
    runDir: URL,
    mode: String,
    policyAllowed: Bool,
    businessCheckpoint: TKWorkspaceBusinessCheckpoint?,
    actionExecution: TKWorkspaceActionExecutionResult?,
    postActionObservation: TKWorkspaceObservationSeed?,
    modelRequest: TKWorkspaceModelDecisionRequest,
    modelDecision: TKWorkspaceModelDecision
) throws {
    let actionCandidate = modelDecision.candidate
    let command = actionCandidate.command
    try writeWorkspaceJSONArtifact(
        workspaceModelDecisionRequestArtifact(
            run: run,
            mode: mode,
            task: "bootstrap",
            bootstrapProposalRef: nil,
            modelRequest: modelRequest,
            modelDecision: modelDecision
        ),
        to: runDir.appendingPathComponent("evidence/model/bootstrap-proposal-000-request.redacted.json")
    )
    try workspaceWriteRawModelResponse(
        modelDecision.bootstrapResponseText,
        to: runDir.appendingPathComponent("evidence/model/bootstrap-proposal-000-response.raw.txt")
    )
    try writeWorkspaceJSONArtifact([
        "summary": modelDecision.summary,
        "command": command,
        "confidence": modelDecision.confidence,
        "candidateSource": actionCandidate.source,
        "evidenceId": "ev_0000",
        "expected": modelDecision.expected,
        "artifacts": [
            "request": "evidence/model/bootstrap-proposal-000-request.redacted.json",
            "response": "evidence/model/bootstrap-proposal-000-response.raw.txt",
        ],
    ], to: runDir.appendingPathComponent("evidence/model/bootstrap-proposal-000.json"))
    try writeWorkspaceJSONArtifact(
        workspaceModelDecisionRequestArtifact(
            run: run,
            mode: mode,
            task: "decide",
            bootstrapProposalRef: "evidence/model/bootstrap-proposal-000.json",
            modelRequest: modelRequest,
            modelDecision: modelDecision
        ),
        to: runDir.appendingPathComponent("evidence/model/decision-000-request.redacted.json")
    )
    try workspaceWriteRawModelResponse(
        modelDecision.decisionResponseText,
        to: runDir.appendingPathComponent("evidence/model/decision-000-response.raw.txt")
    )
    try writeWorkspaceJSONArtifact([
        "summary": modelDecision.summary,
        "command": command,
        "confidence": modelDecision.confidence,
        "candidateSource": actionCandidate.source,
        "usedVLM": modelDecision.usedVLM,
        "artifacts": [
            "request": "evidence/model/decision-000-request.redacted.json",
            "response": "evidence/model/decision-000-response.raw.txt",
        ],
    ], to: runDir.appendingPathComponent("evidence/model/decision-000.json"))
    if !policyAllowed {
        try writeWorkspaceJSONArtifact([
            "allowed": false,
            "reason": "runner allowedActions does not include \(actionCandidate.action)",
            "stopReason": "policy_rejected",
            "action": actionCandidate.action,
            "allowedActions": run.runner?.allowedActions ?? defaultWorkspaceRunnerAllowedActions,
            "command": command,
        ], to: runDir.appendingPathComponent("evidence/model/policy-000.json"))
        try writeWorkspaceJSONArtifact([
            "failureCode": "policy_rejected",
            "kind": "policy_rejected",
            "proposal": "stop",
            "reason": "candidate action is outside runner allowedActions",
        ], to: runDir.appendingPathComponent("evidence/model/recovery-000.json"))
        return
    }
    try writeWorkspaceJSONArtifact([
        "allowed": true,
        "reason": "\(mode) command is low-risk and single-step",
        "command": command,
    ], to: runDir.appendingPathComponent("evidence/model/policy-000.json"))
    if let actionExecution {
        try writeWorkspaceJSONArtifact(
            try workspaceActionExecutionArtifact(actionExecution),
            to: runDir.appendingPathComponent("evidence/actions/action-000.json")
        )
    } else {
        try writeWorkspaceJSONArtifact([
            "ok": true,
            "mode": mode,
            "command": command,
        ], to: runDir.appendingPathComponent("evidence/actions/action-000.json"))
    }
    if let businessCheckpoint, businessCheckpoint.stage == .postAction {
        try writeWorkspaceJSONArtifact([
            "status": businessCheckpoint.readiness.status,
            "reason": businessCheckpoint.ready
                ? "post-action business checkpoint passed"
                : "post-action business checkpoint did not pass",
            "businessRef": businessCheckpoint.readiness.ref,
            "check": businessCheckpoint.readiness.check,
            "phase": businessCheckpoint.readiness.phase,
        ], to: runDir.appendingPathComponent("evidence/model/verify-000.json"))
        if !businessCheckpoint.ready {
            try writeWorkspaceJSONArtifact([
                "failureCode": "business_checkpoint_missing",
                "kind": "post_action_business_not_ready",
                "proposal": "stop",
                "businessRef": businessCheckpoint.readiness.ref,
            ], to: runDir.appendingPathComponent("evidence/model/recovery-000.json"))
        }
    } else {
        try writeWorkspaceJSONArtifact([
            "status": "failed",
            "reason": actionExecution == nil
                ? "\(mode) simulates expected screen missing"
                : "action executed without a post-action business verification request",
        ], to: runDir.appendingPathComponent("evidence/model/verify-000.json"))
        try writeWorkspaceJSONArtifact([
            "failureCode": "expected_screen_missing",
            "kind": actionExecution == nil ? "selector_drift" : "post_action_unverified",
            "proposal": "stop",
        ], to: runDir.appendingPathComponent("evidence/model/recovery-000.json"))
    }
    let toScreenID = postActionObservation == nil ? "screen_0000" : "screen_0001"
    try """
    {"deltaId":"atlas_delta_0000","kind":"transition","transitionId":"transition_0000","fromScreenId":"screen_0000","toScreenId":"\(toScreenID)","status":"\(workspaceModelTransitionStatus(actionExecution: actionExecution, businessCheckpoint: businessCheckpoint))","confidence":\(modelDecision.confidence),"evidenceRefs":["events.jsonl#action.executed","events.jsonl#verify.checked","evidence/model/decision-000.json","evidence/model/verify-000.json"]}
    """.write(to: runDir.appendingPathComponent("atlas/deltas.jsonl"), atomically: true, encoding: .utf8)
    try """
    schemaVersion: 1
    kind: triton.workspace.flow
    steps:
      - action: \(actionCandidate.action)
        target: "\(yamlEscaped(actionCandidate.query))"
        evidenceRef: events.jsonl#action.executed

    """.write(to: runDir.appendingPathComponent("flow.tritonflow.yaml"), atomically: true, encoding: .utf8)
}

private func workspaceModelDecisionRequestArtifact(
    run: TKWorkspaceRunResponse,
    mode: String,
    task: String,
    bootstrapProposalRef: String?,
    modelRequest: TKWorkspaceModelDecisionRequest,
    modelDecision: TKWorkspaceModelDecision
) -> [String: Any] {
    var artifact: [String: Any] = [
        "kind": "triton.workspace.model-request",
        "mode": mode,
        "task": task,
        "goal": run.goal,
        "app": run.app,
        "observationRef": "events.jsonl#observation.captured",
        "allowedActions": run.runner?.allowedActions ?? defaultWorkspaceRunnerAllowedActions,
        "candidateSource": modelDecision.candidate.source,
    ]
    if let bootstrapProposalRef {
        artifact["bootstrapProposalRef"] = bootstrapProposalRef
    }
    for (key, value) in workspaceDefaultModelDecisionRequestContext(modelRequest) {
        artifact[key] = value
    }
    for (key, value) in modelDecision.requestContext {
        artifact[key] = value
    }
    return artifact
}

private func workspaceWriteRawModelResponse(_ text: String, to url: URL) throws {
    let output = text.hasSuffix("\n") ? text : "\(text)\n"
    try output.write(to: url, atomically: true, encoding: .utf8)
}
