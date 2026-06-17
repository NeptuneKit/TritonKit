import Foundation
import TritonKitShared

enum RouteURLAssertionStatus: String, Codable, Equatable {
    case pass
    case fail
}

struct WebViewCurrentURLSummary: Codable, Equatable {
    let ok: Bool
    let action: String
    let platform: String
    let capturedAt: String
    let target: String
    let webViewID: String
    let url: String
    let title: String?
    let pageSessionID: String?
    let providerStatus: String
    let bridgeStatus: String
    let providerCapabilities: TKWebViewProviderCapabilities?
    let sourceCommands: [String]

    init(
        ok: Bool,
        action: String,
        platform: String,
        capturedAt: String,
        target: String,
        webViewID: String,
        url: String,
        title: String?,
        pageSessionID: String?,
        providerStatus: String,
        bridgeStatus: String,
        providerCapabilities: TKWebViewProviderCapabilities? = nil,
        sourceCommands: [String]
    ) {
        self.ok = ok
        self.action = action
        self.platform = platform
        self.capturedAt = capturedAt
        self.target = target
        self.webViewID = webViewID
        self.url = url
        self.title = title
        self.pageSessionID = pageSessionID
        self.providerStatus = providerStatus
        self.bridgeStatus = bridgeStatus
        self.providerCapabilities = providerCapabilities
        self.sourceCommands = sourceCommands
    }
}

struct RouteCurrentURLAssertionSummary: Codable, Equatable {
    let ok: Bool
    let action: String
    let status: RouteURLAssertionStatus
    let expectedURL: String
    let actualURL: String
    let matched: Bool
    let ignoreQuery: Bool
    let platform: String
    let target: String
    let webViewID: String
    let title: String?
    let pageSessionID: String?
    let hint: String?
}
