import Foundation
import Testing
@testable import TritonKitShared

@Suite("WebView transport error wire compatibility")
struct TKWebViewTransportErrorTests {
    @Test("CDP failures survive DTO encoding without being reclassified as page errors", arguments: [
        "webview_transport_error", "webview_protocol_error", "javascript_error", "webview_bridge_timeout"
    ])
    func errorRoundTrip(code: String) throws {
        let data = Data("\"\(code)\"".utf8)
        let decoded = try JSONDecoder().decode(TKWebViewErrorCode.self, from: data)
        #expect(decoded.rawValue == code)
        #expect(try JSONEncoder().encode(decoded) == data)
        let envelope = TKWebViewError(code: decoded, message: "synthetic fixture", hint: "Inspect before retrying")
        let roundTrip = try JSONDecoder().decode(TKWebViewError.self, from: JSONEncoder().encode(envelope))
        #expect(roundTrip.code == decoded)
        #expect(roundTrip.hint == envelope.hint)
    }
}
