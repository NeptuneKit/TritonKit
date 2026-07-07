import Foundation
import TritonKitShared

struct TKWorkspaceActionLoopStep {
    let artifactIndex: Int
    let observation: TKWorkspaceObservationSeed
    let modelRequest: TKWorkspaceModelDecisionRequest
    let modelDecision: TKWorkspaceModelDecision
    let policyAllowed: Bool
    let actionExecution: TKWorkspaceActionExecutionResult?
    let postActionObservation: TKWorkspaceObservationSeed?
    let businessCheckpoint: TKWorkspaceBusinessCheckpoint?

    var actionCandidate: TKWorkspaceActionCandidate { modelDecision.candidate }
}

func workspaceShouldUseBoundedActionLoop(
    request: TKWorkspaceRunRequest,
    runner: TKWorkspaceRunRunner,
    providerPreflight: TKWorkspaceProviderPreflight,
    initialBusinessCheckpoint: TKWorkspaceBusinessCheckpoint?
) -> Bool {
    request.executeActions
        && request.observeLive
        && request.businessReadyLiveWait
        && runner.maxSteps > 1
        && initialBusinessCheckpoint?.ready != true
        && (request.dryModelFixture || providerPreflight.providersReady)
}

func runWorkspaceActionLoop(
    request: TKWorkspaceRunRequest,
    targetResolution: TKWorkspaceTargetResolution?,
    initialObservation: TKWorkspaceObservationSeed,
    appReady: TKWorkspaceAppReadyEvidence,
    runner: TKWorkspaceRunRunner,
    providerPreflight: TKWorkspaceProviderPreflight,
    modelLoopMode: String,
    initialBusinessCheckpoint: TKWorkspaceBusinessCheckpoint?,
    observeProvider: TKWorkspaceLiveObserveProvider,
    businessWaitProvider: TKWorkspaceBusinessWaitProvider,
    modelDecisionProvider: TKWorkspaceModelDecisionProvider,
    vlmGroundingProvider: TKWorkspaceVLMGroundingProvider,
    actionExecutionProvider: TKWorkspaceActionExecutionProvider
) async throws -> TKWorkspaceRunResponse {
    guard let runID = request.runID else {
        throw RuntimeError("Workspace action loop requires a resolved run ID.")
    }
    let runDir = workspaceRunDirectory(runID: runID, runsDirectory: request.runsDirectory)
    try createWorkspaceRunDirectories(runDir)

    var currentObservation = initialObservation
    var observations = [initialObservation]
    var steps: [TKWorkspaceActionLoopStep] = []

    for artifactIndex in 0..<runner.maxSteps {
        let modelRequest = workspaceModelDecisionRequest(
            for: request,
            observation: currentObservation,
            runner: runner,
            providerPreflight: providerPreflight,
            mode: modelLoopMode
        )
        let modelDecision = try await modelDecisionProvider(modelRequest)
        let actionCandidate = modelDecision.candidate
        let policyAllowed = workspacePolicyAllowsAction(actionCandidate.action, runner: runner)
        guard policyAllowed else {
            steps.append(TKWorkspaceActionLoopStep(
                artifactIndex: artifactIndex,
                observation: currentObservation,
                modelRequest: modelRequest,
                modelDecision: modelDecision,
                policyAllowed: false,
                actionExecution: nil,
                postActionObservation: nil,
                businessCheckpoint: nil
            ))
            break
        }

        let vlmGrounding: TKVLMGroundResponse?
        do {
            vlmGrounding = try await workspaceVLMGroundingForAction(
                request: request,
                observation: currentObservation,
                actionCandidate: actionCandidate,
                runDir: runDir,
                providerPreflight: providerPreflight,
                vlmGroundingProvider: vlmGroundingProvider,
                artifactIndex: artifactIndex
            )
        } catch {
            let actionExecution = try workspaceVLMGroundingFailureActionExecution(
                actionCandidate: actionCandidate,
                error: error,
                runDir: runDir,
                artifactIndex: artifactIndex
            )
            steps.append(TKWorkspaceActionLoopStep(
                artifactIndex: artifactIndex,
                observation: currentObservation,
                modelRequest: modelRequest,
                modelDecision: modelDecision,
                policyAllowed: policyAllowed,
                actionExecution: actionExecution,
                postActionObservation: nil,
                businessCheckpoint: nil
            ))
            break
        }
        let actionExecution = try await actionExecutionProvider(workspaceActionExecutionRequest(
            for: request,
            candidate: actionCandidate,
            vlmGrounding: vlmGrounding
        ))
        let postActionObservation: TKWorkspaceObservationSeed?
        if actionExecution.ok {
            postActionObservation = try await workspaceObservationSeed(for: request, observeProvider: observeProvider)
            if let postActionObservation {
                observations.append(postActionObservation)
            }
        } else {
            postActionObservation = nil
        }

        let businessCheckpoint: TKWorkspaceBusinessCheckpoint?
        if actionExecution.ok {
            let waitResult = try await businessWaitProvider(workspaceBusinessWaitRequest(for: request))
            businessCheckpoint = workspaceBusinessCheckpoint(
                for: request,
                observation: postActionObservation ?? currentObservation,
                appReady: appReady,
                waitResult: waitResult,
                stage: .postAction
            )
        } else {
            businessCheckpoint = nil
        }

        steps.append(TKWorkspaceActionLoopStep(
            artifactIndex: artifactIndex,
            observation: currentObservation,
            modelRequest: modelRequest,
            modelDecision: modelDecision,
            policyAllowed: policyAllowed,
            actionExecution: actionExecution,
            postActionObservation: postActionObservation,
            businessCheckpoint: businessCheckpoint
        ))

        if businessCheckpoint?.ready == true || !actionExecution.ok {
            break
        }
        guard let postActionObservation else {
            break
        }
        currentObservation = postActionObservation
    }

    let finalStep = steps.last
    let finalBusinessCheckpoint = finalStep?.businessCheckpoint ?? initialBusinessCheckpoint
    let finalActionExecution = finalStep?.actionExecution
    let finalState = workspaceRunFinalState(
        providerPreflight: providerPreflight,
        dryModelFixture: request.dryModelFixture,
        modelLoopEnabled: true,
        modelDecisionAllowed: finalStep?.policyAllowed ?? true,
        businessCheckpoint: finalBusinessCheckpoint,
        actionExecution: finalActionExecution
    )
    let response = workspaceActionLoopRunResponse(
        request: request,
        targetResolution: targetResolution,
        runID: runID,
        runDir: runDir,
        runner: runner,
        providerPreflight: providerPreflight,
        finalState: finalState,
        businessCheckpoint: finalBusinessCheckpoint,
        actionExecution: finalActionExecution
    )

    try writeWorkspaceRunConfig(response, to: runDir.appendingPathComponent("config.yaml"))
    try writeWorkspaceActionLoopBaseArtifacts(
        run: response,
        request: request,
        runDir: runDir,
        appReady: appReady,
        observations: observations,
        businessCheckpoint: finalBusinessCheckpoint,
        steps: steps
    )
    for step in steps {
        try writeWorkspaceModelDecisionArtifacts(
            run: response,
            runDir: runDir,
            mode: modelLoopMode,
            policyAllowed: step.policyAllowed,
            businessCheckpoint: step.businessCheckpoint,
            actionExecution: step.actionExecution,
            postActionObservation: step.postActionObservation,
            modelRequest: step.modelRequest,
            modelDecision: step.modelDecision,
            artifactIndex: step.artifactIndex,
            fromScreenID: workspaceScreenID(step.artifactIndex),
            toScreenID: step.postActionObservation == nil
                ? workspaceScreenID(step.artifactIndex)
                : workspaceScreenID(step.artifactIndex + 1),
            appendAtlasDelta: step.artifactIndex > 0,
            writeFlow: false
        )
    }
    try writeWorkspaceActionLoopFlow(response, steps: steps, to: runDir.appendingPathComponent("flow.tritonflow.yaml"))
    try projectWorkspaceAtlasAppMap(run: response, runDir: runDir)
    try writeWorkspaceRun(response, to: runDir.appendingPathComponent("run.json"))
    try writeWorkspaceRun(response, to: runDir.appendingPathComponent("report.json"))
    try writeWorkspaceEvents(
        workspaceActionLoopEvents(
            runID: runID,
            providerPreflight: providerPreflight,
            appReady: appReady,
            initialObservation: initialObservation,
            finalState: finalState,
            steps: steps
        ),
        to: runDir.appendingPathComponent("events.jsonl")
    )
    return response
}

private func workspaceActionLoopRunResponse(
    request: TKWorkspaceRunRequest,
    targetResolution: TKWorkspaceTargetResolution?,
    runID: String,
    runDir: URL,
    runner: TKWorkspaceRunRunner,
    providerPreflight: TKWorkspaceProviderPreflight,
    finalState: TKWorkspaceRunFinalState,
    businessCheckpoint: TKWorkspaceBusinessCheckpoint?,
    actionExecution: TKWorkspaceActionExecutionResult?
) -> TKWorkspaceRunResponse {
    let target = workspaceRunTarget(for: request, targetResolution: targetResolution)
    return TKWorkspaceRunResponse(
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
        business: businessCheckpoint?.readiness,
        paths: TKWorkspaceRunPaths(
            runDir: runDir.path,
            events: runDir.appendingPathComponent("events.jsonl").path,
            report: runDir.appendingPathComponent("report.json").path
        ),
        nextActions: workspaceRunNextActions(
            providerNextActions: providerPreflight.nextActions,
            finalState: finalState,
            businessCheckpoint: businessCheckpoint,
            actionExecution: actionExecution
        )
    )
}

private func writeWorkspaceActionLoopBaseArtifacts(
    run: TKWorkspaceRunResponse,
    request: TKWorkspaceRunRequest,
    runDir: URL,
    appReady: TKWorkspaceAppReadyEvidence,
    observations: [TKWorkspaceObservationSeed],
    businessCheckpoint: TKWorkspaceBusinessCheckpoint?,
    steps: [TKWorkspaceActionLoopStep]
) throws {
    try writeWorkspaceJSONArtifact(
        workspaceTargetArtifact(for: run.target),
        to: runDir.appendingPathComponent("evidence/model/target.json")
    )
    try writeWorkspaceJSONArtifact(
        workspaceActionLoopProviderArtifact(run: run, request: request),
        to: runDir.appendingPathComponent("evidence/model/provider-check.json")
    )
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
    for (index, observation) in observations.enumerated() {
        try writeWorkspaceObservationEvidence(observation, runDir: runDir, index: index)
    }
    try writeWorkspaceJSONArtifact([
        "state": workspaceBootstrapState(for: run.ai),
        "ready": false,
        "evidenceId": "ev_0000",
        "proposal": run.ai.providersReady ? "candidate_available" : "stop",
    ], to: runDir.appendingPathComponent("evidence/model/bootstrap-000.json"))
    try writeWorkspaceJSONArtifact(
        workspaceActionLoopAtlasDocument(run: run, observations: observations, steps: steps),
        to: runDir.appendingPathComponent("atlas/atlas.json")
    )
}

private func workspaceActionLoopProviderArtifact(
    run: TKWorkspaceRunResponse,
    request: TKWorkspaceRunRequest
) -> [String: Any] {
    var providerArtifact: [String: Any] = [
        "llmEnabled": run.ai.llmEnabled,
        "vlmEnabled": run.ai.vlmEnabled,
        "providersReady": run.ai.providersReady,
        "providerStatus": run.ai.providerStatus,
        "allowRemoteLLM": request.allowRemoteLLM,
        "allowRemoteVLM": request.allowRemoteVLM,
    ]
    if let llmProviderStatus = run.ai.llmProviderStatus {
        providerArtifact["llmProviderStatus"] = llmProviderStatus
    }
    if let llmProvider = run.ai.llmProvider {
        providerArtifact["llmProvider"] = llmProvider
    }
    if let llmBaseURL = workspaceNonEmpty(request.llmBaseURL) {
        providerArtifact["llmBaseURL"] = redactedWorkspaceProviderBaseURL(llmBaseURL)
    }
    if let llmModel = workspaceNonEmpty(request.llmModel) {
        providerArtifact["llmModel"] = llmModel
    }
    if let llmAPIKeyEnv = workspaceNonEmpty(request.llmAPIKeyEnv) {
        providerArtifact["llmAPIKeyEnv"] = llmAPIKeyEnv
    }
    if let vlmProvider = run.ai.vlmProvider {
        providerArtifact["vlmProvider"] = vlmProvider
    }
    if let vlmBaseURL = workspaceNonEmpty(request.vlmBaseURL) {
        providerArtifact["vlmBaseURL"] = redactedWorkspaceProviderBaseURL(vlmBaseURL)
    }
    if let vlmModel = workspaceNonEmpty(request.vlmModel) {
        providerArtifact["vlmModel"] = vlmModel
    }
    if let vlmModelPath = workspaceNonEmpty(request.vlmModelPath) {
        providerArtifact["vlmModelPath"] = vlmModelPath
    }
    if let vlmHelper = workspaceNonEmpty(request.vlmHelper) {
        providerArtifact["vlmHelper"] = vlmHelper
    }
    providerArtifact["vlmAllowModelDownload"] = request.vlmAllowModelDownload
    if let vlmAPIKeyEnv = workspaceNonEmpty(request.vlmAPIKeyEnv) {
        providerArtifact["vlmAPIKeyEnv"] = vlmAPIKeyEnv
    }
    if let vlmProviderStatus = run.ai.vlmProviderStatus {
        providerArtifact["vlmProviderStatus"] = vlmProviderStatus
    }
    return providerArtifact
}

private func workspaceActionLoopAtlasDocument(
    run: TKWorkspaceRunResponse,
    observations: [TKWorkspaceObservationSeed],
    steps: [TKWorkspaceActionLoopStep]
) -> [String: Any] {
    let screens = observations.enumerated().map { index, observation in
        workspaceAtlasScreen(
            screenID: workspaceScreenID(index),
            stateID: workspaceStateID(index),
            observation: observation,
            evidenceRefs: workspaceActionLoopObservationRefs(observation, index: index)
        )
    }
    let states = observations.enumerated().map { index, observation in
        workspaceAtlasState(
            stateID: workspaceStateID(index),
            screenID: workspaceScreenID(index),
            phase: index == 0 ? "initial" : "post_action",
            evidenceRefs: workspaceActionLoopObservationRefs(observation, index: index)
        )
    }
    let transitions = steps.compactMap(workspaceActionLoopTransition)
    return [
        "schemaVersion": 1,
        "kind": "triton.workspace.atlas",
        "runId": run.runID,
        "app": run.app,
        "source": [
            "events": "events.jsonl",
            "mode": "workspace-run-loop",
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

private func workspaceActionLoopObservationRefs(
    _ observation: TKWorkspaceObservationSeed,
    index: Int
) -> [String] {
    workspaceAtlasObservationRefs(
        observation,
        eventRef: index == 0 ? "events.jsonl#observation.captured" : "events.jsonl#observation.captured:post_action",
        evidenceIndex: index
    )
}

private func workspaceActionLoopTransition(_ step: TKWorkspaceActionLoopStep) -> [String: Any]? {
    guard step.policyAllowed else {
        return nil
    }
    let suffix = workspaceArtifactSuffix(step.artifactIndex)
    return [
        "transitionId": "transition_\(workspaceGraphSuffix(step.artifactIndex))",
        "fromScreenId": workspaceScreenID(step.artifactIndex),
        "toScreenId": step.postActionObservation == nil
            ? workspaceScreenID(step.artifactIndex)
            : workspaceScreenID(step.artifactIndex + 1),
        "action": step.actionCandidate.action,
        "selector": [
            "text": step.actionCandidate.query,
        ],
        "status": workspaceModelTransitionStatus(
            actionExecution: step.actionExecution,
            businessCheckpoint: step.businessCheckpoint
        ),
        "confidence": step.modelDecision.confidence,
        "evidenceRefs": [
            "events.jsonl#model.decided",
            "events.jsonl#policy.checked",
            "events.jsonl#action.executed",
            "events.jsonl#verify.checked",
            "evidence/model/decision-\(suffix).json",
            "evidence/model/policy-\(suffix).json",
            "evidence/actions/action-\(suffix).json",
            "evidence/model/verify-\(suffix).json",
        ],
    ]
}

private func workspaceActionLoopEvents(
    runID: String,
    providerPreflight: TKWorkspaceProviderPreflight,
    appReady: TKWorkspaceAppReadyEvidence,
    initialObservation: TKWorkspaceObservationSeed,
    finalState: TKWorkspaceRunFinalState,
    steps: [TKWorkspaceActionLoopStep]
) -> [TKTestRunEvent] {
    var events = workspaceSkeletonEvents(
        runID: runID,
        providerEventPhase: providerPreflight.providerEventPhase,
        bootstrapPhase: providerPreflight.bootstrapPhase,
        appReady: appReady,
        observation: initialObservation,
        businessCheckpoint: nil,
        finalState: finalState
    )
    let finalEvent = events.removeLast()
    for (offset, step) in steps.enumerated() {
        let isLastStep = offset == steps.index(before: steps.endIndex)
        let recoveryCommand = step.businessCheckpoint?.ready == false && !isLastStep ? ["continue"] : ["stop"]
        events += workspaceModelDecisionEvents(
            runID: runID,
            mode: step.modelRequest.mode,
            policyAllowed: step.policyAllowed,
            businessCheckpoint: step.businessCheckpoint,
            actionExecution: step.actionExecution,
            postActionObservation: step.postActionObservation,
            actionCandidate: step.actionCandidate,
            artifactIndex: step.artifactIndex,
            recoveryCommand: recoveryCommand
        )
    }
    events.append(finalEvent)
    return events
}

private func writeWorkspaceActionLoopFlow(
    _ run: TKWorkspaceRunResponse,
    steps: [TKWorkspaceActionLoopStep],
    to url: URL
) throws {
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
    for step in steps where step.policyAllowed {
        let suffix = workspaceArtifactSuffix(step.artifactIndex)
        lines.append("  - action: \(step.actionCandidate.action)")
        lines.append("    target: \"\(yamlEscaped(step.actionCandidate.query))\"")
        lines.append("    evidenceRef: evidence/actions/action-\(suffix).json")
        lines.append("    modelEvidenceRef: evidence/model/decision-\(suffix).json")
        lines.append("    policyEvidenceRef: evidence/model/policy-\(suffix).json")
        lines.append("    verifyEvidenceRef: evidence/model/verify-\(suffix).json")
    }
    try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
}
