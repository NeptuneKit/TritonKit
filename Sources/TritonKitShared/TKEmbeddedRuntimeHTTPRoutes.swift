import Foundation

public enum TKEmbeddedRuntimeHTTPMethod: String, Codable, Equatable {
    case get = "GET"
    case post = "POST"
}

public struct TKEmbeddedRuntimeHTTPRoute: Codable, Equatable {
    public let method: TKEmbeddedRuntimeHTTPMethod
    public let path: String

    public init(method: TKEmbeddedRuntimeHTTPMethod, path: String) {
        self.method = method
        self.path = path
    }

    public static func route(for requestType: TKRequestType) -> TKEmbeddedRuntimeHTTPRoute? {
        switch requestType {
        case .runtimeManifest:
            TKEmbeddedRuntimeHTTPRoute(method: .get, path: "/v2/runtime/manifest")
        case .stateApp:
            TKEmbeddedRuntimeHTTPRoute(method: .get, path: "/v2/runtime/state/app")
        case .stateScene:
            TKEmbeddedRuntimeHTTPRoute(method: .get, path: "/v2/runtime/state/scene")
        case .stateRoute:
            TKEmbeddedRuntimeHTTPRoute(method: .get, path: "/v2/runtime/state/route")
        case .stateResponder:
            TKEmbeddedRuntimeHTTPRoute(method: .get, path: "/v2/runtime/state/responder")
        case .runtimeSnapshot:
            TKEmbeddedRuntimeHTTPRoute(method: .get, path: "/v2/runtime/snapshot")
        case .webViewList:
            TKEmbeddedRuntimeHTTPRoute(method: .get, path: "/v2/runtime/webview/list")
        case .webViewCurrent:
            TKEmbeddedRuntimeHTTPRoute(method: .get, path: "/v2/runtime/webview/current")
        case .webViewSnapshot:
            TKEmbeddedRuntimeHTTPRoute(method: .post, path: "/v2/runtime/webview/snapshot")
        case .webViewBridgeCall:
            TKEmbeddedRuntimeHTTPRoute(method: .post, path: "/v2/runtime/webview/call")
        case .webViewBridgePost:
            TKEmbeddedRuntimeHTTPRoute(method: .post, path: "/v2/runtime/webview/post")
        case .webViewWait:
            TKEmbeddedRuntimeHTTPRoute(method: .post, path: "/v2/runtime/webview/wait")
        case .webViewEvents:
            TKEmbeddedRuntimeHTTPRoute(method: .get, path: "/v2/runtime/webview/events")
        case .webViewLedger:
            TKEmbeddedRuntimeHTTPRoute(method: .get, path: "/v2/runtime/webview/ledger")
        case .runtimeLedger:
            TKEmbeddedRuntimeHTTPRoute(method: .get, path: "/v2/runtime/ledger")
        case .semanticAction:
            TKEmbeddedRuntimeHTTPRoute(method: .post, path: "/v2/runtime/action")
        default:
            nil
        }
    }
}
