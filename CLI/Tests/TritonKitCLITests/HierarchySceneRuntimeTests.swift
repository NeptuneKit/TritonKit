import ArgumentParser
import CoreGraphics
import Foundation
import Testing
import TritonKit
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct HierarchySceneRuntimeTests {
    @Test("hierarchy command accepts platform scene mode without changing legacy default")
    func hierarchyCommandAcceptsPlatformSceneMode() throws {
        let legacy = try Hierarchy.parse(["--json"])
        #expect(legacy.platform == nil)
        #expect(legacy.target == TKLocalTargetID)

        let android = try Hierarchy.parse(["--platform", "android", "--device", "emulator-5554", "--json"])
        #expect(android.platform == .android)
        #expect(android.device == "emulator-5554")
        #expect(android.json)

        let androidAutoTarget = try Hierarchy.parse(["--platform", "android", "--json"])
        #expect(androidAutoTarget.platform == .android)
        #expect(androidAutoTarget.device == nil)
        #expect(androidAutoTarget.target == TKLocalTargetID)
    }

    @Test("observable nodes convert to platform-neutral hierarchy scene")
    func observableNodesConvertToHierarchyScene() {
        let nodes = [
            ObserveNodeOutput(
                nodeID: "ios-runtime:1",
                source: "runtime-tree",
                role: "window",
                text: nil,
                identifier: "root",
                frame: TKRect(x: 0, y: 0, width: 390, height: 844),
                enabled: true,
                focused: false,
                hidden: false,
                candidateOnly: false,
                confidence: 0.9,
                capabilities: ["visible"],
                missingCapabilities: []
            ),
            ObserveNodeOutput(
                nodeID: "ios-runtime:2",
                source: "runtime-tree",
                role: "button",
                text: "Continue",
                identifier: "continueButton",
                frame: TKRect(x: 24, y: 120, width: 342, height: 56),
                enabled: true,
                focused: false,
                hidden: false,
                candidateOnly: false,
                confidence: 0.9,
                capabilities: ["visible", "tap"],
                missingCapabilities: []
            ),
        ]

        let scene = makeHierarchyScene(
            platform: "ios",
            target: "triton:local",
            nodes: nodes,
            sourceCommands: ["triton runtimeSnapshot request"]
        )

        #expect(scene.platform == "ios")
        #expect(scene.rootId == "ios-runtime:1")
        #expect(scene.viewport.width == 390)
        #expect(scene.viewport.height == 844)
        #expect(scene.nodes.map(\.id) == ["ios-runtime:1", "ios-runtime:2"])
        #expect(scene.nodes[1].parentId == "ios-runtime:1")
        #expect(scene.nodes[1].type == "button")
        #expect(scene.nodes[1].name == "Continue")
        #expect(scene.nodes[1].interactive)
        #expect(scene.nodes[1].style?.display == "button")
        #expect(scene.nodes[1].style?.text == "Continue")
        #expect(scene.nodes[1].renderHints?.preferredMode == "style")
        #expect(scene.nodes[1].renderHints?.fallbackMode == "wireframe")
        #expect(scene.nodes[1].renderHints?.quality == "approximate")
    }

    @Test("legacy iOS display items convert to Lookin-style hierarchy scene slices")
    func legacyIOSDisplayItemsConvertToLookinHierarchySceneSlices() {
        let button = TKDisplayItem(
            subitems: [],
            isHidden: false,
            alpha: 1,
            frame: CGRect(x: 24, y: 132, width: 342, height: 58),
            bounds: CGRect(x: 0, y: 0, width: 342, height: 58),
            screenshotRef: "11111111-1111-1111-1111-111111111111",
            viewObject: TKObject(oid: 38, memoryAddress: "0x38", classChainList: ["UIButtonLabel", "UILabel", "UIView"]),
            layerObject: TKObject(oid: 39, memoryAddress: "0x39", classChainList: ["UIButtonLabel", "UILabel", "UIView"]),
            hostViewControllerObject: TKObject(oid: 88, memoryAddress: "0x88", classChainList: ["Demo.ProfileViewController", "UIViewController"]),
            backgroundColor: TKColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1),
            layerPosition: CGPoint(x: 195, y: 161),
            layerAnchorPoint: CGPoint(x: 0.5, y: 0.5),
            layerZPosition: 4,
            layerTransform: [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 12, 0, 0, 1],
            layerMasksToBounds: true,
            layerCornerRadius: 14,
            layerOpacity: 0.85,
            layerIsHidden: false,
            layerContentsScale: 3,
            layerContentsGravity: "resizeAspect",
            layerContentsRect: CGRect(x: 0, y: 0, width: 1, height: 1),
            layerBorderWidth: 1,
            layerBorderColor: TKColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1),
            layerShadowOpacity: 0.2,
            layerShadowRadius: 8,
            layerShadowOffset: CGSize(width: 0, height: 4),
            layerShadowColor: TKColor(red: 0, green: 0, blue: 0, alpha: 0.3),
            customDisplayTitle: "Continue",
            indentLevel: 1
        )
        let root = TKDisplayItem(
            subitems: [button],
            isHidden: false,
            alpha: 1,
            frame: CGRect(x: 0, y: 0, width: 402, height: 874),
            bounds: CGRect(x: 0, y: 0, width: 402, height: 874),
            viewObject: TKObject(oid: 2, memoryAddress: "0x2", classChainList: ["UIWindow", "UIView"]),
            layerObject: TKObject(oid: 3, memoryAddress: "0x3", classChainList: ["UIWindow", "UIView"]),
            representedAsKeyWindow: true,
            indentLevel: 0
        )

        let scene = makeLegacyIosHierarchyScene(target: "triton:local", displayItems: [root])

        #expect(scene.platform == "ios")
        #expect(scene.viewport.width == 402)
        #expect(scene.viewport.height == 874)
        #expect(scene.nodes.count == 3)
        let controller = scene.nodes[1]
        #expect(controller.id == "ios:controller:88")
        #expect(controller.parentId == scene.nodes[0].id)
        #expect(controller.type == "Demo.ProfileViewController")
        #expect(controller.name == "ProfileViewController#88")
        #expect(controller.raw?.role == "UIViewController")
        #expect(controller.style?.display == "controller")
        #expect(controller.renderHints?.preferredMode == "structure")
        #expect(scene.controllerContext?.activeControllerId == "ios:controller:88")
        #expect(scene.controllerContext?.activeControllerName == "ProfileViewController")
        #expect(scene.controllerContext?.source == "scene-controller-node-fallback")

        let convertedButton = scene.nodes[2]
        #expect(convertedButton.parentId == controller.id)
        #expect(convertedButton.type == "UIButtonLabel")
        #expect(convertedButton.name == "Continue")
        #expect(convertedButton.style?.text == "Continue")
        #expect(convertedButton.style?.backgroundColor == "#1a334d")
        #expect(convertedButton.slice?.available == true)
        #expect(convertedButton.slice?.mode == "node-screenshot-ref")
        #expect(convertedButton.slice?.dataRef == "11111111-1111-1111-1111-111111111111")
        #expect(convertedButton.visualSources?.count == 1)
        #expect(convertedButton.visualSources?.first?.kind == "subtreeSnapshot")
        #expect(convertedButton.visualSources?.first?.dataRef == "11111111-1111-1111-1111-111111111111")
        #expect(convertedButton.visualSources?.first?.capturedBy == "UIView.render")
        #expect(convertedButton.view?.className == "UIButtonLabel")
        #expect(convertedButton.view?.accessibilityLabel == "Continue")
        #expect(convertedButton.layer?.bounds.width == 342)
        #expect(convertedButton.layer?.position.x == 195)
        #expect(convertedButton.layer?.anchorPoint.x == 0.5)
        #expect(convertedButton.layer?.zPosition == 4)
        #expect(convertedButton.layer?.masksToBounds == true)
        #expect(convertedButton.layer?.cornerRadius == 14)
        #expect(abs((convertedButton.layer?.opacity ?? 0) - 0.85) < 0.0001)
        #expect(convertedButton.layer?.contentsScale == 3)
        #expect(convertedButton.layer?.contentsGravity == "resizeAspect")
        #expect(convertedButton.layer?.contentsRect?.width == 1)
        #expect(convertedButton.layer?.borderWidth == 1)
        #expect(abs((convertedButton.layer?.shadowOpacity ?? 0) - 0.2) < 0.0001)
        #expect(convertedButton.layer?.shadowRadius == 8)
        #expect(convertedButton.layer?.shadowOffset?.height == 4)
        #expect(convertedButton.layer?.borderColor == "#808080")
        #expect(convertedButton.layer?.shadowColor == "#000000")
        #expect(convertedButton.renderHints?.preferredMode == "slice")
        #expect(convertedButton.renderHints?.quality == "exact")
    }
}
