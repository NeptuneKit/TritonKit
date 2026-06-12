import Foundation
import TritonKitShared

private func nextActionSchemaFields(
    name: String,
    required: Bool,
    description: String
) -> [TKCommandSchemaField] {
    [
        TKCommandSchemaField(name: name, type: "TKCLINextAction?", required: required, description: description),
        TKCommandSchemaField(
            name: "\(name).command",
            type: "String",
            required: true,
            description: "Suggested Triton command root for the next action"
        ),
        TKCommandSchemaField(
            name: "\(name).args",
            type: "[String]",
            required: true,
            description: "Suggested command arguments for the next action"
        ),
        TKCommandSchemaField(
            name: "\(name).category",
            type: "String",
            required: true,
            description: "Recovery category derived from the next action command root"
        ),
        TKCommandSchemaField(
            name: "\(name).requiresLongRunningProcess",
            type: "Bool",
            required: true,
            description: "Whether the next action starts a long-running process"
        ),
    ]
}

func schemaContractFields(_ specs: [(String, String, Bool, String)]) -> [TKCommandSchemaField] {
    specs.flatMap { spec -> [TKCommandSchemaField] in
        let field = TKCommandSchemaField(name: spec.0, type: spec.1, required: spec.2, description: spec.3)
        if spec.0 == "error", spec.1 == "TKCLIErrorDetail?" {
            return [
                field,
                TKCommandSchemaField(
                    name: "error.endpoint",
                    type: "String?",
                    required: false,
                    description: "Associated endpoint when the failure came from runtime transport or another addressable surface"
                ),
                TKCommandSchemaField(
                    name: "error.hint",
                    type: "String?",
                    required: false,
                    description: "Suggested diagnostic hint for the failure"
                ),
                TKCommandSchemaField(
                    name: "error.nearestCandidates",
                    type: "[String]?",
                    required: false,
                    description: "Nearest candidate strings when the failure exposes selector or text alternatives"
                ),
                TKCommandSchemaField(
                    name: "error.suggestedCommands",
                    type: "[String]?",
                    required: false,
                    description: "Command suggestions bundled directly inside the failure diagnostic"
                ),
                TKCommandSchemaField(
                    name: "error.candidateCount",
                    type: "Int?",
                    required: false,
                    description: "Candidate count associated with the failure diagnostic"
                ),
            ] + nextActionSchemaFields(
                name: "error.nextAction",
                required: false,
                description: "Recommended recovery command when the failure is actionable"
            )
        }
        if spec.1 == "TKCLINextAction?" {
            return nextActionSchemaFields(name: spec.0, required: spec.2, description: spec.3)
        }
        return [field]
    }
}

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

func capabilitiesOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "capabilities",
        format: "json",
        kind: "capability-matrix",
        model: "TKCapabilitiesResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the capability probe completed"),
            ("serverReachable", "Bool", true, "Whether the local Triton server responded"),
            ("connected", "Bool", true, "Whether at least one embedded runtime target is connected"),
            ("latestHierarchyAvailable", "Bool", true, "Whether a hierarchy snapshot is cached"),
            ("targetCount", "Int", true, "Number of connected runtime targets"),
            ("runtime", "String", true, "embedded when connected, otherwise none"),
            ("surface", "String", true, "Bootstrap entry surface identifier; always capabilities for this response"),
            ("capabilities", "[TKRuntimeCapability]", true, "Machine-readable capability matrix"),
            ("primaryCapability", "String?", false, "Capability name whose nextAction agents should try first from this snapshot"),
            ("primaryWorkflowCategory", "String?", false, "Primary workflow taxonomy value implied by the primary capability"),
            ("primaryEvidence", "String?", false, "Primary evidence artifact taxonomy value implied by the primary capability"),
            ("primaryNextAction", "TKCLINextAction?", false, "Primary structured command agents should try first from this capability snapshot"),
            ("primaryNextActionSource", "String?", false, "Machine-readable provenance for why this capability response selected the primary next action"),
            ("capabilities[].name", "String", true, "Machine-readable capability identifier"),
            ("capabilities[].supported", "Bool", true, "Whether the capability can run in the current environment"),
            ("capabilities[].reason", "String?", false, "Why an unsupported capability is currently unavailable"),
            ("capabilities[].group", "String?", false, "Agent-facing capability group such as target, runtime, xcode, action, assert, or evidence"),
            ("capabilities[].requiredBy", "[String]", true, "Workflow categories that depend on this capability"),
            ("capabilities[].nextAction", "TKCLINextAction?", false, "Recommended command to inspect, enable, or exercise the capability"),
            ("capabilities[].evidence", "[String]", true, "Artifacts or output surfaces that can prove this capability ran"),
            ("activeHierarchyAvailable", "Bool?", false, "Whether the active target has a hierarchy snapshot"),
            ("hierarchyCacheState", "String?", false, "active, stale, or unavailable"),
            ("targetConnectionState", "String?", false, "connected or disconnected target state"),
            ("error", "TKCLIErrorDetail?", false, "Recoverable server or target diagnostic"),
        ])
    )
}

func doctorOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "doctor",
        format: "json",
        kind: "diagnostic-checks",
        model: "TKDoctorResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether all required checks passed"),
            ("serverReachable", "Bool", true, "Whether the local Triton server responded"),
            ("connected", "Bool", true, "Whether at least one embedded runtime target is connected"),
            ("runtime", "String", true, "embedded when connected, otherwise none or unknown"),
            ("surface", "String", true, "Bootstrap entry surface identifier; always doctor for this response"),
            ("nextStep", "String", true, "Machine-readable next diagnostic or recovery step"),
            ("nextWorkflows", "[String]", true, "Workflow taxonomy values most directly affected by the next actionable doctor check"),
            ("primaryCapability", "String?", false, "Capability name whose check agents should inspect first from this doctor snapshot"),
            ("primaryWorkflowCategory", "String?", false, "Primary workflow taxonomy value implied by the doctor primary check"),
            ("primaryNextAction", "TKCLINextAction?", false, "Primary structured recovery command agents should try first from doctor"),
            ("primaryNextActionSource", "String?", false, "Machine-readable provenance for why doctor selected the primary next action"),
            ("checks", "[TKDoctorCheck]", true, "Ordered diagnostic checks with status, code, hint, nextAction, and related capabilities"),
            ("checks[].id", "String", true, "Stable check identifier"),
            ("checks[].status", "String", true, "pass, warn, fail, or skipped"),
            ("checks[].code", "String", true, "Machine-readable diagnostic code"),
            ("checks[].message", "String", true, "Human-readable diagnostic summary"),
            ("checks[].hint", "String?", false, "Short recovery hint"),
            ("checks[].nextAction", "TKCLINextAction?", false, "Recommended recovery command"),
            ("checks[].relatedCapabilities", "[String]", true, "Capability names that explain or depend on this check"),
            ("checks[].workflowCategories", "[String]", true, "Workflow taxonomy values derived from the related capability set"),
            ("error", "TKCLIErrorDetail?", false, "Underlying server or target diagnostic when available"),
        ])
    )
}

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

func schemaCommandsOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "schema.commands",
        format: "json",
        kind: "command-schema-list",
        model: "TKCLISchemaResponse",
        fields: schemaContractFields([
            ("schemaVersion", "Int", true, "CLI schema contract version"),
            ("commands", "[TKCommandSchema]", true, "Machine-readable command contracts"),
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
            ("geometry", "TKGeometryResponse?", false, "Window geometry when included"),
            ("ax", "[TKAXNode]?", false, "Accessibility tree when included"),
            ("screenshot", "TKRuntimeScreenshotMetadata?", false, "Screenshot metadata when included"),
            ("artifacts", "[TKRuntimeSnapshotArtifact]", true, "Captured artifact freshness summaries"),
            ("skipped", "[TKRuntimeSnapshotSkipped]", true, "Skipped sections and reasons"),
            ("truncation", "TKRuntimeSnapshotTruncation", true, "Snapshot truncation summary"),
        ])
    )
}

func observeSurfaceOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "observe.surface",
        format: "json",
        kind: "observe-surface",
        model: "ObserveOutput",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether observation completed"),
            ("action", "String", true, "observe.current or observe.tree"),
            ("platform", "String", true, "ios or harmony"),
            ("capturedAt", "String", true, "Capture timestamp"),
            ("partial", "Bool", true, "Whether observation is partial"),
            ("target", "String", true, "Resolved target selector"),
            ("primarySource", "ObserveSourceOutput?", false, "Primary source agents should trust first for this observed surface"),
            ("primarySource.name", "String", true, "Primary source name"),
            ("primarySource.available", "Bool", true, "Whether the primary source was available"),
            ("primarySource.reason", "String?", false, "Unavailable reason when the primary source is missing"),
            ("primarySource.artifact", "String?", false, "Backing artifact path when the primary source emitted one"),
            ("primarySource.sourceCommands", "[String]", true, "Underlying commands that produced the primary source"),
            ("sources", "[ObserveSourceOutput]", true, "Observation sources and availability"),
            ("nodes", "[ObserveNodeOutput]", true, "Visible node summaries"),
            ("artifacts", "[String]", true, "Artifact paths written by host observation"),
            ("sourceCommands", "[String]", true, "Underlying host commands"),
            ("note", "String", true, "Boundary or follow-up note"),
        ])
    )
}

func webViewListOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "webview.list",
        format: "json",
        kind: "webview-candidates",
        model: "TKWebViewListResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether WebView candidate discovery completed"),
            ("action", "String", true, "webview.list"),
            ("platform", "String", true, "ios or harmony"),
            ("capturedAt", "String", true, "Capture timestamp"),
            ("target", "String", true, "Resolved target selector"),
            ("current", "TKWebViewDescriptor?", false, "Best current WebView candidate when selection is unambiguous"),
            ("candidates", "[TKWebViewDescriptor]", true, "Visible WebView candidates"),
            ("primarySource", "TKWebViewSource?", false, "Primary WebView source agents should trust first"),
            ("primarySource.name", "String", true, "Primary source name"),
            ("primarySource.available", "Bool", true, "Whether the primary source was available"),
            ("primarySource.reason", "String?", false, "Unavailable reason when the primary source is missing"),
            ("primarySource.sourceCommands", "[String]", true, "Underlying commands that produced the primary source"),
            ("sources", "[TKWebViewSource]", true, "WebView sources and availability"),
            ("sourceCommands", "[String]", true, "Underlying commands that produced this response"),
            ("note", "String", true, "Provider boundary or follow-up note"),
        ])
    )
}

func webViewCurrentOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "webview.current",
        format: "json",
        kind: "webview-current",
        model: "TKWebViewCurrentResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether current WebView resolution completed"),
            ("action", "String", true, "webview.current"),
            ("platform", "String", true, "ios or harmony"),
            ("capturedAt", "String", true, "Capture timestamp"),
            ("target", "String", true, "Resolved target selector"),
            ("webView", "TKWebViewDescriptor", true, "Selected WebView descriptor"),
            ("primarySource", "TKWebViewSource?", false, "Primary WebView source agents should trust first"),
            ("primarySource.name", "String", true, "Primary source name"),
            ("primarySource.available", "Bool", true, "Whether the primary source was available"),
            ("primarySource.reason", "String?", false, "Unavailable reason when the primary source is missing"),
            ("primarySource.sourceCommands", "[String]", true, "Underlying commands that produced the primary source"),
            ("sources", "[TKWebViewSource]", true, "WebView sources and availability"),
            ("sourceCommands", "[String]", true, "Underlying commands that produced this response"),
            ("note", "String", true, "Provider boundary or follow-up note"),
        ])
    )
}

func webViewCurrentURLOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "webview.current-url",
        format: "json",
        kind: "webview-provider-url",
        model: "WebViewCurrentURLSummary",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether current WebView URL resolution completed"),
            ("action", "String", true, "webview.current-url"),
            ("platform", "String", true, "ios or harmony"),
            ("capturedAt", "String", true, "Capture timestamp"),
            ("target", "String", true, "Resolved target selector"),
            ("webViewID", "String", true, "Selected WebView id"),
            ("url", "String", true, "Provider-reported current URL"),
            ("title", "String?", false, "Provider-reported current document title"),
            ("pageSessionID", "String?", false, "Provider page session id"),
            ("providerStatus", "String", true, "Provider availability status"),
            ("bridgeStatus", "String", true, "Bridge availability status"),
            ("sourceCommands", "[String]", true, "Underlying commands that produced this response"),
        ])
    )
}

func webViewBridgeCallOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "webview.call",
        format: "json",
        kind: "webview-bridge-call",
        model: "TKWebViewBridgeCallResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the allowlisted WebView bridge call succeeded"),
            ("action", "String", true, "webview.call"),
            ("capturedAt", "String", true, "Capture timestamp"),
            ("platform", "String", true, "ios or harmony"),
            ("target", "String", true, "Resolved target selector"),
            ("webViewID", "String", true, "Selected WebView id"),
            ("pageSessionID", "String?", false, "Expected or observed page session id"),
            ("method", "String", true, "Allowlisted bridge method name"),
            ("result", "TKJSONValue?", false, "Bridge method result payload"),
            ("error", "TKWebViewError?", false, "Structured WebView bridge error"),
            ("elapsedMs", "Int", true, "Elapsed milliseconds"),
            ("redaction", "TKWebViewRedaction", true, "WebView redaction policy"),
        ])
    )
}

func webViewEventsOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "webview.events",
        format: "json",
        kind: "webview-events",
        model: "TKWebViewEventsResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether buffered WebView event reading completed"),
            ("action", "String", true, "webview.events"),
            ("capturedAt", "String", true, "Capture timestamp"),
            ("platform", "String", true, "ios or harmony"),
            ("target", "String", true, "Resolved target selector"),
            ("events", "[TKWebViewEvent]", true, "Buffered opt-in WebView events"),
            ("limit", "Int", true, "Maximum event count requested"),
            ("events[].id", "String", true, "Stable event id"),
            ("events[].timestamp", "String", true, "Event timestamp"),
            ("events[].webViewID", "String", true, "Event WebView id"),
            ("events[].pageSessionID", "String?", false, "Event page session id"),
            ("events[].name", "String", true, "Allowlisted event name"),
            ("events[].payload", "TKJSONValue?", false, "Redacted event payload"),
            ("events[].redaction", "TKWebViewRedaction", true, "Event redaction policy"),
            ("events[].source", "String", true, "Event source"),
        ])
    )
}

func webViewSnapshotOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "webview.snapshot",
        format: "json",
        kind: "webview-snapshot",
        model: "TKWebViewSnapshotResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the WebView snapshot succeeded"),
            ("action", "String", true, "webview.snapshot"),
            ("capturedAt", "String", true, "Capture timestamp"),
            ("platform", "String", true, "ios or harmony"),
            ("target", "String", true, "Resolved target selector"),
            ("webView", "TKWebViewDescriptor", true, "Selected WebView descriptor"),
            ("include", "[String]", true, "Requested WebView sections"),
            ("text", "[String]", true, "Bounded visible text lines"),
            ("dom", "[TKWebViewDOMNodeSummary]", true, "Bounded DOM node summaries"),
            ("forms", "[TKWebViewFormFieldSummary]", true, "Bounded form field summaries"),
            ("links", "[TKWebViewLinkSummary]", true, "Bounded link summaries"),
            ("skipped", "[TKRuntimeSnapshotSkipped]", true, "Skipped sections and reasons"),
            ("truncation", "TKWebViewSnapshotTruncation", true, "Snapshot truncation summary"),
            ("redaction", "TKWebViewRedaction", true, "WebView redaction policy"),
        ])
    )
}

func webViewWaitOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "webview.wait",
        format: "json",
        kind: "webview-wait-result",
        model: "TKWebViewWaitResponse",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the WebView wait matched"),
            ("action", "String", true, "webview.wait"),
            ("capturedAt", "String", true, "Capture timestamp"),
            ("platform", "String", true, "ios or harmony"),
            ("target", "String", true, "Resolved target selector"),
            ("webView", "TKWebViewDescriptor?", false, "Selected WebView descriptor"),
            ("candidates", "[TKWebViewDescriptor]?", false, "Candidate WebViews on selection failure"),
            ("condition", "String", true, "text, selector, or event"),
            ("query", "String", true, "Exact wait query"),
            ("matched", "Bool", true, "Whether the condition matched"),
            ("timedOut", "Bool", true, "Whether the wait timed out"),
            ("elapsedMs", "Int", true, "Elapsed milliseconds"),
            ("pollCount", "Int", true, "Number of polls"),
            ("timeoutSeconds", "Double", true, "Timeout in seconds"),
            ("intervalSeconds", "Double", true, "Polling interval in seconds"),
            ("pageSessionID", "String?", false, "Expected or observed page session id"),
            ("lastObservedTextSample", "[String]", true, "Bounded observed text sample"),
            ("lastObservedNodeIDs", "[String]", true, "Bounded observed DOM ids"),
            ("lastObservedEventNames", "[String]", true, "Bounded observed event names"),
            ("match", "TKWebViewWaitMatch?", false, "Matched text, selector, or event"),
            ("error", "TKWebViewError?", false, "Structured WebView wait error"),
            ("redaction", "TKWebViewRedaction", true, "WebView redaction policy"),
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
            ("format", "String", true, "Image format"),
            ("width", "Double", true, "Image width in points or pixels depending on source"),
            ("height", "Double", true, "Image height in points or pixels depending on source"),
            ("scale", "Double", true, "Image scale"),
            ("output", "String", true, "Written screenshot path"),
            ("bytes", "Int", true, "Written byte count"),
        ])
    )
}

func hostArtifactOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "host.artifact",
        format: "json",
        kind: "host-artifact",
        model: "HostDeviceArtifactOutput",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether host artifact capture succeeded"),
            ("action", "String", true, "Host action name"),
            ("platform", "String", true, "ios or harmony"),
            ("target", "HostDeviceTarget", true, "Resolved host target"),
            ("selection", "HostDeviceSelectionResult?", false, "Target selection details"),
            ("artifact", "String", true, "Written artifact path"),
            ("sourceCommands", "[String]", true, "Underlying host commands"),
            ("note", "String", true, "Boundary or follow-up note"),
        ])
    )
}

func hostHarmonyArtifactOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "host.harmony-artifact",
        format: "json",
        kind: "host-artifact",
        model: "HostHarmonyArtifactOutput",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether Harmony host artifact capture succeeded"),
            ("action", "String", true, "Host action name"),
            ("platform", "String", true, "harmony"),
            ("target", "TKHarmonyTarget", true, "Resolved Harmony target"),
            ("artifact", "String", true, "Written artifact path"),
            ("sourceCommands", "[String]", true, "Underlying host commands"),
            ("note", "String", true, "Boundary or follow-up note"),
        ])
    )
}

func hostDeviceListOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "host.device-list",
        format: "json",
        kind: "host-device-list",
        model: "HostDeviceListOutput",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether host device listing succeeded"),
            ("platform", "String", true, "ios or harmony"),
            ("targets", "[HostDeviceTarget]", true, "Discovered host targets"),
            ("targets[].appName", "String?", false, "Foreground app display name when host discovery can determine it"),
            ("targets[].bundleIdentifier", "String?", false, "Foreground app bundle identifier when host discovery can determine it"),
            ("targets[].identityState", "String?", false, "Foreground identity state: current, unknown, or unsupported"),
            ("targets[].current", "Bool?", false, "Whether the target identity describes the current foreground app"),
            ("defaultTarget", "HostDeviceTarget?", false, "Default selected target if one exists"),
            ("sourceCommand", "String", true, "Underlying host command"),
        ])
    )
}

func hostDeviceSelectionOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "host.device-selection",
        format: "json",
        kind: "host-device-selection",
        model: "HostDeviceUseOutput|HostDeviceResolveOutput|HostDeviceCurrentOutput",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether host device selection succeeded"),
            ("platform", "String?", false, "ios or harmony"),
            ("current", "String?", false, "Current alias or target id"),
            ("target", "HostDeviceTarget?", false, "Resolved target"),
            ("defaultsPath", "String?", false, "Persisted defaults path"),
            ("selection", "HostDeviceSelectionResult?", false, "Selection source and filters"),
            ("path", "String?", false, "Alias store path"),
        ])
    )
}

func hostDeviceReadyOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "host.device-ready",
        format: "json",
        kind: "host-device-ready",
        model: "HostDeviceReadyEvent",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether target readiness was reached"),
            ("platform", "String", true, "ios or harmony"),
            ("target", "HostDeviceTarget", true, "Resolved host target"),
            ("ready", "Bool", true, "Whether the target is ready"),
            ("attempt", "Int", true, "Readiness poll attempt"),
            ("sourceCommand", "String", true, "Underlying host command"),
            ("error", "TKCLIErrorDetail?", false, "Structured readiness failure"),
        ])
    )
}

func hostSimulatorListOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "host.simulator-list",
        format: "json",
        kind: "host-simulator-list",
        model: "HostSimulatorListOutput",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether simulator listing succeeded"),
            ("simulators", "[TKHostSimulatorTarget]", true, "Discovered simulator targets"),
        ])
    )
}

func hostSimulatorScreenshotOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "host.simulator-screenshot",
        format: "json",
        kind: "simulator-screenshot",
        model: "HostSimulatorScreenshotOutput",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether simulator screenshot capture succeeded"),
            ("action", "String", true, "sim.screenshot"),
            ("runtimeScope", "String", true, "host-simulator"),
            ("target", "String", true, "Simulator target selector"),
            ("tool", "String", true, "Host executable"),
            ("exitCode", "Int32", true, "Host process exit code"),
            ("riskLevel", "String", true, "Host command risk level"),
            ("sourceCommand", "String", true, "Underlying xcrun simctl command"),
            ("stdoutTruncated", "Bool", true, "Whether stdout sample was truncated"),
            ("stderrTruncated", "Bool", true, "Whether stderr sample was truncated"),
            ("stderr", "String?", false, "Bounded stderr sample from simctl"),
            ("artifact", "String", true, "Written screenshot path"),
            ("pixelWidth", "Int?", false, "Captured image pixel width when readable"),
            ("pixelHeight", "Int?", false, "Captured image pixel height when readable"),
            ("display", "HostSimulatorScreenshotDisplayMetadata", true, "CoreSimulator display metadata parsed from simctl stderr"),
            ("display.rawLine", "String?", false, "Raw simctl display metadata line"),
            ("display.displayID", "String?", false, "CoreSimulator display identifier when reported"),
            ("display.screenID", "String?", false, "CoreSimulator screen id when reported"),
            ("display.name", "String?", false, "CoreSimulator display name when reported"),
            ("orientationPolicy", "String", true, "raw-framebuffer until Triton normalizes screenshots"),
            ("orientationNote", "String", true, "Human-readable orientation boundary"),
            ("note", "String", true, "Boundary or follow-up note"),
        ])
    )
}

func hostActionOutputContract(selector: String, model: String) -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: selector,
        format: "json",
        kind: "host-action",
        model: model,
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the host action completed"),
            ("action", "String", true, "Host action name"),
            ("runtimeScope", "String", true, "host-simulator or host-harmony"),
            ("target", "String", true, "Resolved host target id"),
            ("selection", "HostDeviceSelectionResult?", false, "Unified target selection details"),
            ("tool", "String", true, "Host executable"),
            ("exitCode", "Int32", true, "Host process exit code"),
            ("riskLevel", "String", true, "Host command risk level"),
            ("sourceCommand", "String", true, "Underlying host command"),
            ("stdoutTruncated", "Bool", true, "Whether stdout sample was truncated"),
            ("stderrTruncated", "Bool", true, "Whether stderr sample was truncated"),
            ("stdout", "String?", false, "Bounded stdout sample"),
            ("stderr", "String?", false, "Bounded stderr sample"),
            ("artifacts", "[String]", true, "Written artifact paths"),
            ("screenshot", "HostSimulatorScreenshotMetadata?", false, "Simulator screenshot orientation and pixel metadata"),
            ("note", "String?", false, "Boundary or follow-up note"),
        ])
    )
}

func hostSimulatorScreenshotMetadataOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "host.simulator-screenshot-metadata",
        format: "json",
        kind: "host-simulator-screenshot-metadata",
        model: "HostSimulatorScreenshotMetadata",
        fields: schemaContractFields([
            ("path", "String", true, "Screenshot artifact path"),
            ("contentType", "String", true, "Screenshot content type"),
            ("pixelWidth", "Int?", false, "PNG pixel width when readable"),
            ("pixelHeight", "Int?", false, "PNG pixel height when readable"),
            ("orientationSemantics", "String", true, "Screenshot orientation coordinate-space semantics"),
            ("normalizationApplied", "Bool", true, "Whether TritonKit rotated or otherwise normalized the image"),
            ("normalizationStrategy", "String", true, "Normalization strategy used for this artifact"),
            ("note", "String", true, "Human-readable caveat for agents and evidence consumers"),
        ])
    )
}

func hostHarmonyTapOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "host.harmony-tap",
        format: "json",
        kind: "host-action",
        model: "HostHarmonyTapOutput",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the Harmony host tap command succeeded"),
            ("action", "String", true, "Host action name"),
            ("platform", "String", true, "harmony"),
            ("target", "TKHarmonyTarget", true, "Resolved Harmony target"),
            ("query", "String?", false, "Text query used for target resolution"),
            ("x", "Int", true, "Screen x coordinate used for tap"),
            ("y", "Int", true, "Screen y coordinate used for tap"),
            ("match", "TKHarmonyLayoutTextMatch?", false, "Matched host layout text node"),
            ("sourceCommands", "[String]", true, "Underlying host commands"),
            ("note", "String", true, "Boundary or follow-up note"),
        ])
    )
}

func hostAndroidTapOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "host.android-tap",
        format: "json",
        kind: "host-action",
        model: "HostAndroidTapOutput",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the Android host tap command succeeded"),
            ("action", "String", true, "Host action name"),
            ("platform", "String", true, "android"),
            ("target", "HostDeviceTarget", true, "Resolved Android target"),
            ("query", "String?", false, "Text query used for target resolution"),
            ("x", "Int", true, "Screen x coordinate used for tap"),
            ("y", "Int", true, "Screen y coordinate used for tap"),
            ("match", "HostAndroidTapMatch?", false, "Matched Android host layout node"),
            ("sourceCommands", "[String]", true, "Underlying host commands"),
            ("note", "String", true, "Boundary or follow-up note"),
        ])
    )
}

func hostHarmonySwipeOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "host.harmony-swipe",
        format: "json",
        kind: "host-action",
        model: "HostHarmonySwipeOutput",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the Harmony host swipe command succeeded"),
            ("action", "String", true, "Host action name"),
            ("platform", "String", true, "harmony"),
            ("target", "TKHarmonyTarget", true, "Resolved Harmony target"),
            ("startX", "Int", true, "Swipe start x coordinate"),
            ("startY", "Int", true, "Swipe start y coordinate"),
            ("endX", "Int", true, "Swipe end x coordinate"),
            ("endY", "Int", true, "Swipe end y coordinate"),
            ("velocity", "Int?", false, "Host swipe velocity when available"),
            ("sourceCommands", "[String]", true, "Underlying host commands"),
            ("note", "String", true, "Boundary or follow-up note"),
        ])
    )
}

func hostAndroidSwipeOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "host.android-swipe",
        format: "json",
        kind: "host-action",
        model: "HostAndroidSwipeOutput",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the Android host swipe command succeeded"),
            ("action", "String", true, "Host action name"),
            ("platform", "String", true, "android"),
            ("target", "HostDeviceTarget", true, "Resolved Android target"),
            ("startX", "Int", true, "Swipe start x coordinate"),
            ("startY", "Int", true, "Swipe start y coordinate"),
            ("endX", "Int", true, "Swipe end x coordinate"),
            ("endY", "Int", true, "Swipe end y coordinate"),
            ("durationMs", "Int?", false, "Swipe duration in milliseconds when supplied"),
            ("sourceCommands", "[String]", true, "Underlying host commands"),
            ("note", "String", true, "Boundary or follow-up note"),
        ])
    )
}

func hostHarmonyTextInputOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "host.harmony-text-input",
        format: "json",
        kind: "host-action",
        model: "HostHarmonyTextInputOutput",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the Harmony host text input command succeeded"),
            ("action", "String", true, "Host action name"),
            ("platform", "String", true, "harmony"),
            ("target", "TKHarmonyTarget", true, "Resolved Harmony target"),
            ("x", "Int?", false, "Focused screen x coordinate when supplied"),
            ("y", "Int?", false, "Focused screen y coordinate when supplied"),
            ("secure", "Bool", true, "Whether input was treated as secure"),
            ("redacted", "Bool", true, "Whether output text details were redacted"),
            ("insertedLength", "Int", true, "Inserted text length"),
            ("sourceCommands", "[String]", true, "Underlying host commands"),
            ("note", "String", true, "Boundary or follow-up note"),
        ])
    )
}

func hostAndroidTextInputOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "host.android-text-input",
        format: "json",
        kind: "host-action",
        model: "HostAndroidTextInputOutput",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the Android host text input command succeeded"),
            ("action", "String", true, "Host action name"),
            ("platform", "String", true, "android"),
            ("target", "HostDeviceTarget", true, "Resolved Android target"),
            ("x", "Int?", false, "Focused screen x coordinate when supplied"),
            ("y", "Int?", false, "Focused screen y coordinate when supplied"),
            ("secure", "Bool", true, "Whether input was treated as secure"),
            ("redacted", "Bool", true, "Whether output text details were redacted"),
            ("insertedLength", "Int", true, "Inserted text length"),
            ("sourceCommands", "[String]", true, "Underlying host commands"),
            ("note", "String", true, "Boundary or follow-up note"),
        ])
    )
}

func hostHarmonyWaitOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "host.harmony-wait",
        format: "json",
        kind: "host-action",
        model: "HostHarmonyWaitOutput",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the Harmony host wait matched before timeout"),
            ("action", "String", true, "Host action name"),
            ("platform", "String", true, "harmony"),
            ("target", "TKHarmonyTarget", true, "Resolved Harmony target"),
            ("condition", "String", true, "text or gone"),
            ("query", "String", true, "Text query used for host layout polling"),
            ("matched", "Bool", true, "Whether the condition matched"),
            ("timedOut", "Bool", true, "Whether the host wait timed out"),
            ("elapsedMs", "Int", true, "Elapsed milliseconds"),
            ("pollCount", "Int", true, "Number of layout polling attempts"),
            ("match", "TKHarmonyLayoutTextMatch?", false, "Last matched host layout text node"),
            ("sourceCommands", "[String]", true, "Underlying host commands"),
        ])
    )
}

func hostAndroidWaitOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "host.android-wait",
        format: "json",
        kind: "host-action",
        model: "HostAndroidWaitOutput",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the Android host wait matched before timeout"),
            ("action", "String", true, "Host action name"),
            ("platform", "String", true, "android"),
            ("target", "HostDeviceTarget", true, "Resolved Android target"),
            ("condition", "String", true, "text or gone"),
            ("query", "String", true, "Text query used for host layout polling"),
            ("matched", "Bool", true, "Whether the condition matched"),
            ("timedOut", "Bool", true, "Whether the host wait timed out"),
            ("elapsedMs", "Int", true, "Elapsed milliseconds"),
            ("pollCount", "Int", true, "Number of layout polling attempts"),
            ("match", "HostAndroidTapMatch?", false, "Last matched Android host layout node"),
            ("sourceCommands", "[String]", true, "Underlying host commands"),
        ])
    )
}

func hostAppOpenURLOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "host.app-open-url",
        format: "json",
        kind: "host-app-open-url-flow",
        model: "HostAppOpenURLFlowSummary",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the open-url flow passed"),
            ("action", "String", true, "app.open-url"),
            ("status", "String", true, "pass or fail"),
            ("platform", "String", true, "ios"),
            ("url", "String", true, "Submitted URL"),
            ("simulator", "String", true, "Simulator target"),
            ("runtimeTarget", "String", true, "Embedded runtime target"),
            ("hostAction", "HostAppOpenURLHostStep", true, "Host-side URL submission result"),
            ("ready", "HostAppOpenURLReadySummary?", false, "Optional runtime readiness summary"),
            ("snapshot", "HostAppOpenURLSnapshotSummary?", false, "Optional runtime snapshot summary"),
            ("elapsedMs", "Int", true, "Elapsed milliseconds"),
            ("note", "String", true, "Boundary or follow-up note"),
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
            ("action", "String", true, "smoke.ios or smoke.harmony"),
            ("platform", "String", true, "ios or harmony"),
            ("status", "String", true, "pass, fail, or blocked"),
            ("target", "SmokeTargetSummary", true, "Target app/device summary"),
            ("steps", "[SmokeStepSummary]", true, "Executed smoke steps"),
            ("assertions", "[SmokeAssertionSummary]", true, "Assertion summaries"),
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
            ("suggestedCommands", "[String]", true, "Suggested offline follow-up commands"),
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
            ("platform", "String", true, "ios or harmony"),
            ("query", "String", true, "Text, id, key, accessibility id, or point query"),
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
