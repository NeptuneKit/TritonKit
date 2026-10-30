import { Smartphone } from "lucide-react";
import type { DevicePlatform, DeviceTarget, HierarchyLayerNode, HierarchyScene } from "../src/types";

const platforms: DevicePlatform[] = ["ios", "android", "harmony"];

export function makeSyntheticTargets(state = "ready"): DeviceTarget[] {
  if (state === "empty") return [];
  return platforms.map(platform => ({
    id: `synthetic-${platform}`,
    name: state === "long" ? `Synthetic ${platform.toUpperCase()} target with a deliberately long readable device name` : `Synthetic ${platform.toUpperCase()} target`,
    platform,
    device: "Synthetic device",
    appName: "Synthetic workspace",
    bundleId: "example.synthetic.workspace",
    os: "Synthetic OS",
    status: "ready",
    statusLabel: "就绪",
    transport: "synthetic",
    screenshotTone: "neutral",
    screenSize: "390 × 844",
    fps: 0,
    latencyMs: 0,
    proxyMode: "off",
    proxyLabel: "未启用",
    hierarchyNodes: 4,
    lastAction: "仅设计预览",
    actionResult: "ok",
    accent: "#5b8dba",
    Icon: Smartphone,
    targetSelector: `synthetic-${platform}`,
    udid: `synthetic-${platform}`,
    scope: platform === "ios" ? "simulator" : "emulator",
    kind: platform === "ios" ? "simulator" : "emulator",
    screenshotSource: "host",
    canScreenshot: true,
    canInput: false,
    inputCapabilities: [],
    readonly: true,
  }));
}

export function makeSyntheticHierarchy(platform: DevicePlatform = "ios", state = "ready"): HierarchyScene {
  const source = platform === "ios" ? "ios-runtime" : platform === "android" ? "android-uiautomator" : "harmony-hdc";
  const viewType = platform === "ios" ? "UIView" : platform === "android" ? "android.widget.FrameLayout" : "Column";
  const textType = platform === "ios" ? "UILabel" : platform === "android" ? "android.widget.TextView" : "Text";
  const actionType = platform === "ios" ? "UIButton" : platform === "android" ? "android.widget.Button" : "Button";
  const node = (id: string, type: string, name: string, parentId: string | null, frame: HierarchyLayerNode["frame"], text?: string, interactive = false): HierarchyLayerNode => ({
    id, type, className: type, name, parentId, frame, depth: parentId === "child-container" ? 2 : parentId ? 1 : 0,
    visible: true, interactive, source, color: "#5b8dba",
    view: { className: type, isHidden: false, alpha: 1, isUserInteractionEnabled: interactive,
      accessibilityIdentifier: id === "root" || id === "child-container" ? undefined : `synthetic-${id}`,
      accessibilityLabel: text },
    style: { text, backgroundColor: "#202a36", foregroundColor: "#edf2f7", alpha: 1, cornerRadius: 8 },
    raw: { platform, source, role: interactive ? "button" : "view", identifier: `synthetic-${id}` },
  });
  const title = state === "long" ? "Synthetic readable accessibility label and identifier ".repeat(8) : "Synthetic workspace";
  const nodes = state === "empty" ? [] : [
    node("root", viewType, "Synthetic screen", null, { x: 0, y: 0, width: 390, height: 844 }),
    node("child-container", viewType, "Synthetic content", "root", { x: 16, y: 72, width: 358, height: 148 }),
    node("child-title", textType, "Synthetic title", "child-container", { x: 32, y: 96, width: 326, height: 70 }, title),
    node("child-action", actionType, "Synthetic action", "root", { x: 24, y: 260, width: 342, height: 56 }, state === "long" ? title : "Synthetic action", true),
  ];
  if (state === "deep") {
    for (let index = 0; index < 24; index++) {
      const parentId = index === 0 ? "child-container" : `deep-${index - 1}`;
      const child = node(`deep-${index}`, viewType, `Synthetic level ${index + 3}`, parentId,
        { x: 32 + index, y: 90 + index, width: 260 - index * 2, height: 110 - index * 2 },
        `Readable nested node ${index + 3}`);
      child.depth = index + 2;
      nodes.push(child);
    }
  }
  return { platform, rootId: "root", viewport: { width: 390, height: 844 }, nodes,
    collection: { visitedNodes: nodes.length, limitReasons: [] } };
}
