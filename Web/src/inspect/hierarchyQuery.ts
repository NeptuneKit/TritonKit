import type { InspectTarget } from "./target";

export function inspectHierarchyQuery(target: InspectTarget) {
  const params = new URLSearchParams({ platform: target.platform, target: target.target });
  if (target.scope) params.set("scope", target.scope);
  if (target.kind) params.set("kind", target.kind);
  if (target.hierarchySource) params.set("source", target.hierarchySource);
  return params;
}
