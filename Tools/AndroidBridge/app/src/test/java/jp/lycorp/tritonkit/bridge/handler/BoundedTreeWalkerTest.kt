// SPDX-License-Identifier: Apache-2.0
package jp.lycorp.tritonkit.bridge.handler

import org.junit.Assert.*
import org.junit.Test

class BoundedTreeWalkerTest {
    private data class Node(val id: Int, val children: List<Node> = emptyList())
    private data class Built(val id: Int, val children: List<Built>)
    private val borrowed = mutableListOf<Int>()
    private val recycled = mutableListOf<Int>()
    private val read = mutableListOf<Int>()

    private fun walk(root: Node, budget: TreeCollectionBudget): Built? = BoundedTreeWalker<Node, Built>(
        childCount = { it.children.size },
        child = { node, index -> node.children[index].also { borrowed.add(it.id) } },
        recycle = { recycled.add(it.id) },
        read = { node -> read.add(node.id); Built(node.id, emptyList()) },
        withChildren = { node, children -> node.copy(children = children) },
    ).walk(root, budget)

    @Test fun nodeBudgetStopsBorrowingBeforeLimit() {
        val root = Node(0, (1..100).map { Node(it) })
        val budget = TreeCollectionBudget(TreeCollectionLimits(maxNodes = 3), clock = { 0L })
        val tree = walk(root, budget)!!
        assertEquals(listOf(1, 2), borrowed)
        assertEquals(3, read.size)
        assertEquals(2, tree.children.size)
        assertEquals(3, recycled.size)
        assertTrue(budget.reasons.contains("max_nodes"))
    }

    @Test fun depthAndWidthBoundActualChildReads() {
        val root = Node(0, (1..20).map { Node(it, listOf(Node(100 + it))) })
        val budget = TreeCollectionBudget(TreeCollectionLimits(maxDepth = 1, maxChildren = 2), clock = { 0L })
        val tree = walk(root, budget)!!
        assertEquals(listOf(1, 2), borrowed)
        assertTrue(tree.children.all { it.children.isEmpty() })
        assertTrue(budget.reasons.containsAll(listOf("max_depth", "max_children")))
    }

    @Test fun deadlineStopsBeforeNextBinderChildRead() {
        var now = 0L
        val root = Node(0, (1..10).map { Node(it) })
        val budget = TreeCollectionBudget(TreeCollectionLimits(timeoutMs = 5), clock = { now })
        val walker = BoundedTreeWalker<Node, Built>(
            childCount = { it.children.size },
            child = { node, index -> borrowed.add(node.children[index].id); now += 6; node.children[index] },
            recycle = { recycled.add(it.id) },
            read = { node -> Built(node.id, emptyList()) },
            withChildren = { node, children -> node.copy(children = children) },
        )
        val tree = walker.walk(root, budget)!!
        assertEquals(listOf(1), borrowed)
        assertTrue(tree.children.isEmpty())
        assertEquals(setOf(0, 1), recycled.toSet())
        assertEquals(setOf("timeout"), budget.reasons)
    }

    @Test fun multiWindowRootsShareNodeLimit() {
        val budget = TreeCollectionBudget(TreeCollectionLimits(maxNodes = 2), clock = { 0L })
        assertNotNull(walk(Node(0, listOf(Node(1))), budget))
        assertNull(walk(Node(2), budget))
        assertEquals(2, read.size)
        assertTrue(recycled.contains(2))
    }

    @Test fun exceptionRecyclesBorrowedNodes() {
        val walker = BoundedTreeWalker<Node, Built>(
            childCount = { it.children.size }, child = { node, i -> node.children[i] },
            recycle = { recycled.add(it.id) },
            read = { node -> if (node.id == 1) error("read failed") else Built(node.id, emptyList()) },
            withChildren = { node, children -> node.copy(children = children) },
        )
        try { walker.walk(Node(0, listOf(Node(1))), TreeCollectionBudget(clock = { 0L })); fail("expected failure") }
        catch (_: IllegalStateException) { assertEquals(setOf(0, 1), recycled.toSet()) }
    }

    @Test fun invalidAndExcessiveLimitsAreRejected() {
        listOf(mapOf("max_nodes" to "0"), mapOf("max_depth" to "-1"), mapOf("max_children" to "no"), mapOf("timeout_ms" to "10001")).forEach {
            try { TreeCollectionLimits.fromParams(it); fail("expected invalid budget") } catch (_: IllegalArgumentException) {}
        }
    }
}
