import Foundation
import Testing
import TritonKitShared

struct TKRuntimeUIHealthModelsTests {
    @Test("old action and WebView error JSON remain compatible")
    func legacyDomainResponsesDecode() throws {
        let input = try JSONDecoder().decode(TKInputResult.self, from: Data("{\"ok\":false,\"action\":\"tap\"}".utf8))
        let semantic = try JSONDecoder().decode(TKSemanticActionResponse.self, from: Data("{\"ok\":false,\"action\":\"focus\",\"strategy\":\"old\",\"elapsedMs\":0}".utf8))
        let web = try JSONDecoder().decode(TKWebViewErrorResponse.self, from: Data("{\"ok\":false,\"action\":\"webview.tap\",\"platform\":\"ios\",\"target\":\"embedded-runtime\",\"error\":{\"code\":\"old\",\"message\":\"old\"}}".utf8))
        #expect(input.outcome == nil && input.uiHealth == nil)
        #expect(semantic.outcome == nil && semantic.uiHealth == nil)
        #expect(web.outcome == nil && web.uiHealth == nil)
    }

    @Test("typed domain decoding and reencoding preserve unknown execution evidence")
    func domainResponsesPreserveUnknown() throws {
        let request = TKRuntimeUIInflightRequest(token: "current", requestID: 2, requestType: "input", elapsedMilliseconds: 50, timedOut: true)
        let health = TKRuntimeUIHealthSnapshot(state: .timedOut, allowsUIRequests: false, inflight: request, consecutiveTimeouts: 1, failureThreshold: 3, timeoutMilliseconds: 50, lastCompletion: nil)
        let error = TKCLIErrorDetail(code: "runtime_ui_timeout", message: "unknown")
        let input = TKInputResult.failure(action: "tap", message: "unknown", error: error, outcome: "unknown", uiHealth: health)
        let semantic = TKSemanticActionResponse(ok: false, action: .focus, strategy: "health", elapsedMs: 50, error: error, outcome: "unknown", uiHealth: health)
        let web = TKWebViewErrorResponse(action: "webview.tap", platform: "ios", target: "embedded-runtime", error: error, outcome: "unknown", uiHealth: health)
        try roundTrip(input)
        try roundTrip(semantic)
        try roundTrip(web)
        let inputCopy = try JSONDecoder().decode(TKInputResult.self, from: JSONEncoder().encode(input))
        #expect(inputCopy.uiHealth == health)
        #expect(inputCopy.outcome == "unknown")
        #expect(TKInputResult.unsupported(action: "tap", message: "unknown", error: error, outcome: "unknown", uiHealth: health).uiHealth == health)
    }

    private func roundTrip<T: Codable & Equatable>(_ response: T) throws {
        let first = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(T.self, from: first)
        let second = try JSONEncoder().encode(decoded)
        let copied = try JSONDecoder().decode(T.self, from: second)
        #expect(copied == response)
        let object = try #require(try JSONSerialization.jsonObject(with: second) as? [String: Any])
        #expect(object["outcome"] as? String == "unknown")
        #expect(object["uiHealth"] != nil)
    }

    @Test("legacy pong payload decodes without health metadata")
    func legacyPingDecodes() throws {
        let response = try JSONDecoder().decode(TKRuntimePingResponse.self, from: Data("{\"pong\":true,\"timestamp\":123}".utf8))
        #expect(response.pong)
        #expect(response.timestamp == 123)
        #expect(response.uiHealth == nil)
    }

    @Test("health metadata carries bounded execution identity without request payload")
    func healthRoundTrips() throws {
        let request = TKRuntimeUIInflightRequest(token: "unique", requestID: 17, requestType: "input", elapsedMilliseconds: 30, timedOut: true)
        let health = TKRuntimeUIHealthSnapshot(state: .timedOut, allowsUIRequests: false, inflight: request, consecutiveTimeouts: 1, failureThreshold: 3, timeoutMilliseconds: 30, lastCompletion: nil)
        let data = try JSONEncoder().encode(TKRuntimePingResponse(pong: true, timestamp: 123, uiHealth: health))
        #expect(try JSONDecoder().decode(TKRuntimePingResponse.self, from: data).uiHealth == health)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["pong"] as? Bool == true)
        #expect(String(decoding: data, as: UTF8.self).contains("requestPayload") == false)
    }
}
