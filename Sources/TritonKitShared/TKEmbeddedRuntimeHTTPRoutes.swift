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
        case .runtimeLedger:
            TKEmbeddedRuntimeHTTPRoute(method: .get, path: "/v2/runtime/ledger")
        case .semanticAction:
            TKEmbeddedRuntimeHTTPRoute(method: .post, path: "/v2/runtime/action")
        default:
            nil
        }
    }
}
