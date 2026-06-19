/**
 * @module hierarchyMaterialPolicy
 *
 * Snapshot evidence viewer material policy.
 *
 * Design invariants:
 * - `subtreeSnapshot` is evidence-only, never used as default node material.
 * - `layerOwnContents` is the only eligible default material kind.
 * - `mainScreenshotCrop` and `styledFallback` are evidence sources, never default material.
 *
 * The main screenshot surface (target.screenshotDataUrl) is the primary visual layer.
 * Node-level visual sources are only used as evidence for the selected node.
 */

import type { HierarchyLayerNode, HierarchyScene, HierarchyVisualSource } from "../types";

export type HierarchyParityClaim = {
  level: "snapshotEvidenceViewer" | "lookinLikeObjectReconstruction";
  canClaimLookinParity: boolean;
  reasons: string[];
};

export type HierarchyMaterialExplanation = {
  nodeId: string;
  defaultMaterial: HierarchyVisualSource["kind"] | null;
  reason: string;
  evidenceSources: HierarchyVisualSource["kind"][];
};

/**
 * Returns all visual sources for a node, bridging legacy `slice.dataUrl`/`slice.dataRef`
 * into the `subtreeSnapshot` visual source kind for backward compatibility with the
 * legacy iOS runtime JSON contract. This bridging does NOT make subtreeSnapshot eligible
 * as default material — see {@link resolveDefaultMaterialSource}.
 */
export function effectiveVisualSources(node: HierarchyLayerNode): HierarchyVisualSource[] {
  const explicitSources = Array.isArray(node.visualSources) ? node.visualSources : [];
  const legacySlice = node.slice?.available && (node.slice.dataUrl || node.slice.dataRef)
    ? [{
        kind: "subtreeSnapshot" as const,
        dataUrl: node.slice.dataUrl,
        dataRef: node.slice.dataRef,
        rect: node.frame,
        capturedBy: "unknown" as const,
      }]
    : [];
  return [...explicitSources, ...legacySlice];
}

/**
 * Returns the default material source for a node, or `null` if none is eligible.
 * Only `layerOwnContents` sources are eligible. Nodes with only `subtreeSnapshot`
 * evidence will return `null` — this is the expected behavior for the current iOS
 * runtime, which captures subtree screenshots rather than individual layer contents.
 */
export function resolveDefaultMaterialSource(node: HierarchyLayerNode): HierarchyVisualSource | null {
  return effectiveVisualSources(node).find((source) => source.kind === "layerOwnContents") ?? null;
}

export function resolveEvidenceSources(node: HierarchyLayerNode): HierarchyVisualSource[] {
  return effectiveVisualSources(node);
}

export function getMaterialExplanation(node: HierarchyLayerNode): HierarchyMaterialExplanation {
  const defaultMaterial = resolveDefaultMaterialSource(node);
  const evidenceSources = resolveEvidenceSources(node).map((source) => source.kind);
  return {
    nodeId: node.id,
    defaultMaterial: defaultMaterial?.kind ?? null,
    reason: defaultMaterial ? "layerOwnContents source is eligible for default material" : "No layerOwnContents source available",
    evidenceSources,
  };
}

/**
 * Computes the Lookin parity claim for a hierarchy scene.
 * `canClaimLookinParity` can only be `true` when every visible non-root node has
 * a `layerOwnContents` source, which currently never happens on iOS (all nodes
 * have `subtreeSnapshot` evidence from `view.layer.render(in:)`).
 */
export function computeParityClaim(scene: HierarchyScene): HierarchyParityClaim {
  const nodes = scene.nodes.filter((node) => node.visible && node.depth > 0);
  const subtreeEvidenceCount = nodes.filter((node) =>
    effectiveVisualSources(node).some((source) => source.kind === "subtreeSnapshot")
  ).length;
  const missingLayerOwnContentsCount = nodes.filter((node) => !resolveDefaultMaterialSource(node)).length;

  const reasons: string[] = [];
  if (subtreeEvidenceCount > 0) {
    reasons.push("subtreeSnapshot is evidence only and cannot reconstruct layer-own contents");
  }
  if (missingLayerOwnContentsCount > 0) {
    reasons.push("not every visible non-root node has layerOwnContents source");
  }

  return {
    level: reasons.length === 0 && nodes.length > 0 ? "lookinLikeObjectReconstruction" : "snapshotEvidenceViewer",
    canClaimLookinParity: reasons.length === 0 && nodes.length > 0,
    reasons,
  };
}
