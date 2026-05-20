import Foundation
import Testing
@testable import TritonKitShared

@Suite
struct TKUIAssertionModelsTests {
    @Test("text exists assertion returns matches and freshness")
    func textExists() {
        let result = TKUIAssertEvaluate(
            TKUIAssertRequest(condition: .textExists, query: "Macau", role: "text"),
            nodes: assertionNodes(),
            targetConnectionState: "connected",
            hierarchyCacheState: "active"
        )

        #expect(result.ok)
        #expect(result.count == 1)
        #expect(result.matches.first?.text == "Macau")
        #expect(result.targetConnectionState == "connected")
        #expect(result.hierarchyCacheState == "active")
    }

    @Test("text not exists can be scoped to bounds")
    func textNotExistsWithinBounds() {
        let result = TKUIAssertEvaluate(
            TKUIAssertRequest(
                condition: .textNotExists,
                query: "Qinghai",
                within: TKRect(x: 180, y: 0, width: 200, height: 500)
            ),
            nodes: assertionNodes()
        )

        #expect(result.ok)
        #expect(result.count == 0)
    }

    @Test("count assertion fails on repeated text")
    func countAssertion() {
        let result = TKUIAssertEvaluate(
            TKUIAssertRequest(condition: .textExists, query: "Macau", count: 1),
            nodes: assertionNodesWithDuplicateMacau()
        )

        #expect(!result.ok)
        #expect(result.count == 2)
        #expect(result.message?.contains("Expected 1") == true)
    }

    private func assertionNodes() -> [TKAXNode] {
        [
            TKAXNode(
                role: "text",
                label: "Macau",
                value: nil,
                identifier: nil,
                title: nil,
                frame: TKRect(x: 20, y: 120, width: 80, height: 36),
                enabled: true,
                focused: false,
                hidden: false,
                targetOID: 1,
                className: "UILabel",
                children: []
            ),
            TKAXNode(
                role: "text",
                label: "Qinghai",
                value: nil,
                identifier: nil,
                title: nil,
                frame: TKRect(x: 20, y: 180, width: 80, height: 36),
                enabled: true,
                focused: false,
                hidden: false,
                targetOID: 2,
                className: "UILabel",
                children: []
            ),
        ]
    }

    private func assertionNodesWithDuplicateMacau() -> [TKAXNode] {
        assertionNodes() + [
            TKAXNode(
                role: "button",
                label: "Macau",
                value: nil,
                identifier: nil,
                title: nil,
                frame: TKRect(x: 200, y: 120, width: 80, height: 36),
                enabled: true,
                focused: false,
                hidden: false,
                targetOID: 3,
                className: "UIButton",
                children: []
            ),
        ]
    }
}
