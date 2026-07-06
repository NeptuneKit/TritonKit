import type { HierarchyLayerNode } from "../types";
import { deriveOverlayNodes } from "./hierarchyDerive";

export type HitTestResult = {
  nodeId: string | null;
  reason: "deepest" | "selected-descendant" | "none";
  candidates: string[];
};

export function hitTestHierarchyNode(input: {
  nodes: HierarchyLayerNode[];
  mode: "none" | "view" | "ax";
  point: { x: number; y: number };
  selectedNodeId?: string | null;
}): HitTestResult {
  const nodes = deriveOverlayNodes(input.nodes, input.mode);
  const byId = new Map(nodes.map((node) => [node.id, node]));
  const hits = sortHits(nodes.filter((node) => containsPoint(node, input.point.x, input.point.y)));
  const selected = input.selectedNodeId ? byId.get(input.selectedNodeId) : undefined;
  if (selected && containsPoint(selected, input.point.x, input.point.y)) {
    const descendant = sortHits(hits.filter((node) => node.id !== selected.id && isDescendantOf(node, selected.id, byId)))[0];
    if (descendant) {
      return { nodeId: descendant.id, reason: "selected-descendant", candidates: hits.map((node) => node.id) };
    }
  }
  return hits[0]
    ? { nodeId: hits[0].id, reason: "deepest", candidates: hits.map((node) => node.id) }
    : { nodeId: null, reason: "none", candidates: [] };
}

function sortHits(nodes: HierarchyLayerNode[]) {
  return [...nodes].sort((a, b) => (area(a) - area(b)) || (b.depth - a.depth));
}

function containsPoint(node: HierarchyLayerNode, x: number, y: number) {
  return x >= node.frame.x && x <= node.frame.x + node.frame.width && y >= node.frame.y && y <= node.frame.y + node.frame.height;
}

function area(node: HierarchyLayerNode) {
  return node.frame.width * node.frame.height;
}

function isDescendantOf(node: HierarchyLayerNode, parentId: string, byId: Map<string, HierarchyLayerNode>) {
  let current = node.parentId ? byId.get(node.parentId) : undefined;
  while (current) {
    if (current.id === parentId) return true;
    current = current.parentId ? byId.get(current.parentId) : undefined;
  }
  return false;
}
