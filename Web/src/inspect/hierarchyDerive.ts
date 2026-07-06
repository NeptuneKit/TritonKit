import type { HierarchyLayerNode } from "../types";

export type HierarchyTreeNode = HierarchyLayerNode & {
  children: HierarchyTreeNode[];
};

export function deriveViewTree(nodes: HierarchyLayerNode[], options: { simplify?: boolean } = {}) {
  const roots = buildTree(visibleNodes(nodes));
  return options.simplify ? simplifyViewTree(roots) : roots;
}

export function deriveAxTree(nodes: HierarchyLayerNode[]) {
  const all = visibleNodes(nodes);
  const descendantsWithAx = new Set<string>();
  const byId = new Map(all.map((node) => [node.id, node]));
  for (const node of all) {
    if (!hasOwnAx(node)) continue;
    let parent = node.parentId ? byId.get(node.parentId) : undefined;
    while (parent) {
      descendantsWithAx.add(parent.id);
      parent = parent.parentId ? byId.get(parent.parentId) : undefined;
    }
  }
  return deriveAxFromTree(buildTree(all), descendantsWithAx);
}

export function deriveOverlayNodes(nodes: HierarchyLayerNode[], mode: "none" | "view" | "ax") {
  if (mode === "none") return [];
  if (mode === "view") return flattenTree(deriveViewTree(nodes, { simplify: false }));
  return flattenTree(deriveAxTree(nodes));
}

export function findSelectedNode(nodes: HierarchyLayerNode[], selectedNodeId?: string | null) {
  if (!selectedNodeId) return null;
  return visibleNodes(nodes).find((node) => node.id === selectedNodeId) ?? null;
}

export function isCellLike(node: HierarchyLayerNode) {
  const text = `${node.type ?? ""} ${node.className ?? ""} ${node.raw?.role ?? ""} ${(node.raw?.classHierarchy ?? []).join(" ")}`;
  return /\b(Cell|UITableViewCell|UICollectionViewCell|AXCell)\b/i.test(text);
}

export function hasOwnAx(node: HierarchyLayerNode) {
  return Boolean(
    node.view?.accessibilityIdentifier
    || node.view?.accessibilityLabel
    || node.style?.text
    || node.raw?.identifier
    || node.interactive
  );
}

function deriveAxFromTree(nodes: HierarchyTreeNode[], descendantsWithAx: Set<string>): HierarchyTreeNode[] {
  return nodes.flatMap((node) => {
    const children = deriveAxFromTree(node.children, descendantsWithAx);
    if (hasOwnAx(node) || (isCellLike(node) && descendantsWithAx.has(node.id))) {
      return [{ ...node, children }];
    }
    return children;
  });
}

function simplifyViewTree(nodes: HierarchyTreeNode[]): HierarchyTreeNode[] {
  return nodes.flatMap((node) => {
    const children = simplifyViewTree(node.children);
    if (isNoise(node) && !hasOwnAx(node) && !isCellLike(node) && children.length === 1) {
      return children;
    }
    return [{ ...node, children }];
  });
}

function buildTree(nodes: HierarchyLayerNode[]): HierarchyTreeNode[] {
  const map = new Map(nodes.map((node) => [node.id, { ...node, children: [] as HierarchyTreeNode[] }]));
  const roots: HierarchyTreeNode[] = [];
  for (const node of nodes) {
    const treeNode = map.get(node.id);
    if (!treeNode) continue;
    const parent = node.parentId ? map.get(node.parentId) : undefined;
    if (parent) {
      parent.children.push(treeNode);
    } else {
      roots.push(treeNode);
    }
  }
  return roots;
}

function visibleNodes(nodes: HierarchyLayerNode[]) {
  const byId = new Map(nodes.map((node) => [node.id, node]));
  const cache = new Map<string, boolean>();
  const visible = (node: HierarchyLayerNode): boolean => {
    const cached = cache.get(node.id);
    if (cached !== undefined) return cached;
    const selfVisible = node.visible !== false
      && node.view?.isHidden !== true
      && node.layer?.isHidden !== true
      && node.view?.alpha !== 0
      && node.style?.alpha !== 0
      && node.layer?.opacity !== 0
      && node.frame.width > 0
      && node.frame.height > 0;
    const result = selfVisible && (!node.parentId || !byId.has(node.parentId) || visible(byId.get(node.parentId)!));
    cache.set(node.id, result);
    return result;
  };
  return nodes.filter(visible);
}

function flattenTree(nodes: HierarchyTreeNode[]): HierarchyTreeNode[] {
  return nodes.flatMap((node) => [node, ...flattenTree(node.children)]);
}

function isNoise(node: HierarchyLayerNode) {
  return [
    "UIView",
    "UITransitionView",
    "UIDropShadowView",
    "UILayoutContainerView",
    "UIViewControllerWrapperView",
    "WKCompositingView",
    "WKScrollView",
    "WKContentView",
  ].includes(node.type || node.className || "");
}
