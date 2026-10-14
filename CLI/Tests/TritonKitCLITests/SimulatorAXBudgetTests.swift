import Foundation
import Testing
@testable import TritonKitCLI

@Suite
struct SimulatorAXBudgetTests {
    private final class Fixture {
        let id: Int
        var children: [Fixture]
        init(_ id: Int, _ children: [Fixture] = []) {
            self.id = id
            self.children = children
        }
    }

    @Test("node budget bounds preparation and attribute reads, not only output")
    func nodeBudgetBoundsActualVisits() {
        let root = Fixture(0, (1...100).map { Fixture($0) })
        var stamped: [Int] = []
        var read: [Int] = []
        var childReads: [Int] = []
        let collector = CLIObservationTreeCollector(budget: .init(maxNodes: 3, maxDepth: 10, maxChildren: 200, timeoutSeconds: 2))
        let tree = collector.collect(root, prepare: { stamped.append($0.id) }, read: {
            read.append($0.id)
            return $0.id
        }, children: {
            childReads.append($0.id)
            return $0.children
        })
        #expect(tree?.children.map(\.value) == [1, 2])
        #expect(stamped == [0, 1, 2])
        #expect(read == stamped)
        #expect(childReads == [0, 1, 2])
        #expect(collector.summary.visitedNodes == 3)
        #expect(collector.summary.limitReasons == ["max_nodes"])
        #expect(collector.summary.partial)
    }

    @Test("width and depth bounds prevent touching rejected descendants")
    func widthAndDepthBounds() {
        let root = Fixture(0, [Fixture(1, [Fixture(3)]), Fixture(2), Fixture(4)])
        var reads: [Int] = []
        var childReads: [Int] = []
        let collector = CLIObservationTreeCollector(budget: .init(maxNodes: 100, maxDepth: 1, maxChildren: 2, timeoutSeconds: 2))
        let tree = collector.collect(root, prepare: { _ in }, read: {
            reads.append($0.id)
            return $0.id
        }, children: {
            childReads.append($0.id)
            return $0.children
        })
        #expect(tree?.children.map(\.value) == [1, 2])
        #expect(reads == [0, 1, 2])
        #expect(childReads == [0])
        #expect(collector.summary.limitReasons == ["max_depth", "max_children"])
    }

    @Test("deadline stops before prepare and property calls, including preprocessing")
    func deadlineBoundsEveryStage() {
        var time = 0.0
        var prepared: [Int] = []
        var read: [Int] = []
        var childReads = 0
        let collector = CLIObservationTreeCollector(
            budget: .init(maxNodes: 100, maxDepth: 10, maxChildren: 100, timeoutSeconds: 1),
            now: { time }
        )
        let result = collector.collect(Fixture(0, [Fixture(1)]), prepare: {
            prepared.append($0.id)
            time = 1
        }, read: {
            read.append($0.id)
            return $0.id
        }, children: {
            childReads += 1
            return $0.children
        })
        #expect(result == nil)
        #expect(prepared == [0])
        #expect(read.isEmpty)
        #expect(childReads == 0)
        #expect(collector.summary.limitReasons == ["deadline"])
    }

    @Test("expired budgets perform no native-like reads")
    func expiredBudgetDoesNotTouchTree() {
        var touched = 0
        let collector = CLIObservationTreeCollector(budget: .init(timeoutSeconds: 0))
        let result = collector.collect(Fixture(0), prepare: { _ in touched += 1 }, read: { $0.id }, children: { $0.children })
        #expect(result == nil)
        #expect(touched == 0)
        #expect(collector.summary.visitedNodes == 0)
        #expect(collector.summary.limitReasons == ["deadline"])
    }

    @Test("complete small trees report no truncation and count exactly once")
    func completeTree() {
        let collector = CLIObservationTreeCollector(budget: .init(maxNodes: 3, maxDepth: 10, maxChildren: 10))
        let result = collector.collect(Fixture(0, [Fixture(1), Fixture(2)]), prepare: { _ in }, read: { $0.id }, children: { $0.children })
        #expect(result?.children.count == 2)
        #expect(collector.summary.visitedNodes == 3)
        #expect(!collector.summary.partial)
        #expect(collector.summary.limitReasons.isEmpty)
    }

    @Test("slow attribute calls prevent later attributes and children calls")
    func slowAttributeBoundsFollowingCalls() {
        var time = 0.0
        var attributes = 0
        var children = 0
        let collector = CLIObservationTreeCollector(budget: .init(timeoutSeconds: 1), now: { time })
        let result = collector.collect(Fixture(0), prepare: { _ in }, read: { node in
            _ = collector.readIfWithinDeadline { attributes += 1; time = 1 }
            _ = collector.readIfWithinDeadline { attributes += 1 }
            return node.id
        }, children: {
            children += 1
            return $0.children
        })
        #expect(result?.value == 0)
        #expect(attributes == 1)
        #expect(children == 0)
        #expect(collector.summary.limitReasons == ["deadline"])
    }
}
