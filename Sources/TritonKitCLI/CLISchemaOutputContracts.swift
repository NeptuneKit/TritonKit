import Foundation
import TritonKitShared

func statusOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "status",
        format: "json",
        kind: "status-envelope",
        model: "TKCLIStatusEnvelope",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the status request completed"),
            ("serverReachable", "Bool", true, "Whether the local Triton server responded"),
            ("connected", "Bool", true, "Whether at least one embedded runtime target is connected"),
            ("latestHierarchyAvailable", "Bool", true, "Whether a hierarchy snapshot is cached"),
            ("targetCount", "Int", true, "Number of connected runtime targets"),
            ("runtime", "String", true, "embedded when connected, otherwise none"),
            ("surface", "String", true, "Bootstrap entry surface identifier; always status for this response"),
            ("activeHierarchyAvailable", "Bool?", false, "Whether the active target has a hierarchy snapshot"),
            ("hierarchyCacheState", "String?", false, "active, stale, or unavailable"),
            ("targetConnectionState", "String?", false, "connected or disconnected target state"),
        ])
    )
}
func schemaCommandsOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "schema.commands",
        format: "json",
        kind: "command-schema-list",
        model: "TKCLISchemaResponse",
        fields: schemaContractFields([
            ("schemaVersion", "Int", true, "CLI schema contract version"),
            ("commands", "[TKCommandSchema]", true, "Machine-readable command contracts"),
            ("commands[].surfaceLayer", "String", true, "P23 product surface layer: workflow, diagnostic, host-adapter, agent-support, or raw-engine"),
            ("commands[].deprecatedForMainPath", "Bool", true, "Whether this command remains executable but should not be used as the main workflow entry"),
            ("commands[].replacementCommand", "String?", false, "Preferred workflow command when deprecatedForMainPath is true and a replacement exists"),
            ("commands[].rawDebugCommand", "String?", false, "Future debug-surface command shape for raw engine entries"),
            ("commands[].surfaceRationale", "String?", false, "Short rationale for the surface-layer decision"),
        ])
    )
}
func updatePlanOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "update.plan",
        format: "json",
        kind: "cli-update-plan",
        model: "CLIUpdateResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether update planning or execution completed"),
            ("currentVersion", "String", true, "Current running TritonKit CLI version"),
            ("latestVersion", "String?", false, "Latest or requested release version without the v prefix"),
            ("targetVersion", "String?", false, "Target release version without the v prefix"),
            ("releaseTag", "String?", false, "Target release tag such as v0.1.24"),
            ("updateAvailable", "Bool", true, "Whether the target version is newer than the current version"),
            ("checkOnly", "Bool", true, "Whether the command only checked update status"),
            ("dryRun", "Bool", true, "Whether the command printed a plan without mutating files"),
            ("requiresConfirmation", "Bool", true, "Whether rerun with --yes is required before mutation"),
            ("updated", "Bool", true, "Whether the CLI update action completed"),
            ("skillsUpdated", "Bool", true, "Whether the public skills bundle update completed"),
            ("installSource", "String", true, "Detected install source: homebrew, manual, sourceCheckout, or unknown"),
            ("currentExecutable", "String", true, "Path to the active triton executable"),
            ("repository", "String", true, "GitHub owner/name repository used for release lookup"),
            ("assetName", "String?", false, "Architecture-specific CLI release asset name"),
            ("checksumManifestName", "String?", false, "Release checksum manifest asset name"),
            ("actions", "[CLIUpdateAction]", true, "Ordered update plan actions"),
            ("actions[].id", "String", true, "Stable action id"),
            ("actions[].kind", "String", true, "Stable action kind"),
            ("actions[].description", "String", true, "Human-readable action description"),
            ("actions[].command", "String?", false, "Host command executable when action is command-backed"),
            ("actions[].args", "[String]", true, "Host command arguments when action is command-backed"),
            ("actions[].path", "String?", false, "Relevant local path for file mutation actions"),
            ("actions[].destructive", "Bool", true, "Whether the action mutates local files or package state"),
            ("manualInstructions", "[String]", true, "Manual follow-up notes when automatic update is not appropriate"),
            ("error", "CLIUpdateErrorDetail?", false, "Machine-readable error detail when ok is false"),
            ("error.code", "String?", false, "Stable update failure code"),
            ("error.message", "String?", false, "Human-readable failure summary"),
            ("error.hint", "String?", false, "Suggested recovery step"),
        ])
    )
}
func testValidationOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "test.validation",
        format: "json",
        kind: "test-validation-result",
        model: "TKTestValidationResponse|TKTestValidationFailureResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the .tritontest.yaml contract validated"),
            ("schemaVersion", "Int?", false, "Validation response schema version for ok responses"),
            ("kind", "String?", false, "Stable response kind; triton.test.validation-result when ok"),
            ("input", "String?", false, "Input .tritontest.yaml path when validation succeeds"),
            ("normalizedPlan", "TKTestNormalizedPlan?", false, "Normalized offline plan when validation succeeds"),
            ("error", "TKTestValidationErrorDetail?", false, "Machine-readable validation failure when ok is false"),
            ("error.type", "String?", false, "Stable failure type; validation_error"),
            ("error.message", "String?", false, "Human-readable validation failure summary"),
            ("error.path", "String?", false, "JSONPath-style path to the rejected field"),
            ("error.code", "String?", false, "Stable validation error code"),
            ("error.allowed", "[String]?", false, "Allowed values for unsupported step or coordinate-space failures"),
        ])
    )
}
func testNormalizedPlanOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "test.normalized-plan",
        format: "json",
        kind: "test-normalized-plan",
        model: "TKTestNormalizedPlan",
        fields: schemaContractFields([
            ("schemaVersion", "Int", true, "Normalized plan schema version; always 1"),
            ("kind", "String", true, "Stable kind; triton.test.normalized-plan"),
            ("name", "String", true, "Test case name from the input YAML"),
            ("app", "TKTestPlanApp", true, "Target app metadata"),
            ("app.bundleId", "String", true, "App bundle identifier"),
            ("device", "TKTestPlanDevice", true, "Device platform metadata"),
            ("device.platform", "String", true, "Platform such as ios"),
            ("settings", "TKTestPlanSettings", true, "Normalized validation settings"),
            ("settings.strict", "Bool", true, "Whether strict validation is enabled"),
            ("settings.timeoutMs", "Int", true, "Default step timeout in milliseconds"),
            ("settings.retry", "TKTestPlanRetry", true, "Retry policy"),
            ("settings.retry.count", "Int", true, "Retry count"),
            ("settings.retry.intervalMs", "Int", true, "Retry interval in milliseconds"),
            ("steps", "[TKTestPlanStep]", true, "0-based normalized steps"),
            ("steps[].index", "Int", true, "0-based step index"),
            ("steps[].id", "String", true, "Stable step id, generated as step-000 when omitted"),
            ("steps[].kind", "String", true, "Step kind: action, observation, or assertion"),
            ("steps[].type", "String", true, "Step type: launch, stop, takeScreenshot, tap, input, press, swipe, assertVisible, assertNotVisible, scrollUntilVisible, assertWithAI, assertNoDefectsWithAI, extractTextWithAI, or assertScreenshot"),
            ("steps[].optional", "Bool", true, "Whether failure of this step is optional"),
            ("steps[].timeoutMs", "Int?", false, "Step timeout override"),
            ("steps[].point", "TKTestPlanPoint?", false, "Runtime point for tap steps"),
            ("steps[].point.x", "Double?", false, "Runtime point x coordinate"),
            ("steps[].point.y", "Double?", false, "Runtime point y coordinate"),
            ("steps[].point.coordinateSpace", "String?", false, "Coordinate space; runtime-point"),
            ("steps[].endPoint", "TKTestPlanPoint?", false, "Runtime end point for swipe steps"),
            ("steps[].endPoint.x", "Double?", false, "Runtime end point x coordinate"),
            ("steps[].endPoint.y", "Double?", false, "Runtime end point y coordinate"),
            ("steps[].endPoint.coordinateSpace", "String?", false, "Coordinate space; runtime-point"),
            ("steps[].selector", "TKTestPlanSelector?", false, "AX text selector for assertVisible/assertNotVisible/scrollUntilVisible"),
            ("steps[].selector.text", "String?", false, "Exact visible text"),
            ("steps[].selector.match", "String?", false, "Match mode; exact"),
            ("steps[].selector.source", "String?", false, "Observation source; ax"),
            ("steps[].text", "String?", false, "Text payload for input steps"),
            ("steps[].button", "String?", false, "Button/key payload for press steps"),
            ("steps[].direction", "String?", false, "Scroll direction for scrollUntilVisible: down, up, left, or right"),
            ("steps[].maxScrolls", "Int?", false, "Maximum scroll attempts for scrollUntilVisible"),
            ("steps[].target", "String?", false, "VLM-assisted tap target phrase when tap uses grounding=vlm"),
            ("steps[].grounding", "String?", false, "Grounding mode for experimental target taps; vlm"),
            ("steps[].provider", "String?", false, "VLM provider for experimental target taps; mock or openai-compatible"),
            ("steps[].prompt", "String?", false, "Prompt for P14 mock AI assertion/extraction steps"),
            ("steps[].baseline", "String?", false, "Baseline screenshot path for assertScreenshot"),
            ("steps[].threshold", "Double?", false, "Normalized threshold for assertScreenshot contract; P14 execution uses strict hash comparison"),
            ("steps[].cropOn", "String?", false, "Optional crop label for future screenshot diff projection"),
        ])
    )
}
func testRunOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "test.run-result",
        format: "json",
        kind: "test-run-result",
        model: "TKTestRunExecutionResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether all executed deterministic steps passed"),
            ("schemaVersion", "Int", true, "Runner response schema version; always 1"),
            ("kind", "String", true, "Stable kind; triton.test.run-result"),
            ("input", "String", true, "Input .tritontest.yaml path"),
            ("evidenceDir", "String", true, "Output .tritonevidence directory"),
            ("normalizedPlan", "TKTestNormalizedPlan", true, "Normalized plan reused before execution"),
            ("run", "TKTestRunMetadata", true, "Run metadata saved to run/run.json"),
            ("summary", "TKTestRunEventSummary", true, "Parsed summary of run/events.jsonl"),
            ("summary.observationCount", "Int", true, "Count of observation.captured events"),
            ("run.planRef", "String?", false, "Reference to normalized-plan.json from run/run.json"),
            ("failedStepIndex", "Int?", false, "0-based failed step index when ok is false"),
            ("failure", "TKTestRunFailure?", false, "Machine-readable failure with selector and artifactRefs"),
            ("failure.artifactRefs", "[String]?", false, "Relative refs to assertion, screenshot, AX, or hierarchy evidence on failure"),
            ("evidence artifacts", "[TKEvidenceArtifact]", false, "manifest.json includes coordinate.contract, run events, normalized plan, captured observation artifacts, and explicit VLM grounding artifacts when enabled"),
        ])
    )
}
func testReportOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "test.report",
        format: "json",
        kind: "test-report",
        model: "TKTestReportResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the report was generated from evidence"),
            ("schemaVersion", "Int", true, "Report schema version; always 1"),
            ("kind", "String", true, "Stable kind; triton.test.report"),
            ("evidenceDir", "String", true, "Resolved .tritonevidence directory"),
            ("run", "TKTestReportRun?", false, "Run metadata read from run/run.json when present"),
            ("summary.status", "TKTestRunStatus?", false, "Final run status from run.finished, run.paused, run.stopped, or run/run.json"),
            ("summary.eventCount", "Int", true, "Total run event count"),
            ("summary.stepCount", "Int", true, "Executed step count"),
            ("summary.assertionCount", "Int", true, "Assertion result count"),
            ("summary.artifactCount", "Int", true, "artifact.created event count"),
            ("summary.observationCount", "Int", true, "observation.captured event count"),
            ("summary.failureCount", "Int", true, "failure.recorded event count"),
            ("summary.screenshotCount", "Int", true, "Unique screenshot refs from artifacts and observations"),
            ("summary.overlayCount", "Int", true, "VLM overlay artifact count"),
            ("failure", "TKTestRunFailure?", false, "First machine-readable failure, when the test run failed"),
            ("steps", "[TKTestReportStep]", true, "Per-step event projection with commands, assertions, observations, artifacts, and VLM grounding"),
            ("steps[].observations[].screenCandidate", "TKTestRunScreenCandidate", false, "Observation fingerprint and visibleTexts for state-diff inspection"),
            ("artifacts", "[TKTestReportArtifact]", true, "Deduplicated artifact.created refs"),
            ("suggestedCommands", "[String]", true, "Follow-up evidence commands"),
        ])
    )
}
func testCreateOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "test.create",
        format: "json",
        kind: "test-create-result",
        model: "TKTestCreateResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the .tritontest.yaml draft was created"),
            ("schemaVersion", "Int", true, "Create response schema version; always 1"),
            ("kind", "String", true, "Stable kind; triton.test.create-result"),
            ("input", "String", true, "Resolved input .tritonevidence directory"),
            ("output", "String", true, "Written .tritontest.yaml path"),
            ("source", "String", true, "Evidence source used for projection; normalized-plan.json"),
            ("name", "String", true, "Generated test name"),
            ("stepCount", "Int", true, "Number of generated test steps"),
            ("validation", "TKTestValidationResponse", true, "Validation result for the generated YAML"),
            ("suggestedCommands", "[String]", true, "Follow-up validate/run commands"),
        ])
    )
}

func testRecorderSessionStartOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "testrec.session-start",
        format: "json",
        kind: "testrec-session-start",
        model: "TKTestRecorderSessionStartResponse|TKTestRecorderValidationFailureResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the explicit-event test recorder session started"),
            ("schemaVersion", "Int?", false, "Session start response schema version for ok responses"),
            ("kind", "String?", false, "Stable response kind; triton.testrec.session-start when ok"),
            ("sessionId", "String?", false, "Opaque local session id used by testrec event and stop"),
            ("casePath", "String?", false, "Output .tritontestcase directory path"),
            ("manifest", "TKTestRecorderManifest?", false, "Written manifest.json payload"),
            ("manifest.name", "String?", false, "Test case name"),
            ("manifest.sourcePlatform", "String?", false, "Source platform being recorded"),
            ("manifest.tritonKitVersion", "String?", false, "TritonKit CLI version that created the case, or unknown for hand-written manifests"),
            ("manifest.capabilitiesRef", "String?", false, "Relative capabilities file path inside the .tritontestcase package; default contract-capabilities.json"),
            ("manifest.redactionStatus", "String?", false, "Redaction lifecycle status, default pending before compile review"),
            ("manifest.truncationStatus", "String?", false, "Raw stream truncation status, default not-truncated"),
            ("capabilities", "TKTestRecorderContractCapabilities?", false, "Written contract-capabilities.json payload"),
            ("capabilities.actions", "[String]?", false, "Action capabilities enabled for the case"),
            ("capabilities.pages", "[String]?", false, "Page capabilities enabled for the case"),
            ("capabilities.network", "[String]?", false, "Network capabilities enabled for the case"),
            ("suggestedCommands", "[String]?", false, "Executable follow-up event, stop, and inspect commands"),
            ("error", "TKTestRecorderValidationErrorDetail?", false, "Machine-readable validation failure when ok is false"),
            ("error.code", "String?", false, "Stable validation error code"),
            ("error.path", "String?", false, "Rejected file, field, or option path"),
        ])
    )
}

func testRecorderEventOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "testrec.event",
        format: "json",
        kind: "testrec-event",
        model: "TKTestRecorderEventResponse|TKTestRecorderValidationFailureResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the explicit event was appended"),
            ("schemaVersion", "Int?", false, "Event response schema version for ok responses"),
            ("kind", "String?", false, "Stable response kind; triton.testrec.event when ok"),
            ("sessionId", "String?", false, "Recording session id"),
            ("casePath", "String?", false, "Output .tritontestcase directory path"),
            ("eventKind", "String?", false, "Event kind: action, network, page-route, page-fingerprint, or page-snapshot"),
            ("eventPath", "String?", false, "Case-relative JSONL path written by this event"),
            ("eventCount", "Int?", false, "Total event count for the session after append"),
            ("suggestedCommands", "[String]?", false, "Executable follow-up event, stop, and inspect commands"),
            ("error", "TKTestRecorderValidationErrorDetail?", false, "Machine-readable validation failure when ok is false"),
            ("error.code", "String?", false, "Stable validation error code"),
            ("error.path", "String?", false, "Rejected file, field, or option path"),
        ])
    )
}

func testRecorderSessionStopOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "testrec.session-stop",
        format: "json",
        kind: "testrec-session-stop",
        model: "TKTestRecorderSessionStopResponse|TKTestRecorderValidationFailureResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the explicit-event recording session stopped"),
            ("schemaVersion", "Int?", false, "Session stop response schema version for ok responses"),
            ("kind", "String?", false, "Stable response kind; triton.testrec.session-stop when ok"),
            ("sessionId", "String?", false, "Recording session id"),
            ("casePath", "String?", false, "Output .tritontestcase directory path"),
            ("eventCount", "Int?", false, "Total event count captured by the session"),
            ("artifacts", "[TKTestRecorderArtifact]?", false, "Known .tritontestcase artifact presence report after stop"),
            ("artifacts[].kind", "String?", false, "Artifact kind"),
            ("artifacts[].path", "String?", false, "Artifact path relative to the case package"),
            ("artifacts[].present", "Bool?", false, "Whether the artifact exists"),
            ("suggestedCommands", "[String]?", false, "Executable inspect and compile follow-up commands"),
            ("error", "TKTestRecorderValidationErrorDetail?", false, "Machine-readable validation failure when ok is false"),
            ("error.code", "String?", false, "Stable validation error code"),
            ("error.path", "String?", false, "Rejected file, field, or option path"),
        ])
    )
}

func testRecorderInspectOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "testrec.inspect",
        format: "json",
        kind: "testrec-inspect",
        model: "TKTestRecorderInspectResponse|TKTestRecorderValidationFailureResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the .tritontestcase package inspected successfully"),
            ("schemaVersion", "Int?", false, "Inspect response schema version for ok responses"),
            ("kind", "String?", false, "Stable response kind; triton.testrec.inspect when ok"),
            ("path", "String?", false, "Resolved .tritontestcase directory path"),
            ("manifest", "TKTestRecorderManifest?", false, "Decoded manifest.json"),
            ("manifest.name", "String?", false, "Test case name"),
            ("manifest.sourcePlatform", "String?", false, "Source platform that produced the contract"),
            ("manifest.tritonKitVersion", "String?", false, "TritonKit CLI version that created the case, or unknown for hand-written manifests"),
            ("manifest.capabilitiesRef", "String?", false, "Relative capabilities file path inside the .tritontestcase package; default contract-capabilities.json"),
            ("manifest.redactionStatus", "String?", false, "Redaction lifecycle status, default pending before compile review"),
            ("manifest.truncationStatus", "String?", false, "Raw stream truncation status, default not-truncated"),
            ("capabilities", "TKTestRecorderContractCapabilities?", false, "Decoded contract-capabilities.json"),
            ("capabilities.actions", "[String]?", false, "Action contract capabilities such as tap, type, and scroll"),
            ("capabilities.pages", "[String]?", false, "Page contract capabilities such as route, ax, and fingerprint"),
            ("capabilities.network", "[String]?", false, "Network contract capabilities such as fixture and passthrough"),
            ("lifecycle", "TKTestRecorderLifecycle?", false, "Current .tritontestcase lifecycle summary"),
            ("lifecycle.stage", "String?", false, "raw, compiled, or proposed"),
            ("lifecycle.health", "String?", false, "needs-compile, ready, or review-proposals"),
            ("lifecycle.hasCompiledContract", "Bool?", false, "Whether compiled-contract.json exists"),
            ("lifecycle.hasCompileProposals", "Bool?", false, "Whether compile-proposals.jsonl exists"),
            ("unsupportedCapabilities", "[TKTestRecorderUnsupportedCapability]?", false, "Capabilities present in the contract but unsupported by current P0 inspect semantics"),
            ("unsupportedCapabilities[].domain", "String?", false, "Capability domain: actions, pages, or network"),
            ("unsupportedCapabilities[].name", "String?", false, "Unsupported capability name"),
            ("artifacts", "[TKTestRecorderArtifact]?", false, "Known .tritontestcase artifact presence report"),
            ("artifacts[].kind", "String?", false, "Artifact kind"),
            ("artifacts[].path", "String?", false, "Artifact path relative to the case package"),
            ("artifacts[].required", "Bool?", false, "Whether the artifact is required for P0 inspect"),
            ("artifacts[].present", "Bool?", false, "Whether the artifact exists"),
            ("artifacts[].byteCount", "Int?", false, "File byte count when the artifact exists"),
            ("artifacts[].digestAlgorithm", "String?", false, "Digest algorithm for artifacts[].digest; currently fnv1a64"),
            ("artifacts[].digest", "String?", false, "Deterministic artifact file digest when present"),
            ("suggestedCommands", "[String]?", false, "Current executable follow-up commands; inspect only exposes schema until compile/replay are implemented"),
            ("error", "TKTestRecorderValidationErrorDetail?", false, "Machine-readable validation failure when ok is false"),
            ("error.code", "String?", false, "Stable validation error code"),
            ("error.path", "String?", false, "Rejected file or field path"),
        ])
    )
}

func testRecorderCompileOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "testrec.compile",
        format: "json",
        kind: "testrec-compile",
        model: "TKTestRecorderCompileResponse|TKTestRecorderValidationFailureResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether compile preflight completed without validation errors"),
            ("schemaVersion", "Int?", false, "Compile response schema version for ok responses"),
            ("kind", "String?", false, "Stable response kind; triton.testrec.compile when ok"),
            ("path", "String?", false, "Resolved .tritontestcase directory path"),
            ("status", "String?", false, "compiled, needs-input, or needs-review"),
            ("manifest", "TKTestRecorderManifest?", false, "Decoded manifest.json"),
            ("capabilities", "TKTestRecorderContractCapabilities?", false, "Decoded contract-capabilities.json"),
            ("summary", "TKTestRecorderCompileSummary?", false, "Raw stream counts used by deterministic compile preflight"),
            ("summary.actionEventCount", "Int?", false, "Non-empty records in actions.jsonl"),
            ("summary.networkEventCount", "Int?", false, "Non-empty records in network/capture.ndjson"),
            ("summary.pageRouteEventCount", "Int?", false, "Non-empty records in pages/route-events.jsonl"),
            ("summary.pageFingerprintCount", "Int?", false, "Non-empty records in pages/fingerprints.jsonl"),
            ("compiledContract", "TKTestRecorderCompiledContract?", false, "Deterministic compiled contract payload when status is compiled"),
            ("compiledContract.kind", "String?", false, "Stable compiled contract kind"),
            ("compiledContract.compiler.mode", "String?", false, "Compiler mode; deterministic-offline for P0"),
            ("compiledContract.compiler.llmUsed", "Bool?", false, "Whether LLM was used to produce this contract"),
            ("compiledContract.compiler.vlmUsed", "Bool?", false, "Whether VLM was used to produce this contract"),
            ("compiledContract.actions", "[TKTestRecorderCompiledAction]?", false, "Semantic actions extracted from actions.jsonl"),
            ("compiledContract.actions[].action", "String?", false, "Semantic action name"),
            ("compiledContract.actions[].targetText", "String?", false, "Best-effort target label/text"),
            ("compiledContract.actions[].inputText", "String?", false, "Best-effort input text for type/paste actions"),
            ("compiledContract.network.requests", "[TKTestRecorderCompiledNetworkRequest]?", false, "Structured network capture requests extracted from network/capture.ndjson"),
            ("compiledContract.network.requests[].method", "String?", false, "Captured request method"),
            ("compiledContract.network.requests[].url", "String?", false, "Captured request URL"),
            ("compiledContract.pages.routes", "[TKTestRecorderCompiledPageRoute]?", false, "Structured page route events extracted from pages/route-events.jsonl"),
            ("compiledContract.pages.routes[].route", "String?", false, "Observed route identifier"),
            ("compiledContract.pages.fingerprints", "[TKTestRecorderCompiledPageFingerprint]?", false, "Structured page fingerprints extracted from pages/fingerprints.jsonl"),
            ("compiledContract.pages.fingerprints[].pageId", "String?", false, "Fingerprint page identifier"),
            ("compiledContract.pages.fingerprints[].kind", "String?", false, "Fingerprint kind, including future VLM-generated kinds"),
            ("compiledContract.pages.matchPolicy.scorer", "String?", false, "Deterministic page fingerprint matcher used for replay evidence"),
            ("compiledContract.pages.matchPolicy.thresholds.matched", "Double?", false, "Score threshold for matched page evidence"),
            ("compiledContract.pages.matchPolicy.thresholds.assistedMatched", "Double?", false, "Score threshold for assisted matched page evidence"),
            ("compiledContract.pages.matchPolicy.thresholds.needsReview", "Double?", false, "Score threshold for needs-review page evidence"),
            ("compiledContract.pages.matchPolicy.llmDecisionAuthority", "Bool?", false, "Whether LLM can directly decide page match pass/fail; false in P0"),
            ("compiledContract.qualityFindings", "[TKTestRecorderQualityFinding]?", false, "Deterministic compile findings for privacy, transient network, weak selector, and fixed wait review"),
            ("compiledContract.qualityFindings[].code", "String?", false, "Stable quality finding code"),
            ("compiledContract.qualityFindings[].severity", "String?", false, "Finding severity such as review"),
            ("compiledContract.qualityFindings[].proposalKind", "String?", false, "Future proposal family for LLM/VLM assisted compile suggestions"),
            ("contractArtifact", "TKTestRecorderContractArtifact?", false, "Written compiled contract artifact metadata"),
            ("contractArtifact.path", "String?", false, "Compiled contract artifact path"),
            ("contractArtifact.written", "Bool?", false, "Whether the compiled contract artifact was written"),
            ("actionMapArtifact", "TKTestRecorderContractArtifact?", false, "Written deterministic action map artifact metadata"),
            ("actionMapArtifact.path", "String?", false, "Action map artifact path, normally actions/action-map.json"),
            ("actionMapArtifact.written", "Bool?", false, "Whether the action map artifact was written"),
            ("networkMapArtifact", "TKTestRecorderContractArtifact?", false, "Written deterministic network map artifact metadata"),
            ("networkMapArtifact.path", "String?", false, "Network map artifact path, normally network/map-rules.json"),
            ("networkMapArtifact.written", "Bool?", false, "Whether the network map artifact was written"),
            ("pageMapArtifact", "TKTestRecorderContractArtifact?", false, "Written deterministic page map artifact metadata"),
            ("pageMapArtifact.path", "String?", false, "Page map artifact path, normally pages/page-map.json"),
            ("pageMapArtifact.written", "Bool?", false, "Whether the page map artifact was written"),
            ("proposalArtifact", "TKTestRecorderContractArtifact?", false, "Written compile proposal JSONL artifact metadata"),
            ("proposalArtifact.path", "String?", false, "Compile proposal artifact path"),
            ("proposalArtifact.written", "Bool?", false, "Whether compile proposals were written"),
            ("artifacts", "[TKTestRecorderArtifact]?", false, "Known .tritontestcase artifact presence report"),
            ("warnings", "[TKTestRecorderCompileWarning]?", false, "Compile preflight warnings requiring input or review"),
            ("warnings[].code", "String?", false, "Stable warning code"),
            ("warnings[].path", "String?", false, "Related case path"),
            ("warnings[].message", "String?", false, "Human-readable warning"),
            ("suggestedCommands", "[String]?", false, "Current executable follow-up commands"),
            ("error", "TKTestRecorderValidationErrorDetail?", false, "Machine-readable validation failure when ok is false"),
            ("error.code", "String?", false, "Stable validation error code"),
            ("error.path", "String?", false, "Rejected file or field path"),
        ])
    )
}

func testRecorderReplayDryRunOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "testrec.replay-dry-run",
        format: "json",
        kind: "testrec-replay-dry-run",
        model: "TKTestRecorderReplayDryRunResponse|TKTestRecorderValidationFailureResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether replay dry-run planning completed without validation errors"),
            ("schemaVersion", "Int?", false, "Replay dry-run response schema version for ok responses"),
            ("kind", "String?", false, "Stable response kind; triton.testrec.replay-dry-run when ok"),
            ("path", "String?", false, "Resolved .tritontestcase directory path"),
            ("dryRun", "Bool?", false, "Always true for this P0 replay surface"),
            ("platform", "String?", false, "Target platform requested for replay planning"),
            ("device", "String?", false, "Optional target device selector"),
            ("status", "String?", false, "ready or blocked"),
            ("manifest", "TKTestRecorderManifest?", false, "Decoded manifest.json"),
            ("capabilities", "TKTestRecorderContractCapabilities?", false, "Decoded contract-capabilities.json"),
            ("compileSummary", "TKTestRecorderCompileSummary?", false, "Compile preflight summary reused by replay planning"),
            ("contractRef", "TKTestRecorderReplayContractRef?", false, "Stable identity of compiled-contract.json used for this dry-run plan"),
            ("contractRef.path", "String?", false, "Contract artifact path, normally compiled-contract.json"),
            ("contractRef.byteCount", "Int?", false, "Compiled contract byte count"),
            ("contractRef.digestAlgorithm", "String?", false, "Digest algorithm used for contractRef.digest, currently fnv1a64"),
            ("contractRef.digest", "String?", false, "Deterministic digest of compiled-contract.json bytes"),
            ("pageChecks", "[TKTestRecorderReplayPageCheck]?", false, "Page fingerprint checkpoints planned before or during replay without execution"),
            ("pageChecks[].index", "Int?", false, "1-based page checkpoint index"),
            ("pageChecks[].pageId", "String?", false, "Source page id from compiled page fingerprint"),
            ("pageChecks[].route", "String?", false, "Source route from compiled page fingerprint"),
            ("pageChecks[].status", "String?", false, "planned, planned-with-partial-fingerprint, or needs-review"),
            ("pageChecks[].sourcePath", "String?", false, "Source compiled-contract.json fingerprint reference"),
            ("pageChecks[].command", "String?", false, "Triton command root planned for page matching"),
            ("pageChecks[].argv", "[String]?", false, "Executable Triton argv template for the planned page match"),
            ("pageChecks[].expectedArtifacts", "[String]?", false, "Evidence surfaces expected from executing the page check"),
            ("pageChecks[].stopConditions", "[String]?", false, "Machine-readable conditions that should stop or re-plan replay"),
            ("executorProfiles", "[TKTestRecorderReplayExecutorProfile]?", false, "Available and unsupported executor profiles for this dry-run plan"),
            ("executorProfiles[].id", "String?", false, "Executor id such as local-simulated or local-device"),
            ("executorProfiles[].status", "String?", false, "available or unsupported"),
            ("executorProfiles[].mode", "String?", false, "Execution mode, e.g. offline-simulated or device-execution"),
            ("executorProfiles[].message", "String?", false, "Human-readable executor profile summary"),
            ("executorProfiles[].requirements", "[TKTestRecorderReplayExecutorRequirement]?", false, "Capabilities required by this executor profile"),
            ("executorProfiles[].requirements[].name", "String?", false, "Requirement key"),
            ("executorProfiles[].requirements[].required", "Bool?", false, "Whether this profile requires the capability"),
            ("executorProfiles[].requirements[].status", "String?", false, "satisfied, missing, optional, not-required, simulated, not-present, or not-requested"),
            ("executorProfiles[].requirements[].evidence", "[String]?", false, "Evidence tags explaining requirement status"),
            ("executorProfiles[].nextCommand", "String?", false, "Next command for available executor or schema inspection"),
            ("plannedSteps", "[TKTestRecorderReplayPlannedStep]?", false, "Replay steps planned from actions.jsonl without execution"),
            ("plannedSteps[].index", "Int?", false, "1-based planned step index"),
            ("plannedSteps[].sourceEventID", "String?", false, "Optional source action event id"),
            ("plannedSteps[].action", "String?", false, "Semantic action name"),
            ("plannedSteps[].command", "String?", false, "Triton command root planned for this semantic action"),
            ("plannedSteps[].argv", "[String]?", false, "Executable Triton argv for the planned dry-run step"),
            ("plannedSteps[].status", "String?", false, "planned or unsupported"),
            ("plannedSteps[].sourcePath", "String?", false, "Source actions.jsonl line reference"),
            ("plannedSteps[].workflowCategories", "[String]?", false, "Workflow taxonomy values associated with the planned step"),
            ("plannedSteps[].expectedArtifacts", "[String]?", false, "Evidence surfaces expected from executing the planned step"),
            ("plannedSteps[].stopConditions", "[String]?", false, "Machine-readable conditions that should stop or re-plan replay"),
            ("blockers", "[TKTestRecorderReplayBlocker]?", false, "Dry-run blockers that prevent real replay execution"),
            ("blockers[].code", "String?", false, "Stable blocker code"),
            ("blockers[].path", "String?", false, "Related case path or CLI option"),
            ("blockers[].message", "String?", false, "Human-readable blocker"),
            ("suggestedCommands", "[String]?", false, "Current executable follow-up commands"),
            ("error", "TKTestRecorderValidationErrorDetail?", false, "Machine-readable validation failure when ok is false"),
            ("error.code", "String?", false, "Stable validation error code"),
            ("error.path", "String?", false, "Rejected file or field path"),
        ])
    )
}

func testRecorderReplayRunOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "testrec.replay-result",
        format: "json",
        kind: "testrec-replay-result",
        model: "TKTestRecorderReplayRunResponse|TKTestRecorderValidationFailureResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the replay executor finished without blockers"),
            ("schemaVersion", "Int?", false, "Replay result response schema version for ok responses"),
            ("kind", "String?", false, "Stable response kind; triton.testrec.replay-result when ok"),
            ("path", "String?", false, "Resolved .tritontestcase directory path"),
            ("dryRun", "Bool?", false, "False for replay-result responses"),
            ("executor", "String?", false, "Replay executor identifier; local-simulated or local-device"),
            ("platform", "String?", false, "Target platform requested for replay"),
            ("device", "String?", false, "Optional target device selector"),
            ("status", "String?", false, "passed or blocked"),
            ("manifest", "TKTestRecorderManifest?", false, "Decoded manifest.json"),
            ("capabilities", "TKTestRecorderContractCapabilities?", false, "Decoded contract-capabilities.json"),
            ("compileSummary", "TKTestRecorderCompileSummary?", false, "Compile preflight summary reused by replay"),
            ("contractRef", "TKTestRecorderReplayContractRef?", false, "Stable identity of compiled-contract.json used for this replay result"),
            ("contractRef.path", "String?", false, "Contract artifact path, normally compiled-contract.json"),
            ("contractRef.byteCount", "Int?", false, "Compiled contract byte count"),
            ("contractRef.digestAlgorithm", "String?", false, "Digest algorithm used for contractRef.digest, currently fnv1a64"),
            ("contractRef.digest", "String?", false, "Deterministic digest of compiled-contract.json bytes"),
            ("evidenceDir", "String?", false, "Optional .tritonevidence directory written by replay"),
            ("artifactRefs", "[String]?", false, "Evidence artifact refs written under evidenceDir"),
            ("execution", "TKTestRecorderReplayExecutionSummary?", false, "Executor boundary summary proving whether replay executed real device/model/network side effects"),
            ("execution.mode", "String?", false, "Execution mode, offline-simulated or device-execution"),
            ("execution.executor", "String?", false, "Executor identifier repeated for nested evidence consumers"),
            ("execution.requiresDevice", "Bool?", false, "Whether this executor requires a live target device"),
            ("execution.deviceCommandsExecuted", "Bool?", false, "Whether Triton device action commands were actually executed"),
            ("execution.llmUsed", "Bool?", false, "Whether an LLM participated in this replay result"),
            ("execution.vlmUsed", "Bool?", false, "Whether a VLM participated in this replay result"),
            ("execution.networkPolicyMode", "String?", false, "not-present, simulated-projection, or not-applied"),
            ("execution.stepStatusTaxonomy", "[String]?", false, "Allowed step result statuses: executed, failed, skipped, blocked, not-run, simulated-passed"),
            ("execution.executorRequirements", "[TKTestRecorderReplayExecutorRequirement]?", false, "Executor capability requirements and whether this executor satisfies, simulates, or does not require them"),
            ("execution.executorRequirements[].name", "String?", false, "Requirement key such as compiled-contract or live-target-device"),
            ("execution.executorRequirements[].required", "Bool?", false, "Whether the current executor requires this capability"),
            ("execution.executorRequirements[].status", "String?", false, "satisfied, missing, optional, not-required, simulated, not-present, or not-requested"),
            ("execution.executorRequirements[].evidence", "[String]?", false, "Evidence tags explaining the requirement status"),
            ("execution.evidence", "[String]?", false, "Evidence tags explaining executor side-effect boundaries"),
            ("evidenceSummary", "TKTestRecorderReplayEvidenceSummary?", false, "Expected evidence/event consistency counts for replay result and events.jsonl"),
            ("evidenceSummary.expectedEventCount", "Int?", false, "Expected events.jsonl line count: started + page + network + step + finished"),
            ("evidenceSummary.pageEventCount", "Int?", false, "Expected page event count"),
            ("evidenceSummary.networkEventCount", "Int?", false, "Expected network event count"),
            ("evidenceSummary.stepEventCount", "Int?", false, "Expected step event count"),
            ("evidenceSummary.artifactRefCount", "Int?", false, "Unique top-level replay artifactRefs count"),
            ("evidenceSummary.pageArtifactRefCount", "Int?", false, "Total page result artifactRefs count"),
            ("evidenceSummary.networkArtifactRefCount", "Int?", false, "Total network result artifactRefs count"),
            ("evidenceSummary.stepArtifactRefCount", "Int?", false, "Total step and step failure artifactRefs count"),
            ("evidenceSummary.blockerCount", "Int?", false, "Replay blocker count"),
            ("evidenceSummary.statusConsistent", "Bool?", false, "Whether status and blockers are internally consistent"),
            ("pageResults", "[TKTestRecorderReplayPageResult]?", false, "Page checkpoint results from the executor"),
            ("pageResults[].index", "Int?", false, "1-based page checkpoint index"),
            ("pageResults[].pageId", "String?", false, "Source page id from compiled page fingerprint"),
            ("pageResults[].route", "String?", false, "Source route from compiled page fingerprint"),
            ("pageResults[].status", "String?", false, "simulated, matched, assisted-matched, needs-review, not-matched, or not-run"),
            ("pageResults[].matchScore", "Double?", false, "Deterministic target fingerprint match score when target fingerprints are supplied"),
            ("pageResults[].matchDecision", "String?", false, "Deterministic target fingerprint match decision when target fingerprints are supplied"),
            ("pageResults[].sourcePath", "String?", false, "Source compiled-contract.json fingerprint reference"),
            ("pageResults[].artifactRefs", "[String]?", false, "Page-level evidence artifacts referenced by the replay projection, including target fingerprints when supplied"),
            ("pageResults[].evidence", "[String]?", false, "Evidence tags explaining how this page checkpoint was handled"),
            ("pageResults[].expectedArtifacts", "[String]?", false, "Evidence surfaces expected from a real executor"),
            ("networkResults", "[TKTestRecorderReplayNetworkResult]?", false, "Network map rule projections consumed by local-simulated replay"),
            ("networkResults[].index", "Int?", false, "Network rule index"),
            ("networkResults[].id", "String?", false, "Network rule id"),
            ("networkResults[].status", "String?", false, "simulated-<strategy>"),
            ("networkResults[].strategy", "String?", false, "Network map strategy such as mock-candidate or passthrough"),
            ("networkResults[].sourcePath", "String?", false, "Source network capture reference"),
            ("networkResults[].method", "String?", false, "Matched request method"),
            ("networkResults[].url", "String?", false, "Matched request URL"),
            ("networkResults[].nonBlocking", "Bool?", false, "Whether the rule is non-blocking for replay"),
            ("networkResults[].redactionRequired", "Bool?", false, "Whether fixture or request data requires redaction before real replay"),
            ("networkResults[].fixturePath", "String?", false, "Redacted network fixture path referenced by the network map rule, when present"),
            ("networkResults[].artifactRefs", "[String]?", false, "Network evidence artifacts referenced by the replay projection, including redacted fixtures"),
            ("networkResults[].evidence", "[String]?", false, "Evidence tags explaining how this network rule was handled"),
            ("steps", "[TKTestRecorderReplayStepResult]?", false, "Per-action executor results"),
            ("steps[].index", "Int?", false, "1-based step index"),
            ("steps[].sourceEventID", "String?", false, "Optional source action event id"),
            ("steps[].action", "String?", false, "Semantic action name"),
            ("steps[].status", "String?", false, "executed, failed, skipped, blocked, not-run, or simulated-passed"),
            ("steps[].sourcePath", "String?", false, "Source compiled-contract.json action reference"),
            ("steps[].command", "String?", false, "Triton command root projected for this semantic action"),
            ("steps[].argv", "[String]?", false, "Projected Triton argv tokens; local-simulated does not execute them"),
            ("steps[].deviceCommandExecuted", "Bool?", false, "Whether this step actually executed its projected device command"),
            ("steps[].artifactRefs", "[String]?", false, "Actual evidence artifacts produced by this step; empty for local-simulated"),
            ("steps[].evidence", "[String]?", false, "Evidence tags explaining how this action was handled"),
            ("steps[].failure", "TKTestRecorderReplayStepFailure?", false, "Machine-readable step failure envelope for real executors"),
            ("steps[].failure.code", "String?", false, "Stable failure code"),
            ("steps[].failure.message", "String?", false, "Human-readable failure summary"),
            ("steps[].failure.path", "String?", false, "Related command, selector, or contract path"),
            ("steps[].failure.artifactRefs", "[String]?", false, "Failure-specific evidence artifacts"),
            ("steps[].failure.recoveryCommands", "[String]?", false, "Suggested Triton recovery commands"),
            ("steps[].failure.retryable", "Bool?", false, "Whether the executor may retry this step safely"),
            ("steps[].expectedArtifacts", "[String]?", false, "Evidence surfaces expected from a real executor"),
            ("steps[].stopConditions", "[String]?", false, "Machine-readable conditions that should stop or re-plan replay"),
            ("blockers", "[TKTestRecorderReplayBlocker]?", false, "Blockers that prevented local simulation from passing"),
            ("blockers[].code", "String?", false, "Stable blocker code"),
            ("blockers[].path", "String?", false, "Related case path or CLI option"),
            ("blockers[].message", "String?", false, "Human-readable blocker"),
            ("suggestedCommands", "[String]?", false, "Current executable follow-up commands"),
            ("error", "TKTestRecorderValidationErrorDetail?", false, "Machine-readable validation failure when ok is false"),
            ("error.code", "String?", false, "Stable validation error code"),
            ("error.path", "String?", false, "Rejected file or field path"),
        ])
    )
}

func testRecorderPageMatchOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "testrec.page-match",
        format: "json",
        kind: "testrec-page-fingerprint-match",
        model: "TKTestRecorderFingerprintMatchResponse|TKTestRecorderValidationFailureResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether page fingerprint matching completed without validation errors"),
            ("schemaVersion", "Int?", false, "Page match response schema version for ok responses"),
            ("kind", "String?", false, "Stable response kind; triton.testrec.page-fingerprint-match when ok"),
            ("path", "String?", false, "Resolved .tritontestcase directory path"),
            ("page", "String?", false, "Source page selector used for lookup"),
            ("source", "TKTestRecorderCompiledPageFingerprint?", false, "Compiled source page fingerprint from compiled-contract.json"),
            ("candidate", "TKTestRecorderFingerprintMatchSubject?", false, "Target-side candidate fingerprint fields considered by the matcher"),
            ("policy", "TKTestRecorderFingerprintMatchPolicy?", false, "Compiled page match policy"),
            ("policy.scorer", "String?", false, "Deterministic scorer id"),
            ("policy.thresholds.matched", "Double?", false, "Score threshold for matched"),
            ("policy.thresholds.assistedMatched", "Double?", false, "Score threshold for assisted-matched"),
            ("policy.thresholds.needsReview", "Double?", false, "Score threshold for needs-review"),
            ("policy.llmDecisionAuthority", "Bool?", false, "Whether LLM can decide pass/fail; false in P0"),
            ("scorer", "String?", false, "Scorer used for this match"),
            ("score", "Double?", false, "Weighted deterministic match score"),
            ("decision", "String?", false, "matched, assisted-matched, needs-review, or not-matched"),
            ("components", "[TKTestRecorderFingerprintMatchComponent]?", false, "Weighted evidence components"),
            ("components[].name", "String?", false, "Component name such as hash, route, pageId, or kind"),
            ("components[].weight", "Double?", false, "Component weight in the score"),
            ("components[].score", "Double?", false, "Component match score"),
            ("components[].evidence", "String?", false, "Component evidence reason"),
            ("evidence", "[String]?", false, "Compact evidence trail for replay diagnostics"),
            ("llmUsed", "Bool?", false, "Whether an LLM was called; false in P0 deterministic matching"),
            ("llmDecisionAuthority", "Bool?", false, "Whether LLM had decision authority; false in P0"),
            ("suggestedCommands", "[String]?", false, "Current executable follow-up commands"),
            ("error", "TKTestRecorderValidationErrorDetail?", false, "Machine-readable validation failure when ok is false"),
            ("error.code", "String?", false, "Stable validation error code"),
            ("error.path", "String?", false, "Rejected file or field path"),
        ])
    )
}

func actionProviderParseOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "action.provider.parse",
        format: "json",
        kind: "action-provider-parse-result",
        model: "TKActionProviderParseResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the provider output parsed"),
            ("schemaVersion", "Int", true, "Parse response schema version; always 1"),
            ("kind", "String", true, "Stable kind; triton.action-provider.parse-result"),
            ("provider", "String", true, "Provider parser: ui-tars or agentcpm-gui"),
            ("sourceFormat", "String", true, "Provider source format"),
            ("primitive", "String", true, "Mapped Triton primitive preview: tap, type, swipe, press, wait, or status"),
            ("action", "String", true, "Original provider action name"),
            ("coordinateSystem", "String?", false, "Coordinate system for point actions; normalized_0_1000"),
            ("point", "TKActionProviderPoint?", false, "Start/tap point"),
            ("endPoint", "TKActionProviderPoint?", false, "End point for swipe"),
            ("text", "String?", false, "Text payload for type"),
            ("key", "String?", false, "Key/button payload for press"),
            ("status", "String?", false, "Status payload for wait/done"),
            ("commandPreview", "[String]", true, "Non-executed Triton primitive command preview"),
        ])
    )
}

func appMapViewerOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "app-map.viewer",
        format: "json",
        kind: "app-map-viewer-result",
        model: "TKAppMapViewerResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the static viewer was written"),
            ("schemaVersion", "Int", true, "Viewer response schema version; always 1"),
            ("kind", "String", true, "Stable kind; triton.app-map.viewer-result"),
            ("mapDir", "String", true, "Input .tritonmap directory"),
            ("output", "String", true, "Output HTML file path"),
            ("bytes", "Int", true, "Written byte count"),
            ("screenCount", "Int", true, "Number of screens included"),
            ("transitionCount", "Int", true, "Number of transitions included"),
            ("pathCount", "Int", true, "Number of paths included"),
            ("suiteCount", "Int", true, "Number of suites in the map"),
        ])
    )
}

func appMapVLMHealthOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "app-map.vlm-health",
        format: "json",
        kind: "app-map-vlm-health-result",
        model: "TKAppMapVLMHealthResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether VLM health inspection succeeded"),
            ("kind", "String", true, "Stable kind; triton.app-map.vlm-health-result"),
            ("mapDir", "String", true, "Input .tritonmap directory"),
            ("providerCount", "Int", true, "Number of provider summaries"),
            ("providers", "[TKAppMapVLMProviderSummary]", true, "Provider-level VLM health summaries"),
            ("providers[].id", "String", true, "Provider id"),
            ("providers[].groundingRuns", "Int", true, "Observed grounding runs"),
            ("providers[].successRate", "Double", true, "Success count divided by grounding runs"),
            ("providers[].meanLatencyMs", "Double?", false, "Mean VLM grounding latency when available"),
            ("providers[].topFailures", "[String]", true, "Top machine-readable failure categories"),
        ])
    )
}

func vlmGroundOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "vlm.ground",
        format: "json",
        kind: "vlm-ground-result",
        model: "TKVLMGroundResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether mock VLM grounding succeeded"),
            ("schemaVersion", "Int", true, "Grounding response schema version"),
            ("kind", "String", true, "Stable kind; triton.vlm.ground-result"),
            ("provider", "String", true, "Grounding provider; mock, openai-compatible, or mlx-swift-lm"),
            ("model", "String?", false, "Provider model for OpenAI-compatible or local MLX grounding"),
            ("baseURL", "String?", false, "Redacted OpenAI-compatible base URL when configured"),
            ("target", "String", true, "Target phrase grounded against the screenshot"),
            ("image", "TKVLMGroundImage", true, "Screenshot metadata"),
            ("image.path", "String", true, "Screenshot path"),
            ("image.width", "Double", true, "Screenshot pixel width"),
            ("image.height", "Double", true, "Screenshot pixel height"),
            ("image.sha256", "String", true, "Screenshot SHA-256"),
            ("coordinateContract", "TKVLMGroundCoordinateContractRef", true, "Coordinate contract reference"),
            ("coordinateContract.path", "String", true, "coordinate-contract.json path"),
            ("coordinateContract.canonicalTapSpace", "String", true, "Canonical tap coordinate space; runtime-point"),
            ("point", "TKVLMGroundPoint", true, "Grounded point in normalized and runtime spaces"),
            ("point.normalized", "TKVLMNormalizedPoint", true, "Provider point in normalized_0_1000"),
            ("point.normalized.x", "Double", true, "Normalized x coordinate"),
            ("point.normalized.y", "Double", true, "Normalized y coordinate"),
            ("point.normalized.scale", "Double", true, "Normalized coordinate scale"),
            ("point.runtimePoint", "TKVLMRuntimePoint", true, "Converted runtime-point"),
            ("point.runtimePoint.x", "Double", true, "Runtime x point"),
            ("point.runtimePoint.y", "Double", true, "Runtime y point"),
            ("point.coordinateSpace", "String", true, "Output coordinate space; runtime-point"),
            ("transform", "TKVLMCoordinateTransform", true, "Coordinate transform metadata"),
            ("transform.inputSpace", "String", true, "Provider coordinate space"),
            ("transform.imageSpace", "String", true, "Intermediate image coordinate space"),
            ("transform.outputSpace", "String", true, "Output coordinate space"),
            ("transform.imageWidth", "Double", true, "Image width used for transform"),
            ("transform.imageHeight", "Double", true, "Image height used for transform"),
            ("transform.runtimeWidth", "Double", true, "Runtime geometry width"),
            ("transform.runtimeHeight", "Double", true, "Runtime geometry height"),
            ("transform.scale", "Double", true, "Runtime display scale from coordinate contract"),
            ("transform.orientation", "String", true, "Runtime orientation from coordinate contract"),
            ("transform.source", "String", true, "Coordinate contract path"),
            ("artifacts", "TKVLMGroundArtifacts", true, "Grounding artifacts"),
            ("artifacts.overlay", "String", true, "Overlay PNG path"),
            ("artifacts.request", "String", true, "Redacted request JSON path"),
            ("artifacts.response", "String", true, "Provider response JSON path"),
            ("artifacts.rawOutput", "String?", false, "MLX raw output text path"),
            ("artifacts.parsedPoint", "String?", false, "MLX parsed point JSON path"),
            ("artifacts.transform", "String?", false, "MLX coordinate transform JSON path"),
            ("artifacts.modelMetadata", "String?", false, "MLX model metadata JSON path"),
        ])
    )
}

func vlmProvidersOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "vlm.providers",
        format: "json",
        kind: "vlm-providers-result",
        model: "TKVLMProviderListResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether provider listing succeeded"),
            ("schemaVersion", "Int", true, "Provider list schema version"),
            ("kind", "String", true, "Stable kind; triton.vlm.providers-result"),
            ("providers", "[TKVLMProviderDescriptor]", true, "Provider descriptors"),
            ("providers[].id", "String", true, "Provider id"),
            ("providers[].kind", "String", true, "Provider kind"),
            ("providers[].status", "String", true, "Provider stability status"),
            ("providers[].requiresNetwork", "Bool", true, "Whether provider requires network"),
            ("providers[].requiresModel", "Bool", true, "Whether provider requires model config"),
            ("providers[].defaultEnabledInCI", "Bool", true, "Whether provider is enabled in default CI"),
            ("providers[].supports", "[String]", true, "Supported operations"),
            ("providers[].coordinateOutputs", "[String]", true, "Supported output coordinate spaces"),
            ("providers[].runnerIntegration", "TKVLMProviderRunnerIntegration?", false, "Runner integration policy"),
        ])
    )
}

func vlmCompareOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "vlm.compare",
        format: "json",
        kind: "vlm-compare-result",
        model: "TKVLMCompareResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether comparison command completed"),
            ("kind", "String", true, "Stable kind; triton.vlm.compare-result"),
            ("target", "String", true, "Grounding target phrase"),
            ("image", "TKVLMGroundImage", true, "Screenshot metadata"),
            ("results", "[TKVLMCompareProviderResult]", true, "Per-provider status and point result"),
            ("results[].provider", "String", true, "Provider id"),
            ("results[].status", "String", true, "passed or failed"),
            ("results[].runtimePoint", "TKVLMRuntimePoint?", false, "Runtime point when provider passed"),
            ("results[].latencyMs", "Int", true, "Provider elapsed time in milliseconds"),
            ("results[].errorCode", "String?", false, "Machine-readable provider failure code"),
            ("agreement", "TKVLMCompareAgreement", true, "Pairwise distance agreement metrics"),
            ("artifacts.comparisonOverlay", "String", true, "Comparison overlay PNG"),
            ("artifacts.results", "String", true, "Persisted comparison JSON"),
        ])
    )
}

func vlmModelListOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "vlm.model.list",
        format: "json",
        kind: "vlm-model-list-result",
        model: "TKVLMModelListResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether model listing succeeded"),
            ("provider", "String", true, "Provider id; mlx-swift-lm"),
            ("cacheDir", "String", true, "Resolved local model cache directory"),
            ("models", "[TKVLMModelCacheEntry]", true, "Cached model entries"),
            ("models[].status", "String", true, "ready or incomplete"),
        ])
    )
}

func vlmModelInspectOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "vlm.model.inspect",
        format: "json",
        kind: "vlm-model-inspect-result",
        model: "TKVLMModelInspectResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether model inspection succeeded"),
            ("provider", "String", true, "Provider id; mlx-swift-lm"),
            ("model", "TKVLMModelCacheEntry", true, "Model cache metadata"),
        ])
    )
}

func vlmModelPreflightOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "vlm.model.preflight",
        format: "json",
        kind: "vlm-model-preflight-result",
        model: "TKVLMModelPreflightResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether required preflight checks passed"),
            ("provider", "String", true, "Provider id; mlx-swift-lm"),
            ("modelPath", "String", true, "Resolved model path"),
            ("checks", "[TKVLMModelPreflightCheck]", true, "Preflight check rows"),
        ])
    )
}

func vlmModelMutationOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "vlm.model.mutation",
        format: "json",
        kind: "vlm-model-mutation-result",
        model: "TKVLMModelMutationResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether prune/remove completed"),
            ("provider", "String", true, "Provider id; mlx-swift-lm"),
            ("cacheDir", "String", true, "Resolved cache directory"),
            ("removed", "[String]", true, "Removed model/cache directories"),
            ("kept", "[String]", true, "Kept model/cache directories"),
        ])
    )
}

func vlmModelDownloadOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "vlm.model.download",
        format: "json",
        kind: "vlm-model-download-result",
        model: "TKVLMModelDownloadResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether model download command completed"),
            ("provider", "String", true, "Provider id; mlx-swift-lm"),
            ("model", "String", true, "Requested model id"),
            ("cacheDir", "String", true, "Resolved local model cache directory"),
            ("modelPath", "String", true, "Resolved local model path"),
            ("status", "String", true, "downloaded or already-ready"),
            ("downloaded", "Bool", true, "Whether helper was invoked to download"),
            ("bytesDownloaded", "Int64?", false, "Helper-reported downloaded or copied bytes"),
            ("modelEntry", "TKVLMModelCacheEntry", true, "Ready cache metadata after download"),
        ])
    )
}

func webLaunchPlanOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "web.launch-plan",
        format: "json",
        kind: "host-action",
        model: "WebLaunchPlan",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the launch plan was resolved"),
            ("action", "String", true, "Stable action id; web.start"),
            ("mode", "String", true, "dev when launching checkout Vite, packaged when serving bundled Web/dist"),
            ("repoRoot", "String?", false, "Resolved TritonKit checkout root in dev mode, or bundled package root in packaged mode"),
            ("webRoot", "String?", false, "Resolved Web package directory in dev mode"),
            ("bundledWebRoot", "String?", false, "Bundled static Web asset directory in packaged mode"),
            ("tritonBin", "String", true, "Triton CLI path injected into TRITONKIT_TRITON_BIN"),
            ("host", "String", true, "Host bind address"),
            ("port", "Int", true, "Web Device Hub port"),
            ("url", "String", true, "Browser URL for the Device Hub"),
            ("readonly", "Bool", true, "Whether the Web surface is readonly for business control"),
            ("discovery", "WebAutoDiscoveryPlan", true, "Default simulator/real-device discovery policy for triton web"),
            ("discovery.simulator", "String", true, "Simulator discovery mode; auto by default"),
            ("discovery.realDevice", "String", true, "Real-device discovery mode; auto unless --simulator-only is set"),
            ("discovery.transportPriority", "[String]", true, "Real-device transport priority, default usb > bonjour > manual"),
            ("discovery.registry", "String", true, "Target registry ownership; serve-owned by default"),
            ("discovery.targetRegistryEndpoint", "String", true, "Readonly HTTP registry endpoint consumed by Web"),
            ("discovery.managedServeHost", "String", true, "Host bind address used when Web bridge auto-starts triton serve; 0.0.0.0 keeps real-device Debug runtimes reachable"),
            ("installCommand", "WebLaunchCommand?", false, "Optional npm install command"),
            ("command", "WebLaunchCommand", true, "npm run dev command in dev mode, or triton web packaged server command in packaged mode"),
            ("environment", "[String:String]", true, "Environment overrides passed to child processes"),
        ])
    )
}

func webStatusOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "web.status",
        format: "json",
        kind: "status-envelope",
        model: "WebStatusResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the status inspection completed"),
            ("action", "String", true, "Stable action id; web.status"),
            ("host", "String", true, "Inspected host address"),
            ("port", "Int", true, "Inspected Web Device Hub port"),
            ("url", "String", true, "Inspected Web Device Hub URL"),
            ("portListening", "Bool", true, "Whether a TCP listener is present"),
            ("probe", "WebServiceProbe?", false, "Optional HTTP probe result when a listener is present"),
            ("recommendedActions", "[String]", true, "Human-copyable recovery or next commands"),
        ])
    )
}

func webDoctorOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "web.doctor",
        format: "json",
        kind: "diagnostic-checks",
        model: "WebDoctorResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the doctor inspection completed"),
            ("action", "String", true, "Stable action id; web.doctor"),
            ("healthy", "Bool", true, "False when a failed check is present"),
            ("status", "WebStatusResponse", true, "Embedded web.status response"),
            ("checks", "[WebDoctorCheck]", true, "Ordered diagnostic checks"),
            ("recommendedActions", "[String]", true, "Human-copyable recovery or next commands"),
        ])
    )
}

func runtimeManifestOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "runtime.manifest",
        format: "json",
        kind: "runtime-manifest",
        model: "TKRuntimeManifestResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the runtime manifest request succeeded"),
            ("platform", "String", true, "Runtime platform such as ios"),
            ("runtime", "String", true, "Runtime scope, usually embedded"),
            ("transport", "String", true, "Runtime transport name"),
            ("enabled", "Bool", true, "Whether runtime features are enabled"),
            ("sdkVersion", "String", true, "Embedded SDK version"),
            ("buildConfiguration", "String", true, "debug or release"),
            ("capabilities", "[TKRuntimeCapabilityDetail]", true, "Runtime capability details"),
            ("capabilities[].name", "String", true, "Machine-readable runtime capability identifier"),
            ("capabilities[].supported", "Bool", true, "Whether the runtime can support this capability in the current environment"),
            ("capabilities[].enabled", "Bool", true, "Whether the app runtime configuration currently allows this capability"),
            ("capabilities[].reason", "String?", false, "Why a capability is unsupported or disabled"),
            ("semanticDomains", "[TKRuntimeSemanticDomainManifest]", true, "Registered app semantic domains advertised by opt-in providers; state values are read through snapshot"),
            ("semanticDomains[].domain", "String", true, "Provider-owned semantic domain identifier"),
            ("semanticDomains[].source", "String", true, "Provider source such as runtime-provider"),
            ("semanticDomains[].confidence", "String", true, "Provider confidence such as provider-backed"),
            ("semanticDomains[].schema", "[TKRuntimeSemanticStateField]", true, "Typed state field catalog for query/assert planning"),
            ("semanticDomains[].actions", "[TKRuntimeSemanticActionDescriptor]", true, "Provider-declared action catalog for action discovery"),
            ("semanticDomains[].redaction", "TKRuntimeSemanticRedaction", true, "Provider-declared redaction policy"),
            ("limits", "TKRuntimeLimits", true, "Runtime collection limits"),
            ("redaction", "TKRuntimeRedactionPolicy", true, "Runtime redaction policy"),
        ])
    )
}

func runtimeStateOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "runtime.state",
        format: "json",
        kind: "runtime-state",
        model: "TKRuntimeAppStateResponse|TKRuntimeSceneStateResponse|TKRuntimeRouteStateResponse|TKRuntimeResponderStateResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the state request succeeded"),
            ("capturedAt", "String", true, "Capture timestamp"),
            ("runtime", "String", true, "Runtime scope, usually embedded"),
            ("targetConnectionState", "String?", false, "Connected or disconnected target state"),
            ("app", "TKRuntimeAppState?", false, "App state for state app"),
            ("scenes", "[TKRuntimeSceneState]?", false, "Scene states for state scene"),
            ("keyWindow", "TKRuntimeWindowState?", false, "Key window summary for state scene"),
            ("rootController", "TKRuntimeControllerState?", false, "Root controller for state route"),
            ("visibleController", "TKRuntimeControllerState?", false, "Visible controller for state route"),
            ("presentedStack", "[TKRuntimeControllerState]?", false, "Presented controller stack"),
            ("navigationStack", "[TKRuntimeControllerState]?", false, "Navigation controller stack"),
            ("tab", "TKRuntimeTabState?", false, "Tab state summary"),
            ("firstResponder", "TKRuntimeResponderState?", false, "First responder summary without text content"),
            ("redaction", "TKRuntimeStateRedaction?", false, "Responder redaction policy"),
            ("warnings", "[String]", true, "Non-fatal warnings"),
            ("unsupported", "[TKRuntimeUnsupportedState]", true, "Unsupported fields and reasons"),
        ])
    )
}

func runtimeSnapshotOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "runtime.snapshot",
        format: "json",
        kind: "runtime-snapshot",
        model: "TKRuntimeSnapshotResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the snapshot request succeeded"),
            ("capturedAt", "String", true, "Capture timestamp"),
            ("runtime", "String", true, "Runtime scope, usually embedded"),
            ("targetConnectionState", "String?", false, "Connected or disconnected target state"),
            ("include", "[String]", true, "Requested snapshot sections"),
            ("app", "TKRuntimeAppState?", false, "App state when included"),
            ("scene", "TKRuntimeSceneStateResponse?", false, "Scene state when included"),
            ("route", "TKRuntimeRouteStateResponse?", false, "Route state when included"),
            ("responder", "TKRuntimeResponderStateResponse?", false, "Responder state when included"),
            ("media", "TKRuntimeMediaStateResponse?", false, "Media playback surfaces, AX control candidates, confidence, fallback guidance, and evidence commands when included"),
            ("semantic", "TKRuntimeSemanticStateResponse?", false, "Provider-backed app semantic domains, typed state, action descriptors, redaction metadata, and evidence commands when included"),
            ("semantic.domains[]", "TKRuntimeSemanticDomainState", false, "Registered semantic domain state entries"),
            ("semantic.domains[].source", "String", true, "Provider source; runtime-provider is app-owned state, unlike ax-tree or host-layout inference"),
            ("semantic.domains[].confidence", "String", true, "Provider confidence label for business fact trust decisions"),
            ("semantic.domains[].schema", "[TKRuntimeSemanticStateField]", false, "Typed state field catalog for query/assert planning"),
            ("semantic.domains[].state", "[String:TKJSONValue]", false, "Provider-owned typed business state values"),
            ("semantic.domains[].actions", "[TKRuntimeSemanticActionDescriptor]", false, "Provider-declared semantic action catalog; execution is a future provider command slice"),
            ("semantic.domains[].redaction", "TKRuntimeSemanticRedaction", false, "Provider-declared redaction metadata for state and action fields"),
            ("geometry", "TKGeometryResponse?", false, "Window geometry when included"),
            ("ax", "[TKAXNode]?", false, "Accessibility tree when included"),
            ("screenshot", "TKRuntimeScreenshotMetadata?", false, "Screenshot metadata when included"),
            ("artifacts", "[TKRuntimeSnapshotArtifact]", true, "Captured artifact freshness summaries"),
            ("skipped", "[TKRuntimeSnapshotSkipped]", true, "Skipped sections and reasons"),
            ("truncation", "TKRuntimeSnapshotTruncation", true, "Snapshot truncation summary"),
        ])
    )
}

func routeCurrentURLAssertionOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "route.current-url-assert",
        format: "json",
        kind: "route-assertion",
        model: "RouteCurrentURLAssertionSummary",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the route assertion passed"),
            ("action", "String", true, "route.assert-current-url"),
            ("status", "String", true, "pass or fail"),
            ("expectedURL", "String", true, "Expected URL"),
            ("actualURL", "String", true, "Observed URL"),
            ("matched", "Bool", true, "Whether URLs matched"),
            ("ignoreQuery", "Bool", true, "Whether query items were ignored"),
            ("platform", "String", true, "ios or harmony"),
            ("target", "String", true, "Resolved target selector"),
            ("webViewID", "String", true, "Selected WebView id"),
            ("title", "String?", false, "Provider page title"),
            ("pageSessionID", "String?", false, "Provider page session id"),
            ("hint", "String?", false, "Failure follow-up hint"),
        ])
    )
}

func screenshotMetadataOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "screenshot.metadata",
        format: "json",
        kind: "screenshot-metadata",
        model: "ScreenshotMetadataOutput",
        fields: schemaContractFields([
            ("format", "String", true, "Validated image format; embedded runtime success is png"),
            ("width", "Double", true, "Image width in points or pixels depending on source"),
            ("height", "Double", true, "Image height in points or pixels depending on source"),
            ("scale", "Double", true, "Image scale"),
            ("output", "String", true, "Written screenshot path"),
            ("bytes", "Int", true, "Written byte count"),
        ])
    )
}

func targetResolutionOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "target.resolution",
        format: "json",
        kind: "target-resolution",
        model: "TapTargetResolution",
        fields: schemaContractFields([
            ("query", "String", true, "Original text or identifier query"),
            ("source", "String", true, "Matched source such as ax, hierarchy, or option"),
            ("strategy", "String", true, "Activation strategy used for the candidate"),
            ("role", "String?", false, "Optional accessibility role"),
            ("label", "String?", false, "Matched label"),
            ("value", "String?", false, "Matched value"),
            ("identifier", "String?", false, "Matched accessibility identifier"),
            ("className", "String?", false, "Matched view class name"),
            ("viewOID", "UInt?", false, "Matched view oid"),
            ("targetOID", "UInt?", false, "Action target oid"),
            ("layerOID", "UInt?", false, "Matched layer oid"),
            ("frame", "TKRect?", false, "Matched frame in window points"),
            ("request", "TKInputRequest", true, "Executable input request for the selected target"),
            ("matchIndex", "Int", true, "1-based selected match index"),
            ("matchCount", "Int", true, "Total match count"),
            ("candidates", "[TapTargetCandidate]?", false, "All candidates when --all is requested"),
        ])
    )
}

func axOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "ax.nodes",
        format: "json",
        kind: "ax-node-list",
        model: "[TKAXNode]|TKAXHierarchyMapResponse",
        fields: schemaContractFields([
            ("role", "String", true, "AX role"),
            ("label", "String?", false, "Accessible label"),
            ("value", "String?", false, "Accessible value"),
            ("identifier", "String?", false, "Accessibility identifier"),
            ("title", "String?", false, "Control title"),
            ("frame", "TKRect", true, "Window bounds in points"),
            ("enabled", "Bool", true, "Whether the node is enabled"),
            ("focused", "Bool", true, "Whether the node is focused"),
            ("hidden", "Bool", true, "Whether the node is hidden"),
            ("targetOID", "UInt?", false, "Preferred runtime target oid"),
            ("viewOID", "UInt?", false, "View oid when available"),
            ("layerOID", "UInt?", false, "Layer oid when available"),
            ("className", "String?", false, "UIKit or host class name"),
            ("children", "[TKAXNode]", true, "Child nodes"),
        ])
    )
}

func waitResultOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "wait.result",
        format: "json",
        kind: "wait-result",
        model: "TKWaitResult",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the wait completed successfully"),
            ("matched", "Bool", true, "Whether the condition matched"),
            ("condition", "String", true, "text, gone, exists, idle, hierarchy-change, or predicate"),
            ("query", "String?", false, "Text query when applicable"),
            ("predicate", "String?", false, "Predicate expression when applicable"),
            ("role", "String?", false, "Optional role filter"),
            ("timedOut", "Bool", true, "Whether the wait timed out"),
            ("elapsedMs", "Int", true, "Elapsed milliseconds"),
            ("pollCount", "Int", true, "Number of polls"),
            ("timeoutSeconds", "Double", true, "Timeout in seconds"),
            ("intervalSeconds", "Double", true, "Polling interval in seconds"),
            ("targetConnectionState", "String?", false, "Target connection state"),
            ("hierarchyCacheState", "String?", false, "Hierarchy cache state"),
            ("lastObservedNodeCount", "Int?", false, "Last observed node count"),
            ("lastObservedTextSample", "[String]", true, "Bounded text sample from the last observation"),
            ("lastObservedHierarchyHash", "String?", false, "Last hierarchy hash"),
            ("match", "TKWaitMatch?", false, "Matched element summary"),
        ])
    )
}

func inputResultOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "input.result",
        format: "json",
        kind: "input-result",
        model: "TKInputResult",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the action succeeded"),
            ("action", "String", true, "Action name"),
            ("message", "String?", false, "Human-readable action message"),
            ("targetOID", "UInt?", false, "Target view oid"),
            ("targetClassName", "String?", false, "Target view class"),
            ("matchedOID", "UInt?", false, "Original matched oid"),
            ("matchedClassName", "String?", false, "Original matched class"),
            ("activationOID", "UInt?", false, "Activated target oid"),
            ("activationClassName", "String?", false, "Activated target class"),
            ("strategy", "String?", false, "Activation strategy"),
            ("secure", "Bool?", false, "Whether inserted text was treated as secure"),
            ("redacted", "Bool?", false, "Whether output text details were redacted"),
            ("insertedLength", "Int?", false, "Inserted text length"),
        ])
    )
}

func webViewAwareTapOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "act.webview-aware-tap",
        format: "json",
        kind: "webview-aware-tap-result",
        model: "TKActTapWebViewAwareResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the command completed without transport failure"),
            ("action", "String", true, "act.tap"),
            ("status", "passed|failed|uncertain", true, "passed only when expectation is proven; uncertain when DOM dispatch is not enough"),
            ("context", "String", true, "webview for this output contract"),
            ("selector", "String?", false, "CSS selector used for WebView DOM dispatch"),
            ("target", "TKWebViewTapTarget?", false, "Resolved DOM element and native/WebView rects"),
            ("attempts", "[TKActTapAttempt]", true, "Attempt ledger such as dom_dispatch trusted=false"),
            ("attempts[].trusted", "Bool?", false, "Always false for DOM-dispatched WebView click"),
            ("verification", "TKActTapVerification", true, "Expectation and observation result"),
            ("verification.expectProvided", "Bool", true, "Whether the caller supplied --expect-text"),
            ("verification.textMatched", "Bool?", false, "Whether expected WebView text was observed"),
            ("recoveryCommand", "String?", false, "Suggested next command when status is uncertain or failed"),
            ("sourceCommands", "[String]", true, "Underlying runtime request commands"),
            ("note", "String", true, "Boundary note explaining that DOM dispatch does not prove business completion"),
        ])
    )
}

func inputSummaryOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "input.summary",
        format: "json",
        kind: "input-batch-summary",
        model: "TKInputBatchSummaryResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the batch completed under strict/fail-fast rules"),
            ("actionCount", "Int", true, "Number of input actions processed"),
            ("failedCount", "Int", true, "Number of failed input actions"),
        ])
    )
}

func assertResultOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "assert.result",
        format: "json",
        kind: "assert-result",
        model: "TKUIAssertResult",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the assertion passed"),
            ("condition", "String", true, "text-exists or text-not-exists"),
            ("query", "String", true, "Asserted text"),
            ("role", "String?", false, "Optional role filter"),
            ("count", "Int", true, "Actual match count"),
            ("expectedCount", "Int?", false, "Exact expected match count"),
            ("minCount", "Int?", false, "Minimum match count"),
            ("maxCount", "Int?", false, "Maximum match count"),
            ("within", "TKRect?", false, "Optional bounds filter"),
            ("matches", "[TKWaitMatch]", true, "Matched elements"),
            ("sample", "[String]", true, "Bounded observed text sample"),
            ("targetConnectionState", "String?", false, "Target connection state"),
            ("hierarchyCacheState", "String?", false, "Hierarchy cache state"),
            ("message", "String?", false, "Failure or success message"),
            ("nearestText", "[String]?", false, "Nearest observed text on failure"),
            ("suggestedCommands", "[String]?", false, "Follow-up commands on failure"),
        ])
    )
}

func targetsListOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "targets.list",
        format: "json",
        kind: "target-list",
        model: "TKTargetsResponse",
        fields: schemaContractFields([
            ("targets", "[TKTargetSummary]", true, "Connected Triton runtime target summaries"),
        ])
    )
}

func targetSummaryOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "target.summary",
        format: "json",
        kind: "target-summary",
        model: "TKTargetSummary",
        fields: schemaContractFields([
            ("id", "String", true, "Triton target id"),
            ("transport", "String", true, "Transport name"),
            ("platform", "String", true, "Target platform: ios, android, harmony, or another runtime-provided value"),
            ("connected", "Bool", true, "Whether the target is connected"),
            ("latestHierarchyAvailable", "Bool", true, "Whether the target has a latest hierarchy"),
            ("appName", "String?", false, "Runtime app display name"),
            ("bundleIdentifier", "String?", false, "Runtime app bundle identifier"),
            ("deviceDescription", "String?", false, "Host or runtime device description"),
            ("osDescription", "String?", false, "Host or runtime OS description"),
            ("simulatorUDID", "String?", false, "Simulator UDID when known"),
            ("activeHierarchyAvailable", "Bool?", false, "Whether active hierarchy is available"),
            ("cachedHierarchyAvailable", "Bool?", false, "Whether cached hierarchy is available"),
            ("hierarchyCacheState", "String?", false, "active, stale, or unavailable"),
            ("identityState", "String?", false, "current or unknown identity state"),
        ])
    )
}

func hierarchyInfoOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "hierarchy.info",
        format: "json",
        kind: "hierarchy-info",
        model: "TKHierarchyInfo",
        fields: schemaContractFields([
            ("displayItems", "[TKDisplayItem]", true, "Nested display item hierarchy"),
            ("appInfo", "TKAppInfo", true, "App and device metadata"),
            ("serverVersion", "Int", true, "Lookin/Triton hierarchy server version"),
            ("colorAlias", "[String:String]", true, "Color alias metadata"),
            ("collapsedClassList", "[String]", true, "Classes collapsed by the hierarchy renderer"),
        ])
    )
}

func hierarchySceneOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "hierarchy.scene",
        format: "json",
        kind: "hierarchy-scene",
        model: "TKHostHierarchyResponse",
        fields: schemaContractFields([
            ("platform", "String", true, "Scene platform: ios, android, or harmony"),
            ("rootId", "String", true, "Root node id"),
            ("viewport", "TKHierarchyViewport", true, "Viewport coordinate space"),
            ("nodes", "[TKHierarchyLayerNode]", true, "Flattened hierarchy layer nodes"),
            ("controllerContext", "TKHierarchyControllerContext?", false, "Current UIViewController context for iOS scenes, including active controller and stack"),
            ("style", "TKHierarchyNodeStyle?", false, "Normalized drawable style for Lookin-style node surfaces"),
            ("slice", "TKHierarchyNodeSlice?", false, "Per-node screenshot slice metadata with dataRef/dataUrl when available"),
            ("view", "TKHierarchyViewMetadata?", false, "UIView metadata for future Lookin-like object reconstruction"),
            ("layer", "TKHierarchyLayerMetadata?", false, "CALayer geometry, transform, clipping, opacity, and contents metadata"),
            ("visualSources", "[TKHierarchyVisualSource]?", false, "Material/evidence source list; subtreeSnapshot is evidence-only and layerOwnContents is default-material eligible"),
            ("raw", "TKHierarchyNodeRawInfo?", false, "Platform/source metadata for debugging and future exact mapping"),
            ("renderHints", "TKHierarchyNodeRenderHints?", false, "Preferred rendering order: slice, style, fallback, or wireframe"),
        ])
    )
}

func hierarchyNodesOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "hierarchy.nodes",
        format: "json",
        kind: "hierarchy-node-list",
        model: "HierarchyNodeSummaryMap",
        fields: schemaContractFields([
            ("nodes", "[HierarchyNodeSummary]", true, "Flattened hierarchy node summaries"),
        ])
    )
}

func hierarchyNodeOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "hierarchy.node",
        format: "json",
        kind: "hierarchy-node",
        model: "HierarchyNodeSummary",
        fields: schemaContractFields([
            ("oid", "UInt?", false, "View object oid"),
            ("viewOid", "UInt?", false, "View object oid"),
            ("layerOid", "UInt?", false, "Layer object oid"),
            ("className", "String?", false, "View or layer class name"),
            ("depth", "Int", true, "Node depth in the flattened hierarchy"),
            ("frame", "String", true, "Frame rendered as x,y,width,height"),
            ("hidden", "Bool", true, "Whether the display item is hidden"),
            ("alpha", "Float", true, "Display item alpha"),
        ])
    )
}

func nodeResolveOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "node.resolve",
        format: "json",
        kind: "node-resolution",
        model: "NodeResolveOutput",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether node resolution succeeded"),
            ("action", "String", true, "node.resolve"),
            ("platform", "String", true, "ios, android, or harmony"),
            ("query", "String", true, "Text, id, key, accessibility id, point query, or @N alias"),
            ("matchIndex", "Int", true, "1-based selected match index"),
            ("matchCount", "Int", true, "Total candidate count"),
            ("node", "ObserveNodeOutput", true, "Selected visible node"),
            ("candidates", "[ObserveNodeOutput]?", false, "All candidates when requested"),
            ("sourceCommands", "[String]", true, "Underlying host commands"),
        ])
    )
}

func nodeAttributesOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "node.attributes",
        format: "json",
        kind: "node-attributes",
        model: "[TKAttributesGroup]",
        fields: schemaContractFields([
            ("identifier", "String", true, "Attribute group identifier"),
            ("userCustomTitle", "String?", false, "Custom group title when provided"),
            ("attrSections", "[TKAttributesSection]", true, "Attribute sections and attributes"),
        ])
    )
}

func nodeObjectOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "node.object",
        format: "json",
        kind: "node-object",
        model: "TKObject",
        fields: schemaContractFields([
            ("oid", "UInt", true, "Object oid"),
            ("memoryAddress", "String", true, "Object memory address"),
            ("classChainList", "[String]", true, "Class inheritance chain"),
            ("specialTrace", "String", true, "Special object trace"),
            ("ivarTraces", "[TKIvarTrace]", true, "Instance variable traces"),
        ])
    )
}

func exportArchiveOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "export.archive",
        format: "archive",
        kind: "export-archive",
        model: "TKExportArchive",
        fields: schemaContractFields([
            ("schemaVersion", "Int", true, "Export archive schema version"),
            ("exportedAt", "String", true, "Export timestamp"),
            ("target", "TKTargetSummary", true, "Target metadata"),
            ("hierarchy", "TKJSONValue", true, "Captured hierarchy JSON"),
            ("geometry", "TKGeometryResponse?", false, "Optional window geometry"),
            ("accessibility", "[TKAXNode]?", false, "Optional accessibility nodes"),
            ("screenshot", "TKScreenshotResponse?", false, "Optional screenshot payload"),
        ])
    )
}

func geometryCurrentOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "geometry.current",
        format: "json",
        kind: "window-geometry",
        model: "TKGeometryResponse",
        fields: schemaContractFields([
            ("bounds", "TKRect", true, "Window bounds"),
            ("safeArea", "TKInsets", true, "Window safe area insets"),
            ("scale", "Double", true, "Display scale"),
            ("orientation", "String", true, "Runtime orientation"),
        ])
    )
}

func hitResultOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "hit.result",
        format: "json",
        kind: "hit-test-result",
        model: "TKHitTestResponse",
        fields: schemaContractFields([
            ("x", "Double", true, "Window x coordinate"),
            ("y", "Double", true, "Window y coordinate"),
            ("node", "TKAXNode?", false, "Hit accessibility node"),
            ("centerX", "Double?", false, "Hit node center x"),
            ("centerY", "Double?", false, "Hit node center y"),
        ])
    )
}

func semanticActionOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "semantic.action",
        format: "json",
        kind: "semantic-action-result",
        model: "TKSemanticActionResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the semantic action succeeded"),
            ("action", "TKSemanticActionType", true, "focus, setText, selectSegment, or setSwitch"),
            ("strategy", "String", true, "Resolution and execution strategy"),
            ("targetOID", "UInt?", false, "Resolved target oid"),
            ("targetClassName", "String?", false, "Resolved target class name"),
            ("elapsedMs", "Int", true, "Elapsed milliseconds"),
            ("message", "String?", false, "Human-readable result message"),
            ("error", "TKCLIErrorDetail?", false, "Structured action failure"),
            ("redaction", "TKSemanticActionRedaction?", false, "Text redaction policy and inserted length"),
        ])
    )
}

func runtimeLedgerOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "runtime.ledger",
        format: "json",
        kind: "runtime-ledger",
        model: "TKRuntimeLedgerResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the ledger read succeeded"),
            ("entries", "[TKRuntimeLedgerEntry]", true, "Recent request/action ledger entries"),
            ("limit", "Int", true, "Requested entry limit"),
            ("count", "Int", true, "Returned entry count"),
            ("maxEntries", "Int", true, "Runtime ledger retention limit"),
        ])
    )
}

func runtimeLedgerEntryOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "runtime.ledger-entry",
        format: "jsonl",
        kind: "runtime-ledger-entry",
        model: "TKRuntimeLedgerEntry",
        fields: schemaContractFields([
            ("id", "Int", true, "Ledger entry id"),
            ("timestamp", "String", true, "Entry timestamp"),
            ("source", "String", true, "Request source"),
            ("requestType", "String", true, "Runtime request type"),
            ("action", "String?", false, "Semantic action name when applicable"),
            ("ok", "Bool", true, "Whether the request/action succeeded"),
            ("elapsedMs", "Int", true, "Elapsed milliseconds"),
            ("errorCode", "String?", false, "Structured error code when failed"),
            ("message", "String?", false, "Human-readable message"),
            ("redaction", "TKSemanticActionRedaction?", false, "Redaction metadata for secure actions"),
        ])
    )
}

func nodePropertyPatchOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "node.property-patch",
        format: "json",
        kind: "runtime-node-property-patch",
        model: "TKNodePropertyPatchResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether at least one supported runtime node property was applied"),
            ("success", "Bool", true, "Backward-compatible alias for ok"),
            ("action", "String", true, "Runtime action name, currently node.patch"),
            ("nodeId", "String?", false, "Hierarchy node id supplied by the caller"),
            ("oid", "UInt?", false, "Resolved runtime object identifier"),
            ("applied", "[String]", true, "Applied property paths"),
            ("skipped", "[String]", true, "Unsupported, missing, invalid, or unchanged property paths"),
            ("message", "String?", false, "Human-readable diagnostic message"),
        ])
    )
}
