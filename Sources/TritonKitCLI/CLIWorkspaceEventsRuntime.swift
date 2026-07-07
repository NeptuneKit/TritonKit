import Foundation
import TritonKitShared

func workspaceSkeletonEvents(
    runID: String,
    providerEventPhase: String,
    bootstrapPhase: String,
    appReady: TKWorkspaceAppReadyEvidence,
    observation: TKWorkspaceObservationSeed,
    businessCheckpoint: TKWorkspaceBusinessCheckpoint?,
    finalState: TKWorkspaceRunFinalState
) -> [TKTestRunEvent] {
    let now = workspaceTimestamp()
    var events: [TKTestRunEvent] = [
        .runStarted(runID: runID, timestamp: now),
        .init(type: .targetResolved, runID: runID, timestamp: now, ref: "evidence/model/target.json"),
        .init(type: .providerChecked, runID: runID, timestamp: now, ref: "evidence/model/provider-check.json", phase: providerEventPhase),
        .init(type: .appReady, runID: runID, timestamp: now, ref: "evidence/actions/app-ready.json", phase: appReady.phase),
        .observationCaptured(
            runID: runID,
            stepIndex: 0,
            phase: "initial",
            artifacts: observation.artifacts,
            screenCandidate: observation.screenCandidate,
            changed: observation.changed,
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
    ]
    if let businessCheckpoint, businessCheckpoint.stage != .postAction {
        events.append(contentsOf: workspaceBusinessCheckpointEvents(
            runID: runID,
            timestamp: now,
            stepIndex: 1,
            businessCheckpoint: businessCheckpoint
        ))
    }
    events.append(.init(
        type: finalState.eventType,
        runID: runID,
        timestamp: now,
        status: finalState.eventStatus,
        durationMs: 0,
        phase: finalState.phase
    ))
    return events
}

func workspaceBusinessCheckpointEvents(
    runID: String,
    timestamp: String,
    stepIndex: Int,
    businessCheckpoint: TKWorkspaceBusinessCheckpoint
) -> [TKTestRunEvent] {
    let selector = TKTestRunSelector(text: TKTestRunTextSelector(
        value: businessCheckpoint.readiness.query,
        match: "exact",
        source: businessCheckpoint.source
    ))
    return [
        .init(
            type: .businessReady,
            runID: runID,
            timestamp: timestamp,
            stepIndex: stepIndex,
            status: businessCheckpoint.eventStatus,
            ref: businessCheckpoint.readiness.ref,
            selector: selector,
            phase: businessCheckpoint.readiness.phase
        ),
        .init(
            type: .verifyChecked,
            runID: runID,
            timestamp: timestamp,
            stepIndex: stepIndex,
            status: businessCheckpoint.eventStatus,
            ref: businessCheckpoint.readiness.ref
        ),
    ]
}

func workspaceModelDecisionEvents(
    runID: String,
    mode: String,
    policyAllowed: Bool,
    businessCheckpoint: TKWorkspaceBusinessCheckpoint?,
    actionExecution: TKWorkspaceActionExecutionResult?,
    postActionObservation: TKWorkspaceObservationSeed?,
    actionCandidate: TKWorkspaceActionCandidate,
    artifactIndex: Int = 0,
    recoveryCommand: [String] = ["stop"]
) -> [TKTestRunEvent] {
    let now = workspaceTimestamp()
    let command = actionCandidate.command
    let failureMode = mode.replacingOccurrences(of: "-", with: "_")
    let suffix = workspaceArtifactSuffix(artifactIndex)
    let stepIndex = artifactIndex + 1
    let bootstrapStepIndex = artifactIndex == 0 ? 0 : stepIndex
    if !policyAllowed {
        return [
            .init(type: .flowBootstrapProposed, runID: runID, timestamp: now, stepIndex: bootstrapStepIndex, command: command, ref: "evidence/model/bootstrap-proposal-\(suffix).json"),
            .init(type: .modelDecided, runID: runID, timestamp: now, stepIndex: stepIndex, command: command, ref: "evidence/model/decision-\(suffix).json"),
            .init(type: .policyChecked, runID: runID, timestamp: now, stepIndex: stepIndex, command: command, status: .failed, ref: "evidence/model/policy-\(suffix).json"),
            .init(
                type: .flowRecoveryDetected,
                runID: runID,
                timestamp: now,
                stepIndex: stepIndex,
                failure: TKTestRunFailure(
                    type: "policy_rejected",
                    message: "Runner allowedActions rejected \(mode) \(actionCandidate.action) candidate.",
                    artifactRefs: ["evidence/model/policy-\(suffix).json"]
                ),
                phase: "policy_rejected"
            ),
            .init(type: .flowRecoveryProposed, runID: runID, timestamp: now, stepIndex: stepIndex, command: ["stop"], ref: "evidence/model/recovery-\(suffix).json"),
        ]
    }
    var events: [TKTestRunEvent] = [
        .init(type: .flowBootstrapProposed, runID: runID, timestamp: now, stepIndex: bootstrapStepIndex, command: command, ref: "evidence/model/bootstrap-proposal-\(suffix).json"),
        .init(type: .modelDecided, runID: runID, timestamp: now, stepIndex: stepIndex, command: command, ref: "evidence/model/decision-\(suffix).json"),
        .init(type: .policyChecked, runID: runID, timestamp: now, stepIndex: stepIndex, command: command, status: .passed, ref: "evidence/model/policy-\(suffix).json"),
        .init(
            type: .actionExecuted,
            runID: runID,
            timestamp: now,
            stepIndex: stepIndex,
            command: command,
            status: actionExecution?.eventStatus ?? .passed,
            exitCode: actionExecution?.exitCode ?? 0,
            ref: "evidence/actions/action-\(suffix).json"
        ),
    ]
    if let postActionObservation {
        events.append(.observationCaptured(
            runID: runID,
            stepIndex: stepIndex,
            phase: "post_action",
            artifacts: postActionObservation.artifacts,
            screenCandidate: postActionObservation.screenCandidate,
            changed: postActionObservation.changed,
            timestamp: now
        ))
    }
    if let actionExecution, !actionExecution.ok {
        let failureType = actionExecution.failure?.code ?? "action_failed"
        let failurePhase = actionExecution.failure?.kind ?? "action_failed"
        var artifactRefs = [
            "evidence/actions/action-\(suffix).json",
            "evidence/model/verify-\(suffix).json",
        ]
        if let artifactRef = actionExecution.failure?.artifactRef {
            artifactRefs.append(artifactRef)
        }
        events.append(.init(type: .verifyChecked, runID: runID, timestamp: now, stepIndex: stepIndex, status: .failed, ref: "evidence/model/verify-\(suffix).json"))
        events.append(.init(
            type: .flowRecoveryDetected,
            runID: runID,
            timestamp: now,
            stepIndex: stepIndex,
            failure: TKTestRunFailure(
                type: failureType,
                message: actionExecution.message ?? "Workspace action failed before verification.",
                artifactRefs: artifactRefs
            ),
            phase: failurePhase
        ))
        events.append(.init(type: .flowRecoveryProposed, runID: runID, timestamp: now, stepIndex: stepIndex, command: ["stop"], ref: "evidence/model/recovery-\(suffix).json"))
    } else if let businessCheckpoint, businessCheckpoint.stage == .postAction {
        events += workspaceBusinessCheckpointEvents(
            runID: runID,
            timestamp: now,
            stepIndex: stepIndex,
            businessCheckpoint: businessCheckpoint
        )
        if !businessCheckpoint.ready {
            events.append(.init(
                type: .flowRecoveryDetected,
                runID: runID,
                timestamp: now,
                stepIndex: stepIndex,
                failure: TKTestRunFailure(
                    type: "business_checkpoint_missing",
                    message: "Post-action business checkpoint '\(businessCheckpoint.readiness.query)' did not pass.",
                    artifactRefs: [businessCheckpoint.readiness.ref]
                ),
                phase: businessCheckpoint.readiness.phase
            ))
            events.append(.init(
                type: .flowRecoveryProposed,
                runID: runID,
                timestamp: now,
                stepIndex: stepIndex,
                command: recoveryCommand,
                ref: "evidence/model/recovery-\(suffix).json"
            ))
        }
    } else {
        events.append(.init(type: .verifyChecked, runID: runID, timestamp: now, stepIndex: stepIndex, status: .failed, ref: "evidence/model/verify-\(suffix).json"))
        events.append(.init(
            type: .flowRecoveryDetected,
            runID: runID,
            timestamp: now,
            stepIndex: stepIndex,
            failure: TKTestRunFailure(
                type: "expected_screen_missing",
                message: "\(mode) simulates selector drift after action.",
                artifactRefs: ["evidence/model/verify-\(suffix).json"]
            ),
            phase: "selector_drift"
        ))
        events.append(.init(type: .flowRecoveryProposed, runID: runID, timestamp: now, stepIndex: stepIndex, command: ["stop"], ref: "evidence/model/recovery-\(suffix).json"))
        events.append(.init(
            type: .flowRecoveryRejected,
            runID: runID,
            timestamp: now,
            stepIndex: stepIndex,
            failure: TKTestRunFailure(
                type: "\(failureMode)_stop",
                message: "\(mode) does not execute recovery actions.",
                artifactRefs: ["evidence/model/recovery-\(suffix).json"]
            )
        ))
    }
    events.append(.init(type: .atlasUpdated, runID: runID, timestamp: now, stepIndex: stepIndex, ref: "atlas/deltas.jsonl"))
    events.append(.init(type: .flowUpdated, runID: runID, timestamp: now, ref: "flow.tritonflow.yaml"))
    return events
}

func workspaceTimestamp() -> String {
    ISO8601DateFormatter().string(from: Date())
}
