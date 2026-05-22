import Foundation

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
