import Foundation

/// Collection limits bound application traversal; they do not cancel a native IPC call.
public struct TKCollectionBudgetLimits: Codable, Equatable, Sendable {
    public let maxNodes: Int
    public let maxDepth: Int
    public let maxChildren: Int
    public let timeoutMilliseconds: Double

    public init(maxNodes: Int = 800, maxDepth: Int = 64, maxChildren: Int = 200, timeoutMilliseconds: Double = 2_000) {
        self.maxNodes = min(10_000, max(1, maxNodes))
        self.maxDepth = min(128, max(0, maxDepth))
        self.maxChildren = min(1_000, max(1, maxChildren))
        self.timeoutMilliseconds = timeoutMilliseconds.isFinite ? min(30_000, max(1, timeoutMilliseconds)) : 2_000
    }
    private enum CodingKeys: String, CodingKey { case maxNodes, maxDepth, maxChildren, timeoutMilliseconds }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(maxNodes: try c.decodeIfPresent(Int.self, forKey: .maxNodes) ?? 800,
            maxDepth: try c.decodeIfPresent(Int.self, forKey: .maxDepth) ?? 64,
            maxChildren: try c.decodeIfPresent(Int.self, forKey: .maxChildren) ?? 200,
            timeoutMilliseconds: try c.decodeIfPresent(Double.self, forKey: .timeoutMilliseconds) ?? 2_000)
    }

}

public struct TKCollectionBudgetSummary: Codable, Equatable, Sendable {
    public let visitedNodes: Int
    public let limitReasons: [String]
    public var partial: Bool { !limitReasons.isEmpty }

    public init(visitedNodes: Int, limitReasons: [String]) {
        self.visitedNodes = visitedNodes
        self.limitReasons = limitReasons
    }
}

public struct TKCollectionBudgetState {
    public let limits: TKCollectionBudgetLimits
    private let deadline: Double
    private var visitedNodes = 0
    private var reasons: [String] = []

    public init(limits: TKCollectionBudgetLimits = .init(), startedAtUptime: Double = ProcessInfo.processInfo.systemUptime) {
        self.limits = limits
        self.deadline = startedAtUptime + limits.timeoutMilliseconds / 1_000
    }

    public mutating func admit(depth: Int, nowUptime: Double = ProcessInfo.processInfo.systemUptime) -> Bool {
        guard !isExhausted(nowUptime: nowUptime) else { return false }
        guard depth <= limits.maxDepth else { recordLimit("max_depth"); return false }
        visitedNodes += 1
        return true
    }

    public mutating func isExhausted(nowUptime: Double = ProcessInfo.processInfo.systemUptime) -> Bool {
        if !nowUptime.isFinite || nowUptime >= deadline { recordLimit("deadline"); return true }
        if visitedNodes >= limits.maxNodes { recordLimit("max_nodes"); return true }
        return false
    }

    public mutating func childCount(_ count: Int) -> Int {
        if count > limits.maxChildren { recordLimit("max_children") }
        return min(max(0, count), limits.maxChildren)
    }

    public mutating func recordLimit(_ reason: String) {
        if !reasons.contains(reason) { reasons.append(reason) }
    }

    public var summary: TKCollectionBudgetSummary { .init(visitedNodes: visitedNodes, limitReasons: reasons) }
}

public struct TKBoundedNodeCollection<Node> {
    public let nodes: [Node]
    public let collection: TKCollectionBudgetSummary

    public init(nodes: [Node], collection: TKCollectionBudgetSummary) {
        self.nodes = nodes
        self.collection = collection
    }
}

public enum TKCollectionInputError: Error {
    case inputTooLarge
}
