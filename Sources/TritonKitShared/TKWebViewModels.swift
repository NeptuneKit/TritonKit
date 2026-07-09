import Foundation

public enum TKWebViewErrorCode: String, Codable, Equatable {
    case webviewNotFound = "webview_not_found"
    case ambiguousWebView = "ambiguous_webview"
    case webViewIDNotFound = "webview_id_not_found"
    case webViewProviderUnavailable = "webview_provider_unavailable"
    case webViewNavigationChanged = "webview_navigation_changed"
    case webViewBridgeUnavailable = "webview_bridge_unavailable"
    case webViewMethodNotAllowed = "webview_method_not_allowed"
    case webViewWaitTimeout = "webview_wait_timeout"
    case webViewWaitUnsupported = "webview_wait_unsupported"
    case webViewElementNotFound = "webview_element_not_found"
    case webViewElementNotInteractable = "webview_element_not_interactable"
    case javascriptTimeout = "javascript_timeout"
    case javascriptError = "javascript_error"
    case unsafeEvalDisabled = "unsafe_eval_disabled"
}

public struct TKWebViewSource: Codable, Equatable {
    public let name: String
    public let available: Bool
    public let reason: String?
    public let sourceCommands: [String]

    public init(name: String, available: Bool, reason: String? = nil, sourceCommands: [String] = []) {
        self.name = name
        self.available = available
        self.reason = reason
        self.sourceCommands = sourceCommands
    }
}

public struct TKWebViewDiagnosticWarning: Codable, Equatable {
    public let code: String
    public let message: String
    public let nextAction: TKCLINextAction?
    public let source: String?

    public init(
        code: String,
        message: String,
        nextAction: TKCLINextAction? = nil,
        source: String? = nil
    ) {
        self.code = code
        self.message = message
        self.nextAction = nextAction
        self.source = source
    }
}

public struct TKWebViewProviderCapability: Codable, Equatable {
    public let supported: Bool
    public let reason: String?
    public let nextAction: TKCLINextAction?

    public init(
        supported: Bool,
        reason: String? = nil,
        nextAction: TKCLINextAction? = nil
    ) {
        self.supported = supported
        self.reason = reason
        self.nextAction = nextAction
    }
}

public struct TKWebViewProviderCapabilities: Codable, Equatable {
    public let supportsCurrentURL: TKWebViewProviderCapability
    public let supportsSnapshot: TKWebViewProviderCapability
    public let supportsBridgeCall: TKWebViewProviderCapability
    public let supportsEvents: TKWebViewProviderCapability
    public let supportsDOMInput: TKWebViewProviderCapability
    public let supportsContentEditableTyping: TKWebViewProviderCapability

    public init(
        supportsCurrentURL: TKWebViewProviderCapability,
        supportsSnapshot: TKWebViewProviderCapability,
        supportsBridgeCall: TKWebViewProviderCapability,
        supportsEvents: TKWebViewProviderCapability,
        supportsDOMInput: TKWebViewProviderCapability,
        supportsContentEditableTyping: TKWebViewProviderCapability
    ) {
        self.supportsCurrentURL = supportsCurrentURL
        self.supportsSnapshot = supportsSnapshot
        self.supportsBridgeCall = supportsBridgeCall
        self.supportsEvents = supportsEvents
        self.supportsDOMInput = supportsDOMInput
        self.supportsContentEditableTyping = supportsContentEditableTyping
    }

    public static func iosRuntimeDefaults() -> TKWebViewProviderCapabilities {
        TKWebViewProviderCapabilities(
            supportsCurrentURL: TKWebViewProviderCapability(
                supported: true,
                nextAction: TKCLINextAction(command: "webview", args: ["current-url", "--json"])
            ),
            supportsSnapshot: TKWebViewProviderCapability(
                supported: true,
                nextAction: TKCLINextAction(command: "webview", args: ["snapshot", "--include", "metadata,text,dom,forms", "--json"])
            ),
            supportsBridgeCall: TKWebViewProviderCapability(
                supported: false,
                reason: "page must expose an allowlisted window.__tritonBridge.methods entry",
                nextAction: TKCLINextAction(command: "webview", args: ["call", "<method>", "--json"])
            ),
            supportsEvents: TKWebViewProviderCapability(
                supported: true,
                reason: "page bridge event buffer is available after bridge installation",
                nextAction: TKCLINextAction(command: "webview", args: ["events", "--json"])
            ),
            supportsDOMInput: TKWebViewProviderCapability(
                supported: true,
                reason: "focused activeElement text insertion is supported after runtime focus",
                nextAction: TKCLINextAction(command: "input", args: ["--json"])
            ),
            supportsContentEditableTyping: TKWebViewProviderCapability(
                supported: true,
                reason: "focused contenteditable insertion is supported after runtime focus",
                nextAction: TKCLINextAction(command: "input", args: ["--json"])
            )
        )
    }
}

public struct TKWebViewDescriptor: Codable, Equatable {
    public let webViewID: String
    public let platform: String
    public let source: String
    public let nodeID: String?
    public let role: String?
    public let text: String?
    public let identifier: String?
    public let frame: TKRect?
    public let visibleRatio: Double?
    public let candidateOnly: Bool
    public let confidence: Double
    public let url: String?
    public let title: String?
    public let pageSessionID: String?
    public let isLoading: Bool?
    public let estimatedProgress: Double?
    public let canGoBack: Bool?
    public let canGoForward: Bool?
    public let providerStatus: String
    public let bridgeStatus: String
    public let capabilities: [String]
    public let missingCapabilities: [String]
    public let providerCapabilities: TKWebViewProviderCapabilities?

    public init(
        webViewID: String,
        platform: String,
        source: String,
        nodeID: String? = nil,
        role: String? = nil,
        text: String? = nil,
        identifier: String? = nil,
        frame: TKRect? = nil,
        visibleRatio: Double? = nil,
        candidateOnly: Bool = true,
        confidence: Double,
        url: String? = nil,
        title: String? = nil,
        pageSessionID: String? = nil,
        isLoading: Bool? = nil,
        estimatedProgress: Double? = nil,
        canGoBack: Bool? = nil,
        canGoForward: Bool? = nil,
        providerStatus: String = "unavailable",
        bridgeStatus: String = "unavailable",
        capabilities: [String],
        missingCapabilities: [String],
        providerCapabilities: TKWebViewProviderCapabilities? = nil
    ) {
        self.webViewID = webViewID
        self.platform = platform
        self.source = source
        self.nodeID = nodeID
        self.role = role
        self.text = text
        self.identifier = identifier
        self.frame = frame
        self.visibleRatio = visibleRatio
        self.candidateOnly = candidateOnly
        self.confidence = confidence
        self.url = url
        self.title = title
        self.pageSessionID = pageSessionID
        self.isLoading = isLoading
        self.estimatedProgress = estimatedProgress
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.providerStatus = providerStatus
        self.bridgeStatus = bridgeStatus
        self.capabilities = capabilities
        self.missingCapabilities = missingCapabilities
        self.providerCapabilities = providerCapabilities
    }
}

public struct TKWebViewListResponse: Codable, Equatable {
    public let ok: Bool
    public let action: String
    public let platform: String
    public let capturedAt: String
    public let target: String
    public let primarySource: TKWebViewSource?
    public let current: TKWebViewDescriptor?
    public let candidates: [TKWebViewDescriptor]
    public let sources: [TKWebViewSource]
    public let sourceCommands: [String]
    public let warnings: [TKWebViewDiagnosticWarning]
    public let note: String

    public init(
        ok: Bool,
        action: String,
        platform: String,
        capturedAt: String,
        target: String,
        primarySource: TKWebViewSource? = nil,
        current: TKWebViewDescriptor?,
        candidates: [TKWebViewDescriptor],
        sources: [TKWebViewSource],
        sourceCommands: [String],
        warnings: [TKWebViewDiagnosticWarning] = [],
        note: String
    ) {
        self.ok = ok
        self.action = action
        self.platform = platform
        self.capturedAt = capturedAt
        self.target = target
        self.primarySource = primarySource ?? Self.defaultPrimarySource(from: sources)
        self.current = current
        self.candidates = candidates
        self.sources = sources
        self.sourceCommands = sourceCommands
        self.warnings = warnings
        self.note = note
    }

    enum CodingKeys: String, CodingKey {
        case ok
        case action
        case platform
        case capturedAt
        case target
        case primarySource
        case current
        case candidates
        case sources
        case sourceCommands
        case warnings
        case note
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let sources = try container.decode([TKWebViewSource].self, forKey: .sources)
        self.ok = try container.decode(Bool.self, forKey: .ok)
        self.action = try container.decode(String.self, forKey: .action)
        self.platform = try container.decode(String.self, forKey: .platform)
        self.capturedAt = try container.decode(String.self, forKey: .capturedAt)
        self.target = try container.decode(String.self, forKey: .target)
        self.primarySource = try container.decodeIfPresent(TKWebViewSource.self, forKey: .primarySource) ?? Self.defaultPrimarySource(from: sources)
        self.current = try container.decodeIfPresent(TKWebViewDescriptor.self, forKey: .current)
        self.candidates = try container.decode([TKWebViewDescriptor].self, forKey: .candidates)
        self.sources = sources
        self.sourceCommands = try container.decode([String].self, forKey: .sourceCommands)
        self.warnings = try container.decodeIfPresent([TKWebViewDiagnosticWarning].self, forKey: .warnings) ?? []
        self.note = try container.decode(String.self, forKey: .note)
    }

    static func defaultPrimarySource(from sources: [TKWebViewSource]) -> TKWebViewSource? {
        for name in ["webview-provider", "runtime-tree", "host-layout"] {
            if let source = sources.first(where: { $0.name == name && $0.available }) {
                return source
            }
        }
        return sources.first(where: { $0.available }) ?? sources.first
    }
}

public struct TKWebViewCurrentResponse: Codable, Equatable {
    public let ok: Bool
    public let action: String
    public let platform: String
    public let capturedAt: String
    public let target: String
    public let primarySource: TKWebViewSource?
    public let webView: TKWebViewDescriptor
    public let sources: [TKWebViewSource]
    public let sourceCommands: [String]
    public let warnings: [TKWebViewDiagnosticWarning]
    public let note: String

    public init(
        ok: Bool,
        action: String,
        platform: String,
        capturedAt: String,
        target: String,
        primarySource: TKWebViewSource? = nil,
        webView: TKWebViewDescriptor,
        sources: [TKWebViewSource],
        sourceCommands: [String],
        warnings: [TKWebViewDiagnosticWarning] = [],
        note: String
    ) {
        self.ok = ok
        self.action = action
        self.platform = platform
        self.capturedAt = capturedAt
        self.target = target
        self.primarySource = primarySource ?? TKWebViewListResponse.defaultPrimarySource(from: sources)
        self.webView = webView
        self.sources = sources
        self.sourceCommands = sourceCommands
        self.warnings = warnings
        self.note = note
    }

    enum CodingKeys: String, CodingKey {
        case ok
        case action
        case platform
        case capturedAt
        case target
        case primarySource
        case webView
        case sources
        case sourceCommands
        case warnings
        case note
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let sources = try container.decode([TKWebViewSource].self, forKey: .sources)
        self.ok = try container.decode(Bool.self, forKey: .ok)
        self.action = try container.decode(String.self, forKey: .action)
        self.platform = try container.decode(String.self, forKey: .platform)
        self.capturedAt = try container.decode(String.self, forKey: .capturedAt)
        self.target = try container.decode(String.self, forKey: .target)
        self.primarySource = try container.decodeIfPresent(TKWebViewSource.self, forKey: .primarySource) ?? TKWebViewListResponse.defaultPrimarySource(from: sources)
        self.webView = try container.decode(TKWebViewDescriptor.self, forKey: .webView)
        self.sources = sources
        self.sourceCommands = try container.decode([String].self, forKey: .sourceCommands)
        self.warnings = try container.decodeIfPresent([TKWebViewDiagnosticWarning].self, forKey: .warnings) ?? []
        self.note = try container.decode(String.self, forKey: .note)
    }
}

public struct TKWebViewRedaction: Codable, Equatable {
    public let secureText: String?
    public let payload: String?

    public init(secureText: String? = nil, payload: String? = nil) {
        self.secureText = secureText
        self.payload = payload
    }
}

public struct TKWebViewSnapshotTruncation: Codable, Equatable {
    public let truncated: Bool
    public let reason: String?
    public let maxNodes: Int?
    public let returnedNodes: Int?
    public let maxBytes: Int?
    public let returnedBytes: Int?

    public init(
        truncated: Bool = false,
        reason: String? = nil,
        maxNodes: Int? = nil,
        returnedNodes: Int? = nil,
        maxBytes: Int? = nil,
        returnedBytes: Int? = nil
    ) {
        self.truncated = truncated
        self.reason = reason
        self.maxNodes = maxNodes
        self.returnedNodes = returnedNodes
        self.maxBytes = maxBytes
        self.returnedBytes = returnedBytes
    }
}

public struct TKWebViewDOMNodeSummary: Codable, Equatable {
    public let nodeID: String?
    public let role: String?
    public let tagName: String?
    public let text: String?
    public let frame: TKRect?

    public init(nodeID: String? = nil, role: String? = nil, tagName: String? = nil, text: String? = nil, frame: TKRect? = nil) {
        self.nodeID = nodeID
        self.role = role
        self.tagName = tagName
        self.text = text
        self.frame = frame
    }
}

public struct TKWebViewFormFieldSummary: Codable, Equatable {
    public let name: String?
    public let inputType: String
    public let label: String?
    public let valueRedaction: String?
    public let valueLength: Int?
    public let frame: TKRect?

    public init(
        name: String? = nil,
        inputType: String,
        label: String? = nil,
        valueRedaction: String? = nil,
        valueLength: Int? = nil,
        frame: TKRect? = nil
    ) {
        self.name = name
        self.inputType = inputType
        self.label = label
        self.valueRedaction = valueRedaction
        self.valueLength = valueLength
        self.frame = frame
    }
}

public struct TKWebViewLinkSummary: Codable, Equatable {
    public let text: String?
    public let href: String?
    public let frame: TKRect?

    public init(text: String? = nil, href: String? = nil, frame: TKRect? = nil) {
        self.text = text
        self.href = href
        self.frame = frame
    }
}

public struct TKWebViewSnapshotRequest: Codable, Equatable {
    public let webViewID: String?
    public let pageSessionID: String?
    public let include: [String]
    public let maxDOMNodes: Int?
    public let maxTextBytes: Int?

    public init(
        webViewID: String? = nil,
        pageSessionID: String? = nil,
        include: [String] = ["metadata", "dom", "text", "forms", "links"],
        maxDOMNodes: Int? = nil,
        maxTextBytes: Int? = nil
    ) {
        self.webViewID = webViewID
        self.pageSessionID = pageSessionID
        self.include = include
        self.maxDOMNodes = maxDOMNodes
        self.maxTextBytes = maxTextBytes
    }
}

public struct TKWebViewSnapshotResponse: Codable, Equatable {
    public let ok: Bool
    public let action: String
    public let capturedAt: String
    public let platform: String
    public let target: String
    public let webView: TKWebViewDescriptor
    public let include: [String]
    public let text: [String]
    public let dom: [TKWebViewDOMNodeSummary]
    public let forms: [TKWebViewFormFieldSummary]
    public let links: [TKWebViewLinkSummary]
    public let skipped: [TKRuntimeSnapshotSkipped]
    public let warnings: [TKWebViewDiagnosticWarning]
    public let truncation: TKWebViewSnapshotTruncation
    public let redaction: TKWebViewRedaction

    public init(
        ok: Bool = true,
        action: String = "webview.snapshot",
        capturedAt: String,
        platform: String,
        target: String,
        webView: TKWebViewDescriptor,
        include: [String],
        text: [String] = [],
        dom: [TKWebViewDOMNodeSummary] = [],
        forms: [TKWebViewFormFieldSummary] = [],
        links: [TKWebViewLinkSummary] = [],
        skipped: [TKRuntimeSnapshotSkipped] = [],
        warnings: [TKWebViewDiagnosticWarning] = [],
        truncation: TKWebViewSnapshotTruncation = TKWebViewSnapshotTruncation(),
        redaction: TKWebViewRedaction = TKWebViewRedaction()
    ) {
        self.ok = ok
        self.action = action
        self.capturedAt = capturedAt
        self.platform = platform
        self.target = target
        self.webView = webView
        self.include = include
        self.text = text
        self.dom = dom
        self.forms = forms
        self.links = links
        self.skipped = skipped
        self.warnings = warnings
        self.truncation = truncation
        self.redaction = redaction
    }
}

public struct TKWebViewBridgeCallRequest: Codable, Equatable {
    public let webViewID: String?
    public let pageSessionID: String?
    public let method: String
    public let arguments: [String: TKJSONValue]
    public let timeoutMs: Int?
    public let sourceCommand: String?

    public init(
        webViewID: String? = nil,
        pageSessionID: String? = nil,
        method: String,
        arguments: [String: TKJSONValue] = [:],
        timeoutMs: Int? = nil,
        sourceCommand: String? = nil
    ) {
        self.webViewID = webViewID
        self.pageSessionID = pageSessionID
        self.method = method
        self.arguments = arguments
        self.timeoutMs = timeoutMs
        self.sourceCommand = sourceCommand
    }
}

public struct TKWebViewBridgeCallResponse: Codable, Equatable {
    public let ok: Bool
    public let action: String
    public let capturedAt: String
    public let platform: String
    public let target: String
    public let webViewID: String
    public let pageSessionID: String?
    public let method: String
    public let result: TKJSONValue?
    public let error: TKWebViewError?
    public let elapsedMs: Int
    public let redaction: TKWebViewRedaction

    public init(
        ok: Bool = true,
        action: String = "webview.call",
        capturedAt: String,
        platform: String,
        target: String,
        webViewID: String,
        pageSessionID: String? = nil,
        method: String,
        result: TKJSONValue? = nil,
        error: TKWebViewError? = nil,
        elapsedMs: Int,
        redaction: TKWebViewRedaction = TKWebViewRedaction()
    ) {
        self.ok = ok
        self.action = action
        self.capturedAt = capturedAt
        self.platform = platform
        self.target = target
        self.webViewID = webViewID
        self.pageSessionID = pageSessionID
        self.method = method
        self.result = result
        self.error = error
        self.elapsedMs = elapsedMs
        self.redaction = redaction
    }
}

public struct TKWebViewTapRequest: Codable, Equatable {
    public let webViewID: String?
    public let pageSessionID: String?
    public let selector: String
    public let sourceCommand: String?

    public init(
        webViewID: String? = nil,
        pageSessionID: String? = nil,
        selector: String,
        sourceCommand: String? = nil
    ) {
        self.webViewID = webViewID
        self.pageSessionID = pageSessionID
        self.selector = selector
        self.sourceCommand = sourceCommand
    }
}

public struct TKWebViewTapTarget: Codable, Equatable {
    public let selector: String
    public let tagName: String?
    public let nodeID: String?
    public let text: String?
    public let disabled: Bool?
    public let visible: Bool?
    public let webViewID: String?
    public let pageSessionID: String?
    public let webViewFrame: TKRect?
    public let domRect: TKRect?
    public let nativeRect: TKRect?

    public init(
        selector: String,
        tagName: String? = nil,
        nodeID: String? = nil,
        text: String? = nil,
        disabled: Bool? = nil,
        visible: Bool? = nil,
        webViewID: String? = nil,
        pageSessionID: String? = nil,
        webViewFrame: TKRect? = nil,
        domRect: TKRect? = nil,
        nativeRect: TKRect? = nil
    ) {
        self.selector = selector
        self.tagName = tagName
        self.nodeID = nodeID
        self.text = text
        self.disabled = disabled
        self.visible = visible
        self.webViewID = webViewID
        self.pageSessionID = pageSessionID
        self.webViewFrame = webViewFrame
        self.domRect = domRect
        self.nativeRect = nativeRect
    }
}

public struct TKWebViewTapResponse: Codable, Equatable {
    public let ok: Bool
    public let action: String
    public let capturedAt: String
    public let platform: String
    public let target: String
    public let webViewID: String?
    public let pageSessionID: String?
    public let selector: String
    public let dispatched: Bool
    public let trusted: Bool
    public let element: TKWebViewTapTarget?
    public let error: TKWebViewError?
    public let elapsedMs: Int
    public let sourceCommands: [String]
    public let note: String?

    public init(
        ok: Bool = true,
        action: String = "webview.tap",
        capturedAt: String,
        platform: String,
        target: String,
        webViewID: String? = nil,
        pageSessionID: String? = nil,
        selector: String,
        dispatched: Bool,
        trusted: Bool = false,
        element: TKWebViewTapTarget? = nil,
        error: TKWebViewError? = nil,
        elapsedMs: Int,
        sourceCommands: [String] = [],
        note: String? = nil
    ) {
        self.ok = ok
        self.action = action
        self.capturedAt = capturedAt
        self.platform = platform
        self.target = target
        self.webViewID = webViewID
        self.pageSessionID = pageSessionID
        self.selector = selector
        self.dispatched = dispatched
        self.trusted = trusted
        self.element = element
        self.error = error
        self.elapsedMs = elapsedMs
        self.sourceCommands = sourceCommands
        self.note = note
    }
}

public enum TKActTapStatus: String, Codable, Equatable {
    case passed
    case failed
    case uncertain
}

public struct TKActTapAttempt: Codable, Equatable {
    public let method: String
    public let dispatched: Bool?
    public let trusted: Bool?
    public let performed: Bool?
    public let source: String?

    public init(method: String, dispatched: Bool? = nil, trusted: Bool? = nil, performed: Bool? = nil, source: String? = nil) {
        self.method = method
        self.dispatched = dispatched
        self.trusted = trusted
        self.performed = performed
        self.source = source
    }
}

public struct TKActTapVerification: Codable, Equatable {
    public let expectProvided: Bool
    public let expectText: String?
    public let textMatched: Bool?
    public let urlChanged: Bool?
    public let eventObserved: Bool?
    public let domChanged: Bool?

    public init(
        expectProvided: Bool,
        expectText: String? = nil,
        textMatched: Bool? = nil,
        urlChanged: Bool? = nil,
        eventObserved: Bool? = nil,
        domChanged: Bool? = nil
    ) {
        self.expectProvided = expectProvided
        self.expectText = expectText
        self.textMatched = textMatched
        self.urlChanged = urlChanged
        self.eventObserved = eventObserved
        self.domChanged = domChanged
    }
}

public struct TKActTapWebViewAwareResponse: Codable, Equatable {
    public let ok: Bool
    public let action: String
    public let status: TKActTapStatus
    public let context: String
    public let query: String?
    public let selector: String?
    public let target: TKWebViewTapTarget?
    public let attempts: [TKActTapAttempt]
    public let verification: TKActTapVerification
    public let recoveryCommand: String?
    public let sourceCommands: [String]
    public let note: String

    public init(
        ok: Bool,
        action: String = "act.tap",
        status: TKActTapStatus,
        context: String = "webview",
        query: String? = nil,
        selector: String? = nil,
        target: TKWebViewTapTarget? = nil,
        attempts: [TKActTapAttempt],
        verification: TKActTapVerification,
        recoveryCommand: String? = nil,
        sourceCommands: [String] = [],
        note: String
    ) {
        self.ok = ok
        self.action = action
        self.status = status
        self.context = context
        self.query = query
        self.selector = selector
        self.target = target
        self.attempts = attempts
        self.verification = verification
        self.recoveryCommand = recoveryCommand
        self.sourceCommands = sourceCommands
        self.note = note
    }
}

public func TKMakeWebViewAwareTapResponse(
    selector: String,
    tap: TKWebViewTapResponse,
    expectText: String? = nil,
    wait: TKWebViewWaitResponse? = nil,
    recoveryCommand: String? = nil
) -> TKActTapWebViewAwareResponse {
    let expectProvided = expectText != nil
    let textMatched = wait?.matched
    let status: TKActTapStatus
    let ok: Bool
    let note: String
    if !tap.ok {
        status = .failed
        ok = false
        note = tap.error?.message ?? "WebView tap failed before dispatch."
    } else if expectProvided, textMatched == true {
        status = .passed
        ok = true
        note = "DOM click was dispatched and the expected WebView text was observed."
    } else {
        status = .uncertain
        ok = true
        note = expectProvided
            ? "DOM click was dispatched, but the expected WebView text was not observed; business completion is uncertain."
            : "DOM click was dispatched, but no expectation was provided; dispatch does not prove business completion."
    }
    return TKActTapWebViewAwareResponse(
        ok: ok,
        status: status,
        selector: selector,
        target: tap.element,
        attempts: [
            TKActTapAttempt(method: "dom_dispatch", dispatched: tap.dispatched, trusted: tap.trusted, performed: tap.ok, source: "webview.tap"),
        ],
        verification: TKActTapVerification(
            expectProvided: expectProvided,
            expectText: expectText,
            textMatched: textMatched
        ),
        recoveryCommand: status == .passed ? nil : recoveryCommand,
        sourceCommands: tap.sourceCommands + (wait?.webView.map { _ in ["triton webview wait --text <expect> --json"] } ?? []),
        note: note
    )
}

public struct TKWebViewEvent: Codable, Equatable {
    public let id: String
    public let timestamp: String
    public let webViewID: String
    public let pageSessionID: String?
    public let name: String
    public let payload: TKJSONValue?
    public let redaction: TKWebViewRedaction
    public let source: String

    public init(
        id: String,
        timestamp: String,
        webViewID: String,
        pageSessionID: String? = nil,
        name: String,
        payload: TKJSONValue? = nil,
        redaction: TKWebViewRedaction = TKWebViewRedaction(),
        source: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.webViewID = webViewID
        self.pageSessionID = pageSessionID
        self.name = name
        self.payload = payload
        self.redaction = redaction
        self.source = source
    }
}

public struct TKWebViewEventsResponse: Codable, Equatable {
    public let ok: Bool
    public let action: String
    public let capturedAt: String
    public let platform: String
    public let target: String
    public let events: [TKWebViewEvent]
    public let limit: Int

    public init(
        ok: Bool = true,
        action: String = "webview.events",
        capturedAt: String,
        platform: String,
        target: String,
        events: [TKWebViewEvent],
        limit: Int
    ) {
        self.ok = ok
        self.action = action
        self.capturedAt = capturedAt
        self.platform = platform
        self.target = target
        self.events = events
        self.limit = limit
    }
}

public enum TKWebViewWaitCondition: String, Codable, CaseIterable {
    case text
    case selector
    case event
}

public struct TKWebViewWaitRequest: Codable, Equatable {
    public let webViewID: String?
    public let pageSessionID: String?
    public let condition: TKWebViewWaitCondition
    public let query: String
    public let timeoutSeconds: Double
    public let intervalSeconds: Double
    public let sourceCommand: String?

    public init(
        webViewID: String? = nil,
        pageSessionID: String? = nil,
        condition: TKWebViewWaitCondition,
        query: String,
        timeoutSeconds: Double = 10,
        intervalSeconds: Double = 0.5,
        sourceCommand: String? = nil
    ) {
        self.webViewID = webViewID
        self.pageSessionID = pageSessionID
        self.condition = condition
        self.query = query
        self.timeoutSeconds = timeoutSeconds
        self.intervalSeconds = intervalSeconds
        self.sourceCommand = sourceCommand
    }
}

public struct TKWebViewWaitMatch: Codable, Equatable {
    public let text: String?
    public let selector: String?
    public let event: String?
    public let nodeID: String?
    public let frame: TKRect?
    public let source: String

    public init(
        text: String? = nil,
        selector: String? = nil,
        event: String? = nil,
        nodeID: String? = nil,
        frame: TKRect? = nil,
        source: String
    ) {
        self.text = text
        self.selector = selector
        self.event = event
        self.nodeID = nodeID
        self.frame = frame
        self.source = source
    }
}

public struct TKWebViewWaitResponse: Codable, Equatable {
    public let ok: Bool
    public let action: String
    public let capturedAt: String
    public let platform: String
    public let target: String
    public let webView: TKWebViewDescriptor?
    public let candidates: [TKWebViewDescriptor]?
    public let condition: String
    public let query: String
    public let matched: Bool
    public let timedOut: Bool
    public let elapsedMs: Int
    public let pollCount: Int
    public let timeoutSeconds: Double
    public let intervalSeconds: Double
    public let pageSessionID: String?
    public let lastObservedTextSample: [String]
    public let lastObservedNodeIDs: [String]
    public let lastObservedEventNames: [String]
    public let match: TKWebViewWaitMatch?
    public let error: TKWebViewError?
    public let redaction: TKWebViewRedaction

    public init(
        ok: Bool = true,
        action: String = "webview.wait",
        capturedAt: String,
        platform: String,
        target: String,
        webView: TKWebViewDescriptor? = nil,
        candidates: [TKWebViewDescriptor]? = nil,
        condition: String,
        query: String,
        matched: Bool,
        timedOut: Bool,
        elapsedMs: Int,
        pollCount: Int,
        timeoutSeconds: Double,
        intervalSeconds: Double,
        pageSessionID: String? = nil,
        lastObservedTextSample: [String] = [],
        lastObservedNodeIDs: [String] = [],
        lastObservedEventNames: [String] = [],
        match: TKWebViewWaitMatch? = nil,
        error: TKWebViewError? = nil,
        redaction: TKWebViewRedaction = TKWebViewRedaction(secureText: "length-only")
    ) {
        self.ok = ok
        self.action = action
        self.capturedAt = capturedAt
        self.platform = platform
        self.target = target
        self.webView = webView
        self.candidates = candidates
        self.condition = condition
        self.query = query
        self.matched = matched
        self.timedOut = timedOut
        self.elapsedMs = elapsedMs
        self.pollCount = pollCount
        self.timeoutSeconds = timeoutSeconds
        self.intervalSeconds = intervalSeconds
        self.pageSessionID = pageSessionID
        self.lastObservedTextSample = lastObservedTextSample
        self.lastObservedNodeIDs = lastObservedNodeIDs
        self.lastObservedEventNames = lastObservedEventNames
        self.match = match
        self.error = error
        self.redaction = redaction
    }
}

public struct TKWebViewWaitEvaluation: Codable, Equatable {
    public let hit: Bool
    public let match: TKWebViewWaitMatch?
    public let lastObservedTextSample: [String]
    public let lastObservedNodeIDs: [String]
    public let lastObservedEventNames: [String]
    public let error: TKWebViewError?

    public init(
        hit: Bool,
        match: TKWebViewWaitMatch? = nil,
        lastObservedTextSample: [String] = [],
        lastObservedNodeIDs: [String] = [],
        lastObservedEventNames: [String] = [],
        error: TKWebViewError? = nil
    ) {
        self.hit = hit
        self.match = match
        self.lastObservedTextSample = lastObservedTextSample
        self.lastObservedNodeIDs = lastObservedNodeIDs
        self.lastObservedEventNames = lastObservedEventNames
        self.error = error
    }
}

public struct TKWebViewError: Codable, Equatable {
    public let code: TKWebViewErrorCode
    public let message: String
    public let hint: String?
    public let webViewID: String?
    public let candidates: [TKWebViewDescriptor]?

    public init(
        code: TKWebViewErrorCode,
        message: String,
        hint: String? = nil,
        webViewID: String? = nil,
        candidates: [TKWebViewDescriptor]? = nil
    ) {
        self.code = code
        self.message = message
        self.hint = hint
        self.webViewID = webViewID
        self.candidates = candidates
    }
}

public struct TKWebViewErrorResponse: Codable, Equatable {
    public let ok: Bool
    public let action: String
    public let platform: String
    public let target: String
    public let error: TKCLIErrorDetail
    public let candidates: [TKWebViewDescriptor]?

    public init(
        action: String,
        platform: String,
        target: String,
        error: TKCLIErrorDetail,
        candidates: [TKWebViewDescriptor]? = nil
    ) {
        self.ok = false
        self.action = action
        self.platform = platform
        self.target = target
        self.error = error
        self.candidates = candidates
    }
}

public struct TKWebViewSelectionError: Error, Equatable, CustomStringConvertible {
    public let detail: TKWebViewError

    public init(detail: TKWebViewError) {
        self.detail = detail
    }

    public var description: String {
        detail.message
    }
}

public func TKSelectCurrentWebView(
    from candidates: [TKWebViewDescriptor],
    webViewID: String? = nil,
    ambiguityConfidenceDelta: Double = 0.05
) throws -> TKWebViewDescriptor {
    let sorted = candidates.sorted(by: TKWebViewDescriptorSort)
    if let webViewID {
        guard let selected = sorted.first(where: { $0.webViewID == webViewID || $0.nodeID == webViewID }) else {
            throw TKWebViewSelectionError(detail: TKWebViewError(
                code: .webViewIDNotFound,
                message: "No WebView candidate matched --webview-id \(webViewID).",
                hint: "Run `triton webview list --json` and pass one of the returned webViewID values.",
                webViewID: webViewID,
                candidates: sorted
            ))
        }
        return selected
    }
    guard let first = sorted.first else {
        throw TKWebViewSelectionError(detail: TKWebViewError(
            code: .webviewNotFound,
            message: "No visible WebView candidate found.",
            hint: "Verify the current page contains a visible WebView, or run `triton observe current --json` to inspect visible nodes.",
            candidates: []
        ))
    }
    if sorted.count > 1, abs(first.confidence - sorted[1].confidence) < ambiguityConfidenceDelta {
        throw TKWebViewSelectionError(detail: TKWebViewError(
            code: .ambiguousWebView,
            message: "Multiple visible WebView candidates matched.",
            hint: "Run `triton webview list --json` and pass --webview-id with the intended candidate.",
            candidates: sorted
        ))
    }
    return first
}

public func TKWebViewDescriptorSort(_ lhs: TKWebViewDescriptor, _ rhs: TKWebViewDescriptor) -> Bool {
    if lhs.confidence != rhs.confidence {
        return lhs.confidence > rhs.confidence
    }
    let leftArea = (lhs.frame?.width ?? 0) * (lhs.frame?.height ?? 0)
    let rightArea = (rhs.frame?.width ?? 0) * (rhs.frame?.height ?? 0)
    return leftArea > rightArea
}

public func TKEvaluateWebViewWait(
    request: TKWebViewWaitRequest,
    snapshot: TKWebViewSnapshotResponse,
    events: TKWebViewEventsResponse? = nil
) -> TKWebViewWaitEvaluation {
    let textSample = TKWebViewWaitObservedTextSample(from: snapshot)
    let nodeIDs = TKWebViewWaitObservedNodeIDs(from: snapshot)
    let effectivePageSessionID = request.pageSessionID ?? snapshot.webView.pageSessionID
    let eventNames = TKWebViewWaitObservedEventNames(from: events, pageSessionID: effectivePageSessionID)

    if request.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return TKWebViewWaitEvaluation(
            hit: false,
            lastObservedTextSample: textSample,
            lastObservedNodeIDs: nodeIDs,
            lastObservedEventNames: eventNames,
            error: TKWebViewError(
                code: .webViewWaitUnsupported,
                message: "WebView wait requires a non-empty query.",
                hint: "Pass a non-empty --text, --selector, or --event value."
            )
        )
    }

    if let requestedSession = request.pageSessionID,
       let currentSession = snapshot.webView.pageSessionID,
       requestedSession != currentSession {
        return TKWebViewWaitEvaluation(
            hit: false,
            lastObservedTextSample: textSample,
            lastObservedNodeIDs: nodeIDs,
            lastObservedEventNames: eventNames,
            error: TKWebViewError(
                code: .webViewNavigationChanged,
                message: "WebView page session changed.",
                hint: "Run `triton webview current --json` and retry against the new pageSessionID.",
                webViewID: snapshot.webView.webViewID
            )
        )
    }

    switch request.condition {
    case .text:
        if snapshot.text.contains(where: { TKWebViewWaitExactTextMatches($0, query: request.query) }) {
            return TKWebViewWaitEvaluation(
                hit: true,
                match: TKWebViewWaitMatch(text: request.query, source: "text[]"),
                lastObservedTextSample: textSample,
                lastObservedNodeIDs: nodeIDs,
                lastObservedEventNames: eventNames
            )
        }
        if let domMatch = snapshot.dom.first(where: { TKWebViewWaitExactTextMatches($0.text, query: request.query) }) {
            return TKWebViewWaitEvaluation(
                hit: true,
                match: TKWebViewWaitMatch(
                    text: request.query,
                    nodeID: domMatch.nodeID,
                    frame: domMatch.frame,
                    source: "dom[].text"
                ),
                lastObservedTextSample: textSample,
                lastObservedNodeIDs: nodeIDs,
                lastObservedEventNames: eventNames
            )
        }
        return TKWebViewWaitEvaluation(
            hit: false,
            lastObservedTextSample: textSample,
            lastObservedNodeIDs: nodeIDs,
            lastObservedEventNames: eventNames
        )

    case .selector:
        let selector = request.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard TKWebViewWaitIsSimpleIDSelector(selector) else {
            return TKWebViewWaitEvaluation(
                hit: false,
                lastObservedTextSample: textSample,
                lastObservedNodeIDs: nodeIDs,
                lastObservedEventNames: eventNames,
                error: TKWebViewError(
                    code: .webViewWaitUnsupported,
                    message: "Only simple #id selectors are supported by webview wait.",
                    hint: "Pass --selector #submit or use --text/--event."
                )
            )
        }
        let selectorID = String(selector.dropFirst())
        if selectorID == snapshot.webView.webViewID {
            return TKWebViewWaitEvaluation(
                hit: true,
                match: TKWebViewWaitMatch(
                    selector: selector,
                    nodeID: snapshot.webView.webViewID,
                    frame: snapshot.webView.frame,
                    source: "webView.webViewID"
                ),
                lastObservedTextSample: textSample,
                lastObservedNodeIDs: nodeIDs,
                lastObservedEventNames: eventNames
            )
        }
        if let domMatch = snapshot.dom.first(where: { $0.nodeID == selectorID }) {
            return TKWebViewWaitEvaluation(
                hit: true,
                match: TKWebViewWaitMatch(
                    selector: selector,
                    nodeID: domMatch.nodeID,
                    frame: domMatch.frame,
                    source: "dom[].nodeID"
                ),
                lastObservedTextSample: textSample,
                lastObservedNodeIDs: nodeIDs,
                lastObservedEventNames: eventNames
            )
        }
        return TKWebViewWaitEvaluation(
            hit: false,
            lastObservedTextSample: textSample,
            lastObservedNodeIDs: nodeIDs,
            lastObservedEventNames: eventNames
        )

    case .event:
        let matchingEvent = events?.events.first { event in
            if let pageSessionID = effectivePageSessionID {
                guard event.pageSessionID == pageSessionID else { return false }
            }
            return event.name == request.query
        }
        if let matchingEvent {
            return TKWebViewWaitEvaluation(
                hit: true,
                match: TKWebViewWaitMatch(
                    event: matchingEvent.name,
                    source: "events[].name"
                ),
                lastObservedTextSample: textSample,
                lastObservedNodeIDs: nodeIDs,
                lastObservedEventNames: eventNames
            )
        }
        return TKWebViewWaitEvaluation(
            hit: false,
            lastObservedTextSample: textSample,
            lastObservedNodeIDs: nodeIDs,
            lastObservedEventNames: eventNames
        )
    }
}

private func TKWebViewWaitObservedTextSample(from snapshot: TKWebViewSnapshotResponse, limit: Int = 20) -> [String] {
    var sample: [String] = []
    var seen = Set<String>()
    for text in snapshot.text + snapshot.dom.compactMap(\.text) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !seen.contains(cleaned) else { continue }
        seen.insert(cleaned)
        sample.append(cleaned)
        if sample.count >= limit { break }
    }
    return sample
}

private func TKWebViewWaitObservedNodeIDs(from snapshot: TKWebViewSnapshotResponse, limit: Int = 20) -> [String] {
    var sample = [snapshot.webView.webViewID]
    for nodeID in snapshot.dom.compactMap(\.nodeID) where !sample.contains(nodeID) {
        sample.append(nodeID)
        if sample.count >= limit { break }
    }
    return sample
}

private func TKWebViewWaitObservedEventNames(
    from response: TKWebViewEventsResponse?,
    pageSessionID: String?,
    limit: Int = 20
) -> [String] {
    guard let response else { return [] }
    var sample: [String] = []
    var seen = Set<String>()
    for event in response.events {
        if let pageSessionID, event.pageSessionID != pageSessionID {
            continue
        }
        guard !seen.contains(event.name) else { continue }
        seen.insert(event.name)
        sample.append(event.name)
        if sample.count >= limit { break }
    }
    return sample
}

private func TKWebViewWaitExactTextMatches(_ value: String?, query: String) -> Bool {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
        return false
    }
    return value == query.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func TKWebViewWaitIsSimpleIDSelector(_ selector: String) -> Bool {
    guard selector.first == "#", selector.count > 1 else { return false }
    let body = selector.dropFirst()
    guard !body.contains(where: { $0.isWhitespace }) else { return false }
    return !body.contains(where: { " >+~[],()*".contains($0) })
}
