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

    var eventStatus: TKTestRunStatus { ok ? .passed : .failed }
    var exitCode: Int { ok ? 0 : 1 }
}

func workspaceActionExecutionRequest(for request: TKWorkspaceRunRequest) throws -> TKWorkspaceActionExecutionRequest {
    let command = ["triton", "act", "tap", "Continue", "--json"]
    return TKWorkspaceActionExecutionRequest(
        target: request.target,
        host: request.observeHost,
        port: request.observePort,
        platform: request.platform,
        scope: request.scope,
        action: "tap",
        query: "Continue",
        command: command
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

func workspaceActionExecutionArtifact(_ result: TKWorkspaceActionExecutionResult) throws -> [String: Any] {
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
    actionExecution: TKWorkspaceActionExecutionResult?,
    businessCheckpoint: TKWorkspaceBusinessCheckpoint? = nil,
    toScreenID: String = "screen_0000"
) -> [String: Any] {
    [
        "transitionId": "transition_0000",
        "fromScreenId": "screen_0000",
        "toScreenId": toScreenID,
        "action": "tap",
        "selector": [
            "text": "Continue",
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
