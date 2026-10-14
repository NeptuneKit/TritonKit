import Foundation
import Testing
@testable import TritonKit
import TritonKitShared

@Suite("Runtime hierarchy collection contract")
struct TKRuntimeCollectionBudgetTests {
    @Test func collectionSummarySurvivesHierarchyEncoding() throws {
        let info = TKHierarchyInfo(displayItems: [], collection: .init(visitedNodes: 4, limitReasons: ["deadline"]))
        let decoded = try JSONDecoder().decode(TKHierarchyInfo.self, from: JSONEncoder().encode(info))
        #expect(decoded.collection == info.collection)
        #expect(decoded.collection?.partial == true)
    }
}

#if canImport(UIKit)
import UIKit
extension TKUIKitWindowTests {
    @Suite(.serialized)
    @MainActor
    struct TKRuntimeAXCollectionBudgetTests {
        @Test func nonSemanticViewsAlsoConsumeTraversalBudget() {
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
            window.isHidden = false
            defer { window.isHidden = true }
            let root = UIView(frame: window.bounds)
            window.addSubview(root)
            for _ in 0..<100 { root.addSubview(UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))) }
            var context = AXBuildContext(maxNodes: 3)
            _ = collectAXLeafNodes(from: root, in: window, context: &context)
            #expect(context.collection.summary.visitedNodes == 3)
            #expect(context.collection.summary.limitReasons.contains("max_nodes"))
        }
    }
}
#endif
