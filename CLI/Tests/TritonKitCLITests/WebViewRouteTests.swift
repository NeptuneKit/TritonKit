import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct WebViewRouteTests {
    @Test("current-url summary requires provider URL")
    func currentURLSummaryRequiresProviderURL() throws {
        let list = webViewList(candidates: [
            webView(url: nil, candidateOnly: true, providerStatus: "unavailable")
        ])

        do {
            _ = try makeWebViewCurrentURLSummary(from: list, webViewID: nil)
            Issue.record("Expected provider unavailable error")
        } catch let error as TKWebViewSelectionError {
            #expect(error.detail.code == .webViewProviderUnavailable)
        }
    }

    @Test("current-url summary returns provider metadata")
    func currentURLSummaryReturnsProviderMetadata() throws {
        let list = webViewList(candidates: [
            webView(url: "https://example.invalid/path?debug=1", title: "Example")
        ])

        let summary = try makeWebViewCurrentURLSummary(from: list, webViewID: nil)

        #expect(summary.ok)
        #expect(summary.action == "webview.current-url")
        #expect(summary.url == "https://example.invalid/path?debug=1")
        #expect(summary.title == "Example")
        #expect(summary.providerStatus == "available")
    }

    @Test("route current-url assertion supports exact and ignore-query matching")
    func routeCurrentURLAssertionMatching() {
        let current = WebViewCurrentURLSummary(
            ok: true,
            action: "webview.current-url",
            platform: "ios",
            capturedAt: "2026-05-23T00:00:00Z",
            target: "triton:local",
            webViewID: "webview-1",
            url: "https://example.invalid/path?debug=1",
            title: "Example",
            pageSessionID: "page-1",
            providerStatus: "available",
            bridgeStatus: "available",
            sourceCommands: []
        )

        let exact = makeRouteCurrentURLAssertion(expectedURL: "https://example.invalid/path?debug=1", current: current, ignoreQuery: false)
        let ignored = makeRouteCurrentURLAssertion(expectedURL: "https://example.invalid/path", current: current, ignoreQuery: true)
        let mismatch = makeRouteCurrentURLAssertion(expectedURL: "https://example.invalid/other", current: current, ignoreQuery: true)

        #expect(exact.ok)
        #expect(exact.status == .pass)
        #expect(ignored.ok)
        #expect(ignored.matched)
        #expect(mismatch.ok == false)
        #expect(mismatch.status == .fail)
        #expect(mismatch.hint == "Run `triton webview current-url --json` to inspect the current provider URL.")
    }
}

private func webViewList(candidates: [TKWebViewDescriptor]) -> TKWebViewListResponse {
    TKWebViewListResponse(
        ok: true,
        action: "webview.current-url",
        platform: "ios",
        capturedAt: "2026-05-23T00:00:00Z",
        target: "triton:local",
        current: candidates.first,
        candidates: candidates,
        sources: [TKWebViewSource(name: "webview-provider", available: true)],
        sourceCommands: ["triton webview current-url"],
        note: "test"
    )
}

private func webView(
    url: String?,
    title: String? = nil,
    candidateOnly: Bool = false,
    providerStatus: String = "available"
) -> TKWebViewDescriptor {
    TKWebViewDescriptor(
        webViewID: "webview-1",
        platform: "ios",
        source: "webview-provider",
        candidateOnly: candidateOnly,
        confidence: 0.99,
        url: url,
        title: title,
        pageSessionID: "page-1",
        providerStatus: providerStatus,
        bridgeStatus: "available",
        capabilities: ["webview.url"],
        missingCapabilities: []
    )
}
