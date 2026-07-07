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
    let appMode: String
    let bundleID: String?
    let packageName: String?
    let activity: String?
    let bundle: String?
    let ability: String?
    let adb: String
    let dryModelFixture: Bool
    let llmProvider: String?
    let vlmProvider: String?
    let maxSteps: Int?
    let allowedActions: [String]
    let stopConditions: [String]
    let observationFixture: String?
    let observeLive: Bool
    let observeKind: String
    let observeMaxNodes: Int?
    let observeOutput: String?
    let observeRuntimeBaseURL: String?
    let observeHost: String
    let observePort: Int
    let hdc: String
    let businessReadyText: String?
    let businessReadyLiveWait: Bool
    let businessReadyTimeout: Double
    let businessReadyInterval: Double
    let executeActions: Bool

    init(
        runsDirectory: String,
        runID: String?,
        target: String,
        platform: String? = nil,
        scope: String? = nil,
        app: String,
        goal: String,
        actionPolicy: String,
        appMode: String = "dry",
        bundleID: String? = nil,
        packageName: String? = nil,
        activity: String? = nil,
        bundle: String? = nil,
        ability: String? = nil,
        adb: String = "adb",
        dryModelFixture: Bool = false,
        llmProvider: String? = nil,
        vlmProvider: String? = nil,
        maxSteps: Int? = nil,
        allowedActions: [String] = [],
        stopConditions: [String] = [],
        observationFixture: String? = nil,
        observeLive: Bool = false,
        observeKind: String = "tree",
        observeMaxNodes: Int? = nil,
        observeOutput: String? = nil,
        observeRuntimeBaseURL: String? = nil,
        observeHost: String = "127.0.0.1",
        observePort: Int = 19421,
        hdc: String = "hdc",
        businessReadyText: String? = nil,
        businessReadyLiveWait: Bool = false,
        businessReadyTimeout: Double = 10,
        businessReadyInterval: Double = 0.5,
        executeActions: Bool = false
    ) {
        self.runsDirectory = runsDirectory
        self.runID = runID
        self.target = target
        self.platform = platform
        self.scope = scope
        self.app = app
        self.goal = goal
        self.actionPolicy = actionPolicy
        self.appMode = appMode
        self.bundleID = bundleID
        self.packageName = packageName
        self.activity = activity
        self.bundle = bundle
        self.ability = ability
        self.adb = adb
        self.dryModelFixture = dryModelFixture
        self.llmProvider = llmProvider
        self.vlmProvider = vlmProvider
        self.maxSteps = maxSteps
        self.allowedActions = allowedActions
        self.stopConditions = stopConditions
        self.observationFixture = observationFixture
        self.observeLive = observeLive
        self.observeKind = observeKind
        self.observeMaxNodes = observeMaxNodes
        self.observeOutput = observeOutput
        self.observeRuntimeBaseURL = observeRuntimeBaseURL
        self.observeHost = observeHost
        self.observePort = observePort
        self.hdc = hdc
        self.businessReadyText = businessReadyText
        self.businessReadyLiveWait = businessReadyLiveWait
        self.businessReadyTimeout = businessReadyTimeout
        self.businessReadyInterval = businessReadyInterval
        self.executeActions = executeActions
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
    let business: TKWorkspaceBusinessReadiness?
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
        business: TKWorkspaceBusinessReadiness? = nil,
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
        self.business = business
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
        case business
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

struct TKWorkspaceBusinessReadiness: Codable, Equatable {
    let ready: Bool
    let status: String
    let check: String
    let query: String
    let phase: String
    let ref: String

    init(
        ready: Bool,
        status: String,
        check: String = "visible_text",
        query: String,
        phase: String,
        ref: String = "evidence/business/ready.json"
    ) {
        self.ready = ready
        self.status = status
        self.check = check
        self.query = query
        self.phase = phase
        self.ref = ref
    }
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

struct TKWorkspaceProviderPreflight {
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

struct TKWorkspaceProviderComponentPreflight {
    let provider: String?
    let status: String
    let phase: String
    let nextAction: TKWorkspaceNextAction?

    var ready: Bool { status == "ready" }
}

struct TKWorkspaceRunFinalState {
    let runStatus: String
    let eventType: TKTestRunEventType
    let eventStatus: TKTestRunStatus
    let phase: String?
}

let defaultWorkspaceRunnerMaxSteps = 20
let defaultWorkspaceRunnerAllowedActions = ["tap", "swipe", "type", "wait", "verify", "stop"]
let defaultWorkspaceRunnerStopConditions = [
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
    let latestBootstrapProposal: TKTestRunEvent?
    let latestPause: TKTestRunEvent?
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
    if request.businessReadyLiveWait {
        throw RuntimeError("Workspace business live wait requires the async workspace runtime.")
    }
    if request.executeActions {
        throw RuntimeError("Workspace action execution requires the async workspace runtime.")
    }
    let appLifecycle = try workspaceAppLifecycleEvidence(for: request)
    let observationSeed = try workspaceObservationSeed(for: request)
    return try runWorkspaceRun(request, observationSeed: observationSeed, appLifecycle: appLifecycle)
}

func runWorkspaceRunAsync(
    _ request: TKWorkspaceRunRequest,
    observeProvider: TKWorkspaceLiveObserveProvider = workspaceDefaultLiveObserveProvider,
    appLifecycleProvider: TKWorkspaceAppLifecycleProvider = workspaceDefaultAppLifecycleProvider,
    businessWaitProvider: TKWorkspaceBusinessWaitProvider = workspaceDefaultBusinessWaitProvider,
    modelDecisionProvider: TKWorkspaceModelDecisionProvider = workspaceDefaultModelDecisionProvider,
    actionExecutionProvider: TKWorkspaceActionExecutionProvider = workspaceDefaultActionExecutionProvider
) async throws -> TKWorkspaceRunResponse {
    let appLifecycle = try await workspaceAppLifecycleEvidence(for: request, provider: appLifecycleProvider)
    let observationSeed = try await workspaceObservationSeed(for: request, observeProvider: observeProvider)
    let runner = try workspaceRunnerConfig(for: request)
    let providerPreflight = try workspaceProviderPreflight(request)
    let modelLoopMode = workspaceModelLoopMode(for: request)
    let modelLoopEnabled = request.dryModelFixture || providerPreflight.providersReady
    let modelDecision = modelLoopEnabled
        ? try await modelDecisionProvider(workspaceModelDecisionRequest(
            for: request,
            observation: observationSeed,
            runner: runner,
            providerPreflight: providerPreflight,
            mode: modelLoopMode
        ))
        : nil
    let actionCandidate = modelDecision?.candidate ?? workspaceModelActionCandidate(from: observationSeed)
    let appReady = workspaceAppReadyEvidence(
        lifecycle: appLifecycle,
        observation: observationSeed,
        observedAfterLifecycle: request.observeLive
    )
    let initialBusinessCheckpoint = request.executeActions
        ? workspaceBusinessVisibleTextCheckpoint(for: request, observation: observationSeed, appReady: appReady)
        : nil
    let actionExecution: TKWorkspaceActionExecutionResult?
    if try workspaceShouldExecuteCandidateAction(
        request,
        businessCheckpoint: initialBusinessCheckpoint,
        actionCandidate: actionCandidate
    ) {
        actionExecution = try await actionExecutionProvider(workspaceActionExecutionRequest(
            for: request,
            candidate: actionCandidate
        ))
    } else {
        actionExecution = nil
    }
    let postActionObservation: TKWorkspaceObservationSeed?
    if request.observeLive, actionExecution?.ok == true {
        postActionObservation = try await workspaceObservationSeed(for: request, observeProvider: observeProvider)
    } else {
        postActionObservation = nil
    }
    let businessWaitResult: TKWaitResult?
    let businessCheckpoint: TKWorkspaceBusinessCheckpoint?
    if request.businessReadyLiveWait, initialBusinessCheckpoint?.ready == true {
        businessWaitResult = nil
        businessCheckpoint = initialBusinessCheckpoint
    } else if request.businessReadyLiveWait, actionExecution?.ok == true {
        let waitResult = try await businessWaitProvider(workspaceBusinessWaitRequest(for: request))
        businessWaitResult = waitResult
        businessCheckpoint = workspaceBusinessCheckpoint(
            for: request,
            observation: observationSeed,
            appReady: appReady,
            waitResult: waitResult,
            stage: .postAction
        )
    } else if request.businessReadyLiveWait {
        let waitResult = try await businessWaitProvider(workspaceBusinessWaitRequest(for: request))
        businessWaitResult = waitResult
        businessCheckpoint = workspaceBusinessCheckpoint(
            for: request,
            observation: observationSeed,
            appReady: appReady,
            waitResult: waitResult
        )
    } else {
        businessWaitResult = nil
        businessCheckpoint = workspaceBusinessCheckpoint(
            for: request,
            observation: observationSeed,
            appReady: appReady,
            waitResult: nil
        )
    }
    return try runWorkspaceRun(
        request,
        observationSeed: observationSeed,
        appLifecycle: appLifecycle,
        businessWaitResult: businessWaitResult,
        businessCheckpoint: businessCheckpoint,
        actionExecution: actionExecution,
        postActionObservation: postActionObservation,
        actionCandidate: actionCandidate,
        modelDecision: modelDecision
    )
}

private func runWorkspaceRun(
    _ request: TKWorkspaceRunRequest,
    observationSeed: TKWorkspaceObservationSeed,
    appLifecycle: TKWorkspaceAppLifecycleEvidence,
    businessWaitResult: TKWaitResult? = nil,
    businessCheckpoint: TKWorkspaceBusinessCheckpoint? = nil,
    actionExecution: TKWorkspaceActionExecutionResult? = nil,
    postActionObservation: TKWorkspaceObservationSeed? = nil,
    actionCandidate: TKWorkspaceActionCandidate? = nil,
    modelDecision: TKWorkspaceModelDecision? = nil
) throws -> TKWorkspaceRunResponse {
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
    let modelLoopEnabled = request.dryModelFixture || providerPreflight.providersReady
    let modelLoopMode = workspaceModelLoopMode(for: request)
    let modelDecisionRequest = workspaceModelDecisionRequest(
        for: request,
        observation: observationSeed,
        runner: runner,
        providerPreflight: providerPreflight,
        mode: modelLoopMode
    )
    let modelDecision = modelLoopEnabled
        ? (modelDecision ?? workspaceDefaultModelDecision(modelDecisionRequest))
        : nil
    let actionCandidate = actionCandidate ?? modelDecision?.candidate ?? workspaceModelActionCandidate(from: observationSeed)
    let modelDecisionAllowed = modelLoopEnabled
        ? workspacePolicyAllowsAction(actionCandidate.action, runner: runner)
        : false
    let appReady = workspaceAppReadyEvidence(
        lifecycle: appLifecycle,
        observation: observationSeed,
        observedAfterLifecycle: request.observeLive
    )
    let businessCheckpoint = businessCheckpoint ?? workspaceBusinessCheckpoint(
        for: request,
        observation: observationSeed,
        appReady: appReady,
        waitResult: businessWaitResult
    )
    let businessReady = businessCheckpoint?.readiness
    let shouldWriteModelDecision = modelLoopEnabled
        && modelDecisionAllowed
        && (businessCheckpoint?.ready != true || actionExecution != nil)
    let shouldWritePolicyRejection = modelLoopEnabled && !modelDecisionAllowed && businessCheckpoint?.ready != true
    let finalState = workspaceRunFinalState(
        providerPreflight: providerPreflight,
        dryModelFixture: request.dryModelFixture,
        modelLoopEnabled: modelLoopEnabled,
        modelDecisionAllowed: modelDecisionAllowed,
        businessCheckpoint: businessCheckpoint,
        actionExecution: actionExecution
    )
    let response = TKWorkspaceRunResponse(
        runID: runID,
        goal: request.goal,
        status: finalState.runStatus,
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
        business: businessReady,
        paths: paths,
        nextActions: workspaceRunNextActions(
            providerNextActions: providerPreflight.nextActions,
            finalState: finalState,
            businessCheckpoint: businessCheckpoint,
            actionExecution: actionExecution
        )
    )

    try createWorkspaceRunDirectories(runDir)
    try writeWorkspaceRunConfig(response, to: runDir.appendingPathComponent("config.yaml"))
    try writeWorkspaceRunArtifacts(
        response,
        runDir: runDir,
        observation: observationSeed,
        appReady: appReady,
        businessCheckpoint: businessCheckpoint,
        includeModelTransition: shouldWriteModelDecision,
        actionExecution: actionExecution,
        postActionObservation: postActionObservation,
        actionCandidate: actionCandidate
    )
    if shouldWriteModelDecision || shouldWritePolicyRejection {
        try writeWorkspaceModelDecisionArtifacts(
            run: response,
            runDir: runDir,
            mode: modelLoopMode,
            policyAllowed: modelDecisionAllowed,
            businessCheckpoint: businessCheckpoint,
            actionExecution: actionExecution,
            postActionObservation: postActionObservation,
            modelRequest: modelDecisionRequest,
            modelDecision: modelDecision ?? workspaceDefaultModelDecision(modelDecisionRequest)
        )
    }
    try writeWorkspaceRun(response, to: runDir.appendingPathComponent("run.json"))
    var events = workspaceSkeletonEvents(
        runID: runID,
        providerEventPhase: providerPreflight.providerEventPhase,
        bootstrapPhase: providerPreflight.bootstrapPhase,
        appReady: appReady,
        observation: observationSeed,
        businessCheckpoint: businessCheckpoint,
        finalState: finalState
    )
    if shouldWriteModelDecision || shouldWritePolicyRejection {
        events.insert(
            contentsOf: workspaceModelDecisionEvents(
                runID: runID,
                mode: modelLoopMode,
                policyAllowed: modelDecisionAllowed,
                businessCheckpoint: businessCheckpoint,
                actionExecution: actionExecution,
                postActionObservation: postActionObservation,
                actionCandidate: actionCandidate
            ),
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

private func workspacePolicyAllowsAction(_ action: String, runner: TKWorkspaceRunRunner) -> Bool {
    runner.allowedActions.contains(action)
}

private func workspaceRunFinalState(
    providerPreflight: TKWorkspaceProviderPreflight,
    dryModelFixture: Bool,
    modelLoopEnabled: Bool,
    modelDecisionAllowed: Bool,
    businessCheckpoint: TKWorkspaceBusinessCheckpoint?,
    actionExecution: TKWorkspaceActionExecutionResult?
) -> TKWorkspaceRunFinalState {
    if businessCheckpoint?.ready == true {
        return TKWorkspaceRunFinalState(
            runStatus: "passed",
            eventType: .runFinished,
            eventStatus: .passed,
            phase: nil
        )
    }
    if let actionExecution, !actionExecution.ok {
        return TKWorkspaceRunFinalState(
            runStatus: "paused",
            eventType: .runPaused,
            eventStatus: .paused,
            phase: "action_failed"
        )
    }
    if let businessCheckpoint, !businessCheckpoint.ready {
        return TKWorkspaceRunFinalState(
            runStatus: "paused",
            eventType: .runPaused,
            eventStatus: .paused,
            phase: businessCheckpoint.readiness.phase
        )
    }
    if !providerPreflight.providersReady, !dryModelFixture {
        return TKWorkspaceRunFinalState(
            runStatus: "paused",
            eventType: .runPaused,
            eventStatus: .paused,
            phase: providerPreflight.bootstrapPhase
        )
    }
    if modelLoopEnabled, !modelDecisionAllowed {
        return TKWorkspaceRunFinalState(
            runStatus: "paused",
            eventType: .runPaused,
            eventStatus: .paused,
            phase: "policy_rejected"
        )
    }
    if !providerPreflight.providersReady {
        return TKWorkspaceRunFinalState(
            runStatus: "paused",
            eventType: .runPaused,
            eventStatus: .paused,
            phase: providerPreflight.bootstrapPhase
        )
    }
    return TKWorkspaceRunFinalState(
        runStatus: "stopped",
        eventType: .runStopped,
        eventStatus: .stopped,
        phase: nil
    )
}

private func workspaceRunNextActions(
    providerNextActions: [TKWorkspaceNextAction],
    finalState: TKWorkspaceRunFinalState,
    businessCheckpoint: TKWorkspaceBusinessCheckpoint?,
    actionExecution: TKWorkspaceActionExecutionResult?
) -> [TKWorkspaceNextAction] {
    if let actionExecution, !actionExecution.ok {
        return [
            TKWorkspaceNextAction(
                code: "inspect_action_failure",
                message: "The candidate action '\(actionExecution.action)' failed; inspect evidence/actions/action-000.json, observe the target again, or let the model propose a recovery action."
            ),
        ] + providerNextActions
    }
    if let businessCheckpoint, !businessCheckpoint.ready {
        return [
            TKWorkspaceNextAction(
                code: "business_checkpoint_missing",
                message: "The business checkpoint '\(businessCheckpoint.readiness.query)' did not pass via \(businessCheckpoint.readiness.check) (\(businessCheckpoint.readiness.phase)); run live observe/wait or let the model propose a recovery action."
            ),
        ] + providerNextActions
    }
    if !providerNextActions.isEmpty {
        return providerNextActions
    }
    if finalState.phase == "policy_rejected" {
        return [
            TKWorkspaceNextAction(
                code: "review_policy_rejection",
                message: "Policy rejected the candidate action; adjust runner allowedActions, revise the goal, or inspect evidence/model/policy-000.json before resuming."
            ),
        ]
    }
    return []
}

private func workspaceShouldExecuteCandidateAction(
    _ request: TKWorkspaceRunRequest,
    businessCheckpoint: TKWorkspaceBusinessCheckpoint?,
    actionCandidate: TKWorkspaceActionCandidate
) throws -> Bool {
    guard request.executeActions, businessCheckpoint?.ready != true else {
        return false
    }
    let runner = try workspaceRunnerConfig(for: request)
    let providerPreflight = try workspaceProviderPreflight(request)
    let modelLoopEnabled = request.dryModelFixture || providerPreflight.providersReady
    return modelLoopEnabled && workspacePolicyAllowsAction(actionCandidate.action, runner: runner)
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
        latestBootstrap: parsed.events.last { $0.type == .flowBootstrapChecked },
        latestBootstrapProposal: parsed.events.last { $0.type == .flowBootstrapProposed },
        latestPause: parsed.events.last { $0.type == .runPaused }
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
        business: run.business,
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
        "evidence/observations",
        "evidence/screenshots",
        "evidence/hierarchy",
        "evidence/model",
        "evidence/actions",
        "evidence/business",
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
    observation: TKWorkspaceObservationSeed,
    appReady: TKWorkspaceAppReadyEvidence,
    businessCheckpoint: TKWorkspaceBusinessCheckpoint?,
    includeModelTransition: Bool,
    actionExecution: TKWorkspaceActionExecutionResult?,
    postActionObservation: TKWorkspaceObservationSeed?,
    actionCandidate: TKWorkspaceActionCandidate
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
    try writeWorkspaceJSONArtifact(
        workspaceAppLifecycleArtifact(appReady),
        to: runDir.appendingPathComponent("evidence/actions/app-ready.json")
    )
    if let businessCheckpoint {
        try writeWorkspaceJSONArtifact(
            workspaceBusinessReadyArtifact(businessCheckpoint),
            to: runDir.appendingPathComponent(businessCheckpoint.readiness.ref)
        )
    }
    try "workspace dry screenshot placeholder\n".write(
        to: runDir.appendingPathComponent("evidence/screenshots/0000.txt"),
        atomically: true,
        encoding: .utf8
    )
    try writeWorkspaceJSONArtifact(["nodes": []], to: runDir.appendingPathComponent("evidence/hierarchy/0000.json"))
    try writeWorkspaceJSONArtifact(["ax": []], to: runDir.appendingPathComponent("evidence/hierarchy/0000-ax.json"))
    try writeWorkspaceObservationEvidence(observation, runDir: runDir, index: 0)
    if let postActionObservation {
        try writeWorkspaceObservationEvidence(postActionObservation, runDir: runDir, index: 1)
    }
    try writeWorkspaceJSONArtifact([
        "state": workspaceBootstrapState(for: run.ai),
        "ready": false,
        "evidenceId": "ev_0000",
        "proposal": run.ai.providersReady ? "candidate_available" : "stop",
    ], to: runDir.appendingPathComponent("evidence/model/bootstrap-000.json"))
    try writeWorkspaceJSONArtifact(
        workspaceAtlasDocument(
            for: run,
            observation: observation,
            postActionObservation: postActionObservation,
            includeModelTransition: includeModelTransition,
            businessCheckpoint: businessCheckpoint,
            actionExecution: actionExecution,
            actionCandidate: actionCandidate
        ),
        to: runDir.appendingPathComponent("atlas/atlas.json")
    )
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
    if ai.providerStatus == "ready" {
        return "provider_ready"
    }
    if ai.providerStatus == "partial", ai.vlmProviderStatus == "ready" {
        return "llm_missing"
    }
    return "provider_missing"
}

private func workspaceAtlasDocument(
    for run: TKWorkspaceRunResponse,
    observation: TKWorkspaceObservationSeed,
    postActionObservation: TKWorkspaceObservationSeed?,
    includeModelTransition: Bool,
    businessCheckpoint: TKWorkspaceBusinessCheckpoint?,
    actionExecution: TKWorkspaceActionExecutionResult?,
    actionCandidate: TKWorkspaceActionCandidate
) -> [String: Any] {
    let initialObservationRefs = workspaceAtlasObservationRefs(
        observation,
        eventRef: "events.jsonl#observation.captured",
        evidenceIndex: 0
    )
    let postActionObservationRefs = postActionObservation.map {
        workspaceAtlasObservationRefs(
            $0,
            eventRef: "events.jsonl#observation.captured:post_action",
            evidenceIndex: 1
        )
    }
    let toScreenID = postActionObservation == nil ? "screen_0000" : "screen_0001"
    let transitions = includeModelTransition
        ? [workspaceModelTransition(
            actionCandidate: actionCandidate,
            actionExecution: actionExecution,
            businessCheckpoint: businessCheckpoint,
            toScreenID: toScreenID
        )]
        : []
    var screens: [[String: Any]] = [
        workspaceAtlasScreen(
            screenID: "screen_0000",
            stateID: "state_0000",
            observation: observation,
            evidenceRefs: initialObservationRefs
        ),
    ]
    var states: [[String: Any]] = [
        workspaceAtlasState(
            stateID: "state_0000",
            screenID: "screen_0000",
            phase: "initial",
            evidenceRefs: initialObservationRefs
        ),
    ]
    if let postActionObservation, let postActionObservationRefs {
        screens.append(workspaceAtlasScreen(
            screenID: "screen_0001",
            stateID: "state_0001",
            observation: postActionObservation,
            evidenceRefs: postActionObservationRefs
        ))
        states.append(workspaceAtlasState(
            stateID: "state_0001",
            screenID: "screen_0001",
            phase: "post_action",
            evidenceRefs: postActionObservationRefs
        ))
    }
    return [
        "schemaVersion": 1,
        "kind": "triton.workspace.atlas",
        "runId": run.runID,
        "app": run.app,
        "source": [
            "events": "events.jsonl",
            "mode": "workspace-run-seed",
        ],
        "screens": screens,
        "states": states,
        "transitions": transitions,
        "coverage": [
            "status": "seeded",
            "screenCount": screens.count,
            "stateCount": states.count,
            "transitionCount": transitions.count,
        ],
    ]
}

private func workspaceAtlasObservationRefs(
    _ observation: TKWorkspaceObservationSeed,
    eventRef: String,
    evidenceIndex: Int
) -> [String] {
    let observationEvidenceRef = observation.fixtureRef == nil
        && observation.fixturePath == nil
        && observation.rawObservationData == nil
        ? nil
        : workspaceObservationEvidenceRef(index: evidenceIndex)
    return ([
        eventRef,
        observationEvidenceRef,
        observation.artifacts.screenshot,
        observation.artifacts.hierarchy,
        observation.artifacts.ax,
    ] as [String?]).compactMap { $0 }
}

private func workspaceAtlasScreen(
    screenID: String,
    stateID: String,
    observation: TKWorkspaceObservationSeed,
    evidenceRefs: [String]
) -> [String: Any] {
    [
        "screenId": screenID,
        "stateId": stateID,
        "signature": workspaceAtlasSignature(observation),
        "dominantTexts": observation.screenCandidate.visibleTexts,
        "semanticTags": [],
        "evidenceRefs": evidenceRefs,
    ]
}

private func workspaceAtlasState(
    stateID: String,
    screenID: String,
    phase: String,
    evidenceRefs: [String]
) -> [String: Any] {
    [
        "stateId": stateID,
        "screenId": screenID,
        "phase": phase,
        "evidenceRefs": evidenceRefs,
    ]
}

private func workspaceAtlasSignature(_ observation: TKWorkspaceObservationSeed) -> String {
    [
        observation.screenCandidate.screenshotSha256,
        observation.screenCandidate.axTextHash,
        observation.screenCandidate.hierarchySha256,
    ].joined(separator: ":")
}

func writeWorkspaceJSONArtifact(_ value: [String: Any], to url: URL) throws {
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

func yamlEscaped(_ value: String) -> String {
    value.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
}
