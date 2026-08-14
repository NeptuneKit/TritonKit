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

    @Test("WebView focus request and response preserve stable selector identity")
    func webViewFocusRequestResponseShape() throws {
        let request = TKWebViewFocusRequest(webViewID: "ios-webkit:1", pageSessionID: "page-1", selector: "#body")
        let response = TKWebViewFocusResponse(
            capturedAt: "2026-08-11T00:00:00Z",
            platform: "ios",
            target: "embedded-runtime",
            webViewID: "ios-webkit:1",
            pageSessionID: "page-1",
            selector: "#body",
            focused: true,
            element: TKWebViewFormFieldSummary(
                name: "body",
                inputType: "contenteditable",
                label: nil,
                valueRedaction: "length-only",
                valueLength: 26,
                kind: "contenteditable",
                selector: "#body",
                nodeID: "body",
                focused: true,
                contentEditable: true
            ),
            elapsedMs: 8,
            sourceCommands: ["triton webview focus #body --json"]
        )

        let requestData = try JSONEncoder().encode(request)
        let responseData = try JSONEncoder().encode(response)
        let decodedRequest = try JSONDecoder().decode(TKWebViewFocusRequest.self, from: requestData)
        let decodedResponse = try JSONDecoder().decode(TKWebViewFocusResponse.self, from: responseData)

        #expect(decodedRequest.selector == "#body")
        #expect(decodedResponse.focused)
        #expect(decodedResponse.element?.kind == "contenteditable")
        #expect(decodedResponse.element?.selector == "#body")
        #expect(decodedResponse.element?.contentEditable == true)
    }

    @Test("WebView form input request and response carry redaction, dispatch evidence, and postcondition")
    func webViewFormInputRequestResponseShape() throws {
        let request = TKWebViewFormInputRequest(
            webViewID: "ios-webkit:1",
            pageSessionID: "page-1",
            selector: "#body",
            mode: .setText,
            text: "secret body text",
            secure: true,
            sourceCommand: "triton webview set-text --selector #body --secure"
        )
        let response = TKWebViewFormInputResponse(
            capturedAt: "2026-08-11T00:00:00Z",
            platform: "ios",
            target: "embedded-runtime",
            webViewID: "ios-webkit:1",
            pageSessionID: "page-1",
            selector: "#body",
            mode: "set",
            focused: true,
            insertedLength: 15,
            valueLength: 15,
            valueRedaction: "length-only",
            eventsDispatched: ["input", "change"],
            element: TKWebViewFormFieldSummary(name: "body", inputType: "contenteditable", valueRedaction: "length-only", valueLength: 15, kind: "contenteditable", selector: "#body", nodeID: "body", focused: true, contentEditable: true),
            elapsedMs: 11,
            sourceCommands: ["triton webview set-text --selector #body --secure"],
            redaction: TKWebViewRedaction(secureText: "length-only"),
            note: "Inserted redacted WebView text"
        )

        let requestData = try JSONEncoder().encode(request)
        let responseData = try JSONEncoder().encode(response)
        let decodedRequest = try JSONDecoder().decode(TKWebViewFormInputRequest.self, from: requestData)
        let decodedResponse = try JSONDecoder().decode(TKWebViewFormInputResponse.self, from: responseData)

        #expect(decodedRequest.mode == .setText)
        #expect(decodedRequest.secure)
        #expect(decodedResponse.mode == "set")
        #expect(decodedResponse.eventsDispatched == ["input", "change"])
        #expect(decodedResponse.valueLength == 15)
        #expect(decodedResponse.valueRedaction == "length-only")
        #expect(decodedResponse.redaction.secureText == "length-only")
        #expect(decodedResponse.element?.kind == "contenteditable")
    }

    @Test("WebView focus and form input request types and HTTP routes")
    func webViewFocusFormInputRequestTypesAndRoutes() {
        #expect(TKCLICommandRequest(type: "webViewFocus").requestType == .webViewFocus)
        #expect(TKCLICommandRequest(type: "webview.focus").requestType == .webViewFocus)
        #expect(TKCLICommandRequest(type: "webViewFormInput").requestType == .webViewFormInput)
        #expect(TKCLICommandRequest(type: "webview.form-input").requestType == .webViewFormInput)
        #expect(TKEmbeddedRuntimeHTTPRoute.route(for: .webViewFocus) == TKEmbeddedRuntimeHTTPRoute(method: .post, path: "/v2/runtime/webview/focus"))
        #expect(TKEmbeddedRuntimeHTTPRoute.route(for: .webViewFormInput) == TKEmbeddedRuntimeHTTPRoute(method: .post, path: "/v2/runtime/webview/form-input"))
    }
}
