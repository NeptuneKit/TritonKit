import Foundation
import Testing
@testable import TritonKitShared

@Suite
struct TKWaitModelsTests {
    @Test("wait result reports timeout and last observed hierarchy state")
    func waitResultShape() throws {
        let result = TKWaitResult(
            ok: false,
            matched: false,
            condition: "text",
            query: "我的",
            role: "button",
            timedOut: true,
            elapsedMs: 15010,
            pollCount: 31,
            timeoutSeconds: 15,
            intervalSeconds: 0.5,
            targetConnectionState: "connected",
            hierarchyCacheState: "active",
            lastObservedNodeCount: 4,
            lastObservedTextSample: ["登录", "首页"],
            lastObservedHierarchyHash: "abc123"
        )

        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(TKWaitResult.self, from: data)

        #expect(decoded.ok == false)
        #expect(decoded.timedOut)
        #expect(decoded.condition == "text")
        #expect(decoded.query == "我的")
        #expect(decoded.role == "button")
        #expect(decoded.elapsedMs == 15010)
        #expect(decoded.pollCount == 31)
        #expect(decoded.targetConnectionState == "connected")
        #expect(decoded.hierarchyCacheState == "active")
        #expect(decoded.lastObservedTextSample == ["登录", "首页"])
    }

    @Test("text matching ignores hidden nodes and supports role filters")
    func textMatching() {
        let nodes = [
            TKAXNode(
                role: "button",
                label: "我的",
                value: nil,
                identifier: "profile-tab",
                title: nil,
                frame: TKRect(x: 10, y: 20, width: 80, height: 44),
                enabled: true,
                focused: false,
                hidden: false,
                targetOID: 10,
                className: "UIButton",
                children: []
            ),
            TKAXNode(
                role: "text",
                label: "登录",
                value: nil,
                identifier: nil,
                title: nil,
                frame: TKRect(x: 0, y: 0, width: 10, height: 10),
                enabled: true,
                focused: false,
                hidden: true,
                targetOID: 11,
                className: "UILabel",
                children: []
            ),
            TKAXNode(
                role: "container",
                label: nil,
                value: nil,
                identifier: nil,
                title: nil,
                frame: TKRect(x: 0, y: 0, width: 10, height: 10),
                enabled: true,
                focused: false,
                hidden: true,
                targetOID: 12,
                className: "UIView",
                children: [
                    TKAXNode(
                        role: "text",
                        label: "隐藏子节点",
                        value: nil,
                        identifier: nil,
                        title: nil,
                        frame: TKRect(x: 0, y: 0, width: 10, height: 10),
                        enabled: true,
                        focused: false,
                        hidden: false,
                        targetOID: 13,
                        className: "UILabel",
                        children: []
                    ),
                ]
            ),
        ]

        let match = TKWaitFindTextMatch(in: nodes, query: "我的", role: "button")
        #expect(match?.text == "我的")
        #expect(match?.source == "label")
        #expect(match?.targetOID == 10)
        #expect(TKWaitFindTextMatch(in: nodes, query: "我的", role: "text") == nil)
        #expect(TKWaitFindTextMatch(in: nodes, query: "登录") == nil)
        #expect(TKWaitFindTextMatch(in: nodes, query: "隐藏子节点") == nil)
    }

    @Test("wait text matching shares trim, case, diacritic, and substring normalization with observe/find")
    func waitTextMatchingSharesNormalization() {
        let nodes = [
            TKAXNode(
                role: "button",
                label: "登录",
                value: nil,
                identifier: nil,
                title: nil,
                frame: TKRect(x: 10, y: 20, width: 80, height: 44),
                enabled: true,
                focused: false,
                hidden: false,
                targetOID: 20,
                className: "UIButton",
                children: []
            ),
            TKAXNode(
                role: "text",
                label: "Complex harness: 1",
                value: nil,
                identifier: nil,
                title: nil,
                frame: TKRect(x: 10, y: 80, width: 200, height: 24),
                enabled: true,
                focused: false,
                hidden: false,
                targetOID: 21,
                className: "UILabel",
                children: []
            ),
            TKAXNode(
                role: "text",
                label: "Café",
                value: nil,
                identifier: nil,
                title: nil,
                frame: TKRect(x: 10, y: 120, width: 80, height: 24),
                enabled: true,
                focused: false,
                hidden: false,
                targetOID: 22,
                className: "UILabel",
                children: []
            ),
            TKAXNode(
                role: "button",
                label: "Settings",
                value: nil,
                identifier: nil,
                title: nil,
                frame: TKRect(x: 10, y: 160, width: 120, height: 44),
                enabled: true,
                focused: false,
                hidden: false,
                targetOID: 23,
                className: "UIButton",
                children: []
            ),
        ]

        // whitespace-trimmed query
        #expect(TKWaitFindTextMatch(in: nodes, query: " 登录 ")?.targetOID == 20)
        // substring query against a longer visible label
        #expect(TKWaitFindTextMatch(in: nodes, query: "harness")?.targetOID == 21)
        // case-insensitive
        #expect(TKWaitFindTextMatch(in: nodes, query: "SETTINGS")?.targetOID == 23)
        // diacritic-insensitive
        #expect(TKWaitFindTextMatch(in: nodes, query: "cafe")?.targetOID == 22)
    }

    @Test("predicate supports exists gone boolean operators and negation")
    func predicateEvaluation() throws {
        let nodes = [
            TKAXNode(
                role: "button",
                label: "console",
                value: nil,
                identifier: nil,
                title: nil,
                frame: TKRect(x: 0, y: 0, width: 10, height: 10),
                enabled: true,
                focused: false,
                hidden: false,
                targetOID: nil,
                className: "UIButton",
                children: []
            ),
        ]

        #expect(try TKWaitEvaluatePredicate(#"text.exists("console")"#, nodes: nodes))
        #expect(try TKWaitEvaluatePredicate(#"text.exists("console") && !text.exists("登录")"#, nodes: nodes))
        #expect(try TKWaitEvaluatePredicate(#"text.gone("登录") && exists("console")"#, nodes: nodes))
        #expect(try TKWaitEvaluatePredicate(#"gone("登录") || exists("nope")"#, nodes: nodes))
        #expect(try !TKWaitEvaluatePredicate(#"text.exists("登录")"#, nodes: nodes))
        #expect(throws: TKWaitPredicateError.self) {
            try TKWaitEvaluatePredicate(#"text.exists("console")@"#, nodes: nodes)
        }
    }
}
