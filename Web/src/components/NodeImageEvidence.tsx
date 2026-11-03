import { useEffect, useState } from "react";
import { Stack, Text } from "@linhey/rhine-design";
import { effectiveVisualSources } from "../data/hierarchyMaterialPolicy";
import type { HierarchyLayerNode } from "../types";

export function NodeImageEvidence({ node }: { node: HierarchyLayerNode }) {
  const sources = effectiveVisualSources(node);
  const solo = sources.find(source => source.kind === "layerOwnContents" && source.dataUrl);
  const group = sources.find(source => source.kind === "subtreeSnapshot" && source.dataUrl);
  return <Stack gap={3}>
    <Text as="h3" variant="heading">节点截图</Text>
    <div className="rhine-node-image-evidence">
      <EvidenceImage label="仅此图层" source={solo && "dataUrl" in solo ? solo.dataUrl : undefined} />
      <EvidenceImage label="包含子图层" source={group && "dataUrl" in group ? group.dataUrl : undefined} />
    </div>
  </Stack>;
}
function EvidenceImage({ label, source }: { label: string; source?: string }) {
  const [failed, setFailed] = useState(false);
  useEffect(() => setFailed(false), [source]);
  return <figure><figcaption><Text variant="label">{label}</Text></figcaption>
    {source && !failed ? <img src={source} alt={label} onError={() => setFailed(true)} />
      : <Text variant="caption" tone="muted">{failed ? "截图加载失败" : "当前快照未提供"}</Text>}
  </figure>;
}
