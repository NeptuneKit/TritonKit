import Foundation

public enum TKWebViewErrorCode: String, Codable, Equatable {
    case webviewNotFound = "webview_not_found"
    case ambiguousWebView = "ambiguous_webview"
    case webViewIDNotFound = "webview_id_not_found"
    case webViewProviderUnavailable = "webview_provider_unavailable"
    case webViewNavigationChanged = "webview_navigation_changed"
    case webViewBridgeUnavailable = "webview_bridge_unavailable"
    case webViewMethodNotAllowed = "webview_method_not_allowed"
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
        missingCapabilities: [String]
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
    }
}

public struct TKWebViewListResponse: Codable, Equatable {
    public let ok: Bool
    public let action: String
    public let platform: String
    public let capturedAt: String
    public let target: String
    public let current: TKWebViewDescriptor?
    public let candidates: [TKWebViewDescriptor]
    public let sources: [TKWebViewSource]
    public let sourceCommands: [String]
    public let note: String

    public init(
        ok: Bool,
        action: String,
        platform: String,
        capturedAt: String,
        target: String,
        current: TKWebViewDescriptor?,
        candidates: [TKWebViewDescriptor],
        sources: [TKWebViewSource],
        sourceCommands: [String],
        note: String
    ) {
        self.ok = ok
        self.action = action
        self.platform = platform
        self.capturedAt = capturedAt
        self.target = target
        self.current = current
        self.candidates = candidates
        self.sources = sources
        self.sourceCommands = sourceCommands
        self.note = note
    }
}

public struct TKWebViewCurrentResponse: Codable, Equatable {
    public let ok: Bool
    public let action: String
    public let platform: String
    public let capturedAt: String
    public let target: String
    public let webView: TKWebViewDescriptor
    public let sources: [TKWebViewSource]
    public let sourceCommands: [String]
    public let note: String

    public init(
        ok: Bool,
        action: String,
        platform: String,
        capturedAt: String,
        target: String,
        webView: TKWebViewDescriptor,
        sources: [TKWebViewSource],
        sourceCommands: [String],
        note: String
    ) {
        self.ok = ok
        self.action = action
        self.platform = platform
        self.capturedAt = capturedAt
        self.target = target
        self.webView = webView
        self.sources = sources
        self.sourceCommands = sourceCommands
        self.note = note
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
