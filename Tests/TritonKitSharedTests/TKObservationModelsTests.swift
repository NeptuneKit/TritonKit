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
}
