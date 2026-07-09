import Foundation
import Testing
import TritonKitShared

@Suite
struct TKWebViewActionModelsTests {
    @Test("WebView tap request and response preserve untrusted dispatch")
    func webViewTapRequestResponseShape() throws {
        let request = TKWebViewTapRequest(webViewID: "ios-webkit:1", pageSessionID: "page-1", selector: "#submit")
        let response = TKWebViewTapResponse(
            capturedAt: "2026-07-09T00:00:00Z",
            platform: "ios",
            target: "embedded-runtime",
            webViewID: "ios-webkit:1",
            pageSessionID: "page-1",
            selector: "#submit",
            dispatched: true,
            trusted: false,
            element: TKWebViewTapTarget(selector: "#submit", tagName: "BUTTON", nodeID: "submit", text: "Submit"),
            elapsedMs: 12,
            sourceCommands: ["triton webViewTap request"]
        )

        let requestData = try JSONEncoder().encode(request)
        let responseData = try JSONEncoder().encode(response)
        let decodedRequest = try JSONDecoder().decode(TKWebViewTapRequest.self, from: requestData)
        let decodedResponse = try JSONDecoder().decode(TKWebViewTapResponse.self, from: responseData)

        #expect(decodedRequest.selector == "#submit")
        #expect(decodedResponse.dispatched)
        #expect(decodedResponse.trusted == false)
        #expect(decodedResponse.element?.tagName == "BUTTON")
    }

    @Test("WebView-aware act tap is uncertain without expectation")
    func webViewAwareTapWithoutExpectIsUncertain() throws {
        let tap = TKWebViewTapResponse(
            capturedAt: "2026-07-09T00:00:00Z",
            platform: "ios",
            target: "embedded-runtime",
            selector: "#submit",
            dispatched: true,
            trusted: false,
            elapsedMs: 4
        )

        let response = TKMakeWebViewAwareTapResponse(
            selector: "#submit",
            tap: tap,
            recoveryCommand: "triton act tap --webview-aware --selector '#submit' --expect-text '<text>' --json"
        )

        #expect(response.ok)
        #expect(response.status == .uncertain)
        #expect(response.verification.expectProvided == false)
        #expect(response.attempts.first?.trusted == false)
        #expect(response.recoveryCommand?.contains("--expect-text") == true)
    }

    @Test("WebView-aware act tap passes only when expect text matches")
    func webViewAwareTapRequiresExpectMatchToPass() throws {
        let tap = TKWebViewTapResponse(
            capturedAt: "2026-07-09T00:00:00Z",
            platform: "ios",
            target: "embedded-runtime",
            selector: "#submit",
            dispatched: true,
            trusted: false,
            elapsedMs: 4
        )
        let wait = TKWebViewWaitResponse(
            capturedAt: "2026-07-09T00:00:01Z",
            platform: "ios",
            target: "embedded-runtime",
            condition: "text",
            query: "成功",
            matched: true,
            timedOut: false,
            elapsedMs: 30,
            pollCount: 1,
            timeoutSeconds: 3,
            intervalSeconds: 0.25
        )

        let response = TKMakeWebViewAwareTapResponse(selector: "#submit", tap: tap, expectText: "成功", wait: wait)

        #expect(response.status == .passed)
        #expect(response.verification.expectProvided)
        #expect(response.verification.textMatched == true)
        #expect(response.recoveryCommand == nil)
    }

    @Test("WebView request type and HTTP route include tap")
    func webViewTapRequestTypeAndRoute() {
        #expect(TKCLICommandRequest(type: "webViewTap").requestType == .webViewTap)
        #expect(TKCLICommandRequest(type: "webview.click").requestType == .webViewTap)
        #expect(TKEmbeddedRuntimeHTTPRoute.route(for: .webViewTap) == TKEmbeddedRuntimeHTTPRoute(method: .post, path: "/v2/runtime/webview/tap"))
    }
}
