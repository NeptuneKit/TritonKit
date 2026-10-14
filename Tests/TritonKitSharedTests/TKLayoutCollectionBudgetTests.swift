import Foundation
import Testing
@testable import TritonKitShared

@Suite("Layout collection budgets")
struct TKLayoutCollectionBudgetTests {
    @Test func harmonyStopsDuringTraversal() throws {
        let children = (0..<100).map { ["attributes": ["text": "n\($0)"]] }
        let data = try JSONSerialization.data(withJSONObject: ["attributes": ["text": "root"], "children": children])
        let result = try TKHarmonyLayoutParser.nodeSummaries(in: data, budget: .init(maxNodes: 3))
        #expect(result.nodes.count == 3)
        #expect(result.collection.visitedNodes == 3)
        #expect(result.collection.limitReasons.contains("max_nodes"))
    }

    @Test func xmlBudgetAbortReturnsPartialButMalformedXMLThrows() throws {
        let xml = "<hierarchy>" + String(repeating: "<node text=\"row\"/>", count: 100) + "</hierarchy>"
        let result = try TKAndroidUIAutomatorXMLParser.nodeSummaries(in: Data(xml.utf8), budget: .init(maxNodes: 2))
        #expect(result.nodes.count == 2)
        #expect(result.collection.partial)
        #expect(throws: (any Error).self) {
            try TKAndroidUIAutomatorXMLParser.nodeSummaries(in: Data("<hierarchy><node></hierarchy>".utf8), budget: .init())
        }
    }

    @Test func widthDepthAndInputBytesAreBounded() throws {
        let xml = "<hierarchy><node text=\"root\"><node text=\"child\"><node text=\"deep\"/></node><node text=\"sibling\"/></node></hierarchy>"
        let result = try TKAndroidUIAutomatorXMLParser.nodeSummaries(in: Data(xml.utf8), budget: .init(maxDepth: 0, maxChildren: 1))
        #expect(result.nodes.map(\.text) == ["root"])
        #expect(result.collection.limitReasons.contains("max_depth"))
        #expect(throws: TKCollectionInputError.self) {
            try TKHarmonyLayoutParser.nodeSummaries(in: Data(repeating: 32, count: 10 * 1_024 * 1_024 + 1), budget: .init())
        }
    }
}
