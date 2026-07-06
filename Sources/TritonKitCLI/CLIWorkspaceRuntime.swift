import Foundation
import TritonKitShared

struct TKWorkspaceRunRequest {
    let runsDirectory: String
    let runID: String?
    let target: String
    let platform: String?
    let scope: String?
    let app: String
    let goal: String
    let actionPolicy: String
    let dryModelFixture: Bool
    let llmProvider: String?
    let vlmProvider: String?
    let maxSteps: Int?
    let allowedActions: [String]
    let stopConditions: [String]

    init(
        runsDirectory: String,
        runID: String?,
        target: String,
        platform: String? = nil,
        scope: String? = nil,
        app: String,
        goal: String,
        actionPolicy: String,
        dryModelFixture: Bool = false,
        llmProvider: String? = nil,
        vlmProvider: String? = nil,
        maxSteps: Int? = nil,
        allowedActions: [String] = [],
        stopConditions: [String] = []
    ) {
        self.runsDirectory = runsDirectory
        self.runID = runID
        self.target = target
        self.platform = platform
        self.scope = scope
        self.app = app
        self.goal = goal
        self.actionPolicy = actionPolicy
        self.dryModelFixture = dryModelFixture
        self.llmProvider = llmProvider
        self.vlmProvider = vlmProvider
        self.maxSteps = maxSteps
        self.allowedActions = allowedActions
        self.stopConditions = stopConditions
    }
}

struct TKWorkspaceRunResponse: Codable, Equatable {
    let schemaVersion: Int
    let kind: String
    let runID: String
    let goal: String
    let status: String
    let target: TKWorkspaceRunTarget
    let app: String
    let ai: TKWorkspaceRunAI
    let runner: TKWorkspaceRunRunner?
    let paths: TKWorkspaceRunPaths
    let nextActions: [TKWorkspaceNextAction]

    init(
        schemaVersion: Int = 1,
        kind: String = "triton.workspace.run",
        runID: String,
        goal: String,
        status: String,
        target: TKWorkspaceRunTarget,
        app: String,
        ai: TKWorkspaceRunAI,
        runner: TKWorkspaceRunRunner? = nil,
        paths: TKWorkspaceRunPaths,
        nextActions: [TKWorkspaceNextAction]
    ) {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.runID = runID
        self.goal = goal
        self.status = status
        self.target = target
        self.app = app
        self.ai = ai
        self.runner = runner
        self.paths = paths
        self.nextActions = nextActions
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case kind
        case runID = "runId"
        case goal
        case status
        case target
        case app
        case ai
        case runner
        case paths
        case nextActions
    }
}

struct TKWorkspaceRunTarget: Codable, Equatable {
    let id: String
    let platform: String
    let scope: String
    let capabilities: [String]
}

struct TKWorkspaceRunAI: Codable, Equatable {
    let llmEnabled: Bool
    let vlmEnabled: Bool
    let actionPolicy: String
    let providersReady: Bool
    let providerStatus: String
    let llmProvider: String?
    let llmProviderStatus: String?
    let vlmProvider: String?
    let vlmProviderStatus: String?
}

struct TKWorkspaceRunRunner: Codable, Equatable {
    let actionPolicy: String
    let maxSteps: Int
    let allowedActions: [String]
    let stopConditions: [String]
}

struct TKWorkspaceRunPaths: Codable, Equatable {
    let runDir: String
    let events: String
    let report: String
}

struct TKWorkspaceNextAction: Codable, Equatable {
    let code: String
    let message: String
}

private struct TKWorkspaceProviderPreflight {
    let providersReady: Bool
    let providerStatus: String
    let llmProvider: String?
    let llmProviderStatus: String
    let vlmProvider: String?
    let vlmProviderStatus: String
    let providerEventPhase: String
    let bootstrapPhase: String
    let nextActions: [TKWorkspaceNextAction]
}

private struct TKWorkspaceProviderComponentPreflight {
    let provider: String?
    let status: String
    let phase: String
    let nextAction: TKWorkspaceNextAction?

    var ready: Bool { status == "ready" }
}

private let defaultWorkspaceRunnerMaxSteps = 20
private let defaultWorkspaceRunnerAllowedActions = ["tap", "swipe", "type", "wait", "verify", "stop"]
private let defaultWorkspaceRunnerStopConditions = [
    "max_steps_reached",
    "provider_missing",
    "unsupported_capability",
    "policy_rejected",
    "model_unparseable",
]

struct TKWorkspaceInspectResponse: Codable, Equatable {
    let kind: String
    let run: TKWorkspaceRunResponse
    let summary: TKTestRunEventSummary
    let atlas: TKWorkspaceAtlasSummary
    let latestBootstrap: TKTestRunEvent?
}

struct TKWorkspaceAtlasSummary: Codable, Equatable {
    let atlasRef: String
    let deltaRef: String?
    let coverageStatus: String
    let screenCount: Int
    let stateCount: Int
    let transitionCount: Int
}

struct TKWorkspaceExportFlowResponse: Codable, Equatable {
    let kind: String
    let runID: String
    let output: String
    let stepCount: Int

    enum CodingKeys: String, CodingKey {
        case kind
        case runID = "runId"
        case output
        case stepCount
    }
}

private struct TKWorkspaceFlowActionStep {
    let action: String
    let target: String
    let evidenceRef: String
    let modelEvidenceRef: String?
    let policyEvidenceRef: String?
    let verifyEvidenceRef: String?
}

func runWorkspaceRun(_ request: TKWorkspaceRunRequest) throws -> TKWorkspaceRunResponse {
    let runID = try normalizedWorkspaceRunID(request.runID ?? defaultWorkspaceRunID())
    let runDir = workspaceRunDirectory(runID: runID, runsDirectory: request.runsDirectory)
    let paths = TKWorkspaceRunPaths(
        runDir: runDir.path,
        events: runDir.appendingPathComponent("events.jsonl").path,
        report: runDir.appendingPathComponent("report.json").path
    )
    let targetMetadata = workspaceTargetMetadata(platform: request.platform, scope: request.scope)
    let target = TKWorkspaceRunTarget(
        id: request.target,
        platform: targetMetadata.platform,
        scope: targetMetadata.scope,
        capabilities: ["screenshot", "hierarchy", "input"]
    )
    let runner = try workspaceRunnerConfig(for: request)
    let providerPreflight = try workspaceProviderPreflight(request)
    let response = TKWorkspaceRunResponse(
        runID: runID,
        goal: request.goal,
        status: "stopped",
        target: target,
        app: request.app,
        ai: TKWorkspaceRunAI(
            llmEnabled: true,
            vlmEnabled: true,
            actionPolicy: request.actionPolicy,
            providersReady: providerPreflight.providersReady,
            providerStatus: providerPreflight.providerStatus,
            llmProvider: providerPreflight.llmProvider,
            llmProviderStatus: providerPreflight.llmProviderStatus,
            vlmProvider: providerPreflight.vlmProvider,
            vlmProviderStatus: providerPreflight.vlmProviderStatus
        ),
        runner: runner,
        paths: paths,
        nextActions: providerPreflight.nextActions
    )
    let dryDecisionAllowed = request.dryModelFixture
        ? workspaceDryPolicyAllowsAction("tap", run: response)
        : false

    try createWorkspaceRunDirectories(runDir)
    try writeWorkspaceRunConfig(response, to: runDir.appendingPathComponent("config.yaml"))
    try writeWorkspaceRunArtifacts(
        response,
        runDir: runDir,
        includeDryTransition: dryDecisionAllowed
    )
    if request.dryModelFixture {
        try writeWorkspaceDryDecisionArtifacts(
            run: response,
            runDir: runDir,
            policyAllowed: dryDecisionAllowed
        )
    }
    try writeWorkspaceRun(response, to: runDir.appendingPathComponent("run.json"))
    var events = workspaceSkeletonEvents(
        runID: runID,
        providerEventPhase: providerPreflight.providerEventPhase,
        bootstrapPhase: providerPreflight.bootstrapPhase
    )
    if request.dryModelFixture {
        events.insert(
            contentsOf: workspaceDryDecisionEvents(runID: runID, policyAllowed: dryDecisionAllowed),
            at: events.index(before: events.endIndex)
        )
    }
    try writeWorkspaceEvents(events, to: runDir.appendingPathComponent("events.jsonl"))
    try writeWorkspaceRun(response, to: runDir.appendingPathComponent("report.json"))
    return response
}

private func workspaceProviderPreflight(_ request: TKWorkspaceRunRequest) throws -> TKWorkspaceProviderPreflight {
    let llm = try workspaceLLMProviderPreflight(request.llmProvider)
    let vlm = try workspaceVLMProviderPreflight(request.vlmProvider)
    let providersReady = llm.ready && vlm.ready
    let providerStatus = providersReady ? "ready" : (llm.ready || vlm.ready ? "partial" : "missing")

    let nextActions: [TKWorkspaceNextAction]
    if providersReady {
        nextActions = []
    } else if llm.provider == nil, vlm.provider == nil {
        nextActions = [
            TKWorkspaceNextAction(
                code: "configure_ai_provider",
                message: "LLM/VLM are enabled by default; configure a local or approved provider before autonomous actions."
            ),
        ]
    } else {
        nextActions = [llm.nextAction, vlm.nextAction].compactMap { $0 }
    }

    return TKWorkspaceProviderPreflight(
        providersReady: providersReady,
        providerStatus: providerStatus,
        llmProvider: llm.provider,
        llmProviderStatus: llm.status,
        vlmProvider: vlm.provider,
        vlmProviderStatus: vlm.status,
        providerEventPhase: workspaceProviderEventPhase(llm: llm, vlm: vlm),
        bootstrapPhase: workspaceBootstrapPhase(llm: llm, vlm: vlm),
        nextActions: nextActions
    )
}

private func workspaceRunnerConfig(for request: TKWorkspaceRunRequest) throws -> TKWorkspaceRunRunner {
    let maxSteps = request.maxSteps ?? defaultWorkspaceRunnerMaxSteps
    guard maxSteps > 0 else {
        throw RuntimeError("Invalid workspace runner maxSteps: \(maxSteps). It must be greater than 0.")
    }
    return TKWorkspaceRunRunner(
        actionPolicy: normalizedWorkspaceRunnerValue(request.actionPolicy),
        maxSteps: maxSteps,
        allowedActions: normalizedWorkspaceRunnerList(
            request.allowedActions,
            defaultValues: defaultWorkspaceRunnerAllowedActions
        ),
        stopConditions: normalizedWorkspaceRunnerList(
            request.stopConditions,
            defaultValues: defaultWorkspaceRunnerStopConditions
        )
    )
}

private func normalizedWorkspaceRunnerList(_ values: [String], defaultValues: [String]) -> [String] {
    let normalized = values
        .map(normalizedWorkspaceRunnerValue)
        .filter { !$0.isEmpty }
    return normalized.isEmpty ? defaultValues : normalized
}

private func normalizedWorkspaceRunnerValue(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func workspaceDryPolicyAllowsAction(_ action: String, run: TKWorkspaceRunResponse) -> Bool {
    let allowedActions = run.runner?.allowedActions ?? defaultWorkspaceRunnerAllowedActions
    return allowedActions.contains(action)
}

private func workspaceLLMProviderPreflight(_ rawProvider: String?) throws -> TKWorkspaceProviderComponentPreflight {
    guard let rawProvider = rawProvider?.trimmingCharacters(in: .whitespacesAndNewlines),
          !rawProvider.isEmpty
    else {
        return TKWorkspaceProviderComponentPreflight(
            provider: nil,
            status: "missing",
            phase: "llm_missing",
            nextAction: TKWorkspaceNextAction(
                code: "configure_llm_provider",
                message: "Configure the LLM provider before autonomous actions."
            )
        )
    }

    let provider = rawProvider.lowercased()
    switch provider {
    case "mock":
        return TKWorkspaceProviderComponentPreflight(
            provider: provider,
            status: "ready",
            phase: "llm_ready",
            nextAction: nil
        )
    default:
        throw RuntimeError("Unsupported workspace LLM provider \(rawProvider)")
    }
}

private func workspaceVLMProviderPreflight(_ rawProvider: String?) throws -> TKWorkspaceProviderComponentPreflight {
    guard let rawProvider = rawProvider?.trimmingCharacters(in: .whitespacesAndNewlines),
          !rawProvider.isEmpty
    else {
        return TKWorkspaceProviderComponentPreflight(
            provider: nil,
            status: "missing",
            phase: "vlm_missing",
            nextAction: TKWorkspaceNextAction(
                code: "configure_vlm_provider",
                message: "Configure the VLM provider before autonomous actions."
            )
        )
    }

    let provider = rawProvider.lowercased()
    switch provider {
    case "mock":
        _ = try makeVLMProvider(provider)
        return TKWorkspaceProviderComponentPreflight(
            provider: provider,
            status: "ready",
            phase: "vlm_ready",
            nextAction: nil
        )
    case "mlx-swift-lm":
        return TKWorkspaceProviderComponentPreflight(
            provider: provider,
            status: "missing_model",
            phase: "vlm_missing_model",
            nextAction: TKWorkspaceNextAction(
                code: "configure_vlm_provider",
                message: "mlx-swift-lm requires an explicit model or model path before workspace run can use it."
            )
        )
    case "openai-compatible":
        return TKWorkspaceProviderComponentPreflight(
            provider: provider,
            status: "missing_base_url",
            phase: "vlm_missing_base_url",
            nextAction: TKWorkspaceNextAction(
                code: "configure_vlm_provider",
                message: "openai-compatible VLM requires an explicit local base URL and remote upload approval when not localhost."
            )
        )
    default:
        throw RuntimeError("Unsupported workspace VLM provider \(rawProvider)")
    }
}

private func workspaceProviderEventPhase(
    llm: TKWorkspaceProviderComponentPreflight,
    vlm: TKWorkspaceProviderComponentPreflight
) -> String {
    if llm.ready, vlm.ready {
        return "ready"
    }
    if llm.ready {
        return "llm_ready_\(vlm.phase)"
    }
    if vlm.ready {
        return "vlm_ready_\(llm.phase)"
    }
    if llm.provider == nil, vlm.provider == nil {
        return "missing"
    }
    return "\(llm.phase)_\(vlm.phase)"
}

private func workspaceBootstrapPhase(
    llm: TKWorkspaceProviderComponentPreflight,
    vlm: TKWorkspaceProviderComponentPreflight
) -> String {
    if llm.ready, vlm.ready {
        return "provider_ready"
    }
    if !llm.ready, vlm.ready {
        return "llm_missing"
    }
    if llm.ready, !vlm.ready {
        return "vlm_missing"
    }
    return "provider_missing"
}

private func workspaceTargetMetadata(platform: String?, scope: String?) -> (platform: String, scope: String) {
    (
        platform: normalizedWorkspaceTargetValue(platform, defaultValue: "unknown"),
        scope: normalizedWorkspaceTargetValue(scope, defaultValue: "current")
    )
}

private func normalizedWorkspaceTargetValue(_ raw: String?, defaultValue: String) -> String {
    let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    return value.isEmpty ? defaultValue : value
}

func inspectWorkspaceRun(runID: String, runsDirectory: String) throws -> TKWorkspaceInspectResponse {
    let runID = try normalizedWorkspaceRunID(runID)
    let runDir = workspaceRunDirectory(runID: runID, runsDirectory: runsDirectory)
    let run = try JSONDecoder().decode(
        TKWorkspaceRunResponse.self,
        from: Data(contentsOf: runDir.appendingPathComponent("run.json"))
    )
    let parsed = try TKTestRunEventLogParser().parse(
        Data(contentsOf: runDir.appendingPathComponent("events.jsonl"))
    )
    return TKWorkspaceInspectResponse(
        kind: "triton.workspace.inspect",
        run: run,
        summary: parsed.summary,
        atlas: try workspaceAtlasSummary(runDir: runDir),
        latestBootstrap: parsed.events.last { $0.type == .flowBootstrapChecked }
    )
}

func stopWorkspaceRun(runID: String, runsDirectory: String) throws -> TKWorkspaceInspectResponse {
    let runID = try normalizedWorkspaceRunID(runID)
    let runDir = workspaceRunDirectory(runID: runID, runsDirectory: runsDirectory)
    let eventsURL = runDir.appendingPathComponent("events.jsonl")
    let parsed = try TKTestRunEventLogParser().parse(Data(contentsOf: eventsURL))
    if parsed.events.last?.type != .runStopped {
        try appendWorkspaceEvent(.init(
            type: .runStopped,
            runID: runID,
            timestamp: workspaceTimestamp(),
            status: .stopped,
            durationMs: 0
        ), to: eventsURL)
    }
    let runURL = runDir.appendingPathComponent("run.json")
    let run = try JSONDecoder().decode(TKWorkspaceRunResponse.self, from: Data(contentsOf: runURL))
    try writeWorkspaceRun(TKWorkspaceRunResponse(
        runID: run.runID,
        goal: run.goal,
        status: "stopped",
        target: run.target,
        app: run.app,
        ai: run.ai,
        runner: run.runner,
        paths: run.paths,
        nextActions: run.nextActions
    ), to: runURL)
    return try inspectWorkspaceRun(runID: runID, runsDirectory: runsDirectory)
}

func exportWorkspaceFlow(runID: String, runsDirectory: String, output: String) throws -> TKWorkspaceExportFlowResponse {
    let inspected = try inspectWorkspaceRun(runID: runID, runsDirectory: runsDirectory)
    let runDir = workspaceRunDirectory(runID: inspected.run.runID, runsDirectory: runsDirectory)
    let parsed = try TKTestRunEventLogParser().parse(
        Data(contentsOf: runDir.appendingPathComponent("events.jsonl"))
    )
    let actionSteps = workspaceFlowActionSteps(from: parsed.events)
    let yaml = workspaceFlowYAML(run: inspected.run, actionSteps: actionSteps)
    let outputURL = URL(fileURLWithPath: output)
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try yaml.write(to: outputURL, atomically: true, encoding: .utf8)
    return TKWorkspaceExportFlowResponse(
        kind: "triton.workspace.export-flow",
        runID: inspected.run.runID,
        output: outputURL.path,
        stepCount: 3 + actionSteps.count
    )
}

private func workspaceFlowActionSteps(from events: [TKTestRunEvent]) -> [TKWorkspaceFlowActionStep] {
    events.compactMap { event in
        guard event.type == .actionExecuted,
              let command = event.command,
              command.count >= 4,
              command[0] == "triton",
              command[1] == "act"
        else {
            return nil
        }
        let modelRef = workspaceEventRef(
            in: events,
            stepIndex: event.stepIndex,
            type: .modelDecided
        )
        let policyRef = workspaceEventRef(
            in: events,
            stepIndex: event.stepIndex,
            type: .policyChecked
        )
        let verifyRef = workspaceEventRef(
            in: events,
            stepIndex: event.stepIndex,
            type: .verifyChecked
        )
        return TKWorkspaceFlowActionStep(
            action: command[2],
            target: command[3],
            evidenceRef: "events.jsonl#action.executed",
            modelEvidenceRef: modelRef,
            policyEvidenceRef: policyRef,
            verifyEvidenceRef: verifyRef
        )
    }
}

private func workspaceEventRef(
    in events: [TKTestRunEvent],
    stepIndex: Int?,
    type: TKTestRunEventType
) -> String? {
    events.first { $0.type == type && $0.stepIndex == stepIndex }?.ref
}

private func workspaceFlowYAML(
    run: TKWorkspaceRunResponse,
    actionSteps: [TKWorkspaceFlowActionStep]
) -> String {
    var lines = [
        "schemaVersion: 1",
        "kind: triton.workspace.flow",
        "runId: \(run.runID)",
        "goal: \"\(yamlEscaped(run.goal))\"",
        "app: \"\(yamlEscaped(run.app))\"",
        "steps:",
        "  - action: launchApp",
        "    app: \"\(yamlEscaped(run.app))\"",
        "    evidenceRef: events.jsonl#app.ready",
        "  - action: observe",
        "    evidenceRef: events.jsonl#observation.captured",
        "  - action: bootstrapCheck",
        "    evidenceRef: events.jsonl#flow.bootstrap.checked",
    ]
    for step in actionSteps {
        lines.append("  - action: \(step.action)")
        lines.append("    target: \"\(yamlEscaped(step.target))\"")
        lines.append("    evidenceRef: \(step.evidenceRef)")
        if let modelEvidenceRef = step.modelEvidenceRef {
            lines.append("    modelEvidenceRef: \(modelEvidenceRef)")
        }
        if let policyEvidenceRef = step.policyEvidenceRef {
            lines.append("    policyEvidenceRef: \(policyEvidenceRef)")
        }
        if let verifyEvidenceRef = step.verifyEvidenceRef {
            lines.append("    verifyEvidenceRef: \(verifyEvidenceRef)")
        }
    }
    return lines.joined(separator: "\n") + "\n"
}

private func workspaceAtlasSummary(runDir: URL) throws -> TKWorkspaceAtlasSummary {
    let atlasRef = "atlas/atlas.json"
    let atlasURL = runDir.appendingPathComponent(atlasRef)
    let atlas = try JSONSerialization.jsonObject(with: Data(contentsOf: atlasURL)) as? [String: Any]
    let screens = atlas?["screens"] as? [[String: Any]] ?? []
    let states = atlas?["states"] as? [[String: Any]] ?? []
    let transitions = atlas?["transitions"] as? [[String: Any]] ?? []
    let coverage = atlas?["coverage"] as? [String: Any] ?? [:]
    let deltaRef = FileManager.default.fileExists(atPath: runDir.appendingPathComponent("atlas/deltas.jsonl").path)
        ? "atlas/deltas.jsonl"
        : nil
    return TKWorkspaceAtlasSummary(
        atlasRef: atlasRef,
        deltaRef: deltaRef,
        coverageStatus: coverage["status"] as? String ?? "unknown",
        screenCount: coverage["screenCount"] as? Int ?? screens.count,
        stateCount: coverage["stateCount"] as? Int ?? states.count,
        transitionCount: coverage["transitionCount"] as? Int ?? transitions.count
    )
}

private func createWorkspaceRunDirectories(_ runDir: URL) throws {
    for relativePath in [
        "",
        "evidence/screenshots",
        "evidence/hierarchy",
        "evidence/model",
        "evidence/actions",
        "atlas",
    ] {
        try FileManager.default.createDirectory(
            at: relativePath.isEmpty ? runDir : runDir.appendingPathComponent(relativePath, isDirectory: true),
            withIntermediateDirectories: true
        )
    }
}

private func writeWorkspaceRunArtifacts(
    _ run: TKWorkspaceRunResponse,
    runDir: URL,
    includeDryTransition: Bool
) throws {
    try writeWorkspaceJSONArtifact([
        "target": run.target.id,
        "platform": run.target.platform,
        "scope": run.target.scope,
        "capabilities": run.target.capabilities,
    ], to: runDir.appendingPathComponent("evidence/model/target.json"))
    var providerArtifact: [String: Any] = [
        "llmEnabled": run.ai.llmEnabled,
        "vlmEnabled": run.ai.vlmEnabled,
        "providersReady": run.ai.providersReady,
        "providerStatus": run.ai.providerStatus,
    ]
    if let llmProviderStatus = run.ai.llmProviderStatus {
        providerArtifact["llmProviderStatus"] = llmProviderStatus
    }
    if let llmProvider = run.ai.llmProvider {
        providerArtifact["llmProvider"] = llmProvider
    }
    if let vlmProvider = run.ai.vlmProvider {
        providerArtifact["vlmProvider"] = vlmProvider
    }
    if let vlmProviderStatus = run.ai.vlmProviderStatus {
        providerArtifact["vlmProviderStatus"] = vlmProviderStatus
    }
    try writeWorkspaceJSONArtifact(providerArtifact, to: runDir.appendingPathComponent("evidence/model/provider-check.json"))
    try writeWorkspaceJSONArtifact([
        "app": run.app,
        "ready": false,
        "mode": "dry-skeleton",
    ], to: runDir.appendingPathComponent("evidence/actions/app-ready.json"))
    try "workspace dry screenshot placeholder\n".write(
        to: runDir.appendingPathComponent("evidence/screenshots/0000.txt"),
        atomically: true,
        encoding: .utf8
    )
    try writeWorkspaceJSONArtifact(["nodes": []], to: runDir.appendingPathComponent("evidence/hierarchy/0000.json"))
    try writeWorkspaceJSONArtifact(["ax": []], to: runDir.appendingPathComponent("evidence/hierarchy/0000-ax.json"))
    try writeWorkspaceJSONArtifact([
        "state": workspaceBootstrapState(for: run.ai),
        "ready": false,
        "evidenceId": "ev_0000",
        "proposal": "stop",
    ], to: runDir.appendingPathComponent("evidence/model/bootstrap-000.json"))
    try writeWorkspaceJSONArtifact(
        workspaceAtlasDocument(for: run, includeDryTransition: includeDryTransition),
        to: runDir.appendingPathComponent("atlas/atlas.json")
    )
}

private func writeWorkspaceDryDecisionArtifacts(
    run: TKWorkspaceRunResponse,
    runDir: URL,
    policyAllowed: Bool
) throws {
    let command = ["triton", "act", "tap", "Continue", "--json"]
    try writeWorkspaceJSONArtifact([
        "summary": "Dry fixture selected a single tap candidate.",
        "command": command,
        "confidence": 0.5,
        "usedVLM": true,
    ], to: runDir.appendingPathComponent("evidence/model/decision-000.json"))
    if !policyAllowed {
        try writeWorkspaceJSONArtifact([
            "allowed": false,
            "reason": "runner allowedActions does not include tap",
            "stopReason": "policy_rejected",
            "action": "tap",
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
        "reason": "dry fixture command is low-risk and single-step",
        "command": command,
    ], to: runDir.appendingPathComponent("evidence/model/policy-000.json"))
    try writeWorkspaceJSONArtifact([
        "ok": true,
        "mode": "dry-fixture",
        "command": command,
    ], to: runDir.appendingPathComponent("evidence/actions/action-000.json"))
    try writeWorkspaceJSONArtifact([
        "status": "failed",
        "reason": "dry fixture simulates expected screen missing",
    ], to: runDir.appendingPathComponent("evidence/model/verify-000.json"))
    try writeWorkspaceJSONArtifact([
        "failureCode": "expected_screen_missing",
        "kind": "selector_drift",
        "proposal": "stop",
    ], to: runDir.appendingPathComponent("evidence/model/recovery-000.json"))
    try """
    {"deltaId":"atlas_delta_0000","kind":"transition","transitionId":"transition_0000","fromScreenId":"screen_0000","toScreenId":"screen_0000","status":"candidate_failed","confidence":0.5,"evidenceRefs":["events.jsonl#action.executed","events.jsonl#verify.checked","evidence/model/decision-000.json","evidence/model/verify-000.json"]}
    """.write(to: runDir.appendingPathComponent("atlas/deltas.jsonl"), atomically: true, encoding: .utf8)
    try """
    schemaVersion: 1
    kind: triton.workspace.flow
    steps:
      - action: tap
        evidenceRef: events.jsonl#action.executed

    """.write(to: runDir.appendingPathComponent("flow.tritonflow.yaml"), atomically: true, encoding: .utf8)
}

private func workspaceSkeletonEvents(
    runID: String,
    providerEventPhase: String,
    bootstrapPhase: String
) -> [TKTestRunEvent] {
    let now = workspaceTimestamp()
    return [
        .runStarted(runID: runID, timestamp: now),
        .init(type: .targetResolved, runID: runID, timestamp: now, ref: "evidence/model/target.json"),
        .init(type: .providerChecked, runID: runID, timestamp: now, ref: "evidence/model/provider-check.json", phase: providerEventPhase),
        .init(type: .appReady, runID: runID, timestamp: now, ref: "evidence/actions/app-ready.json", phase: "dry-skeleton"),
        .observationCaptured(
            runID: runID,
            stepIndex: 0,
            phase: "initial",
            artifacts: TKTestRunObservationArtifacts(
                screenshot: "evidence/screenshots/0000.txt",
                ax: "evidence/hierarchy/0000-ax.json",
                hierarchy: "evidence/hierarchy/0000.json"
            ),
            screenCandidate: TKTestRunScreenCandidate(
                screenshotSha256: "placeholder-screenshot",
                axTextHash: "placeholder-ax",
                hierarchySha256: "placeholder-hierarchy",
                visibleTexts: []
            ),
            changed: false,
            timestamp: now
        ),
        .init(
            type: .flowBootstrapChecked,
            runID: runID,
            timestamp: now,
            stepIndex: 0,
            ref: "evidence/model/bootstrap-000.json",
            phase: bootstrapPhase
        ),
        .init(type: .runStopped, runID: runID, timestamp: now, status: .stopped, durationMs: 0),
    ]
}

private func workspaceDryDecisionEvents(runID: String, policyAllowed: Bool) -> [TKTestRunEvent] {
    let now = workspaceTimestamp()
    let command = ["triton", "act", "tap", "Continue", "--json"]
    if !policyAllowed {
        return [
            .init(type: .modelDecided, runID: runID, timestamp: now, stepIndex: 1, command: command, ref: "evidence/model/decision-000.json"),
            .init(type: .policyChecked, runID: runID, timestamp: now, stepIndex: 1, command: command, status: .failed, ref: "evidence/model/policy-000.json"),
            .init(
                type: .flowRecoveryDetected,
                runID: runID,
                timestamp: now,
                stepIndex: 1,
                failure: TKTestRunFailure(
                    type: "policy_rejected",
                    message: "Runner allowedActions rejected dry fixture tap candidate.",
                    artifactRefs: ["evidence/model/policy-000.json"]
                ),
                phase: "policy_rejected"
            ),
            .init(type: .flowRecoveryProposed, runID: runID, timestamp: now, stepIndex: 1, command: ["stop"], ref: "evidence/model/recovery-000.json"),
        ]
    }
    return [
        .init(type: .modelDecided, runID: runID, timestamp: now, stepIndex: 1, command: command, ref: "evidence/model/decision-000.json"),
        .init(type: .policyChecked, runID: runID, timestamp: now, stepIndex: 1, command: command, status: .passed, ref: "evidence/model/policy-000.json"),
        .init(type: .actionExecuted, runID: runID, timestamp: now, stepIndex: 1, command: command, status: .passed, exitCode: 0),
        .init(type: .verifyChecked, runID: runID, timestamp: now, stepIndex: 1, status: .failed, ref: "evidence/model/verify-000.json"),
        .init(
            type: .flowRecoveryDetected,
            runID: runID,
            timestamp: now,
            stepIndex: 1,
            failure: TKTestRunFailure(
                type: "expected_screen_missing",
                message: "Dry fixture simulates selector drift after action.",
                artifactRefs: ["evidence/model/verify-000.json"]
            ),
            phase: "selector_drift"
        ),
        .init(type: .flowRecoveryProposed, runID: runID, timestamp: now, stepIndex: 1, command: ["stop"], ref: "evidence/model/recovery-000.json"),
        .init(
            type: .flowRecoveryRejected,
            runID: runID,
            timestamp: now,
            stepIndex: 1,
            failure: TKTestRunFailure(
                type: "dry_fixture_stop",
                message: "Dry fixture does not execute recovery actions.",
                artifactRefs: ["evidence/model/recovery-000.json"]
            )
        ),
        .init(type: .atlasUpdated, runID: runID, timestamp: now, stepIndex: 1, ref: "atlas/deltas.jsonl"),
        .init(type: .flowUpdated, runID: runID, timestamp: now, ref: "flow.tritonflow.yaml"),
    ]
}

private func writeWorkspaceRun(_ run: TKWorkspaceRunResponse, to url: URL) throws {
    try encodeCompactJSON(run).write(to: url, atomically: true, encoding: .utf8)
}

private func writeWorkspaceEvents(_ events: [TKTestRunEvent], to url: URL) throws {
    let text = try events.map(encodeCompactJSON).joined(separator: "\n") + "\n"
    try text.write(to: url, atomically: true, encoding: .utf8)
}

private func appendWorkspaceEvent(_ event: TKTestRunEvent, to url: URL) throws {
    let line = try encodeCompactJSON(event) + "\n"
    let handle = try FileHandle(forWritingTo: url)
    defer { handle.closeFile() }
    handle.seekToEndOfFile()
    handle.write(Data(line.utf8))
}

private func writeWorkspaceRunConfig(_ run: TKWorkspaceRunResponse, to url: URL) throws {
    let runner = run.runner ?? TKWorkspaceRunRunner(
        actionPolicy: run.ai.actionPolicy,
        maxSteps: defaultWorkspaceRunnerMaxSteps,
        allowedActions: defaultWorkspaceRunnerAllowedActions,
        stopConditions: defaultWorkspaceRunnerStopConditions
    )
    let yaml = """
    llm:
      enabled: true
      provider: \(run.ai.llmProvider ?? "none")
      providerStatus: \(run.ai.llmProviderStatus ?? "missing")
    vlm:
      enabled: true
      provider: \(run.ai.vlmProvider ?? "none")
      providerStatus: \(run.ai.vlmProviderStatus ?? "missing")
    runner:
      actionPolicy: \(runner.actionPolicy)
      maxSteps: \(runner.maxSteps)
      allowedActions:
    \(workspaceYAMLList(runner.allowedActions))
      stopConditions:
    \(workspaceYAMLList(runner.stopConditions))
    provider:
      status: \(run.ai.providerStatus)

    """
    try yaml.write(to: url, atomically: true, encoding: .utf8)
}

private func workspaceYAMLList(_ values: [String]) -> String {
    values
        .map { "    - \($0)" }
        .joined(separator: "\n")
}

private func workspaceBootstrapState(for ai: TKWorkspaceRunAI) -> String {
    if ai.providerStatus == "partial", ai.vlmProviderStatus == "ready" {
        return "llm_missing"
    }
    return "provider_missing"
}

private func workspaceAtlasDocument(
    for run: TKWorkspaceRunResponse,
    includeDryTransition: Bool
) -> [String: Any] {
    let initialObservationRefs = [
        "events.jsonl#observation.captured",
        "evidence/screenshots/0000.txt",
        "evidence/hierarchy/0000.json",
        "evidence/hierarchy/0000-ax.json",
    ]
    let transitions = includeDryTransition ? [workspaceDryTransition()] : []
    return [
        "schemaVersion": 1,
        "kind": "triton.workspace.atlas",
        "runId": run.runID,
        "app": run.app,
        "source": [
            "events": "events.jsonl",
            "mode": "workspace-run-seed",
        ],
        "screens": [
            [
                "screenId": "screen_0000",
                "stateId": "state_0000",
                "signature": "placeholder-screenshot:placeholder-ax:placeholder-hierarchy",
                "dominantTexts": [],
                "semanticTags": [],
                "evidenceRefs": initialObservationRefs,
            ],
        ],
        "states": [
            [
                "stateId": "state_0000",
                "screenId": "screen_0000",
                "phase": "initial",
                "evidenceRefs": initialObservationRefs,
            ],
        ],
        "transitions": transitions,
        "coverage": [
            "status": "seeded",
            "screenCount": 1,
            "stateCount": 1,
            "transitionCount": transitions.count,
        ],
    ]
}

private func workspaceDryTransition() -> [String: Any] {
    [
        "transitionId": "transition_0000",
        "fromScreenId": "screen_0000",
        "toScreenId": "screen_0000",
        "action": "tap",
        "selector": [
            "text": "Continue",
        ],
        "status": "candidate_failed",
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

private func writeWorkspaceJSONArtifact(_ value: [String: Any], to url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url, options: .atomic)
}

private func workspaceRunDirectory(runID: String, runsDirectory: String) -> URL {
    URL(fileURLWithPath: runsDirectory, isDirectory: true)
        .appendingPathComponent(runID, isDirectory: true)
}

private func normalizedWorkspaceRunID(_ raw: String) throws -> String {
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty,
          value.range(of: #"^[A-Za-z0-9_.-]+$"#, options: .regularExpression) != nil,
          !value.contains("..")
    else {
        throw RuntimeError("Invalid workspace run id: \(raw)")
    }
    return value
}

private func defaultWorkspaceRunID() -> String {
    "run_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8))"
}

private func workspaceTimestamp() -> String {
    ISO8601DateFormatter().string(from: Date())
}

private func yamlEscaped(_ value: String) -> String {
    value.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
}
