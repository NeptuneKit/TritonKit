import Foundation
import Testing
@testable import TritonKitShared

@Suite
struct TKObservationModelsTests {
    @Test("observation request types are exposed to CLI transport")
    func requestTypeMapping() {
        #expect(TKCLICommandRequest(type: "accessibility").requestType == .accessibility)
        #expect(TKCLICommandRequest(type: "hitTest").requestType == .hitTest)
        #expect(TKCLICommandRequest(type: "screenshot").requestType == .screenshot)
        #expect(TKCLICommandRequest(type: "geometry").requestType == .geometry)
    }

    @Test("AX node carries actionable frame and semantic fields")
    func axNodeShape() throws {
        let node = TKAXNode(
            role: "button",
            label: "UIKit Tap",
            value: nil,
            identifier: "UIKitSmokeButton",
            title: nil,
            frame: TKRect(x: 10, y: 20, width: 80, height: 30),
            enabled: true,
            focused: false,
            hidden: false,
            targetOID: 7,
            viewOID: 7,
            layerOID: 8,
            className: "UIButton",
            children: []
        )

        let data = try JSONEncoder().encode(node)
        let decoded = try JSONDecoder().decode(TKAXNode.self, from: data)

        #expect(decoded.role == "button")
        #expect(decoded.label == "UIKit Tap")
        #expect(decoded.identifier == "UIKitSmokeButton")
        #expect(decoded.frame.centerX == 50)
        #expect(decoded.frame.centerY == 35)
        #expect(decoded.targetOID == 7)
        #expect(decoded.viewOID == 7)
        #expect(decoded.layerOID == 8)
    }

    @Test("AX node can describe complex harness controls")
    func complexHarnessAXShape() throws {
        let nodes = [
            TKAXNode(
                role: "segmentedControl",
                label: "Mode",
                value: "Inspect",
                identifier: "ComplexHarnessMode",
                title: nil,
                frame: TKRect(x: 20, y: 180, width: 260, height: 32),
                enabled: true,
                focused: false,
                hidden: false,
                targetOID: 21,
                className: "UISegmentedControl",
                children: []
            ),
            TKAXNode(
                role: "slider",
                label: "Progress",
                value: "0.50",
                identifier: "ComplexHarnessSlider",
                title: nil,
                frame: TKRect(x: 20, y: 224, width: 260, height: 32),
                enabled: true,
                focused: false,
                hidden: false,
                targetOID: 22,
                className: "UISlider",
                children: []
            ),
            TKAXNode(
                role: "stepper",
                label: "Count",
                value: "2",
                identifier: "ComplexHarnessStepper",
                title: nil,
                frame: TKRect(x: 20, y: 268, width: 94, height: 32),
                enabled: true,
                focused: false,
                hidden: false,
                targetOID: 23,
                className: "UIStepper",
                children: []
            ),
        ]

        let data = try JSONEncoder().encode(nodes)
        let decoded = try JSONDecoder().decode([TKAXNode].self, from: data)

        #expect(decoded.map(\.identifier).contains("ComplexHarnessMode"))
        #expect(decoded.first?.role == "segmentedControl")
        #expect(decoded[1].value == "0.50")
        #expect(decoded[2].role == "stepper")
    }

    @Test("hit test request and response round trip")
    func hitTestShape() throws {
        let request = TKHitTestRequest(x: 270, y: 300)
        let node = TKAXNode(
            role: "button",
            label: "UIKit Tap",
            value: nil,
            identifier: nil,
            title: nil,
            frame: TKRect(x: 239, y: 285, width: 62, height: 30),
            enabled: true,
            focused: false,
            hidden: false,
            targetOID: 10,
            className: "UIButton",
            children: []
        )
        let response = TKHitTestResponse(x: request.x, y: request.y, node: node)

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TKHitTestResponse.self, from: data)

        #expect(decoded.x == 270)
        #expect(decoded.y == 300)
        #expect(decoded.centerX == 270)
        #expect(decoded.centerY == 300)
        #expect(decoded.node?.targetOID == 10)
    }

    @Test("geometry response includes window bounds and safe area")
    func geometryShape() throws {
        let geometry = TKGeometryResponse(
            bounds: TKRect(x: 0, y: 0, width: 402, height: 874),
            safeArea: TKInsets(top: 62, left: 0, bottom: 34, right: 0),
            scale: 3,
            orientation: "portrait"
        )

        let data = try JSONEncoder().encode(geometry)
        let decoded = try JSONDecoder().decode(TKGeometryResponse.self, from: data)

        #expect(decoded.bounds.width == 402)
        #expect(decoded.safeArea.top == 62)
        #expect(decoded.scale == 3)
        #expect(decoded.orientation == "portrait")
    }

    @Test("screenshot response keeps base64 image payload metadata")
    func screenshotShape() throws {
        let response = TKScreenshotResponse(
            format: "png",
            width: 100,
            height: 200,
            scale: 2,
            dataBase64: Data("png".utf8).base64EncodedString()
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TKScreenshotResponse.self, from: data)

        #expect(decoded.format == "png")
        #expect(decoded.width == 100)
        #expect(decoded.height == 200)
        #expect(Data(base64Encoded: decoded.dataBase64) == Data("png".utf8))
    }

    @Test("WebView descriptor keeps provider boundary explicit")
    func webViewDescriptorShape() throws {
        let descriptor = TKWebViewDescriptor(
            webViewID: "ios-runtime:242",
            platform: "ios",
            source: "runtime-tree",
            nodeID: "ios-runtime:242",
            role: "scrollView",
            text: "Triton WebView Smoke Container",
            identifier: "WebViewSmokeScrollView",
            frame: TKRect(x: 16, y: 560, width: 370, height: 180),
            visibleRatio: 1,
            candidateOnly: true,
            confidence: 0.74,
            capabilities: ["visible", "runtime-oid"],
            missingCapabilities: ["webview.url", "webview.dom", "webview.bridge-call"]
        )

        let response = TKWebViewListResponse(
            ok: true,
            action: "webview.list",
            platform: "ios",
            capturedAt: "2026-05-22T00:00:00Z",
            target: "triton:ios-simulator:demo",
            current: descriptor,
            candidates: [descriptor],
            sources: [
                TKWebViewSource(name: "runtime-tree", available: true, sourceCommands: ["triton runtimeSnapshot request"]),
                TKWebViewSource(name: "webview-provider", available: false, reason: "provider not registered"),
            ],
            sourceCommands: ["triton runtimeSnapshot request"],
            note: "candidate only"
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TKWebViewListResponse.self, from: data)

        #expect(decoded.current?.candidateOnly == true)
        #expect(decoded.current?.providerStatus == "unavailable")
        #expect(decoded.current?.bridgeStatus == "unavailable")
        #expect(decoded.current?.missingCapabilities.contains("webview.dom") == true)
        #expect(decoded.sources.last?.available == false)
    }

    @Test("WebView list response exposes provider as primary source")
    func webViewListPrimarySourcePrefersProvider() throws {
        let descriptor = webViewCandidate(id: "ios-provider:1", confidence: 0.98, area: 100)
        let response = TKWebViewListResponse(
            ok: true,
            action: "webview.list",
            platform: "ios",
            capturedAt: "2026-05-31T00:00:00Z",
            target: "triton:ios-simulator:demo",
            current: descriptor,
            candidates: [descriptor],
            sources: [
                TKWebViewSource(name: "runtime-tree", available: true, sourceCommands: ["triton runtimeSnapshot request"]),
                TKWebViewSource(name: "webview-provider", available: true, sourceCommands: ["triton webview list --json"]),
                TKWebViewSource(name: "host-layout", available: false, reason: "unsupported"),
            ],
            sourceCommands: ["triton webview list --json"],
            note: "provider-backed"
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TKWebViewListResponse.self, from: data)

        #expect(response.primarySource?.name == "webview-provider")
        #expect(decoded.primarySource?.name == "webview-provider")
        #expect(decoded.primarySource?.sourceCommands == ["triton webview list --json"])
    }

    @Test("WebView current response backfills primary source from legacy payload")
    func webViewCurrentBackfillsPrimarySourceFromLegacyPayload() throws {
        let payload = """
        {
          "ok": true,
          "action": "webview.current",
          "platform": "harmony",
          "capturedAt": "2026-05-31T00:00:00Z",
          "target": "127.0.0.1:10100",
          "webView": {
            "webViewID": "harmony:host:1",
            "platform": "harmony",
            "source": "host-layout",
            "candidateOnly": true,
            "confidence": 0.91,
            "providerStatus": "unavailable",
            "bridgeStatus": "unavailable",
            "capabilities": ["visible"],
            "missingCapabilities": ["webview.url"]
          },
          "sources": [
            { "name": "runtime-tree", "available": false, "reason": "runtime-base-url not provided", "sourceCommands": [] },
            { "name": "host-layout", "available": true, "sourceCommands": ["hdc dumpLayout"] },
            { "name": "webview-provider", "available": false, "reason": "provider not registered", "sourceCommands": [] }
          ],
          "sourceCommands": ["hdc dumpLayout"],
          "note": "legacy payload"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(TKWebViewCurrentResponse.self, from: payload)

        #expect(decoded.primarySource?.name == "host-layout")
        #expect(decoded.primarySource?.sourceCommands == ["hdc dumpLayout"])
    }

    @Test("WebView current selection returns stable error codes")
    func webViewCurrentSelectionErrors() throws {
        #expect(throws: TKWebViewSelectionError.self) {
            _ = try TKSelectCurrentWebView(from: [])
        }

        do {
            _ = try TKSelectCurrentWebView(from: [])
        } catch let error as TKWebViewSelectionError {
            #expect(error.detail.code == .webviewNotFound)
        }

        let first = webViewCandidate(id: "ios-runtime:1", confidence: 0.90, area: 100)
        let second = webViewCandidate(id: "ios-runtime:2", confidence: 0.87, area: 80)

        do {
            _ = try TKSelectCurrentWebView(from: [first, second])
        } catch let error as TKWebViewSelectionError {
            #expect(error.detail.code == .ambiguousWebView)
            #expect(error.detail.candidates?.map(\.webViewID) == ["ios-runtime:1", "ios-runtime:2"])
        }

        do {
            _ = try TKSelectCurrentWebView(from: [first], webViewID: "missing")
        } catch let error as TKWebViewSelectionError {
            #expect(error.detail.code == .webViewIDNotFound)
            #expect(error.detail.webViewID == "missing")
        }
    }

    @Test("WebView current selection can use explicit id")
    func webViewCurrentSelectionByID() throws {
        let first = webViewCandidate(id: "ios-runtime:1", confidence: 0.72, area: 80)
        let second = webViewCandidate(id: "ios-runtime:2", confidence: 0.72, area: 120)

        let selected = try TKSelectCurrentWebView(from: [first, second], webViewID: "ios-runtime:1")

        #expect(selected.webViewID == "ios-runtime:1")
    }

    @Test("WebView error response keeps candidates machine readable")
    func webViewErrorResponseShape() throws {
        let candidate = webViewCandidate(id: "ios-runtime:1", confidence: 0.91, area: 100)
        let response = TKWebViewErrorResponse(
            action: "webview.current",
            platform: "ios",
            target: "triton:ios-simulator:demo",
            error: TKCLIErrorDetail(
                code: TKWebViewErrorCode.ambiguousWebView.rawValue,
                message: "Multiple visible WebView candidates matched.",
                hint: "Run `triton webview list --json` and pass --webview-id."
            ),
            candidates: [candidate]
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TKWebViewErrorResponse.self, from: data)

        #expect(decoded.ok == false)
        #expect(decoded.error.code == "ambiguous_webview")
        #expect(decoded.candidates?.first?.webViewID == "ios-runtime:1")
    }

    @Test("WebView provider snapshot bridge and event DTOs round trip")
    func webViewProviderDTOShape() throws {
        let descriptor = webViewCandidate(id: "ios-runtime:1", confidence: 0.91, area: 100)
        let snapshot = TKWebViewSnapshotResponse(
            capturedAt: "2026-05-22T00:00:00Z",
            platform: "ios",
            target: "triton:ios-simulator:demo",
            webView: descriptor,
            include: ["metadata", "dom", "forms"],
            text: ["Checkout"],
            dom: [
                TKWebViewDOMNodeSummary(nodeID: "button-submit", role: "button", tagName: "button", text: "Submit", frame: TKRect(x: 10, y: 20, width: 120, height: 44)),
            ],
            forms: [
                TKWebViewFormFieldSummary(name: "password", inputType: "password", label: "Password", valueRedaction: "length-only", valueLength: 8),
            ],
            links: [],
            skipped: [
                TKRuntimeSnapshotSkipped(name: "iframes", reason: "cross-origin"),
            ],
            truncation: TKWebViewSnapshotTruncation(truncated: false),
            redaction: TKWebViewRedaction(secureText: "length-only")
        )

        let call = TKWebViewBridgeCallRequest(
            webViewID: "ios-runtime:1",
            pageSessionID: "page-1",
            method: "getRouteState",
            arguments: ["source": .string("test")],
            timeoutMs: 1_000
        )
        let callResponse = TKWebViewBridgeCallResponse(
            capturedAt: "2026-05-22T00:00:01Z",
            platform: "ios",
            target: "triton:ios-simulator:demo",
            webViewID: "ios-runtime:1",
            pageSessionID: "page-1",
            method: "getRouteState",
            result: .object(["route": .string("/checkout")]),
            elapsedMs: 12,
            redaction: TKWebViewRedaction()
        )
        let event = TKWebViewEvent(
            id: "event-1",
            timestamp: "2026-05-22T00:00:02Z",
            webViewID: "ios-runtime:1",
            pageSessionID: "page-1",
            name: "checkout.ready",
            payload: .object(["step": .string("payment")]),
            redaction: TKWebViewRedaction(),
            source: "page-bridge"
        )

        let snapshotData = try JSONEncoder().encode(snapshot)
        let callData = try JSONEncoder().encode(call)
        let callResponseData = try JSONEncoder().encode(callResponse)
        let eventData = try JSONEncoder().encode(event)

        #expect(try JSONDecoder().decode(TKWebViewSnapshotResponse.self, from: snapshotData).forms.first?.valueRedaction == "length-only")
        #expect(try JSONDecoder().decode(TKWebViewBridgeCallRequest.self, from: callData).method == "getRouteState")
        #expect(try JSONDecoder().decode(TKWebViewBridgeCallResponse.self, from: callResponseData).ok)
        #expect(try JSONDecoder().decode(TKWebViewEvent.self, from: eventData).name == "checkout.ready")
    }

    @Test("WebView descriptor exposes provider capability details")
    func webViewProviderCapabilityDetailsShape() throws {
        let descriptor = TKWebViewDescriptor(
            webViewID: "ios-webkit:42",
            platform: "ios",
            source: "webview-provider",
            nodeID: "ios-webkit:42",
            role: "webview",
            candidateOnly: false,
            confidence: 1,
            providerStatus: "available",
            bridgeStatus: "page-bridge-required",
            capabilities: ["webview.current-url", "webview.snapshot", "webview.events"],
            missingCapabilities: ["webview.dom-input", "webview.contenteditable-typing"],
            providerCapabilities: TKWebViewProviderCapabilities.iosRuntimeDefaults()
        )

        let data = try JSONEncoder().encode(descriptor)
        let decoded = try JSONDecoder().decode(TKWebViewDescriptor.self, from: data)

        #expect(decoded.providerCapabilities?.supportsCurrentURL.supported == true)
        #expect(decoded.providerCapabilities?.supportsSnapshot.supported == true)
        #expect(decoded.providerCapabilities?.supportsEvents.reason == "page bridge event buffer is available after bridge installation")
        #expect(decoded.providerCapabilities?.supportsBridgeCall.nextAction?.command == "webview")
        #expect(decoded.providerCapabilities?.supportsDOMInput.supported == false)
        #expect(decoded.providerCapabilities?.supportsDOMInput.reason == "generic DOM input is out of scope for the embedded iOS provider")
        #expect(decoded.providerCapabilities?.supportsDOMInput.nextAction?.args == ["snapshot", "--include", "metadata,text,dom,forms", "--json"])
        #expect(decoded.providerCapabilities?.supportsContentEditableTyping.supported == false)
    }

    @Test("WebView request types and Harmony runtime routes are stable")
    func webViewRequestTypesAndRoutes() throws {
        #expect(TKCLICommandRequest(type: "webViewList").requestType == .webViewList)
        #expect(TKCLICommandRequest(type: "webview.current").requestType == .webViewCurrent)
        #expect(TKCLICommandRequest(type: "webViewSnapshot").requestType == .webViewSnapshot)
        #expect(TKCLICommandRequest(type: "webViewBridgeCall").requestType == .webViewBridgeCall)
        #expect(TKCLICommandRequest(type: "webViewEvents").requestType == .webViewEvents)

        #expect(TKEmbeddedRuntimeHTTPRoute.route(for: .webViewList) == TKEmbeddedRuntimeHTTPRoute(method: .get, path: "/v2/runtime/webview/list"))
        #expect(TKEmbeddedRuntimeHTTPRoute.route(for: .webViewCurrent) == TKEmbeddedRuntimeHTTPRoute(method: .get, path: "/v2/runtime/webview/current"))
        #expect(TKEmbeddedRuntimeHTTPRoute.route(for: .webViewSnapshot) == TKEmbeddedRuntimeHTTPRoute(method: .post, path: "/v2/runtime/webview/snapshot"))
        #expect(TKEmbeddedRuntimeHTTPRoute.route(for: .webViewBridgeCall) == TKEmbeddedRuntimeHTTPRoute(method: .post, path: "/v2/runtime/webview/call"))
        #expect(TKEmbeddedRuntimeHTTPRoute.route(for: .webViewEvents) == TKEmbeddedRuntimeHTTPRoute(method: .get, path: "/v2/runtime/webview/events"))
    }

    private func webViewCandidate(id: String, confidence: Double, area: Double) -> TKWebViewDescriptor {
        TKWebViewDescriptor(
            webViewID: id,
            platform: "ios",
            source: "runtime-tree",
            nodeID: id,
            role: "web",
            frame: TKRect(x: 0, y: 0, width: area, height: 1),
            visibleRatio: 1,
            confidence: confidence,
            capabilities: ["visible"],
            missingCapabilities: ["webview.url", "webview.dom", "webview.bridge-call"]
        )
    }
}
