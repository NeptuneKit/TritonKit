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
            ("format", "String", true, "Image format"),
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
