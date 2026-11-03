import "../src/components/inspectorPanel.css";
import { useMemo, useState } from "react";
import { Stack, Text } from "@linhey/rhine-design";
import { NodeImageEvidence } from "../src/components/NodeImageEvidence";
import { HierarchyLayers } from "../src/components/HierarchyLayers";
import { InspectorHierarchyTree } from "../src/components/InspectorHierarchyTree";
import { deriveViewTree } from "../src/inspect/hierarchyDerive";
import { makeSyntheticHierarchy } from "./syntheticData";
import type { DevicePlatform } from "../src/types";

const image = (color: string, caption: string) => `data:image/svg+xml,${encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="390" height="844"><rect width="390" height="844" fill="${color}"/><text x="20" y="55" fill="white" font-size="32">${caption}</text></svg>`)}`;
export function makeLayerScene(platform: DevicePlatform = "ios", state = "ready") {
  const scene = makeSyntheticHierarchy(platform, state);
  scene.nodes = scene.nodes.map((node, i) => ({ ...node, visualSources: state === "missing-images" ? [] : [
    { kind: "layerOwnContents" as const, rect: node.frame, dataUrl: image(["#202a36", "#33515f", "#536e52", "#776149"][i % 4], node.name) },
    { kind: "subtreeSnapshot" as const, rect: node.frame, capturedBy: "unknown" as const, dataUrl: image("#772255", "GROUP — never a plane") },
  ] }));
  return scene;
}
export function LayerScene({ platform = "ios", state = "ready" }: { platform?: DevicePlatform; state?: string }) {
  const scene = useMemo(() => makeLayerScene(platform, state), [platform, state]);
  const [selected, setSelected] = useState<string | null>("child-action");
  const [hovered, setHovered] = useState<string | null>(null);
  return <Stack gap={3}>
    <Text as="h2" variant="heading">层级分层检查</Text>
    <HierarchyLayers key={`${platform}:${state}`} scene={scene} selectedNodeId={selected} onSelect={setSelected} onHover={setHovered} />
    {scene.nodes.find(node => node.id === selected) && <NodeImageEvidence node={scene.nodes.find(node => node.id === selected)!} />}
    <InspectorHierarchyTree label="分层视图关联树" nodes={deriveViewTree(scene.nodes)} selectedNodeId={selected} hoveredNodeId={hovered} onSelect={setSelected} onHover={setHovered} />
  </Stack>;
}
