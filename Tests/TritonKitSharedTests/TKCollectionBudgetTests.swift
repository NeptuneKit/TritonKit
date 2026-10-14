import Foundation
import Testing
@testable import TritonKitShared

@Suite("Collection budgets")
struct TKCollectionBudgetTests {
    @Test func wideTraversalStopsBeforeReadingExtraNodes() {
        var budget = TKCollectionBudgetState(limits: .init(maxNodes: 3), startedAtUptime: 10)
        var reads = 0
        for _ in 0..<1_000 {
            guard budget.admit(depth: 0, nowUptime: 10) else { break }
            reads += 1
        }
        #expect(reads == 3)
        #expect(budget.summary.limitReasons == ["max_nodes"])
        #expect(budget.summary.partial)
    }

    @Test func depthWidthAndDeadlineAreIndependentLimits() {
        var budget = TKCollectionBudgetState(limits: .init(maxDepth: 2, maxChildren: 4, timeoutMilliseconds: 100), startedAtUptime: 10)
        let budgetResult1 = budget.admit(depth: 2, nowUptime: 10.01)
        #expect(budgetResult1)
        let budgetResult2 = !budget.admit(depth: 3, nowUptime: 10.01)
        #expect(budgetResult2)
        let budgetResult3 = budget.childCount(100) == 4
        #expect(budgetResult3)
        let budgetResult4 = !budget.admit(depth: 0, nowUptime: 10.101)
        #expect(budgetResult4)
        #expect(Set(budget.summary.limitReasons) == ["max_depth", "max_children", "deadline"])
        #expect(budget.summary.visitedNodes == 1)
    }

    @Test func limitsAreFiniteAndSummaryRoundTrips() throws {
        let limits = TKCollectionBudgetLimits(maxNodes: -1, maxDepth: -1, maxChildren: -1, timeoutMilliseconds: .infinity)
        #expect(limits.maxNodes == 1)
        #expect(limits.maxDepth == 0)
        #expect(limits.maxChildren == 1)
        #expect(limits.timeoutMilliseconds.isFinite)
        var budget = TKCollectionBudgetState(limits: limits, startedAtUptime: 10)
        let budgetResult5 = budget.admit(depth: 0, nowUptime: 10)
        #expect(budgetResult5)
        let budgetResult6 = !budget.admit(depth: 0, nowUptime: 10)
        #expect(budgetResult6)
        let decoded = try JSONDecoder().decode(TKCollectionBudgetSummary.self, from: JSONEncoder().encode(budget.summary))
        #expect(decoded == budget.summary)
    }
}
