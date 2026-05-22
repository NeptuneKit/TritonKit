import Foundation

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
    let sourceCommands: [String]
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
