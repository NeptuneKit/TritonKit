import Foundation
import TritonKitShared

typealias TKWorkspaceActionExecutionProvider = (TKWorkspaceActionExecutionRequest) async throws -> TKWorkspaceActionExecutionResult

struct TKWorkspaceActionExecutionRequest: Equatable {
    let target: String
    let host: String
    let port: Int
    let platform: String?
    let scope: String?
    let action: String
    let query: String?
    let command: [String]
    let vlmGrounding: TKVLMGroundResponse?
}

struct TKWorkspaceActionCandidate: Equatable {
    static let fallback = TKWorkspaceActionCandidate(action: "tap", query: "Continue", source: "fallback.default")

    let action: String
    let query: String
    let source: String

    var command: [String] { ["triton", "act", action, query, "--json"] }
}

struct TKWorkspaceActionExecutionResult {
    let ok: Bool
    let action: String
    let command: [String]
    let proofSource: String
    let sourceCommands: [String]
    let message: String?
    let inputResult: TKInputResult?
    let tapResolution: TapTargetResolution?
    let vlmGrounding: TKVLMGroundResponse?

    init(
        ok: Bool,
        action: String,
        command: [String],
        proofSource: String,
        sourceCommands: [String],
        message: String?,
        inputResult: TKInputResult?,
        tapResolution: TapTargetResolution?,
        vlmGrounding: TKVLMGroundResponse? = nil
    ) {
        self.ok = ok
        self.action = action
        self.command = command
        self.proofSource = proofSource
        self.sourceCommands = sourceCommands
        self.message = message
        self.inputResult = inputResult
        self.tapResolution = tapResolution
        self.vlmGrounding = vlmGrounding
    }

    var eventStatus: TKTestRunStatus { ok ? .passed : .failed }
    var exitCode: Int { ok ? 0 : 1 }
}

func workspaceModelActionCandidate(from observation: TKWorkspaceObservationSeed) -> TKWorkspaceActionCandidate {
    workspaceModelActionCandidate(fromVisibleTexts: observation.screenCandidate.visibleTexts)
}

func workspaceModelActionCandidate(fromVisibleTexts rawVisibleTexts: [String]) -> TKWorkspaceActionCandidate {
    let visibleTexts = rawVisibleTexts
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    let preferredTexts = ["Continue", "Start", "Get Started", "Next", "Login", "Log In", "Sign In"]
    let query = preferredTexts.first { preferred in
        visibleTexts.contains { $0.compare(preferred, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    } ?? visibleTexts.first
    guard let query else { return .fallback }
    return TKWorkspaceActionCandidate(action: "tap", query: query, source: "observation.visibleTexts")
}

func workspaceActionExecutionRequest(
    for request: TKWorkspaceRunRequest,
    candidate: TKWorkspaceActionCandidate,
    vlmGrounding: TKVLMGroundResponse? = nil
) throws -> TKWorkspaceActionExecutionRequest {
    return TKWorkspaceActionExecutionRequest(
        target: request.target,
        host: request.observeHost,
        port: request.observePort,
        platform: request.platform,
        scope: request.scope,
        action: candidate.action,
        query: candidate.query,
        command: candidate.command,
        vlmGrounding: vlmGrounding
    )
}

func workspaceDefaultActionExecutionProvider(
    _ request: TKWorkspaceActionExecutionRequest
) async throws -> TKWorkspaceActionExecutionResult {
    guard request.action == "tap", let query = request.query else {
        throw RuntimeError("Workspace action execution currently supports tap text candidates only.")
    }
    let (_, client) = try await resolveRuntimeClient(
        target: request.target,
        host: request.host,
        port: request.port,
        jsonError: true
    )
    if let grounding = request.vlmGrounding {
        let point = grounding.point.runtimePoint
        let input = try await executeInputRequest(
            .tap(x: point.x, y: point.y, targetOID: nil, width: nil, height: nil, duration: nil),
            client: client
        )
        return TKWorkspaceActionExecutionResult(
            ok: input.ok,
            action: request.action,
            command: request.command,
            proofSource: "vlm.grounding+runtime.input",
            sourceCommands: [
                request.command.map(shellEscaped).joined(separator: " "),
                "vlm grounding \(grounding.provider) \(grounding.target)",
                "runtime input \(request.action) \(formatDouble(point.x)),\(formatDouble(point.y))",
            ],
            message: input.message,
            inputResult: input,
            tapResolution: nil,
            vlmGrounding: grounding
        )
    }
    let resolution = try await resolveTapTarget(
        query,
        client: client,
        width: nil,
        height: nil,
        duration: nil,
        activationStrategy: .smart,
        includeCandidates: true
    )
    let input = try await executeInputRequest(resolution.request, client: client)
    return TKWorkspaceActionExecutionResult(
        ok: input.ok,
        action: request.action,
        command: request.command,
        proofSource: "runtime.input",
        sourceCommands: [
            request.command.map(shellEscaped).joined(separator: " "),
            "runtime input \(request.action)",
        ],
        message: input.message,
        inputResult: input,
        tapResolution: resolution
    )
}

func workspaceActionExecutionArtifact(
    _ result: TKWorkspaceActionExecutionResult,
    runDir: URL,
    artifactIndex: Int = 0
) throws -> [String: Any] {
    var artifact: [String: Any] = [
        "schemaVersion": 1,
        "kind": "triton.workspace.action-execution",
        "ok": result.ok,
        "mode": "live-action",
        "action": result.action,
        "command": result.command,
        "proofSource": result.proofSource,
        "source": "workspace.action-provider",
        "sourceCommands": result.sourceCommands,
    ]
    if let message = result.message {
        artifact["message"] = message
    }
    if let inputResult = result.inputResult {
        artifact["inputResult"] = try workspaceEncodableJSONObject(inputResult)
    }
    if let tapResolution = result.tapResolution {
        artifact["tapResolution"] = try workspaceEncodableJSONObject(tapResolution)
    }
    if let grounding = result.vlmGrounding {
        artifact["usedVLMGrounding"] = true
        artifact["vlmGrounding"] = workspaceVLMGroundingActionArtifact(
            grounding,
            runDir: runDir,
            artifactIndex: artifactIndex
        )
    } else {
        artifact["usedVLMGrounding"] = false
    }
    return artifact
}

func workspaceModelTransitionStatus(
    actionExecution: TKWorkspaceActionExecutionResult?,
    businessCheckpoint: TKWorkspaceBusinessCheckpoint? = nil
) -> String {
    guard let actionExecution else { return "candidate_failed" }
    guard actionExecution.ok else { return "action_failed" }
    if businessCheckpoint?.stage == .postAction {
        return businessCheckpoint?.ready == true ? "verified" : "verification_failed"
    }
    return "executed_unverified"
}

func workspaceModelTransition(
    actionCandidate: TKWorkspaceActionCandidate = .fallback,
    actionExecution: TKWorkspaceActionExecutionResult?,
    businessCheckpoint: TKWorkspaceBusinessCheckpoint? = nil,
    toScreenID: String = "screen_0000"
) -> [String: Any] {
    [
        "transitionId": "transition_0000",
        "fromScreenId": "screen_0000",
        "toScreenId": toScreenID,
        "action": actionCandidate.action,
        "selector": [
            "text": actionCandidate.query,
        ],
        "status": workspaceModelTransitionStatus(
            actionExecution: actionExecution,
            businessCheckpoint: businessCheckpoint
        ),
        "confidence": 0.5,
        "evidenceRefs": [
            "events.jsonl#model.decided",
            "events.jsonl#policy.checked",
            "events.jsonl#action.executed",
            "events.jsonl#verify.checked",
            "evidence/model/decision-000.json",
            "evidence/model/policy-000.json",
            "evidence/actions/action-000.json",
            "evidence/model/verify-000.json",
        ],
    ]
}

private func workspaceEncodableJSONObject<T: Encodable>(_ value: T) throws -> Any {
    let data = try JSONEncoder().encode(value)
    return try JSONSerialization.jsonObject(with: data)
}

private func workspaceVLMGroundingActionArtifact(
    _ grounding: TKVLMGroundResponse,
    runDir: URL,
    artifactIndex: Int = 0
) -> [String: Any] {
    let suffix = workspaceArtifactSuffix(artifactIndex)
    var payload: [String: Any] = [
        "ref": "evidence/actions/vlm-\(suffix)/vlm-grounding.json",
        "provider": grounding.provider,
        "target": grounding.target,
        "coordinateSpace": grounding.point.coordinateSpace,
        "runtimePoint": [
            "x": grounding.point.runtimePoint.x,
            "y": grounding.point.runtimePoint.y,
        ],
        "normalized": [
            "x": grounding.point.normalized.x,
            "y": grounding.point.normalized.y,
            "scale": grounding.point.normalized.scale,
        ],
        "coordinateContract": workspaceRelativeArtifactPath(grounding.coordinateContract.path, runDir: runDir),
        "overlay": workspaceRelativeArtifactPath(grounding.artifacts.overlay, runDir: runDir),
        "request": workspaceRelativeArtifactPath(grounding.artifacts.request, runDir: runDir),
        "response": workspaceRelativeArtifactPath(grounding.artifacts.response, runDir: runDir),
    ]
    if let model = grounding.model {
        payload["model"] = model
    }
    if let baseURL = grounding.baseURL {
        payload["baseURL"] = baseURL
    }
    if let rawOutput = grounding.artifacts.rawOutput {
        payload["rawOutput"] = workspaceRelativeArtifactPath(rawOutput, runDir: runDir)
    }
    if let parsedPoint = grounding.artifacts.parsedPoint {
        payload["parsedPoint"] = workspaceRelativeArtifactPath(parsedPoint, runDir: runDir)
    }
    if let transform = grounding.artifacts.transform {
        payload["transform"] = workspaceRelativeArtifactPath(transform, runDir: runDir)
    }
    if let modelMetadata = grounding.artifacts.modelMetadata {
        payload["modelMetadata"] = workspaceRelativeArtifactPath(modelMetadata, runDir: runDir)
    }
    return payload
}

func workspaceRelativeArtifactPath(_ path: String, runDir: URL) -> String {
    let runPath = runDir.standardizedFileURL.path
    let artifactPath = URL(fileURLWithPath: path).standardizedFileURL.path
    guard artifactPath.hasPrefix(runPath + "/") else {
        return path
    }
    return String(artifactPath.dropFirst(runPath.count + 1))
}
