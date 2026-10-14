// SPDX-License-Identifier: Apache-2.0
package jp.lycorp.tritonkit.bridge.handler

/** Limits apply to collection, including borrowed nodes, rather than a result prefix. */
data class TreeCollectionLimits(
    val maxNodes: Int = 800,
    val maxDepth: Int = 32,
    val maxChildren: Int = 200,
    val timeoutMs: Long = 2_000,
) {
    init {
        require(maxNodes in 1..10_000) { "invalid_max_nodes" }
        require(maxDepth in 0..128) { "invalid_max_depth" }
        require(maxChildren in 1..1_000) { "invalid_max_children" }
        require(timeoutMs in 1..10_000) { "invalid_timeout_ms" }
    }

    companion object {
        fun fromParams(params: Map<String, String>): TreeCollectionLimits {
            fun int(name: String, fallback: Int) = params[name]?.let {
                it.toIntOrNull() ?: throw IllegalArgumentException("invalid_$name")
            } ?: fallback
            val defaults = TreeCollectionLimits()
            return TreeCollectionLimits(
                maxNodes = int("max_nodes", defaults.maxNodes),
                maxDepth = int("max_depth", defaults.maxDepth),
                maxChildren = int("max_children", defaults.maxChildren),
                timeoutMs = params["timeout_ms"]?.let {
                    it.toLongOrNull() ?: throw IllegalArgumentException("invalid_timeout_ms")
                } ?: defaults.timeoutMs,
            )
        }
    }
}

/** One request owns this budget and shares it across window roots. Monotonic clock only. */
class TreeCollectionBudget(
    val limits: TreeCollectionLimits = TreeCollectionLimits(),
    private val clock: () -> Long = { System.nanoTime() / 1_000_000 },
) {
    private val started = clock()
    var visitedNodes: Int = 0
        private set
    val reasons = linkedSetOf<String>()
    val elapsedMs: Long get() = (clock() - started).coerceAtLeast(0)
    val truncated: Boolean get() = reasons.isNotEmpty()

    fun available(): Boolean {
        if (elapsedMs >= limits.timeoutMs || Thread.currentThread().isInterrupted) {
            reasons.add("timeout")
            return false
        }
        if (visitedNodes >= limits.maxNodes) {
            reasons.add("max_nodes")
            return false
        }
        return true
    }

    internal fun enter(): Boolean {
        if (!available()) return false
        visitedNodes++
        return true
    }

    internal fun childLimit(depth: Int, count: Int): Int {
        if (count == 0) return 0
        if (depth >= limits.maxDepth) {
            reasons.add("max_depth")
            return 0
        }
        if (count > limits.maxChildren) reasons.add("max_children")
        return count.coerceAtMost(limits.maxChildren)
    }
}

/** Deterministic depth-first collector: no unbounded forks or allocations from childCount. */
internal class BoundedTreeWalker<N, R>(
    private val childCount: (N) -> Int,
    private val child: (N, Int) -> N?,
    private val recycle: (N) -> Unit,
    private val read: (N) -> R,
    private val withChildren: (R, MutableList<R>) -> R?,
) {
    fun walk(root: N, budget: TreeCollectionBudget, depth: Int = 0): R? {
        try {
            if (!budget.enter()) return null
            val snapshot = read(root)
            val children = mutableListOf<R>()
            if (budget.availableForChildren()) {
                val count = budget.childLimit(depth, childCount(root).coerceAtLeast(0))
                for (index in 0 until count) {
                    if (!budget.available()) break
                    val borrowed = child(root, index) ?: continue
                    walk(borrowed, budget, depth + 1)?.let(children::add)
                }
            }
            return withChildren(snapshot, children)
        } finally {
            recycle(root)
        }
    }

    // A node reaching the exact limit is still a complete leaf if it has no children.
    private fun TreeCollectionBudget.availableForChildren(): Boolean {
        if (elapsedMs >= limits.timeoutMs || Thread.currentThread().isInterrupted) {
            reasons.add("timeout")
            return false
        }
        return true
    }
}
