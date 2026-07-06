import type { HierarchyLayerNode } from "./types";

export type InspectorTreeTab = {
  key: "view" | "ax" | "source";
  label: string;
  description: string;
};

export function getInspectorTreeTabs(platform: string | undefined, nodes: Pick<HierarchyLayerNode, "source" | "raw">[], hasNodes: boolean): InspectorTreeTab[] {
  if (platform === "ios") {
    return [
      { key: "view", label: "视图树", description: "iOS runtime / hierarchy scene view tree." },
      { key: "ax", label: "AX 树", description: "从同一场景中过滤出的 accessibility 节点。" },
    ];
  }

  const source = firstNodeSource(nodes);
  if (platform === "android" && source === "android-bridge") {
    return [{ key: "source", label: "辅助功能树", description: "Android bridge AccessibilityService tree；当前没有独立 View tree。" }];
  }
  if (platform === "android") {
    return [{ key: "source", label: "布局树", description: "Android UIAutomator host layout；当前没有独立 View/AX 双源。" }];
  }
  if (platform === "harmony") {
    return [{ key: "source", label: "布局树", description: "Harmony HDC dumpLayout host layout；当前没有独立 View/AX 双源。" }];
  }
  return [{ key: "source", label: hasNodes ? "来源树" : "树", description: "当前目标未声明独立 View/AX 双源。" }];
}

function firstNodeSource(nodes: Pick<HierarchyLayerNode, "source" | "raw">[]) {
  return nodes.map((node) => node.source || node.raw?.source).find(Boolean);
}

