import Foundation
import TritonKitShared

func planNextStepsOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "plan.next-steps",
        format: "json",
        kind: "recommended-steps",
        model: "TKCLIPlanResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the planning request completed"),
            ("serverReachable", "Bool", true, "Whether the local Triton server responded"),
            ("connected", "Bool", true, "Whether at least one embedded runtime target is connected"),
            ("runtime", "String", true, "embedded when connected, otherwise none"),
            ("surface", "String", true, "Bootstrap entry surface identifier; always plan for this response"),
            ("mode", "String", true, "bootstrap for environment recovery planning, task for goal-specific workflow planning"),
            ("goal", "String?", false, "Requested planning goal such as general, ios-smoke, open-url, or webview-check"),
            ("nextStep", "String", true, "Machine-readable next step identifier"),
            ("nextWorkflows", "[String]", true, "Workflow taxonomy values most directly associated with the next planning lane"),
            ("primaryWorkflowCategory", "String?", false, "Primary workflow taxonomy value implied by the selected next step"),
            ("primaryExpectedArtifact", "String?", false, "Primary artifact taxonomy value implied by the selected next step"),
            ("primaryNextAction", "TKCLINextAction?", false, "Primary structured command agents should execute next from this plan"),
            ("primaryNextActionSource", "String?", false, "Machine-readable provenance for why this plan selected the primary next action"),
            ("steps", "[TKCLIPlanStep]", true, "Recommended commands and expected outcomes"),
            ("steps[].id", "String", true, "Stable step identifier"),
            ("steps[].command", "String", true, "Human-readable Triton invocation for logging or copy/paste"),
            ("steps[].argv", "[String]", true, "Primary executable argv tokens for agents; avoids shell-string parsing"),
            ("steps[].category", "String", true, "Recovery category derived from the step command root"),
            ("steps[].workflowCategories", "[String]", true, "Workflow taxonomy values directly associated with the step command"),
            ("steps[].requires", "[String]", true, "Machine-readable prerequisites such as cli.available, server.reachable, target.ready, or runtime.connected"),
            ("steps[].expectedArtifacts", "[String]", true, "Expected evidence surfaces produced or consumed by the step"),
            ("steps[].stopConditions", "[String]", true, "Machine-readable conditions that should stop or re-plan the workflow"),
            ("steps[].requiresLongRunningProcess", "Bool", true, "Whether agents must keep this step running while later steps execute"),
            ("steps[].readyEvents", "[String]", true, "JSONL events that prove a long-running step is ready for dependent steps"),
            ("steps[].finalEvents", "[String]", true, "JSONL events expected when a long-running step exits cleanly"),
            ("steps[].terminationSignals", "[String]", true, "Preferred signals for agents to stop a long-running process after dependent steps finish"),
            ("error", "TKCLIErrorDetail?", false, "Recoverable server or target diagnostic"),
        ])
    )
}

func planInspectOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "plan.inspect",
        format: "json",
        kind: "replay-plan-summary",
        model: "TKReplayPlanSummary",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the inspect request completed"),
            ("path", "String", true, "Inspected .tritonplan path"),
            ("schemaVersion", "Int", true, "Replay plan schema version"),
            ("name", "String?", false, "Optional replay plan name"),
            ("variables", "[String]", true, "Variable placeholders expected by the replay plan"),
            ("stepCount", "Int", true, "Number of replay steps"),
            ("actions", "[String]", true, "Replay action names in order"),
            ("target", "TKReplayPlanTarget?", false, "Optional target metadata embedded in the replay plan"),
            ("steps", "[TKReplayPlanStepSummary]", true, "Per-step execution and diagnostic metadata for agents"),
            ("steps[].index", "Int", true, "1-based replay step index"),
            ("steps[].id", "String?", false, "Optional replay step id"),
            ("steps[].name", "String?", false, "Optional replay step name"),
            ("steps[].action", "String", true, "Replay action name"),
            ("steps[].command", "String", true, "Human-readable Triton invocation template for logging or copy/paste"),
            ("steps[].argv", "[String]", true, "Primary executable argv tokens or variable-preserving templates for agents"),
            ("steps[].category", "String", true, "Recovery category derived from the step command root"),
            ("steps[].workflowCategories", "[String]", true, "Workflow taxonomy values directly associated with the replay step"),
            ("steps[].requires", "[String]", true, "Machine-readable prerequisites such as cli.available, server.reachable, target.ready, or runtime.connected"),
            ("steps[].expectedArtifacts", "[String]", true, "Expected evidence surfaces produced or consumed by the step"),
            ("steps[].stopConditions", "[String]", true, "Machine-readable conditions that should stop or re-plan the replay"),
            ("steps[].validationErrors", "[TKReplayPlanStepValidationError]", true, "Static per-step validation diagnostics; empty when the step shape is valid"),
        ])
    )
}

func smokeResultOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "smoke.result",
        format: "json",
        kind: "smoke-result",
        model: "SmokeRunSummary",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the smoke flow passed"),
            ("action", "String", true, "smoke.ios, smoke.android, or smoke.harmony"),
            ("platform", "String", true, "ios, android, or harmony"),
            ("status", "String", true, "pass, fail, or blocked"),
            ("target", "SmokeTargetSummary", true, "Target app/device summary"),
            ("steps", "[SmokeStepSummary]", true, "Executed smoke steps"),
            ("steps[].proofSource", "String?", false, "runtime, host-layout, host-action, or evidence"),
            ("steps[].businessReady", "Bool", true, "Whether this step proves business readiness"),
            ("assertions", "[SmokeAssertionSummary]", true, "Assertion summaries"),
            ("assertions[].proofSource", "String?", false, "Proof source for the assertion, usually runtime or host-layout"),
            ("artifacts", "[SmokeArtifactSummary]", true, "Smoke artifacts"),
            ("evidence", "TKEvidenceManifest?", false, "Evidence bundle manifest"),
            ("failure", "SmokeFailureSummary?", false, "First smoke failure"),
            ("startedAt", "String", true, "Start timestamp"),
            ("endedAt", "String", true, "End timestamp"),
            ("elapsedMs", "Int", true, "Elapsed milliseconds"),
        ])
    )
}

func recordPlanOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "record.plan",
        format: "json",
        kind: "record-plan",
        model: "TKRecordPlanResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the plan template was written"),
            ("output", "String", true, "Written .tritonplan path"),
            ("templateOnly", "Bool", true, "Whether this is a static template"),
            ("message", "String", true, "Human-readable result message"),
            ("plan", "TKReplayPlan", true, "Editable replay plan template"),
        ])
    )
}

func evidenceManifestOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "evidence.manifest",
        format: "json",
        kind: "evidence-manifest",
        model: "TKEvidenceManifest",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the evidence operation succeeded"),
            ("formatVersion", "Int", true, "Evidence manifest format version"),
            ("name", "String?", false, "Scenario name"),
            ("note", "String?", false, "Human note"),
            ("createdAt", "String", true, "Creation timestamp"),
            ("output", "String", true, "Evidence bundle output path"),
            ("artifacts", "[TKEvidenceArtifact]", true, "Captured artifact records"),
            ("primaryArtifact", "TKEvidenceArtifactSummary?", false, "Primary artifact summary agents should inspect first"),
            ("primaryArtifacts", "[TKEvidenceArtifactSummary]", true, "High-signal artifact summaries agents should inspect first"),
            ("skipped", "[TKEvidenceSkippedArtifact]", true, "Skipped artifact records"),
            ("target", "TKEvidenceTarget?", false, "Target metadata"),
            ("cli", "TKEvidenceCLI", true, "CLI metadata"),
            ("run", "TKEvidenceRunManifest?", false, "Run events and screenshots metadata"),
            ("screenWorkspace", "TKEvidenceScreenWorkspaceManifest?", false, "Run-local projected screen and transition metadata"),
        ])
    )
}

func evidenceSummaryOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "evidence.summary",
        format: "json",
        kind: "artifact-envelope",
        model: "TKEvidenceSummaryResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the evidence summary succeeded"),
            ("action", "String", true, "Summary action name"),
            ("input", "String", true, "Input evidence bundle path"),
            ("profile", "String", true, "Redaction profile used for the summary"),
            ("createdAt", "String", true, "Bundle creation timestamp"),
            ("name", "String?", false, "Scenario name"),
            ("note", "String?", false, "Human note"),
            ("output", "String", true, "Evidence bundle output path"),
            ("artifactCount", "Int", true, "Number of artifact records in the bundle"),
            ("sensitiveArtifactCount", "Int", true, "Number of artifacts that should be redacted before handoff"),
            ("skippedCount", "Int", true, "Number of skipped artifact records"),
            ("target", "TKEvidenceTarget?", false, "Target metadata"),
            ("cli", "TKEvidenceCLI", true, "CLI metadata"),
            ("artifacts", "[TKEvidenceArtifactSummary]", true, "Safe artifact summaries for offline inspection"),
            ("primaryArtifact", "TKEvidenceArtifactSummary?", false, "Primary artifact summary agents should inspect first"),
            ("primaryArtifacts", "[TKEvidenceArtifactSummary]", true, "High-signal artifact summaries agents should inspect first"),
            ("skipped", "[TKEvidenceSkippedArtifact]", true, "Skipped artifact records"),
            ("run", "TKEvidenceRunManifest?", false, "Run events and screenshots metadata"),
            ("screenWorkspace", "TKEvidenceScreenWorkspaceManifest?", false, "Run-local projected screen and transition metadata"),
            ("suggestedCommands", "[String]", true, "Suggested offline follow-up commands"),
        ])
    )
}

func evidenceScreenWorkspaceProjectionOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "evidence.screen-workspace-projection",
        format: "json",
        kind: "screen-workspace-projection-result",
        model: "TKScreenWorkspaceProjectionResponse|TKScreenWorkspaceProjectionFailureResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether screen workspace projection succeeded"),
            ("schemaVersion", "Int?", false, "Projection response schema version when ok is true"),
            ("kind", "String?", false, "Stable kind; triton.screen-workspace.projection-result when ok"),
            ("evidenceDir", "String?", false, "Input .tritonevidence directory"),
            ("screensRef", "String?", false, "Projected screens.json path relative to evidence root"),
            ("transitionsRef", "String?", false, "Projected transitions.json path relative to evidence root"),
            ("screenCount", "Int?", false, "Number of run-local screens projected from observation fingerprints"),
            ("transitionCount", "Int?", false, "Number of observed tap transitions projected"),
            ("warningCount", "Int?", false, "Number of non-fatal projection warnings"),
            ("warnings", "[TKScreenWorkspaceProjectionWarning]?", false, "Projection warnings for incomplete action observations"),
            ("error", "TKScreenWorkspaceProjectionErrorDetail?", false, "Machine-readable projection failure when ok is false"),
            ("error.type", "String?", false, "Stable failure type; projection_error"),
            ("error.code", "String?", false, "Stable projection error code"),
            ("error.message", "String?", false, "Human-readable projection failure summary"),
        ])
    )
}

func appMapMergeOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "app-map.merge",
        format: "json",
        kind: "app-map-merge-result",
        model: "TKAppMapMergeResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether merge completed"),
            ("schemaVersion", "Int", true, "Response schema version"),
            ("kind", "String", true, "Stable kind; triton.app-map.merge-result"),
            ("evidenceDir", "String", true, "Input .tritonevidence directory"),
            ("mapDir", "String", true, "Output .tritonmap directory"),
            ("projectedWorkspace", "Bool", true, "Whether screens/transitions were generated before merge"),
            ("screenCount", "Int", true, "Merged screen count from this run"),
            ("transitionCount", "Int", true, "Merged transition count from this run"),
            ("pathCount", "Int", true, "Generated path count from this run"),
            ("suiteCount", "Int", true, "Suite file count after merge"),
            ("pathIDs", "[String]", true, "Generated path ids"),
        ])
    )
}

func appMapInspectOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "app-map.inspect",
        format: "json",
        kind: "app-map-inspect-result",
        model: "TKAppMapInspectResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether inspect completed"),
            ("schemaVersion", "Int", true, "Response schema version"),
            ("kind", "String", true, "Stable kind; triton.app-map.inspect-result"),
            ("mapDir", "String", true, "Input .tritonmap directory"),
            ("screenCount", "Int", true, "Total screen count"),
            ("transitionCount", "Int", true, "Total transition count"),
            ("pathCount", "Int", true, "Total path count"),
            ("suiteCount", "Int", true, "Total suite count"),
            ("health", "TKAppMapHealth", true, "Observed run health"),
        ])
    )
}

func appMapPathsOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "app-map.paths",
        format: "json",
        kind: "app-map-paths-result",
        model: "TKAppMapPathsResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether path listing completed"),
            ("schemaVersion", "Int", true, "Response schema version"),
            ("kind", "String", true, "Stable kind; triton.app-map.paths-result"),
            ("mapDir", "String", true, "Input .tritonmap directory"),
            ("pathCount", "Int", true, "Total path count"),
            ("paths", "[TKAppMapPath]", true, "Replayable and observed path assets"),
        ])
    )
}

func appMapScreensOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "app-map.screens",
        format: "json",
        kind: "app-map-screens-result",
        model: "TKAppMapScreensResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether screen listing completed"),
            ("schemaVersion", "Int", true, "Response schema version"),
            ("kind", "String", true, "Stable kind; triton.app-map.screens-result"),
            ("mapDir", "String", true, "Input .tritonmap directory"),
            ("screenCount", "Int", true, "Total screen count"),
            ("screens", "[TKAppMapScreen]", true, "Screen graph nodes"),
        ])
    )
}

func appMapTransitionsOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "app-map.transitions",
        format: "json",
        kind: "app-map-transitions-result",
        model: "TKAppMapTransitionsResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether transition listing completed"),
            ("schemaVersion", "Int", true, "Response schema version"),
            ("kind", "String", true, "Stable kind; triton.app-map.transitions-result"),
            ("mapDir", "String", true, "Input .tritonmap directory"),
            ("transitionCount", "Int", true, "Total transition count"),
            ("transitions", "[TKAppMapTransition]", true, "Transition graph edges"),
        ])
    )
}

func appMapPathShowOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "app-map.path-show",
        format: "json",
        kind: "app-map-path-show-result",
        model: "TKAppMapPathShowResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether path show completed"),
            ("schemaVersion", "Int", true, "Response schema version"),
            ("kind", "String", true, "Stable kind; triton.app-map.path-show-result"),
            ("mapDir", "String", true, "Input .tritonmap directory"),
            ("path", "TKAppMapPath", true, "Selected path"),
            ("screens", "[TKAppMapScreen]", true, "Path screens"),
            ("transitions", "[TKAppMapTransition]", true, "Path transitions"),
        ])
    )
}

func appMapHealthOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "app-map.health",
        format: "json",
        kind: "app-map-health-result",
        model: "TKAppMapHealthResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether health inspect completed"),
            ("schemaVersion", "Int", true, "Response schema version"),
            ("kind", "String", true, "Stable kind; triton.app-map.health-result"),
            ("mapDir", "String", true, "Input .tritonmap directory"),
            ("health", "TKAppMapHealth", true, "Observed run health"),
            ("pathCount", "Int", true, "Total path count"),
            ("failingPathIds", "[String]", true, "Paths with recorded failures"),
            ("unconfirmedPathIds", "[String]", true, "Paths not confirmed for suite use"),
            ("unreplayablePathIds", "[String]", true, "Paths that cannot be exported safely"),
            ("uncoveredScreenIds", "[String]", true, "Screens not present in any path"),
            ("uncoveredTransitionIds", "[String]", true, "Transitions not covered by a suite path"),
        ])
    )
}

func appMapSuiteInspectOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "app-map.suite-inspect",
        format: "json",
        kind: "app-map-suite-inspect-result",
        model: "TKAppMapSuiteInspectResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether suite inspect completed"),
            ("schemaVersion", "Int", true, "Response schema version"),
            ("kind", "String", true, "Stable kind; triton.app-map.suite-inspect-result"),
            ("mapDir", "String", true, "Input .tritonmap directory"),
            ("suite", "TKAppMapSuite", true, "Selected suite"),
            ("paths", "[TKAppMapPath]", true, "Paths included in the suite"),
        ])
    )
}

func appMapSuiteRunOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "app-map.suite-run",
        format: "json",
        kind: "app-map-suite-run-result",
        model: "TKAppMapSuiteRunResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether all suite paths passed"),
            ("schemaVersion", "Int", true, "Response schema version"),
            ("kind", "String", true, "Stable kind; triton.app-map.suite-run-result"),
            ("mapDir", "String", true, "Input .tritonmap directory"),
            ("suiteId", "String", true, "Executed suite id"),
            ("evidenceRoot", "String", true, "Directory containing exported flows and .tritonevidence bundles"),
            ("status", "String", true, "passed or failed"),
            ("pathCount", "Int", true, "Executed path count"),
            ("passedCount", "Int", true, "Passing path count"),
            ("failedCount", "Int", true, "Failing path count"),
            ("stoppedOnFailure", "Bool", true, "Whether suite policy stopped execution after a failure"),
            ("results", "[TKAppMapSuiteRunPathResult]", true, "Per-path run results"),
        ])
    )
}

func appMapExportFlowOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "app-map.export-flow",
        format: "json",
        kind: "app-map-export-flow-result",
        model: "TKAppMapExportFlowResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether flow export completed"),
            ("schemaVersion", "Int", true, "Response schema version"),
            ("kind", "String", true, "Stable kind; triton.app-map.export-flow-result"),
            ("mapDir", "String", true, "Input .tritonmap directory"),
            ("pathID", "String", true, "Exported path id"),
            ("output", "String", true, "Written .tritontest.yaml file"),
            ("stepCount", "Int", true, "Number of generated P0D-compatible test steps"),
        ])
    )
}

func evidenceRedactionOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "evidence.redact",
        format: "json",
        kind: "artifact-envelope",
        model: "TKEvidenceRedactionResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the evidence redaction succeeded"),
            ("action", "String", true, "Redaction action name"),
            ("input", "String", true, "Input evidence bundle path"),
            ("output", "String", true, "Output redacted bundle path"),
            ("profile", "String", true, "Applied redaction profile"),
            ("createdAt", "String", true, "Original bundle creation timestamp"),
            ("artifactCount", "Int", true, "Total artifact count in the input bundle"),
            ("redactedArtifactCount", "Int", true, "Number of artifacts replaced with redacted placeholders"),
            ("keptArtifactCount", "Int", true, "Number of artifacts copied through unchanged"),
            ("manifest", "TKEvidenceManifest", true, "Redacted evidence manifest"),
            ("redactedArtifacts", "[TKEvidenceArtifactSummary]", true, "Redacted artifact summaries"),
            ("keptArtifacts", "[TKEvidenceArtifactSummary]", true, "Kept artifact summaries"),
            ("primaryArtifact", "TKEvidenceArtifactSummary?", false, "Primary artifact summary agents should inspect first"),
            ("primaryArtifacts", "[TKEvidenceArtifactSummary]", true, "High-signal artifact summaries agents should inspect first"),
            ("summaryPath", "String", true, "Path to the offline summary JSON written into the output bundle"),
            ("suggestedCommands", "[String]", true, "Suggested offline follow-up commands for the redacted bundle"),
        ])
    )
}

func replayResultOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "replay.result",
        format: "json",
        kind: "replay-result",
        model: "TKReplayResult",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the replay succeeded"),
            ("dryRun", "Bool", true, "Whether replay validated without executing"),
            ("planName", "String?", false, "Replay plan name"),
            ("stepCount", "Int", true, "Total step count"),
            ("executedCount", "Int", true, "Executed step count"),
            ("failedStepIndex", "Int?", false, "1-based failed step index; matches steps[].index"),
            ("failureCode", "String?", false, "Stable failure code for the failed replay step"),
            ("failureError", "TKCLIErrorDetail?", false, "Structured diagnostic for the failed replay step when available"),
            ("failurePrimaryWorkflowCategory", "String?", false, "Primary workflow taxonomy value describing where the replay failed"),
            ("failureError.code", "String", true, "Stable error code for the failed replay step"),
            ("failureError.message", "String", true, "Human-readable failure message for the failed replay step"),
            ("failureError.endpoint", "String?", false, "Associated endpoint when the failure came from runtime transport"),
            ("failureError.hint", "String?", false, "Suggested diagnostic hint for the failed replay step"),
            ("failureError.nearestCandidates", "[String]?", false, "Nearest candidate strings when the failed replay step exposes selector or text alternatives"),
            ("failureError.suggestedCommands", "[String]?", false, "Command suggestions bundled directly inside the failed replay step diagnostic"),
            ("failureError.candidateCount", "Int?", false, "Candidate count associated with the failed replay step diagnostic"),
            ("failureError.nextAction", "TKCLINextAction?", false, "Suggested next action when the failure exposes one"),
            ("failureWorkflowCategories", "[String]", true, "Workflow taxonomy values directly associated with the failed step"),
            ("failurePrimaryRecoveryCategory", "String?", false, "Primary recovery taxonomy value agents should prefer first after failure"),
            ("failureRecoveryCategories", "[String]", true, "Recovery category families directly associated with the failure code"),
            ("failurePrimaryHint", "String?", false, "Primary diagnostic hint agents should read first after failure"),
            ("failurePrimaryEndpoint", "String?", false, "Primary transport or runtime endpoint agents should inspect first after failure"),
            ("failurePrimaryNextAction", "TKCLINextAction?", false, "Primary structured next action agents should try first after failure"),
            ("failurePrimaryArtifact", "TKEvidenceArtifactSummary?", false, "Primary artifact agents should inspect first after failure"),
            ("failurePrimaryArtifacts", "[TKEvidenceArtifactSummary]", true, "High-signal artifact summaries agents should inspect first after failure"),
            ("failurePrimarySuggestedCommand", "String?", false, "Primary suggested Triton command string agents should try first after failure"),
            ("failurePrimaryRecoveryCommand", "TKCommandRecoveryCommand?", false, "Primary recovery command agents should try first after failure"),
            ("failurePrimaryRecoveryCommand.command", "String", true, "Triton command string for the primary recovery command"),
            ("failurePrimaryRecoveryCommand.category", "String", true, "Recovery category for the primary recovery command"),
            ("recoveryCommands", "[TKCommandRecoveryCommand]", true, "Structured recovery commands derived from replay failure follow-ups"),
            ("recoveryCommands[].command", "String", true, "Suggested follow-up Triton command"),
            ("recoveryCommands[].category", "String", true, "Recovery category for the follow-up command"),
            ("elapsedMs", "Int", true, "Elapsed milliseconds"),
            ("steps", "[TKReplayStepResult]", true, "Per-step replay results"),
            ("steps[].index", "Int", true, "1-based replay step index"),
            ("steps[].action", "String", true, "Replay action name"),
            ("steps[].name", "String?", false, "Optional replay step name"),
            ("steps[].ok", "Bool", true, "Whether the step succeeded"),
            ("steps[].dryRun", "Bool", true, "Whether the step was only validated"),
            ("steps[].elapsedMs", "Int", true, "Step elapsed milliseconds"),
            ("steps[].command", "[String]", true, "Historical argv alias kept for replay result logging consistency"),
            ("steps[].argv", "[String]", true, "Primary executable argv tokens for agents; mirrors command for replay result consistency"),
            ("steps[].category", "String", true, "Recovery category derived from the step command root"),
            ("steps[].workflowCategories", "[String]", true, "Workflow taxonomy values directly associated with the replay step"),
            ("steps[].requires", "[String]", true, "Machine-readable step prerequisites"),
            ("steps[].expectedArtifacts", "[String]", true, "Expected evidence surfaces produced or consumed by the step"),
            ("steps[].stopConditions", "[String]", true, "Machine-readable conditions that should stop or re-plan the replay"),
            ("steps[].failureCode", "String?", false, "Stable failure code for the replay step when it fails"),
            ("steps[].error", "TKCLIErrorDetail?", false, "Structured replay step diagnostic when the underlying failure is available"),
            ("steps[].error.code", "String", true, "Stable error code for the replay step"),
            ("steps[].error.message", "String", true, "Human-readable failure message for the replay step"),
            ("steps[].error.endpoint", "String?", false, "Associated endpoint when the replay step failed through runtime transport"),
            ("steps[].error.hint", "String?", false, "Suggested diagnostic hint for the replay step"),
            ("steps[].error.nearestCandidates", "[String]?", false, "Nearest candidate strings when the replay step diagnostic exposes selector or text alternatives"),
            ("steps[].error.suggestedCommands", "[String]?", false, "Command suggestions bundled directly inside the replay step diagnostic"),
            ("steps[].error.candidateCount", "Int?", false, "Candidate count associated with the replay step diagnostic"),
            ("steps[].error.nextAction", "TKCLINextAction?", false, "Suggested next action when the replay step exposes one"),
            ("steps[].message", "String?", false, "Optional step message"),
            ("suggestedCommands", "[String]", true, "Suggested follow-up commands for replay failures or post-run inspection"),
        ])
    )
}
