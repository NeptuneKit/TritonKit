import type { HierarchyLayerNode, HierarchyScene, HierarchyVisualSource } from "../types";

export function effectiveVisualSources(node: HierarchyLayerNode): HierarchyVisualSource[] {
  const sources = [...(node.visualSources ?? [])];
  const slice = node.slice;
  if (slice?.available && (slice.dataUrl || slice.dataRef)) {
    const kind = ["solo-screenshot-ref", "solo-screenshot-inline"].includes(slice.mode ?? "") ? "layerOwnContents" : "subtreeSnapshot";
    const duplicate = sources.some(source => source.kind === kind &&
      ((slice.dataRef && "dataRef" in source && source.dataRef === slice.dataRef)
        || (slice.dataUrl && "dataUrl" in source && source.dataUrl === slice.dataUrl)));
    if (!duplicate) sources.push(kind === "layerOwnContents"
      ? { kind, dataUrl: slice.dataUrl, dataRef: slice.dataRef, rect: node.frame }
      : { kind, dataUrl: slice.dataUrl, dataRef: slice.dataRef, rect: node.frame, capturedBy: "unknown" });
  }
  return sources;
}

export function resolveDefaultMaterialSource(node: HierarchyLayerNode) {
  return effectiveVisualSources(node).find((source): source is Extract<HierarchyVisualSource, {kind: "layerOwnContents"}> => source.kind === "layerOwnContents" && Boolean(source.dataUrl)) ?? null;
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
    !resolveDefaultMaterialSource(node) && effectiveVisualSources(node).some((source) => source.kind === "subtreeSnapshot")
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
