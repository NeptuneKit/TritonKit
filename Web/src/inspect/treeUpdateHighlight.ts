import type { HierarchyTreeNode } from "./hierarchyDerive";

export function snapshotHierarchyTree(nodes: HierarchyTreeNode[]) {
  const snapshot = new Map<string, string>();
  const visit = (node: HierarchyTreeNode) => {
    snapshot.set(node.id, hierarchyTreeNodeSignature(node));
    node.children.forEach(visit);
  };
  nodes.forEach(visit);
  return snapshot;
}

export function changedHierarchyTreeNodeIds(
  previous: Map<string, string>,
  next: Map<string, string>
) {
  const changed = new Set<string>();
  if (previous.size === 0) return changed;
  for (const [id, signature] of next) {
    if (previous.get(id) !== signature) {
      changed.add(id);
    }
  }
  return changed;
}

function hierarchyTreeNodeSignature(node: HierarchyTreeNode) {
  const frame = node.frame;
  return [
    node.parentId ?? "",
    node.type ?? "",
    node.className ?? "",
    node.name ?? "",
    node.view?.accessibilityIdentifier ?? "",
    node.view?.accessibilityLabel ?? "",
    node.style?.text ?? "",
    node.interactive ? "1" : "0",
    frame ? `${frame.x},${frame.y},${frame.width},${frame.height}` : "",
    node.children.map((child) => child.id).join(","),
  ].join("|");
}
