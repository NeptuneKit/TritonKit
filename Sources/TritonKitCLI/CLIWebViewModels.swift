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

/// SP-173 / GitHub #207: machine-readable result for `triton webview bridge-call`.
/// Harmony runs through the host-side ArkWeb CDP adapter; iOS wraps the embedded
/// runtime `webview.call` response without changing its provider contract.
struct WebViewBridgeCallSummary: Codable, Equatable {
    let ok: Bool
    let action: String
    let platform: String
    let capturedAt: String
    let target: String
    let webViewID: String
    let pageSessionID: String?
    let method: String
    let params: [String: TKJSONValue]
    let result: TKJSONValue?
    let error: TKWebViewError?
    let elapsedMs: Int
    let source: String
    let sourceCommands: [String]
    let redaction: TKWebViewRedaction

    init(
        ok: Bool,
        action: String = "webview.bridge-call",
        platform: String,
        capturedAt: String,
        target: String,
        webViewID: String,
        pageSessionID: String? = nil,
        method: String,
        params: [String: TKJSONValue] = [:],
        result: TKJSONValue? = nil,
        error: TKWebViewError? = nil,
        elapsedMs: Int,
        source: String,
        sourceCommands: [String] = [],
        redaction: TKWebViewRedaction = TKWebViewRedaction()
    ) {
        self.ok = ok
        self.action = action
        self.platform = platform
        self.capturedAt = capturedAt
        self.target = target
        self.webViewID = webViewID
        self.pageSessionID = pageSessionID
        self.method = method
        self.params = params
        self.result = result
        self.error = error
        self.elapsedMs = elapsedMs
        self.source = source
        self.sourceCommands = sourceCommands
        self.redaction = redaction
    }
}
