import Foundation
import Testing
@testable import TritonKitShared

@Suite
struct TKHierarchySceneModelsTests {
    @Test("hierarchy scene response preserves Lookin-style layer metadata")
    func hierarchySceneResponseShape() throws {
        let scene = TKHierarchyScene(
            platform: "ios",
            rootId: "root",
            viewport: TKHierarchyViewport(width: 390, height: 844),
            nodes: [
                TKHierarchyLayerNode(
                    id: "root",
                    parentId: nil,
                    type: "UIWindow",
                    name: "keyWindow",
                    frame: TKRect(x: 0, y: 0, width: 390, height: 844),
                    depth: 0,
                    visible: true,
                    interactive: false,
                    color: "#6ea8ff",
                    source: "runtime-tree"
                ),
                TKHierarchyLayerNode(
                    id: "button",
                    parentId: "root",
                    type: "UIButton",
                    name: "Continue",
                    frame: TKRect(x: 24, y: 120, width: 342, height: 56),
                    depth: 1,
                    visible: true,
                    interactive: true,
                    color: "#fb7185",
                    source: "runtime-tree"
                ),
            ],
            controllerContext: TKHierarchyControllerContext(
                activeControllerId: "ios:controller:88",
                activeControllerName: "ProfileViewController",
                activeControllerClassName: "Demo.ProfileViewController",
                stack: [
                    TKHierarchyControllerEntry(
                        id: "ios:controller:12",
                        oid: 12,
                        className: "Demo.MainTabBarController",
                        name: "MainTabBarController"
                    ),
                    TKHierarchyControllerEntry(
                        id: "ios:controller:88",
                        oid: 88,
                        className: "Demo.ProfileViewController",
                        name: "ProfileViewController",
                        title: "Profile"
                    ),
                ],
                source: "runtime-route"
            )
        )
        let response = TKHostHierarchyResponse(
            ok: true,
            capturedAt: "2026-06-19T00:00:00Z",
            source: TKHierarchySourceInfo(
                command: "triton hierarchy --platform ios --target triton:local --json",
                runtimeScope: "embedded",
                readonly: true
            ),
            scene: scene
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TKHostHierarchyResponse.self, from: data)

        #expect(decoded.ok)
        #expect(decoded.scene.platform == "ios")
        #expect(decoded.scene.viewport.width == 390)
        #expect(decoded.scene.nodes.count == 2)
        #expect(decoded.scene.nodes[1].parentId == "root")
        #expect(decoded.scene.nodes[1].interactive)
        #expect(decoded.scene.controllerContext?.activeControllerId == "ios:controller:88")
        #expect(decoded.scene.controllerContext?.activeControllerName == "ProfileViewController")
        #expect(decoded.scene.controllerContext?.stack.map(\.name) == ["MainTabBarController", "ProfileViewController"])
        #expect(decoded.source.readonly)
    }
}
