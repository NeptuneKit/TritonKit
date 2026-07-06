import type { HierarchyLayerNode, HierarchyScene, HierarchyVisualSource } from "../types";

export function effectiveVisualSources(node: HierarchyLayerNode): HierarchyVisualSource[] {
  const sources = [...(node.visualSources ?? [])];
  if (node.slice?.available && (node.slice.dataUrl || node.slice.dataRef)) {
    sources.push({
      kind: "subtreeSnapshot",
      dataUrl: node.slice.dataUrl,
      dataRef: node.slice.dataRef,
      rect: node.frame,
      capturedBy: "unknown",
    });
  }
  return sources;
}

export function resolveDefaultMaterialSource(node: HierarchyLayerNode) {
  return effectiveVisualSources(node).find((source) => source.kind === "layerOwnContents") ?? null;
}

export function resolveEvidenceSources(node: HierarchyLayerNode) {
  return effectiveVisualSources(node);
}

export function getMaterialExplanation(node: HierarchyLayerNode) {
  const defaultMaterial = resolveDefaultMaterialSource(node);
  return {
    nodeId: node.id,
    defaultMaterial,
    reason: defaultMaterial ? "layerOwnContents source available" : "No layerOwnContents source available",
    evidenceSources: resolveEvidenceSources(node).map((source) => source.kind),
  };
}

export function computeParityClaim(scene: Pick<HierarchyScene, "nodes">) {
  const visibleNonRoot = scene.nodes.filter((node) => node.visible !== false && node.depth > 0);
  const hasOnlySubtreeEvidence = visibleNonRoot.some((node) =>
    effectiveVisualSources(node).some((source) => source.kind === "subtreeSnapshot")
  );
  const allHaveLayerOwnContents = visibleNonRoot.length > 0
    && visibleNonRoot.every((node) => resolveDefaultMaterialSource(node));
  const reasons: string[] = [];

  if (hasOnlySubtreeEvidence) {
    reasons.push("subtreeSnapshot is evidence only and cannot reconstruct layer-own contents");
  }
  if (!allHaveLayerOwnContents) {
    reasons.push("not every visible non-root node has layerOwnContents source");
  }

  return {
    level: allHaveLayerOwnContents ? "layerOwnContents" : "snapshotEvidenceViewer",
    canClaimLookinParity: allHaveLayerOwnContents,
    reasons,
  };
}
