import ArgumentParser
import Foundation
import Testing
import TritonKit
import TritonKitShared
@testable import TritonKitCLI

@Suite(.serialized) struct HierarchyDetailsCommandTests {
    @Test func detailsCommandIsReachableUnderDebug() throws {
        let command = try TritonKitCLI.parseAsRoot(["debug", "details", "--oid", "21", "--oid", "22", "--screenshots", "solo", "--no-include-attributes", "--max-pixel-count", "4096", "--json"])
        #expect(String(describing: type(of: command)) == "HierarchyDetails")
    }

    @Test func detailsSchemaHasOutputAndExplicitEffect() throws {
        let schema = try #require(commandSchemas().first { $0.name == "debug" })
        let details = try #require(schema.subcommands.first { $0.name == "details" })
        #expect(details.requiredOptions == ["--oid"])
        #expect(details.sideEffect == "temporary_layer_visibility_for_capture")
        #expect(details.outputSelectors == ["hierarchy.details"])
        #expect(schema.outputContracts.contains { $0.selector == "hierarchy.details" })
    }

    @Test func soloAndGroupRemainDistinctInScene() throws {
        let layer = TKDisplayItem(frame: CGRect(x: 4, y: 5, width: 100, height: 60),
            bounds: CGRect(x: 0, y: 0, width: 100, height: 60),
            screenshotRef: "legacy-group",
            layerObject: TKObject(oid: 7, memoryAddress: "0x7", classChainList: ["CALayer", "NSObject"]), indentLevel: 1)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(layer)) as? [String: Any])
        object["soloScreenshotRef"] = "solo-reference"
        object["groupScreenshotRef"] = "group-reference"
        let decoded = try JSONDecoder().decode(TKDisplayItem.self, from: JSONSerialization.data(withJSONObject: object))
        let scene = makeLegacyIosHierarchyScene(target: "fixture", displayItems: [decoded])
        let node = try #require(scene.nodes.first)
        #expect(node.id == "ios:runtime:7")
        #expect(node.type == "CALayer")
        #expect(node.slice?.mode == "solo-screenshot-ref")
        #expect(node.slice?.dataRef == "solo-reference")
        #expect(node.visualSources?.first { $0.kind == "layerOwnContents" }?.dataRef == "solo-reference")
        #expect(node.visualSources?.first { $0.kind == "subtreeSnapshot" }?.dataRef == "group-reference")
    }
}
