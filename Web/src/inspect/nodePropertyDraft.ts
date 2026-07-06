import type { HierarchyLayerNode } from "../types";

export type NodePropertyDraft = {
  frame: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
  view: {
    isHidden: boolean;
    alpha: number;
    isUserInteractionEnabled: boolean;
    accessibilityIdentifier: string;
    accessibilityLabel: string;
  };
  layer: {
    isHidden: boolean;
    masksToBounds: boolean;
    opacity: number;
    cornerRadius: number;
    zPosition: number;
  };
  style: {
    text: string;
    backgroundColor: string;
    foregroundColor: string;
    alpha: number;
    cornerRadius: number;
  };
};

export type NodePropertyPatchPayload = {
  nodeId: string;
  oid?: number;
  viewOID?: number;
  layerOID?: number;
  changes: Partial<{
    frame: Partial<NodePropertyDraft["frame"]>;
    view: Partial<NodePropertyDraft["view"]>;
    layer: Partial<NodePropertyDraft["layer"]>;
    style: Partial<NodePropertyDraft["style"]>;
  }>;
};

export function buildNodePropertyDraft(node: HierarchyLayerNode | null | undefined): NodePropertyDraft | null {
  if (!node) return null;
  return {
    frame: {
      x: numberValue(node.frame?.x, 0),
      y: numberValue(node.frame?.y, 0),
      width: numberValue(node.frame?.width, 0),
      height: numberValue(node.frame?.height, 0),
    },
    view: {
      isHidden: Boolean(node.view?.isHidden),
      alpha: numberValue(node.view?.alpha, 1),
      isUserInteractionEnabled: node.view?.isUserInteractionEnabled ?? Boolean(node.interactive),
      accessibilityIdentifier: node.view?.accessibilityIdentifier ?? node.raw?.identifier ?? "",
      accessibilityLabel: node.view?.accessibilityLabel ?? "",
    },
    layer: {
      isHidden: Boolean(node.layer?.isHidden),
      masksToBounds: Boolean(node.layer?.masksToBounds),
      opacity: numberValue(node.layer?.opacity, 1),
      cornerRadius: numberValue(node.layer?.cornerRadius, 0),
      zPosition: numberValue(node.layer?.zPosition, 0),
    },
    style: {
      text: node.style?.text ?? "",
      backgroundColor: node.style?.backgroundColor ?? "",
      foregroundColor: node.style?.foregroundColor ?? "",
      alpha: numberValue(node.style?.alpha, 1),
      cornerRadius: numberValue(node.style?.cornerRadius, 0),
    },
  };
}

export function diffNodePropertyDraft(base: NodePropertyDraft, draft: NodePropertyDraft): NodePropertyPatchPayload["changes"] {
  const changes: NodePropertyPatchPayload["changes"] = {};
  diffSection(base.frame, draft.frame, (changed) => { changes.frame = changed; });
  diffSection(base.view, draft.view, (changed) => { changes.view = changed; });
  diffSection(base.layer, draft.layer, (changed) => { changes.layer = changed; });
  diffSection(base.style, draft.style, (changed) => { changes.style = changed; });
  return changes;
}

export function buildNodePropertyPatchPayload(input: {
  targetKey?: string | null;
  node: HierarchyLayerNode;
  base: NodePropertyDraft;
  draft: NodePropertyDraft;
}): NodePropertyPatchPayload {
  const nodeOids = extractNodeObjectIdentifiers(input.node);
  return {
    nodeId: input.node.id,
    ...nodeOids,
    changes: diffNodePropertyDraft(input.base, input.draft),
  };
}

export function hasNodePropertyChanges(changes: NodePropertyPatchPayload["changes"] | null | undefined) {
  if (!changes) return false;
  return Object.values(changes).some((section) => section && Object.keys(section).length > 0);
}

function diffSection<T extends Record<string, string | number | boolean>>(
  base: T,
  draft: T,
  assign: (changed: Partial<T>) => void,
) {
  const changed: Partial<T> = {};
  for (const key of Object.keys(base) as (keyof T)[]) {
    if (base[key] !== draft[key]) changed[key] = draft[key];
  }
  if (Object.keys(changed).length > 0) assign(changed);
}

function numberValue(value: unknown, fallback: number) {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function extractNodeObjectIdentifiers(node: HierarchyLayerNode): Pick<NodePropertyPatchPayload, "oid" | "viewOID" | "layerOID"> {
  const extended = node as HierarchyLayerNode & {
    oid?: unknown;
    viewOID?: unknown;
    viewOid?: unknown;
    layerOID?: unknown;
    layerOid?: unknown;
  };
  return compactNumbers({
    oid: numberValueOrUndefined(extended.oid) ?? parseRuntimeNodeOid(node.id),
    viewOID: numberValueOrUndefined(extended.viewOID) ?? numberValueOrUndefined(extended.viewOid),
    layerOID: numberValueOrUndefined(extended.layerOID) ?? numberValueOrUndefined(extended.layerOid),
  });
}

function compactNumbers<T extends Record<string, number | undefined>>(value: T): Partial<T> {
  return Object.fromEntries(Object.entries(value).filter(([, next]) => typeof next === "number")) as Partial<T>;
}

function numberValueOrUndefined(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function parseRuntimeNodeOid(nodeId: string) {
  const match = nodeId.match(/:(\d+)$/);
  return match ? Number(match[1]) : undefined;
}
