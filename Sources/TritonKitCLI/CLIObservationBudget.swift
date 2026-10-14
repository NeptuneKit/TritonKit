import Foundation

/// Host-side work limits. A native children/property call may itself block or
/// materialize a full array; these bounds govern calls and traversal, not native IPC cancellation.
struct CLIObservationBudget: Equatable, Sendable {
    let maxNodes: Int
    let maxDepth: Int
    let maxChildren: Int
    let timeoutSeconds: TimeInterval

    init(maxNodes: Int = 800, maxDepth: Int = 32, maxChildren: Int = 200, timeoutSeconds: TimeInterval = 2) {
        self.maxNodes = min(10_000, max(1, maxNodes))
        self.maxDepth = min(128, max(0, maxDepth))
        self.maxChildren = min(1_000, max(0, maxChildren))
        self.timeoutSeconds = timeoutSeconds.isFinite ? min(30, max(0, timeoutSeconds)) : 2
    }

    static let simulatorDefault = CLIObservationBudget()
}

struct CLIObservationCollectionSummary: Codable, Equatable, Sendable {
    let visitedNodes: Int
    let limitReasons: [String]
    var partial: Bool { !limitReasons.isEmpty }
}

struct CLIObservationCollectedNode<Value> {
    let value: Value
    let children: [CLIObservationCollectedNode<Value>]
}

/// The same fixture-tested traversal is used for translation preparation and AX
/// reads. No recursive preprocessing runs outside this budget.
final class CLIObservationTreeCollector {
    let budget: CLIObservationBudget
    private let now: () -> TimeInterval
    private let deadline: TimeInterval
    private var visitedNodes = 0
    private var reasons: Set<String> = []

    init(budget: CLIObservationBudget, now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.budget = budget
        self.now = now
        self.deadline = now() + budget.timeoutSeconds
    }

    var summary: CLIObservationCollectionSummary {
        .init(visitedNodes: visitedNodes, limitReasons: ["max_nodes", "max_depth", "max_children", "deadline"].filter { reasons.contains($0) })
    }

    var remainingSeconds: TimeInterval {
        let remaining = max(0, deadline - now())
        if remaining == 0 { reasons.insert("deadline") }
        return remaining
    }

    /// Allows native adapters to gate individual property/IPC calls, rather
    /// than treating a multi-property node summary as one indivisible read.
    func readIfWithinDeadline<Value>(_ body: () -> Value) -> Value? {
        guard canContinue() else { return nil }
        return body()
    }

    /// Checks again after each native-like stage: a slow call cannot cause more
    /// calls after the deadline. A call already underway is not canceled.
    func collect<Element, Value>(
        _ root: Element,
        prepare: (Element) -> Void,
        read: (Element) -> Value,
        children: (Element) -> [Element]
    ) -> CLIObservationCollectedNode<Value>? {
        walkInternal(root, depth: 0, prepare: prepare, read: read, children: children)
    }

    private func canContinue() -> Bool {
        guard now() < deadline else {
            reasons.insert("deadline")
            return false
        }
        return true
    }

    private func walkInternal<Element, Value>(
        _ element: Element,
        depth: Int,
        prepare: (Element) -> Void,
        read: (Element) -> Value,
        children: (Element) -> [Element]
    ) -> CLIObservationCollectedNode<Value>? {
        guard canContinue() else { return nil }
        guard visitedNodes < budget.maxNodes else {
            reasons.insert("max_nodes")
            return nil
        }
        visitedNodes += 1
        prepare(element)
        guard canContinue() else { return nil }
        let value = read(element)
        guard canContinue() else { return .init(value: value, children: []) }
        // Do not query children merely to prove a depth cap truncated something.
        // Report the cap conservatively whenever this boundary is reached.
        guard depth < budget.maxDepth else {
            reasons.insert("max_depth")
            return .init(value: value, children: [])
        }
        let availableChildren = children(element)
        guard canContinue() else { return .init(value: value, children: []) }
        if availableChildren.count > budget.maxChildren { reasons.insert("max_children") }
        var collected: [CLIObservationCollectedNode<Value>] = []
        for child in availableChildren.prefix(budget.maxChildren) {
            guard let node = walkInternal(child, depth: depth + 1, prepare: prepare, read: read, children: children) else { break }
            collected.append(node)
        }
        return .init(value: value, children: collected)
    }
}
