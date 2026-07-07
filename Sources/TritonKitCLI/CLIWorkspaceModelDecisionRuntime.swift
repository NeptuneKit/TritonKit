import Foundation

typealias TKWorkspaceModelDecisionProvider = (TKWorkspaceModelDecisionRequest) async throws -> TKWorkspaceModelDecision
typealias TKWorkspaceModelDecisionHTTPTransport = (_ url: URL, _ body: Data, _ headers: [String: String]) throws -> Data

struct TKWorkspaceModelDecisionFailure: Error, CustomStringConvertible {
    let code: String
    let message: String
    let hint: String?

    var description: String { message }
}

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
    let llmBaseURL: String?
    let llmModel: String?
    let llmAPIKeyEnv: String?
    let allowRemoteLLM: Bool
    let vlmProvider: String?
    let vlmBaseURL: String?
    let vlmModel: String?
    let vlmAPIKeyEnv: String?
    let allowRemoteVLM: Bool
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
    if request.dryModelFixture {
        return "dry-fixture"
    }
    if normalizedWorkspaceModelProvider(request.llmProvider) == "openai-compatible",
       workspaceNonEmpty(request.llmBaseURL) != nil,
       workspaceNonEmpty(request.llmModel) != nil {
        return "openai-compatible-provider"
    }
    return "mock-provider"
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
        llmBaseURL: request.llmBaseURL,
        llmModel: request.llmModel,
        llmAPIKeyEnv: request.llmAPIKeyEnv,
        allowRemoteLLM: request.allowRemoteLLM,
        vlmProvider: providerPreflight.vlmProvider,
        vlmBaseURL: request.vlmBaseURL,
        vlmModel: request.vlmModel,
        vlmAPIKeyEnv: request.vlmAPIKeyEnv,
        allowRemoteVLM: request.allowRemoteVLM
    )
}

func workspaceDefaultModelDecisionProvider(
    _ request: TKWorkspaceModelDecisionRequest
) async throws -> TKWorkspaceModelDecision {
    if normalizedWorkspaceModelProvider(request.llmProvider) == "openai-compatible" {
        return try await workspaceOpenAICompatibleModelDecisionProvider(request)
    }
    return workspaceDefaultModelDecision(request)
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
    if let llmBaseURL = workspaceNonEmpty(request.llmBaseURL) {
        context["llmBaseURL"] = redactedWorkspaceProviderBaseURL(llmBaseURL)
    }
    if let llmModel = workspaceNonEmpty(request.llmModel) {
        context["llmModel"] = llmModel
    }
    if let llmAPIKeyEnv = workspaceNonEmpty(request.llmAPIKeyEnv) {
        context["llmAPIKeyEnv"] = llmAPIKeyEnv
    }
    context["allowRemoteLLM"] = request.allowRemoteLLM
    if let vlmProvider = request.vlmProvider {
        context["vlmProvider"] = vlmProvider
    }
    if let vlmBaseURL = workspaceNonEmpty(request.vlmBaseURL) {
        context["vlmBaseURL"] = redactedWorkspaceProviderBaseURL(vlmBaseURL)
    }
    if let vlmModel = workspaceNonEmpty(request.vlmModel) {
        context["vlmModel"] = vlmModel
    }
    if let vlmAPIKeyEnv = workspaceNonEmpty(request.vlmAPIKeyEnv) {
        context["vlmAPIKeyEnv"] = vlmAPIKeyEnv
    }
    context["allowRemoteVLM"] = request.allowRemoteVLM
    return context
}

func workspaceOpenAICompatibleModelDecisionProvider(
    _ request: TKWorkspaceModelDecisionRequest,
    httpTransport: TKWorkspaceModelDecisionHTTPTransport? = nil
) async throws -> TKWorkspaceModelDecision {
    guard let baseURLString = workspaceNonEmpty(request.llmBaseURL) else {
        throw TKWorkspaceModelDecisionFailure(
            code: "workspace_llm_openai_base_url_required",
            message: "--llm-base-url is required for --llm-provider openai-compatible",
            hint: "Use a local OpenAI-compatible endpoint first, for example http://127.0.0.1:8000/v1"
        )
    }
    guard let model = workspaceNonEmpty(request.llmModel) else {
        throw TKWorkspaceModelDecisionFailure(
            code: "workspace_llm_openai_model_required",
            message: "--llm-model is required for --llm-provider openai-compatible",
            hint: "Pass the local model served by your OpenAI-compatible endpoint"
        )
    }
    guard let baseURL = URL(string: baseURLString), let host = baseURL.host else {
        throw TKWorkspaceModelDecisionFailure(
            code: "workspace_llm_openai_base_url_invalid",
            message: "Invalid OpenAI-compatible LLM base URL \(baseURLString)",
            hint: "Pass an absolute http(s) URL ending at the OpenAI-compatible /v1 base"
        )
    }
    if !isLocalWorkspaceProviderHost(host), !request.allowRemoteLLM {
        throw TKWorkspaceModelDecisionFailure(
            code: "workspace_llm_remote_provider_requires_approval",
            message: "Remote LLM provider \(host) requires explicit approval",
            hint: "Pass --allow-remote-llm only when uploading local workspace evidence is intended"
        )
    }
    let apiKey = try workspaceModelDecisionAPIKey(from: request.llmAPIKeyEnv)
    let requestURL = baseURL.appendingPathComponent("chat/completions")
    let body = try makeWorkspaceOpenAICompatibleDecisionRequestBody(request: request, model: model)
    var headers = [
        "Content-Type": "application/json",
    ]
    if let apiKey, !apiKey.isEmpty {
        headers["Authorization"] = "Bearer \(apiKey)"
    }

    let responseData: Data
    do {
        if let httpTransport {
            responseData = try httpTransport(requestURL, body, headers)
        } else {
            responseData = try postWorkspaceModelDecisionJSON(url: requestURL, body: body, headers: headers)
        }
    } catch let failure as TKWorkspaceModelDecisionFailure {
        throw failure
    } catch {
        throw TKWorkspaceModelDecisionFailure(
            code: "workspace_llm_provider_request_failed",
            message: "OpenAI-compatible workspace LLM request failed: \(error)",
            hint: "Check --llm-base-url and provider availability"
        )
    }

    let rawText = try parseWorkspaceOpenAICompatibleText(responseData)
    let parsed = try parseWorkspaceOpenAICompatibleDecision(rawText)
    let candidate = TKWorkspaceActionCandidate(
        action: parsed.action,
        query: parsed.query,
        source: "openai-compatible.llm"
    )
    return TKWorkspaceModelDecision(
        candidate: candidate,
        confidence: parsed.confidence,
        summary: parsed.summary,
        expected: parsed.expected,
        usedVLM: false,
        requestContext: [
            "llmProvider": "openai-compatible",
            "llmBaseURL": redactedWorkspaceProviderBaseURL(baseURLString) ?? baseURLString,
            "llmModel": model,
            "network": "openai-compatible",
        ],
        bootstrapResponseText: rawText,
        decisionResponseText: rawText
    )
}

private struct TKWorkspaceOpenAICompatibleDecisionPayload: Decodable {
    let action: String
    let query: String
    let confidence: Double?
    let summary: String?
    let expected: String?
}

private struct TKWorkspaceParsedModelDecision {
    let action: String
    let query: String
    let confidence: Double
    let summary: String
    let expected: String
}

private func makeWorkspaceOpenAICompatibleDecisionRequestBody(
    request: TKWorkspaceModelDecisionRequest,
    model: String
) throws -> Data {
    let prompt = """
    Return only one JSON object with keys action, query, confidence, summary, and expected.
    Use one action from allowedActions.
    Prefer stable visible text selectors when possible.
    goal: \(request.goal)
    app: \(request.app)
    actionPolicy: \(request.actionPolicy)
    allowedActions: \(request.allowedActions)
    stopConditions: \(request.stopConditions)
    providerStatus: \(request.providerStatus)
    observationRef: \(request.observationRef)
    visibleTexts: \(request.visibleTexts)
    vlmProvider: \(request.vlmProvider ?? "none")
    vlmBaseURL: \(redactedWorkspaceProviderBaseURL(request.vlmBaseURL) ?? "none")
    vlmModel: \(request.vlmModel ?? "none")
    """
    let payload: [String: Any] = [
        "model": model,
        "temperature": 0,
        "messages": [
            [
                "role": "system",
                "content": "You are TritonKit's local workspace decision provider. Propose exactly one bounded UI action candidate; Triton executes and verifies it.",
            ],
            [
                "role": "user",
                "content": prompt,
            ],
        ],
    ]
    guard JSONSerialization.isValidJSONObject(payload) else {
        throw TKWorkspaceModelDecisionFailure(
            code: "workspace_llm_provider_request_invalid",
            message: "OpenAI-compatible workspace LLM payload is not valid JSON",
            hint: nil
        )
    }
    return try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
}

private func parseWorkspaceOpenAICompatibleText(_ data: Data) throws -> String {
    do {
        return try parseOpenAICompatibleText(data)
    } catch let failure as TKVLMGroundingFailure {
        throw TKWorkspaceModelDecisionFailure(
            code: "workspace_llm_provider_response_invalid",
            message: failure.message,
            hint: "Expected Chat Completions-compatible JSON with choices[0].message.content"
        )
    } catch {
        throw TKWorkspaceModelDecisionFailure(
            code: "workspace_llm_provider_response_invalid",
            message: "OpenAI-compatible workspace LLM response is invalid: \(error)",
            hint: "Expected Chat Completions-compatible JSON with choices[0].message.content"
        )
    }
}

private func parseWorkspaceOpenAICompatibleDecision(_ text: String) throws -> TKWorkspaceParsedModelDecision {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let data = Data(trimmed.utf8)
    let payload: TKWorkspaceOpenAICompatibleDecisionPayload
    do {
        payload = try JSONDecoder().decode(TKWorkspaceOpenAICompatibleDecisionPayload.self, from: data)
    } catch {
        throw TKWorkspaceModelDecisionFailure(
            code: "workspace_llm_decision_unparseable",
            message: "Workspace LLM decision is not valid JSON: \(error)",
            hint: #"Return only JSON like {"action":"tap","query":"Continue","confidence":0.8}"#
        )
    }
    let action = payload.action.trimmingCharacters(in: .whitespacesAndNewlines)
    let query = payload.query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !action.isEmpty, !query.isEmpty else {
        throw TKWorkspaceModelDecisionFailure(
            code: "workspace_llm_decision_unparseable",
            message: "Workspace LLM decision must contain non-empty action and query",
            hint: #"Return only JSON like {"action":"tap","query":"Continue","confidence":0.8}"#
        )
    }
    let confidence = min(max(payload.confidence ?? 0.5, 0), 1)
    return TKWorkspaceParsedModelDecision(
        action: action,
        query: query,
        confidence: confidence,
        summary: workspaceNonEmpty(payload.summary) ?? "OpenAI-compatible workspace LLM selected \(action) \(query).",
        expected: workspaceNonEmpty(payload.expected) ?? "\(query) advances the current goal."
    )
}

private func workspaceModelDecisionAPIKey(from apiKeyEnv: String?) throws -> String? {
    guard let apiKeyEnv = workspaceNonEmpty(apiKeyEnv) else {
        return nil
    }
    guard let value = ProcessInfo.processInfo.environment[apiKeyEnv], !value.isEmpty else {
        throw TKWorkspaceModelDecisionFailure(
            code: "workspace_llm_api_key_missing",
            message: "Environment variable \(apiKeyEnv) is not set",
            hint: "Set \(apiKeyEnv) or omit --llm-api-key-env for local unauthenticated providers"
        )
    }
    return value
}

private func postWorkspaceModelDecisionJSON(url: URL, body: Data, headers: [String: String]) throws -> Data {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = body
    request.timeoutInterval = 30
    for (key, value) in headers {
        request.setValue(value, forHTTPHeaderField: key)
    }

    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<(Data, URLResponse), Error>?
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error {
            result = .failure(error)
        } else {
            result = .success((data ?? Data(), response ?? URLResponse()))
        }
        semaphore.signal()
    }.resume()
    semaphore.wait()

    let (data, response) = try result?.get() ?? (Data(), URLResponse())
    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
        let body = String(data: data, encoding: .utf8) ?? ""
        throw TKWorkspaceModelDecisionFailure(
            code: "workspace_llm_provider_request_failed",
            message: "OpenAI-compatible workspace LLM returned HTTP \(http.statusCode): \(body)",
            hint: "Inspect provider logs and response body"
        )
    }
    return data
}

func normalizedWorkspaceModelProvider(_ value: String?) -> String? {
    workspaceNonEmpty(value)?.lowercased()
}

func workspaceNonEmpty(_ value: String?) -> String? {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? nil : trimmed
}

func isLocalWorkspaceProviderHost(_ host: String) -> Bool {
    let normalized = host.lowercased()
    return normalized == "localhost" ||
        normalized == "127.0.0.1" ||
        normalized == "::1" ||
        normalized == "[::1]"
}

func redactedWorkspaceProviderBaseURL(_ baseURL: String?) -> String? {
    guard let baseURL, var components = URLComponents(string: baseURL) else {
        return baseURL
    }
    if components.password != nil {
        components.password = "<redacted>"
    }
    if components.user != nil {
        components.user = "<redacted>"
    }
    return components.string ?? baseURL
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
    modelDecision: TKWorkspaceModelDecision,
    artifactIndex: Int = 0,
    fromScreenID: String = "screen_0000",
    toScreenID: String? = nil,
    appendAtlasDelta: Bool = false,
    writeFlow: Bool = true
) throws {
    let suffix = workspaceArtifactSuffix(artifactIndex)
    let graphSuffix = workspaceGraphSuffix(artifactIndex)
    let transitionID = "transition_\(graphSuffix)"
    let resolvedToScreenID = toScreenID ?? (postActionObservation == nil ? fromScreenID : "screen_0001")
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
        to: runDir.appendingPathComponent("evidence/model/bootstrap-proposal-\(suffix)-request.redacted.json")
    )
    try workspaceWriteRawModelResponse(
        modelDecision.bootstrapResponseText,
        to: runDir.appendingPathComponent("evidence/model/bootstrap-proposal-\(suffix)-response.raw.txt")
    )
    try writeWorkspaceJSONArtifact([
        "summary": modelDecision.summary,
        "command": command,
        "confidence": modelDecision.confidence,
        "candidateSource": actionCandidate.source,
        "evidenceId": "ev_0000",
        "expected": modelDecision.expected,
        "artifacts": [
            "request": "evidence/model/bootstrap-proposal-\(suffix)-request.redacted.json",
            "response": "evidence/model/bootstrap-proposal-\(suffix)-response.raw.txt",
        ],
    ], to: runDir.appendingPathComponent("evidence/model/bootstrap-proposal-\(suffix).json"))
    try writeWorkspaceJSONArtifact(
        workspaceModelDecisionRequestArtifact(
            run: run,
            mode: mode,
            task: "decide",
            bootstrapProposalRef: "evidence/model/bootstrap-proposal-\(suffix).json",
            modelRequest: modelRequest,
            modelDecision: modelDecision
        ),
        to: runDir.appendingPathComponent("evidence/model/decision-\(suffix)-request.redacted.json")
    )
    try workspaceWriteRawModelResponse(
        modelDecision.decisionResponseText,
        to: runDir.appendingPathComponent("evidence/model/decision-\(suffix)-response.raw.txt")
    )
    try writeWorkspaceJSONArtifact([
        "summary": modelDecision.summary,
        "command": command,
        "confidence": modelDecision.confidence,
        "candidateSource": actionCandidate.source,
        "usedVLM": modelDecision.usedVLM,
        "artifacts": [
            "request": "evidence/model/decision-\(suffix)-request.redacted.json",
            "response": "evidence/model/decision-\(suffix)-response.raw.txt",
        ],
    ], to: runDir.appendingPathComponent("evidence/model/decision-\(suffix).json"))
    if !policyAllowed {
        try writeWorkspaceJSONArtifact([
            "allowed": false,
            "reason": "runner allowedActions does not include \(actionCandidate.action)",
            "stopReason": "policy_rejected",
            "action": actionCandidate.action,
            "allowedActions": run.runner?.allowedActions ?? defaultWorkspaceRunnerAllowedActions,
            "command": command,
        ], to: runDir.appendingPathComponent("evidence/model/policy-\(suffix).json"))
        try writeWorkspaceJSONArtifact(
            workspaceRecoveryProposalArtifact(
                failureCode: "policy_rejected",
                diagnosisType: "policy_rejected",
                trigger: "policy_rejected",
                legacyKind: "policy_rejected",
                phase: "policy_rejected",
                stepIndex: artifactIndex + 1,
                confidence: 1.0,
                evidenceRefs: [
                    "events.jsonl#model.decided",
                    "events.jsonl#policy.checked",
                    "evidence/model/decision-\(suffix).json",
                    "evidence/model/policy-\(suffix).json",
                ],
                proposalAction: "stop",
                proposalReason: "candidate action is outside runner allowedActions",
                policyDecision: "rejected",
                command: ["stop"],
                nextActions: [
                    [
                        "code": "review_policy_rejection",
                        "message": "Inspect evidence/model/policy-\(suffix).json and either adjust allowedActions or ask the model for an allowed action.",
                    ],
                ]
            ),
            to: runDir.appendingPathComponent("evidence/model/recovery-\(suffix).json")
        )
        return
    }
    try writeWorkspaceJSONArtifact([
        "allowed": true,
        "reason": "\(mode) command is allowed by the bounded runner policy",
        "command": command,
    ], to: runDir.appendingPathComponent("evidence/model/policy-\(suffix).json"))
    if let actionExecution {
        try writeWorkspaceJSONArtifact(
            try workspaceActionExecutionArtifact(actionExecution, runDir: runDir, artifactIndex: artifactIndex),
            to: runDir.appendingPathComponent("evidence/actions/action-\(suffix).json")
        )
    } else {
        try writeWorkspaceJSONArtifact([
            "ok": true,
            "mode": mode,
            "command": command,
        ], to: runDir.appendingPathComponent("evidence/actions/action-\(suffix).json"))
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
        ], to: runDir.appendingPathComponent("evidence/model/verify-\(suffix).json"))
        if !businessCheckpoint.ready {
            let canContinue = artifactIndex + 1 < (run.runner?.maxSteps ?? defaultWorkspaceRunnerMaxSteps)
            let proposalAction = canContinue ? "continue" : "stop"
            var proposal: [String: Any] = [
                "action": proposalAction,
                "reason": canContinue
                    ? "business checkpoint did not pass; continue from the latest post-action observation within runner bounds"
                    : "business checkpoint did not pass and runner maxSteps is exhausted",
                "policyDecision": canContinue ? "allowed" : "blocked_by_runner_bounds",
                "command": [proposalAction],
                "usesLatestObservation": canContinue,
            ]
            if canContinue {
                proposal["nextStepIndex"] = artifactIndex + 2
            }
            try writeWorkspaceJSONArtifact(
                workspaceRecoveryProposalArtifact(
                    failureCode: "business_checkpoint_missing",
                    diagnosisType: "business_checkpoint_missing",
                    trigger: "business_checkpoint_failed",
                    legacyKind: "post_action_business_not_ready",
                    phase: businessCheckpoint.readiness.phase,
                    stepIndex: artifactIndex + 1,
                    confidence: 0.78,
                    evidenceRefs: [
                        "events.jsonl#action.executed",
                        "events.jsonl#observation.captured:post_action",
                        "events.jsonl#business.ready",
                        "events.jsonl#verify.checked",
                        "evidence/model/decision-\(suffix).json",
                        "evidence/actions/action-\(suffix).json",
                        businessCheckpoint.readiness.ref,
                        "evidence/model/verify-\(suffix).json",
                    ] + businessCheckpoint.evidenceRefs,
                    proposal: proposal,
                    nextActions: [
                        canContinue
                            ? [
                                "code": "continue_from_latest_observation",
                                "message": "Use the latest post-action observation as the next model input and continue the bounded loop.",
                            ]
                            : [
                                "code": "inspect_business_checkpoint_missing",
                                "message": "Runner bounds are exhausted; inspect business readiness evidence before retrying with a larger maxSteps or a revised goal.",
                            ],
                    ],
                    extraFields: [
                        "businessRef": businessCheckpoint.readiness.ref,
                        "businessQuery": businessCheckpoint.readiness.query,
                        "businessCheck": businessCheckpoint.readiness.check,
                    ]
                ),
                to: runDir.appendingPathComponent("evidence/model/recovery-\(suffix).json")
            )
        }
    } else {
        try writeWorkspaceJSONArtifact([
            "status": "failed",
            "reason": actionExecution == nil
                ? "\(mode) simulates expected screen missing"
                : "action executed without a post-action business verification request",
        ], to: runDir.appendingPathComponent("evidence/model/verify-\(suffix).json"))
        let diagnosisType = actionExecution == nil ? "selector_drift" : "post_action_unverified"
        try writeWorkspaceJSONArtifact(
            workspaceRecoveryProposalArtifact(
                failureCode: "expected_screen_missing",
                diagnosisType: diagnosisType,
                trigger: "verification_failed",
                legacyKind: diagnosisType,
                phase: "selector_drift",
                stepIndex: artifactIndex + 1,
                confidence: 0.68,
                evidenceRefs: [
                    "events.jsonl#verify.checked",
                    "evidence/model/verify-\(suffix).json",
                    "evidence/model/decision-\(suffix).json",
                ],
                proposalAction: "stop",
                proposalReason: "verification failed without a safe bounded recovery action",
                policyDecision: "requires_review",
                command: ["stop"],
                nextActions: [
                    [
                        "code": "inspect_verification_failure",
                        "message": "Inspect model and verification evidence, then re-observe the target or revise the goal before retrying.",
                    ],
                ]
            ),
            to: runDir.appendingPathComponent("evidence/model/recovery-\(suffix).json")
        )
    }
    let deltaLine = """
    {"deltaId":"atlas_delta_\(graphSuffix)","kind":"transition","transitionId":"\(transitionID)","fromScreenId":"\(fromScreenID)","toScreenId":"\(resolvedToScreenID)","status":"\(workspaceModelTransitionStatus(actionExecution: actionExecution, businessCheckpoint: businessCheckpoint))","confidence":\(modelDecision.confidence),"evidenceRefs":["events.jsonl#action.executed","events.jsonl#verify.checked","evidence/model/decision-\(suffix).json","evidence/model/verify-\(suffix).json"]}
    """
    try writeWorkspaceAtlasDeltaLine(
        deltaLine,
        to: runDir.appendingPathComponent("atlas/deltas.jsonl"),
        append: appendAtlasDelta
    )
    if writeFlow {
        try """
        schemaVersion: 1
        kind: triton.workspace.flow
        steps:
          - action: \(actionCandidate.action)
            target: "\(yamlEscaped(actionCandidate.query))"
            evidenceRef: events.jsonl#action.executed

        """.write(to: runDir.appendingPathComponent("flow.tritonflow.yaml"), atomically: true, encoding: .utf8)
    }
}

private func workspaceRecoveryProposalArtifact(
    failureCode: String,
    diagnosisType: String,
    trigger: String,
    legacyKind: String,
    phase: String?,
    stepIndex: Int,
    confidence: Double,
    evidenceRefs: [String],
    proposalAction: String,
    proposalReason: String,
    policyDecision: String,
    command: [String],
    nextActions: [[String: Any]],
    extraFields: [String: Any] = [:]
) -> [String: Any] {
    workspaceRecoveryProposalArtifact(
        failureCode: failureCode,
        diagnosisType: diagnosisType,
        trigger: trigger,
        legacyKind: legacyKind,
        phase: phase,
        stepIndex: stepIndex,
        confidence: confidence,
        evidenceRefs: evidenceRefs,
        proposal: [
            "action": proposalAction,
            "reason": proposalReason,
            "policyDecision": policyDecision,
            "command": command,
        ],
        nextActions: nextActions,
        extraFields: extraFields
    )
}

private func workspaceRecoveryProposalArtifact(
    failureCode: String,
    diagnosisType: String,
    trigger: String,
    legacyKind: String,
    phase: String?,
    stepIndex: Int,
    confidence: Double,
    evidenceRefs: [String],
    proposal: [String: Any],
    nextActions: [[String: Any]],
    extraFields: [String: Any] = [:]
) -> [String: Any] {
    let uniqueRefs = uniqueWorkspaceRecoveryEvidenceRefs(evidenceRefs)
    var artifact: [String: Any] = [
        "schemaVersion": 1,
        "kind": "triton.workspace.recovery-proposal",
        "legacyKind": legacyKind,
        "failureCode": failureCode,
        "trigger": trigger,
        "stepIndex": stepIndex,
        "diagnosis": [
            "type": diagnosisType,
            "phase": phase ?? "unknown",
            "confidence": confidence,
            "evidenceRefs": uniqueRefs,
        ],
        "proposal": proposal,
        "proposalAction": proposal["action"] as? String ?? "stop",
        "evidenceRefs": uniqueRefs,
        "nextActions": nextActions,
    ]
    for (key, value) in extraFields {
        artifact[key] = value
    }
    return artifact
}

private func uniqueWorkspaceRecoveryEvidenceRefs(_ refs: [String]) -> [String] {
    var seen = Set<String>()
    var result: [String] = []
    for ref in refs where !ref.isEmpty && !seen.contains(ref) {
        seen.insert(ref)
        result.append(ref)
    }
    return result
}

func writeWorkspaceAtlasDeltaLine(_ line: String, to url: URL, append: Bool) throws {
    let text = line.hasSuffix("\n") ? line : "\(line)\n"
    if append, FileManager.default.fileExists(atPath: url.path) {
        let handle = try FileHandle(forWritingTo: url)
        defer { handle.closeFile() }
        handle.seekToEndOfFile()
        handle.write(Data(text.utf8))
    } else {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
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
