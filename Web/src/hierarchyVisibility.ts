import type { HierarchyLayerNode } from "./types";

function isNodeSelfVisible(node: HierarchyLayerNode) {
  if (node.visible === false) return false;
  if (node.view?.isHidden === true) return false;
  if (node.layer?.isHidden === true) return false;
  if (node.view?.alpha === 0 || node.style?.alpha === 0 || node.layer?.opacity === 0) return false;
  return true;
}

export function getEffectivelyVisibleNodeIds(nodes: HierarchyLayerNode[]) {
  const byId = new Map(nodes.map((node) => [node.id, node]));
  const cache = new Map<string, boolean>();

  const isVisible = (node: HierarchyLayerNode): boolean => {
    const cached = cache.get(node.id);
    if (cached !== undefined) return cached;

    const visible = isNodeSelfVisible(node)
      && (!node.parentId || !byId.has(node.parentId) || isVisible(byId.get(node.parentId)!));
    cache.set(node.id, visible);
    return visible;
  };

  return new Set(nodes.filter(isVisible).map((node) => node.id));
}

export function filterEffectivelyVisibleNodes(nodes: HierarchyLayerNode[]) {
  const visibleIds = getEffectivelyVisibleNodeIds(nodes);
  return nodes.filter((node) => visibleIds.has(node.id));
}

export function findDescendantAtPoint(nodes: HierarchyLayerNode[], parentId: string, x: number, y: number) {
  const byId = new Map(nodes.map((node) => [node.id, node]));
  return nodes
    .filter((node) => node.id !== parentId && isDescendantOf(node, parentId, byId) && containsPoint(node, x, y))
    .sort((a, b) => (area(a) - area(b)) || (b.depth - a.depth))[0] ?? null;
}

function isDescendantOf(node: HierarchyLayerNode, parentId: string, byId: Map<string, HierarchyLayerNode>) {
  let current = node.parentId ? byId.get(node.parentId) : null;
  while (current) {
    if (current.id === parentId) return true;
    current = current.parentId ? byId.get(current.parentId) : null;
  }
  return false;
}

function containsPoint(node: HierarchyLayerNode, x: number, y: number) {
  const frame = node.frame;
  return x >= frame.x && x <= frame.x + frame.width && y >= frame.y && y <= frame.y + frame.height;
}

function area(node: HierarchyLayerNode) {
  return node.frame.width * node.frame.height;
}
