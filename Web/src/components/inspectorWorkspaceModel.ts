import type { HierarchyScene } from "../types";
import { findDescendantAtPoint } from "../hierarchyVisibility";

export function cycleHierarchyNodeAtPoint(scene: HierarchyScene, x: number, y: number, selectedNodeId?: string | null) {
  const hits = scene.nodes
    .filter((node) => node.visible !== false && containsPoint(node, x, y))
    .sort((a, b) => (b.depth - a.depth) || (area(a) - area(b)));

  if (!selectedNodeId) return hits[0] ?? null;

  const selected = scene.nodes.find((node) => node.id === selectedNodeId);
  if (selected && containsPoint(selected, x, y)) {
    return findDescendantAtPoint(scene.nodes, selected.id, x, y) ?? selected;
  }

  return hits[0] ?? null;
}

function containsPoint(node: HierarchyScene["nodes"][number], x: number, y: number) {
  const frame = node.frame;
  return x >= frame.x && x <= frame.x + frame.width && y >= frame.y && y <= frame.y + frame.height;
}

function area(node: HierarchyScene["nodes"][number]) {
  return node.frame.width * node.frame.height;
}
