import type { CSSProperties } from "react";
import type {
  DeviceTarget,
  HierarchyControllerEntry,
  HierarchyLayerNode,
  HierarchyScene,
  LogEntry,
  NetworkEvent,
} from "../types";

export const platformLabel = {
  ios: "iOS",
  android: "Android",
  harmony: "Harmony",
};

const platformDetail = {
  ios: "模拟器",
  android: "仿真器",
  harmony: "DevEco 仿真器",
};

export const modeLabel: Record<DisplayLanguage, Record<NetworkEvent["mode"], string>> = {
  "zh-CN": {
    record: "录制",
    mock: "Mock",
    blocked: "阻断",
    off: "关闭",
  },
  "en-US": {
    record: "Record",
    mock: "Mock",
    blocked: "Blocked",
    off: "Off",
  },
};

export const logLevelLabel: Record<DisplayLanguage, Record<LogEntry["level"], string>> = {
  "zh-CN": {
    info: "信息",
    warn: "警告",
    error: "错误",
  },
  "en-US": {
    info: "Info",
    warn: "Warn",
    error: "Error",
  },
};

type LocalizedLogEntry = {
  timeLabel: string;
  levelLabel: string;
  sourceLabel: string;
  messageLabel: string;
  originalMessage: string;
};

export type BridgeState = {
  loading: boolean;
  error?: string;
  capturedAt?: string;
  sourceCommands: string[];
};

export type LivePreviewState = {
  frameCount: number;
  lastFrameAt: number;
  status: "live" | "error";
};

export type SidebarPanel = "devices" | "view-tree";
export type DevtoolsPanel = "config" | "network" | "logs";
export type DisplayLanguage = "zh-CN" | "en-US";

export type ViewTreeNode = {
  id: string;
  type: string;
  name?: string;
  children?: ViewTreeNode[];
};

export type ViewNodeHighlight = {
  node: HierarchyLayerNode;
  style: CSSProperties;
  isHiddenDraft: boolean;
};

export type ControllerShellBadge = {
  name: string;
  className?: string;
  stack: string[];
  source: string;
  isFallback: boolean;
};

export type HierarchyCacheEntry = {
  loading: boolean;
  error?: string;
  scene?: HierarchyScene;
  stale?: boolean;
};

export type HierarchyNodeHotEditDraft = {
  frame?: Partial<HierarchyLayerNode["frame"]>;
  opacity?: number;
  cornerRadius?: number;
  backgroundColor?: string;
  hidden?: boolean;
};

export const previewFpsMin = 1;
export const previewFpsMax = 60;

export const displayLanguageOptions: Array<{ id: DisplayLanguage; label: string; detail: string }> = [
  { id: "zh-CN", label: "简体中文", detail: "中文界面标签与日志说明" },
  { id: "en-US", label: "English", detail: "English tool labels and log messages" },
];

export function viewTreeNodesForScene(scene: HierarchyScene): ViewTreeNode[] {
  const nodesByParent = new Map<string | undefined, HierarchyLayerNode[]>();
  for (const node of scene.nodes) {
    const parentId = node.parentId ?? undefined;
    const siblings = nodesByParent.get(parentId) ?? [];
    siblings.push(node);
    nodesByParent.set(parentId, siblings);
  }

  const buildNode = (node: HierarchyLayerNode): ViewTreeNode => ({
    id: node.id,
    type: node.type,
    name: node.name,
    children: nodesByParent.get(node.id)?.map(buildNode),
  });

  return (nodesByParent.get(undefined) ?? []).map(buildNode);
}

export function defaultViewTreeSelection(scene: HierarchyScene): string {
  return scene.nodes.find((node) => node.interactive && node.depth >= 3)?.id ?? scene.rootId;
}

export function readableViewTreeLabel(value: string): string {
  const suffix = value.match(/#\d+$/)?.[0] ?? "";
  const withoutSuffix = suffix ? value.slice(0, -suffix.length) : value;
  const swiftNames: string[] = [];
  for (const match of withoutSuffix.matchAll(/\d+/g)) {
    const length = Number(match[0]);
    const start = (match.index ?? 0) + match[0].length;
    const candidate = withoutSuffix.slice(start, start + length);
    if (candidate.length === length && /^[A-Za-z][A-Za-z0-9_]*$/.test(candidate)) {
      swiftNames.push(candidate);
    }
  }
  const swiftName = swiftNames.at(-1);
  if (swiftName && swiftName.length >= 3) {
    return swiftName;
  }

  const namespaceIndex = withoutSuffix.lastIndexOf(".");
  if (namespaceIndex >= 0 && namespaceIndex < withoutSuffix.length - 1) {
    return withoutSuffix.slice(namespaceIndex + 1);
  }

  return withoutSuffix || value;
}

export function readableViewTreeName(typeLabel: string, nameLabel: string | null): string | null {
  if (!nameLabel || nameLabel === typeLabel) return null;
  const instanceMatch = nameLabel.match(/^(.+?)(#\d+)$/);
  if (instanceMatch && instanceMatch[1] === typeLabel) {
    return instanceMatch[2];
  }
  return nameLabel;
}

function resolveHotEditFrame(node: HierarchyLayerNode, draft?: HierarchyNodeHotEditDraft) {
  return {
    x: draft?.frame?.x ?? node.frame.x,
    y: draft?.frame?.y ?? node.frame.y,
    width: draft?.frame?.width ?? node.frame.width,
    height: draft?.frame?.height ?? node.frame.height,
  };
}

function resolveHotEditOpacity(node: HierarchyLayerNode, draft?: HierarchyNodeHotEditDraft) {
  return draft?.opacity ?? node.style?.alpha ?? node.layer?.opacity ?? 1;
}

function resolveHotEditCornerRadius(node: HierarchyLayerNode, draft?: HierarchyNodeHotEditDraft) {
  return draft?.cornerRadius ?? node.style?.cornerRadius ?? node.layer?.cornerRadius ?? 0;
}

function resolveHotEditBackgroundColor(node: HierarchyLayerNode, draft?: HierarchyNodeHotEditDraft) {
  return draft?.backgroundColor ?? node.style?.backgroundColor ?? node.color;
}

function resolveHotEditHidden(node: HierarchyLayerNode, draft?: HierarchyNodeHotEditDraft) {
  if (typeof draft?.hidden === "boolean") return draft.hidden;
  if (typeof node.style?.alpha === "number" && node.style.alpha <= 0) return true;
  if (typeof node.layer?.isHidden === "boolean") return node.layer.isHidden;
  if (typeof node.view?.isHidden === "boolean") return node.view.isHidden;
  return !node.visible;
}

export function viewNodeHighlightForScene(scene: HierarchyScene, nodeId: string | null, draft?: HierarchyNodeHotEditDraft): ViewNodeHighlight | null {
  if (!nodeId || scene.viewport.width <= 0 || scene.viewport.height <= 0) return null;
  const node = scene.nodes.find((candidate) => candidate.id === nodeId);
  if (!node) return null;
  const frame = resolveHotEditFrame(node, draft);
  if (frame.width <= 0 || frame.height <= 0) return null;

  const left = Math.max(0, Math.min(100, (frame.x / scene.viewport.width) * 100));
  const top = Math.max(0, Math.min(100, (frame.y / scene.viewport.height) * 100));
  const right = Math.max(0, Math.min(100, ((frame.x + frame.width) / scene.viewport.width) * 100));
  const bottom = Math.max(0, Math.min(100, ((frame.y + frame.height) / scene.viewport.height) * 100));
  const opacity = resolveHotEditHidden(node, draft) ? 0.24 : resolveHotEditOpacity(node, draft);

  return {
    node,
    isHiddenDraft: resolveHotEditHidden(node, draft),
    style: {
      left: `${left}%`,
      top: `${top}%`,
      width: `${Math.max(0, right - left)}%`,
      height: `${Math.max(0, bottom - top)}%`,
      "--view-node-accent": resolveHotEditBackgroundColor(node, draft),
      "--view-node-alpha": opacity.toString(),
      "--view-node-radius": `${resolveHotEditCornerRadius(node, draft)}px`,
    } as CSSProperties,
  };
}

export function hierarchyNodeAtPoint(scene: HierarchyScene, xPercent: number, yPercent: number) {
  const x = (xPercent / 100) * scene.viewport.width;
  const y = (yPercent / 100) * scene.viewport.height;
  return scene.nodes
    .filter((node) => {
      if (!node.visible) return false;
      if (node.frame.width <= 0 || node.frame.height <= 0) return false;
      return x >= node.frame.x &&
        x <= node.frame.x + node.frame.width &&
        y >= node.frame.y &&
        y <= node.frame.y + node.frame.height;
    })
    .sort((first, second) => second.depth - first.depth)
    .at(0) ?? null;
}

export function resolveControllerShellBadge(scene: HierarchyScene | undefined, selectedNodeId: string | null): ControllerShellBadge | null {
  if (!scene || scene.platform !== "ios") return null;
  const selectedOwner = selectedNodeId ? controllerAncestorForNode(scene, selectedNodeId) : null;
  if (selectedOwner) {
    return {
      name: shortClassName(selectedOwner.type),
      className: selectedOwner.type,
      stack: controllerStackNames(scene.controllerContext?.stack, selectedOwner),
      source: scene.controllerContext?.source ?? "selected-node-owner",
      isFallback: scene.controllerContext?.source !== "runtime-route",
    };
  }

  const context = scene.controllerContext;
  if (context?.activeControllerName || context?.activeControllerClassName) {
    return {
      name: shortClassName(context.activeControllerClassName ?? context.activeControllerName ?? "UIViewController"),
      className: context.activeControllerClassName,
      stack: controllerStackNames(context.stack),
      source: context.source,
      isFallback: context.source !== "runtime-route",
    };
  }

  const fallback = fallbackControllerNodeForScene(scene);
  if (!fallback) return null;
  return {
    name: shortClassName(fallback.type),
    className: fallback.type,
    stack: [controllerNodeDisplayName(fallback)],
    source: "scene-controller-node-fallback",
    isFallback: true,
  };
}

function controllerAncestorForNode(scene: HierarchyScene, nodeId: string) {
  const nodesById = new Map(scene.nodes.map((node) => [node.id, node]));
  let cursor = nodesById.get(nodeId) ?? null;
  while (cursor) {
    if (isControllerNode(cursor)) return cursor;
    cursor = cursor.parentId ? nodesById.get(cursor.parentId) ?? null : null;
  }
  return null;
}

function fallbackControllerNodeForScene(scene: HierarchyScene) {
  return scene.nodes
    .filter(isControllerNode)
    .filter((node) => node.visible)
    .filter((node) => !/UITrackingElementWindowController|UIEditingOverlayViewController/.test(node.type))
    .sort((first, second) => {
      const area = second.frame.width * second.frame.height - first.frame.width * first.frame.height;
      return area === 0 ? second.depth - first.depth : area;
    })
    .at(0) ?? null;
}

function isControllerNode(node: HierarchyLayerNode) {
  return node.source === "runtime-controller" ||
    node.raw?.role === "UIViewController" ||
    node.id.startsWith("ios:controller:");
}

function controllerNodeDisplayName(node: HierarchyLayerNode) {
  return node.name.replace(/#\d+$/, "") || shortClassName(node.type);
}

function controllerStackNames(stack: HierarchyControllerEntry[] | undefined, selectedOwner?: HierarchyLayerNode) {
  const names = (stack ?? []).map((entry) => shortClassName(entry.className || entry.name)).filter(Boolean);
  if (selectedOwner) {
    const selectedName = controllerNodeDisplayName(selectedOwner);
    return names.includes(selectedName) ? names : [...names, selectedName];
  }
  return names;
}

function shortClassName(className: string) {
  const lastSegment = className.split(".").at(-1) ?? className;
  const swiftPrivateName = lastSegment.match(/^_TtC\d+[A-Za-z_][A-Za-z0-9_]*P\d+_[A-Fa-f0-9]{32}\d+([A-Za-z_][A-Za-z0-9_]*)$/);
  if (swiftPrivateName?.[1]) return swiftPrivateName[1];
  return lastSegment;
}

export function targetKindLabel(target: DeviceTarget) {
  if (target.scope === "real" || target.kind === "real-device" || target.realSource?.endsWith("real-device")) {
    return "真机";
  }
  return platformDetail[target.platform];
}

export function platformName(platform: string) {
  const normalized = platform.toLowerCase();
  if (normalized === "ios") return "iOS";
  if (normalized === "android") return "Android";
  if (normalized === "harmony") return "Harmony";
  return platform;
}

export function localizeLogEntry(entry: LogEntry, language: DisplayLanguage): LocalizedLogEntry {
  return {
    timeLabel: formatLogTime(entry.time, language),
    levelLabel: logLevelLabel[language][entry.level],
    sourceLabel: inferLogSource(entry.message, language),
    messageLabel: localizeLogMessage(entry.message, language),
    originalMessage: entry.message,
  };
}

function formatLogTime(time: string, language: DisplayLanguage) {
  const trimmed = time.trim();
  const parsed = Date.parse(trimmed);
  if (!Number.isNaN(parsed) && /[TZ]/.test(trimmed)) {
    return new Intl.DateTimeFormat(language, {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hour12: false,
    }).format(new Date(parsed));
  }
  return trimmed || (language === "zh-CN" ? "未知时间" : "Unknown time");
}

function inferLogSource(message: string, language: DisplayLanguage) {
  if (/(Android|ADB|adb)/i.test(message)) return "Android";
  if (/(Harmony|HDC|hdc)/i.test(message)) return "Harmony";
  if (/(App launched|App runtime)/i.test(message)) return language === "zh-CN" ? "应用" : "App";
  if (/(iOS|simctl|framebuffer)/i.test(message)) return "iOS";
  if (/(network|proxy|route|timeout)/i.test(message)) return language === "zh-CN" ? "网络" : "Network";
  if (/(triton| exit=)/i.test(message)) return "CLI";
  return language === "zh-CN" ? "系统" : "System";
}

function localizeLogMessage(message: string, language: DisplayLanguage) {
  const trimmed = message.replace(/\s+/g, " ").trim();
  const hostSelection = trimmed.match(/^(\w+) target (.+) selected from readonly host discovery$/);
  if (hostSelection) {
    if (language === "en-US") {
      return `${platformName(hostSelection[1])} target selected from read-only host discovery: ${hostSelection[2]}`;
    }
    return `已从只读 host 发现结果选择 ${platformName(hostSelection[1])} 目标：${hostSelection[2]}`;
  }

  const missingEvidence = trimmed.match(/^(\w+) network\/app runtime evidence not exposed by CLI DTO(?: blocked=(.+))?$/);
  if (missingEvidence) {
    if (language === "en-US") {
      const blocked = missingEvidence[2] ? ` Blocked by: ${missingEvidence[2]}` : "";
      return `CLI DTO has not exposed ${platformName(missingEvidence[1])} network or App runtime evidence.${blocked}`;
    }
    const blocked = missingEvidence[2] ? `；阻塞原因：${missingEvidence[2]}` : "";
    return `CLI DTO 尚未暴露 ${platformName(missingEvidence[1])} 的网络或 App runtime 证据${blocked}`;
  }

  const commandOutput = trimmed.match(/^(.+?) exit=([^ ]+)(?: (.*))?$/);
  if (commandOutput) {
    if (language === "en-US") {
      const summary = commandOutput[3] ? ` Summary: ${commandOutput[3]}.` : "";
      return `Command completed: ${commandOutput[1]} (exit code ${commandOutput[2]}).${summary}`;
    }
    const summary = commandOutput[3] ? `；摘要：${commandOutput[3]}` : "";
    return `命令执行完成：${commandOutput[1]}（退出码 ${commandOutput[2]}）${summary}`;
  }

  const framebuffer = trimmed.match(/^Fetched framebuffer through simctl in (\d+) ms$/);
  if (framebuffer) {
    return language === "zh-CN"
      ? `已通过 simctl 获取画面，耗时 ${framebuffer[1]} 毫秒`
      : `Fetched framebuffer through simctl in ${framebuffer[1]} ms`;
  }

  const adbReady = trimmed.match(/^ADB target ready: (.+)$/);
  if (adbReady) {
    return language === "zh-CN" ? `Android ADB 目标已就绪：${adbReady[1]}` : `Android ADB target is ready: ${adbReady[1]}`;
  }

  if (trimmed === "HDC target discovered from plain list fallback") {
    return language === "zh-CN" ? "已从 HDC 列表 fallback 发现目标" : "HDC target discovered from plain list fallback";
  }

  const dictionary: Record<DisplayLanguage, Record<string, string>> = {
    "zh-CN": {
      "Selected host iOS target and paired embedded runtime": "已选择 iOS 目标，并匹配到内嵌 App runtime",
      "Network proxy restore snapshot pending verification": "网络代理恢复快照等待验证",
      "Mock route returned conflict for dry-run request": "Mock 路由在试运行请求中返回冲突",
      "Input command completed through adb shell input": "已通过 adb shell input 完成输入命令",
      "Snapshot display returned JPEG framebuffer": "快照接口返回 JPEG 画面",
      "Proxy lane reports limited host visibility": "代理通道报告 host 可见性受限",
      "App launched": "应用已启动",
      "Network timeout": "网络请求超时",
      ok: "成功",
      failed: "失败",
      "no output": "无输出",
    },
    "en-US": {
      "Selected host iOS target and paired embedded runtime": "Selected iOS target and paired embedded App runtime",
      "Network proxy restore snapshot pending verification": "Network proxy restore snapshot is pending verification",
      "Mock route returned conflict for dry-run request": "Mock route returned a conflict for the dry-run request",
      "Input command completed through adb shell input": "Input command completed through adb shell input",
      "Snapshot display returned JPEG framebuffer": "Snapshot display returned a JPEG framebuffer",
      "Proxy lane reports limited host visibility": "Proxy lane reports limited host visibility",
      "App launched": "App launched",
      "Network timeout": "Network timeout",
      ok: "Succeeded",
      failed: "Failed",
      "no output": "No output",
    },
  };

  return dictionary[language][trimmed] ?? (trimmed || (language === "zh-CN" ? "无日志内容" : "No log message"));
}

export function localizeStatusLabel(label: string) {
  const labels: Record<string, string> = {
    Booted: "已启动",
    Shutdown: "已关机",
    Ready: "就绪",
    Offline: "离线",
    device_not_trusted: "未信任",
    developer_mode_required: "需开发者模式",
    device_locked: "设备锁定",
    ddi_missing: "缺少 DDI",
    unauthorized: "未授权",
    Unknown: "未知",
  };
  return labels[label] ?? label;
}
