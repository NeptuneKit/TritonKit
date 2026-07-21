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

    @Test("snapshot request keeps include and limits machine readable")
    func snapshotRequestShape() {
        let request = makeWebViewSnapshotRequest(
            webViewID: "webview-1",
            pageSessionID: "page-1",
            include: "metadata,text,forms",
            maxDOMNodes: 25,
            maxTextBytes: 512
        )

        #expect(request.webViewID == "webview-1")
        #expect(request.pageSessionID == "page-1")
        #expect(request.include == ["metadata", "text", "forms"])
        #expect(request.maxDOMNodes == 25)
        #expect(request.maxTextBytes == 512)
    }

    @Test("snapshot decoder preserves WebView error envelopes")
    func snapshotDecoderPreservesWebViewErrorEnvelope() throws {
        let data = try JSONEncoder().encode(TKWebViewErrorResponse(
            action: "webview.snapshot",
            platform: "ios",
            target: "embedded-runtime",
            error: TKCLIErrorDetail(
                code: "webview_navigation_changed",
                message: "WebView page session changed.",
                hint: "Run `triton webview current --json` and retry."
            )
        ))

        let result = try decodeWebViewSnapshotRuntimeResult(data)

        switch result {
        case .snapshot:
            Issue.record("Expected WebView error envelope")
        case .error(let response):
            #expect(response.ok == false)
            #expect(response.error.code == "webview_navigation_changed")
        }
    }

    @Test("wait request defaults use seconds")
    func waitRequestDefaultsUseSeconds() {
        let request = TKWebViewWaitRequest(condition: .text, query: "Ready")

        #expect(request.timeoutSeconds == 10)
        #expect(request.intervalSeconds == 0.5)
    }

    @Test("CLI wait request requires exactly one condition")
    func cliWaitRequestRequiresExactlyOneCondition() throws {
        let request = try makeWebViewWaitRequest(
            text: "Ready",
            selector: nil,
            event: nil,
            webViewID: "webview-1",
            pageSessionID: "page-1",
            timeoutSeconds: 3,
            intervalSeconds: 0.25
        )

        #expect(request.condition == .text)
        #expect(request.query == "Ready")
        #expect(request.webViewID == "webview-1")
        #expect(request.pageSessionID == "page-1")
        #expect(request.timeoutSeconds == 3)
        #expect(request.intervalSeconds == 0.25)

        #expect(throws: RuntimeError.self) {
            _ = try makeWebViewWaitRequest(
                text: "Ready",
                selector: "#submit",
                event: nil,
                webViewID: nil,
                pageSessionID: nil,
                timeoutSeconds: 10,
                intervalSeconds: 0.5
            )
        }

        #expect(throws: RuntimeError.self) {
            _ = try makeWebViewWaitRequest(
                text: nil,
                selector: nil,
                event: nil,
                webViewID: nil,
                pageSessionID: nil,
                timeoutSeconds: 10,
                intervalSeconds: 0.5
            )
        }
    }

    @Test("wait decoder preserves WebView wait and error envelopes")
    func waitDecoderPreservesWaitAndErrorEnvelopes() throws {
        let waitData = try JSONEncoder().encode(TKWebViewWaitResponse(
            capturedAt: "2026-05-26T00:00:00Z",
            platform: "ios",
            target: "embedded-runtime",
            webView: webView(url: "https://example.invalid"),
            condition: "text",
            query: "Ready",
            matched: true,
            timedOut: false,
            elapsedMs: 50,
            pollCount: 1,
            timeoutSeconds: 10,
            intervalSeconds: 0.5,
            pageSessionID: "page-1",
            match: TKWebViewWaitMatch(text: "Ready", source: "text[]")
        ))

        switch try decodeWebViewWaitRuntimeResult(waitData) {
        case .wait(let response):
            #expect(response.ok)
            #expect(response.match?.text == "Ready")
        case .error:
            Issue.record("Expected wait response")
        }

        let errorData = try JSONEncoder().encode(TKWebViewErrorResponse(
            action: "webview.wait",
            platform: "ios",
            target: "embedded-runtime",
            error: TKCLIErrorDetail(
                code: "webview_wait_unsupported",
                message: "Only simple #id selectors are supported."
            )
        ))

        switch try decodeWebViewWaitRuntimeResult(errorData) {
        case .wait:
            Issue.record("Expected WebView error envelope")
        case .error(let response):
            #expect(response.error.code == "webview_wait_unsupported")
        }
    }

    @Test("schema exposes WebView wait contract")
    func schemaExposesWebViewWaitContract() throws {
        let schema = try #require(commandSchemas().first { $0.name == "webview" })
        let optionNames = Set(schema.options.map(\.name))
        let usageForms = Set(schema.usageForms.map(\.form))

        #expect(usageForms.contains("wait"))
        #expect(optionNames.contains("--text"))
        #expect(optionNames.contains("--selector"))
        #expect(optionNames.contains("--event"))
        #expect(optionNames.contains("--timeout"))
        #expect(optionNames.contains("--interval"))
        #expect(schema.providedCapabilities.contains("webview-wait"))
        #expect(schema.successShape?.contains("action:webview.wait") == true)
        #expect(schema.failureShape?.contains("webview_wait_unsupported") == true)
        #expect(schema.examples.contains("triton webview wait --text Ready --json"))
    }

    @Test("act schema exposes WebView-aware tap as opt-in agent surface")
    func actSchemaExposesWebViewAwareTap() throws {
        let schema = try #require(commandSchemas().first { $0.name == "act" })
        let optionNames = Set(schema.options.map(\.name))
        let tap = try #require(schema.subcommands.first { $0.name == "tap" })

        #expect(optionNames.contains("--webview-aware"))
        #expect(optionNames.contains("--selector"))
        #expect(optionNames.contains("--webview-id"))
        #expect(optionNames.contains("--page-session-id"))
        #expect(optionNames.contains("--expect-text"))
        #expect(optionNames.contains("--expect-request") == false)
        #expect(schema.providedCapabilities.contains("webview-aware-tap"))
        #expect(schema.outputContracts.contains { $0.selector == "act.webview-aware-tap" })
        #expect(tap.outputSelectors.contains("act.webview-aware-tap"))
        #expect(tap.optionalOptions.contains("--webview-aware"))
        #expect(tap.optionalOptions.contains("--webview-id"))
    }

    @Test("tap schema documents selectable cell ancestor activation")
    func tapSchemaDocumentsSelectableCellAncestorActivation() throws {
        let act = try #require(commandSchemas().first { $0.name == "act" })
        let tap = try #require(actionCommandSchemas().first { $0.name == "tap" })
        let actStrategy = try #require(act.options.first { $0.name == "--strategy" })
        let tapStrategy = try #require(tap.options.first { $0.name == "--strategy" })

        #expect(actStrategy.description.contains("UICollectionViewCell"))
        #expect(tapStrategy.description.contains("UICollectionViewCell"))
        #expect(tap.outputSemantics?.contains("ancestor-collection-cell-selection") == true)
        #expect(tap.outputSemantics?.contains("ancestor-table-cell-selection") == true)
        #expect(tap.outputSemantics?.contains("invokes didSelectRowAt before returning") == true)
        #expect(tap.outputSemantics?.contains("button-primary-menu-action") == true)
    }

    @Test("Harmony route WebView warnings expose next actions")
    func harmonyRouteWebViewWarningsExposeNextActions() {
        let warnings = harmonyRouteWebViewWarnings(hasRuntimeBaseURL: false, hasCandidates: true)

        #expect(warnings.map(\.code).contains("harmony_route_webview_snapshot_partial"))
        #expect(warnings.map(\.code).contains("harmony_route_loop_detector_provider_required"))
        #expect(warnings.map(\.code).contains("harmony_runtime_base_url_missing"))
        #expect(warnings.first { $0.code == "harmony_route_loop_detector_provider_required" }?.nextAction?.command == "evidence")
        #expect(warnings.first { $0.code == "harmony_runtime_base_url_missing" }?.nextAction?.args.contains("runtime-url") == true)
    }

    @Test("WebView responses decode missing warnings as empty")
    func webViewResponsesDecodeMissingWarningsAsEmpty() throws {
        let data = Data("""
        {
          "ok": true,
          "action": "webview.list",
          "platform": "harmony",
          "capturedAt": "2026-06-17T00:00:00Z",
          "target": "harmony:127.0.0.1:10100",
          "current": null,
          "candidates": [],
          "sources": [{ "name": "host-layout", "available": true, "sourceCommands": [] }],
          "sourceCommands": [],
          "note": "legacy"
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(TKWebViewListResponse.self, from: data)

        #expect(decoded.warnings.isEmpty)
    }

    @Test("wait text matches exact visible text lines only")
    func waitTextMatchesExactVisibleTextLinesOnly() {
        let snapshot = webViewSnapshot(
            text: ["Ready", "Submit Order"],
            dom: [TKWebViewDOMNodeSummary(nodeID: "submit", role: "button", tagName: "button", text: "Submit Order")]
        )

        let textHit = TKEvaluateWebViewWait(
            request: TKWebViewWaitRequest(condition: .text, query: "Ready"),
            snapshot: snapshot
        )
        let containsMiss = TKEvaluateWebViewWait(
            request: TKWebViewWaitRequest(condition: .text, query: "Submit"),
            snapshot: snapshot
        )

        #expect(textHit.hit)
        #expect(textHit.match?.source == "text[]")
        #expect(containsMiss.hit == false)
        #expect(containsMiss.match == nil)
        #expect(containsMiss.lastObservedTextSample == ["Ready", "Submit Order"])
    }

    @Test("wait text can match DOM node text exactly")
    func waitTextCanMatchDOMNodeTextExactly() {
        let snapshot = webViewSnapshot(
            text: [],
            dom: [TKWebViewDOMNodeSummary(nodeID: "welcome", role: "heading", tagName: "h1", text: "Welcome")]
        )

        let result = TKEvaluateWebViewWait(
            request: TKWebViewWaitRequest(condition: .text, query: "Welcome"),
            snapshot: snapshot
        )

        #expect(result.hit)
        #expect(result.match?.source == "dom[].text")
        #expect(result.match?.nodeID == "welcome")
    }

    @Test("wait selector supports only simple id selectors")
    func waitSelectorSupportsOnlySimpleIDSelectors() {
        let snapshot = webViewSnapshot(
            dom: [TKWebViewDOMNodeSummary(nodeID: "submit", role: "button", tagName: "button", text: "Submit")]
        )

        let hit = TKEvaluateWebViewWait(
            request: TKWebViewWaitRequest(condition: .selector, query: "#submit"),
            snapshot: snapshot
        )
        let unsupported = TKEvaluateWebViewWait(
            request: TKWebViewWaitRequest(condition: .selector, query: "button#submit"),
            snapshot: snapshot
        )

        #expect(hit.hit)
        #expect(hit.match?.source == "dom[].nodeID")
        #expect(hit.match?.nodeID == "submit")
        #expect(unsupported.hit == false)
        #expect(unsupported.error?.code == .webViewWaitUnsupported)
    }

    @Test("wait event matches event names exactly")
    func waitEventMatchesEventNamesExactly() {
        let snapshot = webViewSnapshot()
        let events = TKWebViewEventsResponse(
            capturedAt: "2026-05-26T00:00:00Z",
            platform: "ios",
            target: "embedded-runtime",
            events: [
                TKWebViewEvent(
                    id: "event-1",
                    timestamp: "2026-05-26T00:00:00Z",
                    webViewID: "webview-1",
                    pageSessionID: "page-1",
                    name: "checkout.ready",
                    source: "page-bridge"
                )
            ],
            limit: 50
        )

        let hit = TKEvaluateWebViewWait(
            request: TKWebViewWaitRequest(condition: .event, query: "checkout.ready"),
            snapshot: snapshot,
            events: events
        )
        let miss = TKEvaluateWebViewWait(
            request: TKWebViewWaitRequest(condition: .event, query: "checkout"),
            snapshot: snapshot,
            events: events
        )

        #expect(hit.hit)
        #expect(hit.match?.source == "events[].name")
        #expect(hit.lastObservedEventNames == ["checkout.ready"])
        #expect(miss.hit == false)
    }

    @Test("wait detects page session changes")
    func waitDetectsPageSessionChanges() {
        let snapshot = webViewSnapshot(pageSessionID: "page-2")

        let result = TKEvaluateWebViewWait(
            request: TKWebViewWaitRequest(pageSessionID: "page-1", condition: .text, query: "Ready"),
            snapshot: snapshot
        )

        #expect(result.hit == false)
        #expect(result.error?.code == .webViewNavigationChanged)
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
        warnings: [],
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

private func webViewSnapshot(
    pageSessionID: String = "page-1",
    text: [String] = [],
    dom: [TKWebViewDOMNodeSummary] = []
) -> TKWebViewSnapshotResponse {
    TKWebViewSnapshotResponse(
        capturedAt: "2026-05-26T00:00:00Z",
        platform: "ios",
        target: "embedded-runtime",
        webView: TKWebViewDescriptor(
            webViewID: "webview-1",
            platform: "ios",
            source: "webview-provider",
            nodeID: "webview-1",
            role: "webview",
            frame: TKRect(x: 0, y: 0, width: 390, height: 844),
            candidateOnly: false,
            confidence: 1,
            pageSessionID: pageSessionID,
            providerStatus: "available",
            bridgeStatus: "available",
            capabilities: ["webview.snapshot"],
            missingCapabilities: []
        ),
        include: ["metadata", "dom", "text"],
        text: text,
        dom: dom
    )
}
