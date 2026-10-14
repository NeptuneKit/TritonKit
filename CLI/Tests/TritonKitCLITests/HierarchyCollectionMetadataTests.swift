import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Hierarchy collection metadata")
struct HierarchyCollectionMetadataTests {
    // Given a budget-limited legacy payload, Then actual decoder and scene JSON
    // retain deadline and visited nodes rather than suggesting a complete tree.
    @Test func legacyNormalizationRetainsCollectionOnJSONRoundTrip() throws {
        let data = Data(#"{"displayItems":[],"collection":{"visitedNodes":4,"limitReasons":["deadline","max_nodes"]}}"#.utf8)
        let scene = try decodeLegacyIosHierarchyScene(data: data, target: "fixture")
        #expect(scene.collection?.visitedNodes == 4)
        #expect(scene.collection?.limitReasons == ["deadline", "max_nodes"])
        #expect(scene.collection?.partial == true)
        let decoded = try JSONDecoder().decode(TKHierarchyScene.self, from: JSONEncoder().encode(scene))
        #expect(decoded.collection == scene.collection)
    }

    // Given old payloads with no metadata, Then legacy and neutral scenes remain
    // decodable and do not fabricate collection success.
    @Test func legacyAndNeutralJSONWithoutCollectionRemainCompatible() throws {
        let scene = try decodeLegacyIosHierarchyScene(data: Data(#"{"displayItems":[]}"#.utf8), target: "fixture")
        #expect(scene.collection == nil)
        let neutral = Data(#"{"platform":"ios","rootId":"root","viewport":{"width":390,"height":844},"nodes":[]}"#.utf8)
        #expect(try JSONDecoder().decode(TKHierarchyScene.self, from: neutral).collection == nil)
    }

    @Test func observedHierarchyScenePreservesReadOnlyBudgetMetadata() {
        let summary = TKCollectionBudgetSummary(visitedNodes: 0, limitReasons: ["deadline"])
        let scene = makeHierarchyScene(platform: "android", target: "fixture", nodes: [], sourceCommands: [], collection: summary)
        #expect(scene.collection == summary)
    }
}
