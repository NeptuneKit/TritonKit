import Foundation
import TritonKitShared

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
            ("defaultTarget", "HostDeviceTarget?", false, "Default selected target if one exists"),
            ("sourceCommand", "String", true, "Underlying host command"),
            ("sourceCommands", "[String]", true, "Underlying host commands"),
            ("targets[].scope", "String?", false, "Target scope: simulator, emulator, or real"),
            ("targets[].kind", "String?", false, "Target kind such as simulator, emulator, or real-device"),
            ("targets[].blockedReasons", "[String]", true, "Readiness blockers observed during discovery"),
            ("targets[].sensitive", "Bool", true, "Whether sensitive raw identifiers are redacted from target/id output"),
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
            ("selection.filters.scope", "String?", false, "Requested target scope filter"),
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
            ("sourceCommands", "[String]", true, "Underlying host commands"),
            ("error", "TKCLIErrorDetail?", false, "Structured readiness failure"),
        ])
    )
}

func hostDeviceProxyOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "host.device-proxy",
        format: "json",
        kind: "host-device-proxy",
        model: "NetworkProxySession",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the host-side proxy request succeeded"),
            ("surface", "String", true, "Stable response surface, host.device-proxy"),
            ("action", "String", true, "Proxy action: doctor, start, status, export, or stop"),
            ("platform", "String", true, "ios, android, or harmony"),
            ("target", "HostDeviceTarget?", false, "Resolved simulator or emulator target"),
            ("lane", "String", true, "Proxy lane, host-side by default or app-runtime when explicitly enabled"),
            ("captureMode", "String?", false, "Proxy mode: record, mock, block, or throttle"),
            ("proxyEndpoint", "String?", false, "Local proxy host and port when a session is configured"),
            ("configured", "Bool", true, "Whether platform network settings are currently configured"),
            ("cert", "NetworkProxyCertificate?", false, "Certificate trust or installation state for HTTPS visibility"),
            ("visibility", "NetworkProxyVisibility", true, "Observed traffic visibility and HTTPS inspection boundaries"),
            ("limitations", "[String]", true, "Known platform or app-scoped visibility limitations"),
            ("artifacts", "[HostArtifact]", true, "Capture/export artifacts such as HAR or NDJSON"),
            ("restore", "NetworkProxyRestore?", false, "Restore plan or result for platform proxy settings"),
            ("sourceCommands", "[String]", true, "Underlying host commands or plan-only command ledger"),
            ("error", "TKCLIErrorDetail?", false, "Structured proxy failure detail"),
            ("redaction", "String?", false, "Capture export redaction policy summary, such as headers-names-only"),
            ("requestCount", "Int?", false, "Number of proxy.serve.request events exported from the capture artifact"),
            ("truncation", "String?", false, "Capture export truncation status; currently none for metadata-only exports"),
            ("probeResults", "[NetworkProxyProbeResult]?", false, "Readonly proxy capability probe results with command, exitCode, stdout/stderr previews, and error summary"),
        ])
    )
}

func hostDeviceProxyServeOutputContract() -> TKCommandOutputContract {
    TKCommandOutputContract(
        selector: "host.device-proxy-serve",
        format: "jsonl",
        kind: "host-device-proxy",
        model: "NetworkProxyServeEvent|NetworkProxyServeSummary",
        fields: schemaContractFields([
            ("ok", "Bool", true, "Whether the serve event or summary succeeded"),
            ("surface", "String", true, "Stable response surface, host.device-proxy-serve"),
            ("event", "String", true, "JSONL event name such as proxy.serve.ready, proxy.serve.request, proxy.serve.connection-failed, or proxy.serve.summary"),
            ("schemaVersion", "String", true, "Network capture event schema version, triton.proxy.capture.v1"),
            ("action", "String?", false, "Final summary action, proxy.serve"),
            ("listen", "String", true, "Local proxy listen endpoint"),
            ("capturePath", "String", true, "NDJSON capture artifact path"),
            ("captureMode", "String?", false, "Capture policy mode such as record, mock, block, or throttle"),
            ("policyAction", "String?", false, "Per-request proxy policy action such as forwarded, mocked, blocked, or throttled"),
            ("mockRuleId", "String?", false, "Matched mock rule id for proxy serve --mode mock when --mock-rules is provided"),
            ("responseStatus", "Int?", false, "Synthetic response status for local proxy policy actions; absent for forwarded requests"),
            ("responseStatusText", "String?", false, "Synthetic response reason phrase for mock, block, or throttle policy actions"),
            ("throttleDelayMs", "Int?", false, "Synthetic response delay in milliseconds for proxy serve --mode throttle"),
            ("requestCount", "Int?", false, "Final captured request count"),
            ("method", "String?", false, "Captured HTTP method for request events"),
            ("host", "String?", false, "Captured upstream host for request events"),
            ("port", "Int?", false, "Captured upstream port for request events"),
            ("path", "String?", false, "Captured request path for request events"),
            ("tunnel", "Bool?", false, "Whether the request used CONNECT tunneling"),
            ("headerNames", "[String]?", false, "Header names only; values are redacted"),
            ("limitations", "[String]?", false, "Capture visibility and redaction limitations"),
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
            ("hostAction", "HostActionSubmissionEvidence", true, "Submission proof; ok=true only means host action was accepted"),
            ("hostAction.ok", "Bool", true, "Whether the host action was submitted"),
            ("hostAction.proofSource", "String", true, "Always host-action for this output"),
            ("hostAction.businessReady", "Bool", true, "Always false until wait/assert/smoke/evidence proves business readiness"),
            ("hostAction.nextAction", "TKCLINextAction?", true, "Suggested proof-producing follow-up command"),
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
