// SPDX-License-Identifier: Apache-2.0
package jp.lycorp.tritonkit.bridge.handler

import android.graphics.Rect
import android.os.Build
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo
import jp.lycorp.tritonkit.bridge.model.ElementNode

/** Bounded collector. Each borrowed AccessibilityNodeInfo is recycled exactly once. */
class TreeHandler {
    fun buildTree(
        root: AccessibilityNodeInfo?,
        filter: Boolean,
        budget: TreeCollectionBudget = TreeCollectionBudget(),
    ): ElementNode? {
        if (root == null) return null
        val walker = BoundedTreeWalker<AccessibilityNodeInfo, ElementNode>(
            childCount = { it.childCount },
            child = { node, index -> node.getChild(index) },
            recycle = ::safeRecycle,
            read = ::snapshotNode,
            withChildren = { node, children ->
                if (filter && node.boundsInScreen.isEmpty() && children.isEmpty()) null
                else node.copy(children = children)
            },
        )
        val tree = walker.walk(root, budget)
        Log.i(TAG, "buildTree: nodes=${budget.visitedNodes} elapsed=${budget.elapsedMs}ms truncated=${budget.truncated}")
        return tree
    }

    private fun snapshotNode(info: AccessibilityNodeInfo): ElementNode {
        val bounds = Rect().also(info::getBoundsInScreen)
        return ElementNode(
            resourceId = info.viewIdResourceName ?: "",
            uniqueId = uniqueIdCompat(info),
            packageName = info.packageName?.toString() ?: "",
            className = info.className?.toString() ?: "",
            text = info.text?.toString() ?: "",
            contentDescription = info.contentDescription?.toString() ?: "",
            hintText = hintTextCompat(info),
            stateDescription = stateDescriptionCompat(info),
            boundsInScreen = bounds,
            clickable = info.isClickable,
            longClickable = info.isLongClickable,
            scrollable = info.isScrollable,
            focusable = info.isFocusable,
            focused = info.isFocused,
            enabled = info.isEnabled,
            checkable = info.isCheckable,
            checked = info.isChecked,
            selected = info.isSelected,
            password = info.isPassword,
            visibleToUser = info.isVisibleToUser,
            collectionInfo = info.collectionInfo?.let {
                ElementNode.CollectionInfo(
                    rowCount = it.rowCount,
                    columnCount = it.columnCount,
                    itemCount = -1,
                    isHierarchical = it.isHierarchical,
                )
            },
            collectionItemInfo = info.collectionItemInfo?.let {
                ElementNode.CollectionItemInfo(
                    rowIndex = it.rowIndex,
                    columnIndex = it.columnIndex,
                    rowSpan = it.rowSpan,
                    columnSpan = it.columnSpan,
                    isHeading = it.isHeading,
                )
            },
            children = mutableListOf(),
        )
    }

    private fun Rect.isEmpty(): Boolean = width() <= 0 || height() <= 0

    private fun uniqueIdCompat(info: AccessibilityNodeInfo): String? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) info.uniqueId else null

    private fun hintTextCompat(info: AccessibilityNodeInfo): String? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) info.hintText?.toString() else null

    private fun stateDescriptionCompat(info: AccessibilityNodeInfo): String? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) info.stateDescription?.toString() else null

    companion object { private const val TAG = "TritonKitTreeHandler" }

    @Suppress("DEPRECATION")
    private fun safeRecycle(node: AccessibilityNodeInfo) {
        try {
            node.recycle()
        } catch (_: Exception) {
            // recycle() is a no-op on API 33+ and may throw if the node
            // has already been recycled. csat swallows both.
        }
    }
}