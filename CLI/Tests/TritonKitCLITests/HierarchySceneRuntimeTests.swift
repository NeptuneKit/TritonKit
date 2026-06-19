import ArgumentParser
import Foundation
import Testing
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
    }
}
