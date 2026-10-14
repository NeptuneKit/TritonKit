import Foundation
import TritonKitShared

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
            ("source", "String?", false, "Execution source such as embedded or host-hid"),
            ("geometry", "TKRect?", false, "Matched runtime node geometry retained as tap evidence"),
            ("fallbackFromStrategy", "String?", false, "Embedded strategy that triggered an explicit host fallback"),
            ("verification", "TKInputVerificationBoundary?", false, "Postcondition verification boundary; host submission is not business completion"),
            ("verification.required", "Bool", false, "Whether the caller must verify a settled postcondition"),
            ("verification.status", "String", false, "Verification state such as not-verified"),
            ("verification.hint", "String", false, "How to verify the postcondition"),
            ("verification.suggestedCommands", "[String]", false, "Suggested wait/verify commands"),
            ("sourceCommands", "[String]?", false, "Bounded host adapter command descriptions"),
            ("outcome", "String?", false, "unknown after UI timeout; not_started on admission rejection. Never automatically replay unknown actions"),
            ("uiHealth", "TKRuntimeUIHealthSnapshot?", false, "Non-UI admission/timeout/circuit diagnostics"),
            ("error", "TKCLIErrorDetail?", false, "Structured runtime action failure"),
            ("error.code", "String?", false, "Stable failure code; unsupported UICollectionViewCell fallback returns unsupported_capability"),
            ("error.message", "String?", false, "Human-readable runtime action failure message"),
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
            ("outcome", "String?", false, "unknown after UI timeout; no automatic replay"),
            ("uiHealth", "TKRuntimeUIHealthSnapshot?", false, "UI admission and timeout diagnostics"),
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
            ("collection", "TKCollectionBudgetSummary?", false, "Actual collection traversal budget evidence"),
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
            ("collection", "TKCollectionBudgetSummary?", false, "Budget metadata preserved through scene normalization"),
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
            ("outcome", "String?", false, "unknown after timeout or not_started on admission rejection"),
            ("uiHealth", "TKRuntimeUIHealthSnapshot?", false, "UI admission and timeout diagnostics"),
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
