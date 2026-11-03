import Foundation
import Testing
import TritonKit
@testable import TritonKitCLI

struct HierarchySceneImageSourceTests {
    @Test func viewIdentityAndLayerLayoutStaySeparate() {
        let item = TKDisplayItem(frame: CGRect(x: 0, y: 0, width: 120, height: 80),
            viewObject: .init(oid: 2, memoryAddress: "0x2", classChainList: ["UILabel", "UIView"]),
            layerObject: .init(oid: 3, memoryAddress: "0x3", classChainList: ["CALayer", "NSObject"]))
        let node = makeLegacyIosHierarchyScene(target: "fixture", displayItems: [item]).nodes.first
        #expect(node?.type == "UILabel")
        #expect(node?.view?.className == "UILabel")
        #expect(node?.layer != nil)
        #expect(node?.raw?.classHierarchy == ["UILabel", "UIView"])
    }

    @Test func zeroSizedStructuralLayerKeepsVisibleDescendant() {
        let child = TKDisplayItem(frame: CGRect(x: 10, y: 20, width: 30, height: 40),
            layerObject: .init(oid: 8, memoryAddress: "0x8", classChainList: ["CAShapeLayer", "CALayer"]), indentLevel: 1)
        let root = TKDisplayItem(subitems: [child], frame: .zero,
            layerObject: .init(oid: 7, memoryAddress: "0x7", classChainList: ["CALayer", "NSObject"]))
        let scene = makeLegacyIosHierarchyScene(target: "fixture", displayItems: [root])
        #expect(scene.nodes.count == 2)
        #expect(scene.nodes.first?.visible == false)
        #expect(scene.nodes.last?.visible == true)
        #expect(scene.nodes.last?.parentId == "ios:runtime:7")
        #expect(scene.nodes.allSatisfy { $0.view == nil })
    }

    @Test func groupOnlyNeverClaimsLayerOwnContents() throws {
        let item = TKDisplayItem(frame: CGRect(x: 0, y: 0, width: 20, height: 20),
            layerObject: .init(oid: 9, memoryAddress: "0x9", classChainList: ["CALayer"]))
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as? [String: Any])
        json["groupScreenshotRef"] = "group-only"
        let decoded = try JSONDecoder().decode(TKDisplayItem.self, from: JSONSerialization.data(withJSONObject: json))
        let node = try #require(makeLegacyIosHierarchyScene(target: "fixture", displayItems: [decoded]).nodes.first)
        #expect(node.slice?.mode == "group-screenshot-ref")
        #expect(node.visualSources?.count == 1)
        #expect(node.visualSources?.first?.kind == "subtreeSnapshot")
        #expect(node.visualSources?.first?.capturedBy == "CALayer.render")
    }
}
