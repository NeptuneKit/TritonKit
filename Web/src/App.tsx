import { useCallback, useEffect, useMemo, useRef, useState, type ChangeEvent, type ClipboardEvent, type CSSProperties, type KeyboardEvent, type PointerEvent } from "react";
import {
  Activity,
  Braces,
  ChevronDown,
  Clock3,
  DatabaseZap,
  Gauge,
  Info,
  Keyboard,
  Minus,
  Network,
  PanelLeft,
  Plus,
  RefreshCw,
  Search,
  Settings2,
  TerminalSquare,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { HostBridgeNotice } from "./components/HostBridgeNotice";
import { logs, networkEvents } from "./data/mockData";
import { describeHostBridgePresentation } from "./data/hostBridgePresentation";
import { fetchHostHierarchy, fetchHostLogs, fetchHostScreenshot, fetchHostTargets, type HostInputResponse, sendHostInput } from "./data/iosSimulatorClient";
import type {
  BridgeCommandOutput,
  DeviceFrameOrientation,
  DeviceTarget,
  HierarchyControllerEntry,
  HierarchyLayerNode,
  HierarchyScene,
  LogEntry,
  NetworkEvent,
} from "./types";

const platformLabel = {
  ios: "iOS",
  android: "Android",
  harmony: "Harmony",
};

const platformDetail = {
  ios: "模拟器",
  android: "仿真器",
  harmony: "DevEco 仿真器",
};

const modeLabel: Record<DisplayLanguage, Record<NetworkEvent["mode"], string>> = {
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

const logLevelLabel: Record<DisplayLanguage, Record<LogEntry["level"], string>> = {
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

type BridgeState = {
  loading: boolean;
  error?: string;
  capturedAt?: string;
  sourceCommands: string[];
};

type LivePreviewState = {
  frameCount: number;
  lastFrameAt: number;
  status: "live" | "error";
};

type InputActivity = {
  status: "dispatching" | "refreshing";
  label: string;
};

type ReadonlyGestureIntent =
  | {
      action: "tap";
      platform: DeviceTarget["platform"];
      target: string;
      x: number;
      y: number;
      width?: number;
      height?: number;
    }
  | {
      action: "longPress";
      platform: DeviceTarget["platform"];
      target: string;
      x: number;
      y: number;
      width?: number;
      height?: number;
      duration: number;
    }
  | {
      action: "swipe";
      platform: DeviceTarget["platform"];
      target: string;
      startX: number;
      startY: number;
      endX: number;
      endY: number;
      width?: number;
      height?: number;
      duration?: number;
    }
  | {
      action: "pinch";
      platform: DeviceTarget["platform"];
      target: string;
      centerX: number;
      centerY: number;
      startDistance: number;
      endDistance: number;
      scale: number;
      width?: number;
      height?: number;
      duration?: number;
    };

type ReadonlyTextIntent =
  | {
      action: "type";
      text: string;
    }
  | {
      action: "paste";
      text: string;
    }
  | {
      action: "deleteBackward";
    };

type ReadonlyInputIntent = ReadonlyGestureIntent | ReadonlyTextIntent;

type GesturePoint = {
  x: number;
  y: number;
  xPercent: number;
  yPercent: number;
};

type SingleGestureState = {
  pointerId: number;
  start: GesturePoint;
  startedAt: number;
};

type PinchSnapshot = {
  centerX: number;
  centerY: number;
  centerXPercent: number;
  centerYPercent: number;
  distance: number;
};

type PinchGestureState = {
  start: PinchSnapshot;
  startedAt: number;
  dispatched: boolean;
};

type GesturePreview =
  | {
      kind: "tap";
      xPercent: number;
      yPercent: number;
    }
  | {
      kind: "longPress";
      xPercent: number;
      yPercent: number;
    }
  | {
      kind: "swipe";
      startXPercent: number;
      startYPercent: number;
      endXPercent: number;
      endYPercent: number;
      distance: number;
    }
  | {
      kind: "pinch";
      centerXPercent: number;
      centerYPercent: number;
      startDistance: number;
      endDistance: number;
      scale: number;
    };

type KeyboardRelayState = {
  xPercent: number;
  yPercent: number;
};

type SidebarPanel = "devices" | "view-tree";
type DevtoolsPanel = "config" | "network" | "logs" | "settings";
type DisplayLanguage = "zh-CN" | "en-US";

type ViewTreeNode = {
  id: string;
  type: string;
  name?: string;
  children?: ViewTreeNode[];
};

type DeviceHubRouteState = {
  targetId?: string;
  panel?: SidebarPanel;
  nodeId?: string;
};

type ViewNodeHighlight = {
  node: HierarchyLayerNode;
  style: CSSProperties;
  isHiddenDraft: boolean;
};

type ControllerShellBadge = {
  name: string;
  className?: string;
  stack: string[];
  source: string;
  isFallback: boolean;
};

type HierarchyCacheEntry = {
  loading: boolean;
  error?: string;
  scene?: HierarchyScene;
};

type HierarchyNodeHotEditDraft = {
  frame?: Partial<HierarchyLayerNode["frame"]>;
  opacity?: number;
  cornerRadius?: number;
  backgroundColor?: string;
  hidden?: boolean;
};

const previewFpsMin = 1;
const previewFpsMax = 60;
const longPressThresholdMs = 520;
const tapDistanceThreshold = 18;
const emptyTargetId = "__no-host-target__";
const displayLanguageStorageKey = "tritonkit.web.displayLanguage";

const displayLanguageOptions: Array<{ id: DisplayLanguage; label: string; detail: string }> = [
  { id: "zh-CN", label: "简体中文", detail: "中文界面标签与日志说明" },
  { id: "en-US", label: "English", detail: "English tool labels and log messages" },
];

const emptyTarget: DeviceTarget = {
  id: emptyTargetId,
  name: "未选择 target",
  platform: "ios",
  device: "Host bridge",
  appName: "暂无运行中的设备",
  bundleId: "unknown",
  os: "等待 host targets",
  status: "limited",
  statusLabel: "No host targets",
  transport: "triton host bridge",
  screenshotTone: "ios-screen",
  screenSize: "No framebuffer",
  fps: 0,
  latencyMs: 0,
  proxyMode: "off",
  proxyLabel: "No mock data",
  hierarchyNodes: 0,
  lastAction: "Host target discovery has not returned a selectable target",
  actionResult: "warning",
  accent: "#8bb6ff",
  Icon: Activity,
  readonly: true,
};

function viewTreeNodesForScene(scene: HierarchyScene): ViewTreeNode[] {
  const nodesByParent = new Map<string | undefined, HierarchyLayerNode[]>();
  for (const node of scene.nodes) {
    const siblings = nodesByParent.get(node.parentId) ?? [];
    siblings.push(node);
    nodesByParent.set(node.parentId, siblings);
  }

  const buildNode = (node: HierarchyLayerNode): ViewTreeNode => ({
    id: node.id,
    type: node.type,
    name: node.name,
    children: nodesByParent.get(node.id)?.map(buildNode),
  });

  return (nodesByParent.get(undefined) ?? []).map(buildNode);
}

function defaultViewTreeSelection(scene: HierarchyScene): string {
  return scene.nodes.find((node) => node.interactive && node.depth >= 3)?.id ?? scene.rootId;
}

function readableViewTreeLabel(value: string): string {
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
    return `${swiftName}${suffix}`;
  }

  const namespaceIndex = withoutSuffix.lastIndexOf(".");
  if (namespaceIndex >= 0 && namespaceIndex < withoutSuffix.length - 1) {
    return `${withoutSuffix.slice(namespaceIndex + 1)}${suffix}`;
  }

  return value;
}

function readableViewTreeName(typeLabel: string, nameLabel: string | null): string | null {
  if (!nameLabel || nameLabel === typeLabel) return null;
  const instanceMatch = nameLabel.match(/^(.+?)(#\d+)$/);
  if (instanceMatch && instanceMatch[1] === typeLabel) {
    return instanceMatch[2];
  }
  return nameLabel;
}

function selectedHierarchyNodeForScene(scene: HierarchyScene | undefined, nodeId: string | null): HierarchyLayerNode | null {
  if (!scene || !nodeId) return null;
  return scene.nodes.find((candidate) => candidate.id === nodeId) ?? null;
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

function viewNodeHighlightForScene(scene: HierarchyScene, nodeId: string | null, draft?: HierarchyNodeHotEditDraft): ViewNodeHighlight | null {
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

function hierarchyNodeAtPoint(scene: HierarchyScene, xPercent: number, yPercent: number) {
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

function resolveControllerShellBadge(scene: HierarchyScene | undefined, selectedNodeId: string | null): ControllerShellBadge | null {
  if (!scene || scene.platform !== "ios") return null;
  const selectedOwner = selectedNodeId ? controllerAncestorForNode(scene, selectedNodeId) : null;
  if (selectedOwner) {
    return {
      name: controllerNodeDisplayName(selectedOwner),
      className: selectedOwner.type,
      stack: controllerStackNames(scene.controllerContext?.stack, selectedOwner),
      source: scene.controllerContext?.source ?? "selected-node-owner",
      isFallback: scene.controllerContext?.source !== "runtime-route",
    };
  }

  const context = scene.controllerContext;
  if (context?.activeControllerName || context?.activeControllerClassName) {
    return {
      name: context.activeControllerName ?? shortClassName(context.activeControllerClassName ?? "UIViewController"),
      className: context.activeControllerClassName,
      stack: controllerStackNames(context.stack),
      source: context.source,
      isFallback: context.source !== "runtime-route",
    };
  }

  const fallback = fallbackControllerNodeForScene(scene);
  if (!fallback) return null;
  return {
    name: controllerNodeDisplayName(fallback),
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
  const names = (stack ?? []).map((entry) => entry.name || shortClassName(entry.className)).filter(Boolean);
  if (selectedOwner) {
    const selectedName = controllerNodeDisplayName(selectedOwner);
    return names.includes(selectedName) ? names : [...names, selectedName];
  }
  return names;
}

function shortClassName(className: string) {
  return className.split(".").at(-1) ?? className;
}

function normalizePreviewFps(value: number) {
  if (!Number.isFinite(value)) return previewFpsMin;
  return Math.max(previewFpsMin, Math.min(previewFpsMax, Math.round(value)));
}

function fpsToRefreshIntervalMs(fps: number) {
  return Math.max(1000 / previewFpsMax, Math.round(1000 / normalizePreviewFps(fps)));
}

function isDisplayLanguage(value: string | null): value is DisplayLanguage {
  return value === "zh-CN" || value === "en-US";
}

function readDisplayLanguagePreference(): DisplayLanguage {
  if (typeof window === "undefined") return "zh-CN";
  try {
    const value = window.localStorage.getItem(displayLanguageStorageKey);
    return isDisplayLanguage(value) ? value : "zh-CN";
  } catch {
    return "zh-CN";
  }
}

function writeDisplayLanguagePreference(language: DisplayLanguage) {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(displayLanguageStorageKey, language);
  } catch {
    // localStorage may be unavailable in restricted browser contexts.
  }
}

function readDeviceHubRoute(): DeviceHubRouteState {
  if (typeof window === "undefined") return {};
  const params = new URL(window.location.href).searchParams;
  return {
    targetId: params.get("target") ?? undefined,
    panel: parseSidebarPanel(params.get("panel")),
    nodeId: params.get("node") ?? undefined,
  };
}

function parseSidebarPanel(value: string | null): SidebarPanel | undefined {
  if (value === "devices" || value === "view-tree") {
    return value;
  }
  return undefined;
}

function writeDeviceHubRoute(route: Required<Pick<DeviceHubRouteState, "targetId">> & DeviceHubRouteState) {
  if (typeof window === "undefined") return;
  const url = new URL(window.location.href);
  url.searchParams.set("target", route.targetId);
  if (route.panel && route.panel !== "devices") {
    url.searchParams.set("panel", route.panel);
  } else {
    url.searchParams.delete("panel");
  }
  if (route.nodeId) {
    url.searchParams.set("node", route.nodeId);
  } else {
    url.searchParams.delete("node");
  }

  const nextURL = `${url.pathname}${url.search}${url.hash}`;
  const currentURL = `${window.location.pathname}${window.location.search}${window.location.hash}`;
  if (nextURL !== currentURL) {
    window.history.replaceState(null, "", nextURL);
  }
}

export function App() {
  const initialRoute = useMemo(() => readDeviceHubRoute(), []);
  const [selectedId, setSelectedId] = useState(initialRoute.targetId ?? "");
  const [hostTargets, setHostTargets] = useState<DeviceTarget[]>([]);
  const [targetSearch, setTargetSearch] = useState("");
  const [bridge, setBridge] = useState<BridgeState>({ loading: true, sourceCommands: [] });
  const [bridgeOutputs, setBridgeOutputs] = useState<BridgeCommandOutput[]>([]);
  const [interactionLogs, setInteractionLogs] = useState<LogEntry[]>([]);
  const [activeDevtoolsPanel, setActiveDevtoolsPanel] = useState<DevtoolsPanel>("config");
  const [displayLanguage, setDisplayLanguage] = useState<DisplayLanguage>(() => readDisplayLanguagePreference());
  const [isSidebarVisible, setIsSidebarVisible] = useState(true);
  const [sidebarPanel, setSidebarPanel] = useState<SidebarPanel>(initialRoute.panel ?? (initialRoute.nodeId ? "view-tree" : "devices"));
  const [isToolbarTargetMenuOpen, setIsToolbarTargetMenuOpen] = useState(false);
  const [selectedHierarchyNode, setSelectedHierarchyNode] = useState<string | null>(initialRoute.nodeId ?? null);
  const [hierarchyReloadKey, setHierarchyReloadKey] = useState(0);
  const [isRefreshingAll, setIsRefreshingAll] = useState(false);
  const [lastActionById, setLastActionById] = useState<
    Record<string, { lastAction: string; actionResult: DeviceTarget["actionResult"] }>
  >({});
  const [screenshotById, setScreenshotById] = useState<
    Record<string, { dataUrl: string; pixelWidth: number | null; pixelHeight: number | null }>
  >({});
  const [hostLogsById, setHostLogsById] = useState<Record<string, LogEntry[]>>({});
  const [hierarchyById, setHierarchyById] = useState<Record<string, HierarchyCacheEntry>>({});
  const [hierarchyNodeDraftsByTargetId, setHierarchyNodeDraftsByTargetId] = useState<Record<string, Record<string, HierarchyNodeHotEditDraft>>>({});
  const [livePreviewById, setLivePreviewById] = useState<Record<string, LivePreviewState>>({});
  const [previewFpsById, setPreviewFpsById] = useState<Record<string, number>>({});
  const [snapshotModeByTargetId, setSnapshotModeByTargetId] = useState<Record<string, boolean>>({});
  const [snapshotRefreshingByTargetId, setSnapshotRefreshingByTargetId] = useState<Record<string, boolean>>({});
  const [inputActivityById, setInputActivityById] = useState<Record<string, InputActivity | undefined>>({});
  const [screenshotError, setScreenshotError] = useState<string | undefined>();
  const pageTargets = hostTargets;
  const filteredTargets = useMemo(() => filterTargetsBySearch(pageTargets, targetSearch), [pageTargets, targetSearch]);
  const bridgePresentation = useMemo(
    () => describeHostBridgePresentation(bridge, hostTargets.length),
    [bridge, hostTargets.length]
  );
  const selected = useMemo(
    () => pageTargets.find((target) => target.id === selectedId) ?? pageTargets[0] ?? emptyTarget,
    [pageTargets, selectedId]
  );
  const selectedHierarchy = hierarchyById[selected.id];
  const selectedHierarchyNodeData = useMemo(
    () => selectedHierarchyNodeForScene(selectedHierarchy?.scene, selectedHierarchyNode),
    [selectedHierarchy?.scene, selectedHierarchyNode]
  );
  const selectedHierarchyNodeDraft =
    selectedHierarchyNode && selectedHierarchyNodeData
      ? hierarchyNodeDraftsByTargetId[selected.id]?.[selectedHierarchyNode]
      : undefined;
  const selectedHasScreenshot = Boolean(screenshotById[selected.id]);
  const selectedPreviewFps = previewFpsById[selected.id] ?? normalizePreviewFps(Math.max(selected.fps, 1));
  const selectedWithScreenshot = useMemo(
    () => ({
      ...selected,
      screenshotDataUrl: screenshotById[selected.id]?.dataUrl,
      screenshotPixelWidth: screenshotById[selected.id]?.pixelWidth,
      screenshotPixelHeight: screenshotById[selected.id]?.pixelHeight,
      frameOrientation: resolveFrameOrientation(selected, screenshotById[selected.id]),
      fps: selectedPreviewFps,
      lastAction: lastActionById[selected.id]?.lastAction ?? selected.lastAction,
      actionResult: lastActionById[selected.id]?.actionResult ?? selected.actionResult,
    }),
    [lastActionById, screenshotById, selected, selectedPreviewFps]
  );
  const selectedLivePreview = livePreviewById[selected.id];
  const selectedInputActivity = inputActivityById[selected.id];
  const isSelectedSnapshotMode = snapshotModeByTargetId[selected.id] ?? false;
  const isSelectedSnapshotRefreshing = snapshotRefreshingByTargetId[selected.id] ?? false;
  const selectedEvents = useMemo(
    () => networkEvents[selected.id] ?? hostNetworkEvidenceForTarget(selected),
    [selected]
  );
  const isDiscoveringHostTargets = bridge.loading && hostTargets.length === 0;
  const selectedLogs = useMemo(
    () => [
      ...interactionLogs,
      ...(hostLogsById[selected.id] ?? hostLogsForTarget(selected)),
      ...commandOutputsToLogs(bridgeOutputs),
      ...(logs[selected.id] ?? []),
    ].slice(0, 8),
    [bridgeOutputs, hostLogsById, interactionLogs, selected]
  );
  useEffect(() => {
    const handlePopState = () => {
      const route = readDeviceHubRoute();
      if (route.targetId) {
        setSelectedId(route.targetId);
      }
      setSidebarPanel(route.panel ?? (route.nodeId ? "view-tree" : "devices"));
      setSelectedHierarchyNode(route.nodeId ?? null);
    };

    window.addEventListener("popstate", handlePopState);
    return () => {
      window.removeEventListener("popstate", handlePopState);
    };
  }, []);

  useEffect(() => {
    if (selected.id === emptyTargetId) return;
    writeDeviceHubRoute({
      targetId: selected.id,
      panel: sidebarPanel,
      nodeId: selectedHierarchyNode ?? undefined,
    });
  }, [selected.id, selectedHierarchyNode, sidebarPanel]);

  useEffect(() => {
    writeDisplayLanguagePreference(displayLanguage);
  }, [displayLanguage]);

  useEffect(() => {
    if (!selectedHierarchyNode) return;
    const scene = selectedHierarchy?.scene;
    if (!scene) return;
    if (!scene.nodes.some((node) => node.id === selectedHierarchyNode)) {
      setSelectedHierarchyNode(null);
    }
  }, [selectedHierarchy?.scene, selectedHierarchyNode]);

  useEffect(() => {
    if (sidebarPanel !== "view-tree") return;
    if (selected.id === emptyTargetId || !(selected.targetSelector ?? selected.udid ?? selected.id)) return;
    if (hierarchyById[selected.id]) return;

    let cancelled = false;
    setHierarchyById((entries) => ({
      ...entries,
      [selected.id]: { loading: true },
    }));

    fetchHostHierarchy(selected)
      .then((scene) => {
        if (cancelled) return;
        setHierarchyById((entries) => ({
          ...entries,
          [selected.id]: { loading: false, scene },
        }));
      })
      .catch((error: unknown) => {
        if (cancelled) return;
        setHierarchyById((entries) => ({
          ...entries,
          [selected.id]: {
            loading: false,
            error: error instanceof Error ? error.message : String(error),
          },
        }));
      });

    return () => {
      cancelled = true;
    };
  }, [hierarchyReloadKey, selected, sidebarPanel]);

  const loadHostTargets = async (preferredSelectedId: string) => {
    const result = await fetchHostTargets();
    setHostTargets(result.targets);
    setBridge({
      loading: false,
      capturedAt: result.capturedAt,
      sourceCommands: result.sourceCommands,
    });
    setBridgeOutputs(result.commandOutputs);
    const nextSelected = result.targets.find((target) => target.id === preferredSelectedId) ?? result.targets[0];
    if (nextSelected && nextSelected.id !== selectedId) {
      setSelectedId(nextSelected.id);
    }
    return nextSelected;
  };

  useEffect(() => {
    let cancelled = false;
    const initialSelectedId = selectedId;
    fetchHostTargets()
      .then((result) => {
        if (cancelled) return;
        setHostTargets(result.targets);
        setBridge({
          loading: false,
          capturedAt: result.capturedAt,
          sourceCommands: result.sourceCommands,
        });
        setBridgeOutputs(result.commandOutputs);
        if (result.targets.length > 0 && !result.targets.some((target) => target.id === initialSelectedId)) {
          setSelectedId(result.targets[0].id);
        }
      })
      .catch((error: unknown) => {
        if (cancelled) return;
        setBridge({
          loading: false,
          sourceCommands: [],
          error: error instanceof Error ? error.message : String(error),
        });
      });
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (!(selected.realSource === "ios-simulator" && selected.readonly)) {
      return;
    }
    if (hostLogsById[selected.id]) {
      return;
    }

    let cancelled = false;
    fetchHostLogs(selected)
      .then((result) => {
        if (cancelled) return;
        setHostLogsById((current) => ({
          ...current,
          [selected.id]: result.entries,
        }));
      })
      .catch(() => {
        if (cancelled) return;
      });

    return () => {
      cancelled = true;
    };
  }, [hostLogsById, selected]);

  const refreshScreenshot = useCallback(async (target: DeviceTarget, options: { live?: boolean } = {}) => {
    if (!target.realSource || !target.canScreenshot || !(target.targetSelector ?? target.udid)) {
      return;
    }
    try {
      const result = await fetchHostScreenshot(target);
      setScreenshotById((current) => ({
        ...current,
        [target.id]: {
          dataUrl: result.dataUrl,
          pixelWidth: result.pixelWidth,
          pixelHeight: result.pixelHeight,
        },
      }));
      if (options.live) {
        setLivePreviewById((current) => ({
          ...current,
          [target.id]: {
            frameCount: (current[target.id]?.frameCount ?? 0) + 1,
            lastFrameAt: Date.now(),
            status: "live",
          },
        }));
      }
      setScreenshotError(undefined);
    } catch (error) {
      if (options.live) {
        setLivePreviewById((current) => ({
          ...current,
          [target.id]: {
            frameCount: current[target.id]?.frameCount ?? 0,
            lastFrameAt: current[target.id]?.lastFrameAt ?? 0,
            status: "error",
          },
        }));
      }
      setScreenshotError(error instanceof Error ? error.message : String(error));
    }
  }, []);

  useEffect(() => {
    if (!selected.realSource || !selected.canScreenshot || !(selected.targetSelector ?? selected.udid)) {
      setScreenshotError(undefined);
      return;
    }
    if (selectedHasScreenshot) {
      return;
    }
    void refreshScreenshot(selected);
  }, [refreshScreenshot, selected, selected.canScreenshot, selected.id, selected.realSource, selected.targetSelector, selected.udid, selectedHasScreenshot]);

  useEffect(() => {
    if (!selected.realSource || !selected.canScreenshot || !(selected.targetSelector ?? selected.udid)) {
      return;
    }
    if (isSelectedSnapshotMode) {
      return;
    }
    let cancelled = false;
    let timer: number | undefined;
    let inFlight = false;

    const tick = async () => {
      if (cancelled || inFlight) {
        return;
      }
      inFlight = true;
      await refreshScreenshot(selected, { live: true });
      inFlight = false;
      if (!cancelled) {
        timer = window.setTimeout(tick, fpsToRefreshIntervalMs(selectedPreviewFps));
      }
    };

    timer = window.setTimeout(tick, selectedHasScreenshot ? fpsToRefreshIntervalMs(selectedPreviewFps) : 120);
    return () => {
      cancelled = true;
      if (timer) {
        window.clearTimeout(timer);
      }
    };
  }, [
    refreshScreenshot,
    selected,
    selected.canScreenshot,
    selected.id,
    selected.realSource,
    selected.targetSelector,
    selected.udid,
    selectedHasScreenshot,
    selectedPreviewFps,
    isSelectedSnapshotMode,
  ]);

  const handleRefreshAll = async () => {
    setIsRefreshingAll(true);
    setBridge((current) => ({ ...current, loading: true, error: undefined }));
    setHierarchyById({});
    setHierarchyReloadKey((current) => current + 1);
    setInteractionLogs((current) => [makeLog("info", "refresh all host data"), ...current]);
    try {
      const refreshedSelected = await loadHostTargets(selected.id);
      await refreshScreenshot(refreshedSelected ?? selected);
      setLastActionById((current) => ({
        ...current,
        [selected.id]: {
          lastAction: "Refreshed host targets and screenshot",
          actionResult: "ok",
        },
      }));
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      setBridge({
        loading: false,
        sourceCommands: [],
        error: message,
      });
      setInteractionLogs((current) => [makeLog("error", `refresh all failed ${message}`), ...current]);
      setLastActionById((current) => ({
        ...current,
        [selected.id]: {
          lastAction: "Refresh failed",
          actionResult: "failed",
        },
      }));
    } finally {
      setIsRefreshingAll(false);
    }
  };

  const handlePreviewFpsChange = (fps: number) => {
    setPreviewFpsById((current) => ({
      ...current,
      [selected.id]: normalizePreviewFps(fps),
    }));
  };

  const setSelectedSnapshotMode = (enabled: boolean) => {
    setSnapshotModeByTargetId((current) => ({
      ...current,
      [selected.id]: enabled,
    }));
    if (enabled) {
      setInputActivityById((current) => ({
        ...current,
        [selected.id]: undefined,
      }));
    }
  };

  const refreshSelectedSnapshot = async () => {
    const target = selected;
    if (!target.realSource || !target.canScreenshot || !(target.targetSelector ?? target.udid)) return;
    setSnapshotRefreshingByTargetId((current) => ({
      ...current,
      [target.id]: true,
    }));
    setInteractionLogs((current) => [makeLog("info", "snapshot refresh requested"), ...current]);
    try {
      await refreshScreenshot(target);
      if (target.realSource && (sidebarPanel === "view-tree" || hierarchyById[target.id]?.scene)) {
        setHierarchyById((entries) => ({
          ...entries,
          [target.id]: { ...entries[target.id], loading: true },
        }));
        const scene = await fetchHostHierarchy(target);
        setHierarchyById((entries) => ({
          ...entries,
          [target.id]: { loading: false, scene },
        }));
      }
      setLastActionById((current) => ({
        ...current,
        [target.id]: {
          lastAction: "Snapshot refreshed manually",
          actionResult: "ok",
        },
      }));
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      setInteractionLogs((current) => [makeLog("error", `snapshot refresh failed ${message}`), ...current]);
      setLastActionById((current) => ({
        ...current,
        [target.id]: {
          lastAction: "Snapshot refresh failed",
          actionResult: "failed",
        },
      }));
    } finally {
      setSnapshotRefreshingByTargetId((current) => ({
        ...current,
        [target.id]: false,
      }));
    }
  };

  const updateSelectedHierarchyNodeDraft = (patch: HierarchyNodeHotEditDraft) => {
    if (!selectedHierarchyNodeData || !selectedHierarchyNode) return;
    setHierarchyNodeDraftsByTargetId((current) => {
      const targetDrafts = current[selected.id] ?? {};
      const existing = targetDrafts[selectedHierarchyNode] ?? {};
      return {
        ...current,
        [selected.id]: {
          ...targetDrafts,
          [selectedHierarchyNode]: {
            ...existing,
            ...patch,
            frame: patch.frame ? { ...existing.frame, ...patch.frame } : existing.frame,
          },
        },
      };
    });
  };

  const resetSelectedHierarchyNodeDraft = () => {
    if (!selectedHierarchyNode) return;
    setHierarchyNodeDraftsByTargetId((current) => {
      const targetDrafts = current[selected.id];
      if (!targetDrafts?.[selectedHierarchyNode]) return current;
      const { [selectedHierarchyNode]: _removed, ...remainingTargetDrafts } = targetDrafts;
      return {
        ...current,
        [selected.id]: remainingTargetDrafts,
      };
    });
  };

  const handleInput = async (input: ReadonlyInputIntent): Promise<HostInputResponse | null> => {
    const activityTargetId = selected.id;
    const detail = describeInputIntent(input);
    if (!selected.canInput) {
      setLastActionById((current) => ({
        ...current,
        [activityTargetId]: {
          lastAction: "Input not available for " + input.action + " " + detail,
          actionResult: "warning",
        },
      }));
      setInteractionLogs((current) => [
        makeLog("warn", "input unavailable " + input.action + " " + detail),
        ...current,
      ]);
      return null;
    }

    setInputActivityById((current) => ({
      ...current,
      [activityTargetId]: {
        status: "dispatching",
        label: `dispatching ${input.action}`,
      },
    }));
    setLastActionById((current) => ({
      ...current,
      [activityTargetId]: {
        lastAction: "Dispatching " + input.action + " " + detail,
        actionResult: "ok",
      },
    }));
    try {
      const payload = inputPayload(input);
      const result = await sendHostInput(selected, payload);
      setInteractionLogs((current) => [
        makeLog(result.ok ? "info" : "warn", `runtime input ${input.action} ${result.message ?? (result.ok ? "ok" : "failed")}`),
        ...current,
      ]);
      setLastActionById((current) => ({
        ...current,
        [activityTargetId]: {
          lastAction: result.message ?? `Runtime ${input.action} submitted`,
          actionResult: result.ok ? "ok" : "warning",
        },
      }));
      setInputActivityById((current) => ({
        ...current,
        [activityTargetId]: {
          status: "refreshing",
          label: "refreshing App screen",
        },
      }));
      await refreshScreenshot(selected);
      return result;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      setInteractionLogs((current) => [makeLog("error", `runtime input failed ${message}`), ...current]);
      setLastActionById((current) => ({
        ...current,
        [activityTargetId]: {
          lastAction: `Input failed: ${message}`,
          actionResult: "failed",
        },
      }));
      return null;
    } finally {
      setInputActivityById((current) => ({
        ...current,
        [activityTargetId]: undefined,
      }));
    }
  };

  function describeInputIntent(input: ReadonlyInputIntent) {
    if (input.action === "tap") {
      return Math.round(input.x) + "," + Math.round(input.y);
    }
    if (input.action === "longPress") {
      return Math.round(input.x) + "," + Math.round(input.y) + " " + input.duration.toFixed(2) + "s";
    }
    if (input.action === "swipe") {
      return Math.round(input.startX) + "," + Math.round(input.startY) + " -> " + Math.round(input.endX) + "," + Math.round(input.endY);
    }
    if (input.action === "pinch") {
      return Math.round(input.centerX) + "," + Math.round(input.centerY) + " scale " + input.scale.toFixed(2);
    }
    if (input.action === "deleteBackward") {
      return "1 char";
    }
    return input.text.length + " chars";
  }

  function inputPayload(input: ReadonlyInputIntent) {
    if (input.action === "tap") {
      return {
        type: "tap",
        x: input.x,
        y: input.y,
        width: input.width,
        height: input.height,
      };
    }
    if (input.action === "longPress") {
      return {
        type: "longPress",
        x: input.x,
        y: input.y,
        width: input.width,
        height: input.height,
        duration: input.duration,
      };
    }
    if (input.action === "swipe") {
      return {
        type: "swipe",
        startX: input.startX,
        startY: input.startY,
        endX: input.endX,
        endY: input.endY,
        width: input.width,
        height: input.height,
        duration: input.duration,
      };
    }
    if (input.action === "pinch") {
      return {
        type: "pinch",
        centerX: input.centerX,
        centerY: input.centerY,
        startDistance: input.startDistance,
        endDistance: input.endDistance,
        scale: input.scale,
        width: input.width,
        height: input.height,
        duration: input.duration,
      };
    }
    if (input.action === "deleteBackward") {
      return {
        type: "deleteBackward",
      };
    }
    return {
      type: input.action,
      text: input.text,
    };
  }

  return (
    <main className="device-hub-shell">
      <section
        className="device-hub-window"
        aria-label="TritonKit 设备中心原型"
      >
        <DeviceHubToolbar
          target={selectedWithScreenshot}
          targets={pageTargets}
          bridgeSubtitle={bridgePresentation.toolbarLabel}
          isSidebarVisible={isSidebarVisible}
          isRefreshing={isRefreshingAll}
          isTargetMenuOpen={isToolbarTargetMenuOpen}
          onToggleSidebar={() => setIsSidebarVisible((current) => !current)}
          onRefresh={handleRefreshAll}
          onToggleTargetMenu={() => setIsToolbarTargetMenuOpen((current) => !current)}
          onCloseTargetMenu={() => setIsToolbarTargetMenuOpen(false)}
          onSelectTarget={(targetId) => {
            setSelectedId(targetId);
            setIsToolbarTargetMenuOpen(false);
          }}
        />
        <section className={`hub-body ${isSidebarVisible ? "" : "is-sidebar-hidden"}`}>
          {bridgePresentation.notice ? <HostBridgeNotice notice={bridgePresentation.notice} /> : null}
          {isSidebarVisible ? (
            <TargetNavigator
              selected={selectedWithScreenshot}
              targets={filteredTargets}
              hierarchy={selectedHierarchy}
              activePanel={sidebarPanel}
              searchValue={targetSearch}
              isSearching={targetSearch.trim().length > 0}
              onSearchChange={setTargetSearch}
              onPanelChange={setSidebarPanel}
              onSelect={setSelectedId}
              selectedHierarchyNode={selectedHierarchyNode}
              onSelectHierarchyNode={setSelectedHierarchyNode}
            />
          ) : null}
          <DeviceCanvas
            target={selectedWithScreenshot}
            hierarchyScene={selectedHierarchy?.scene}
            selectedHierarchyNode={selectedHierarchyNode}
            selectedHierarchyNodeDraft={selectedHierarchyNodeDraft}
            screenshotError={screenshotError}
            livePreview={selectedLivePreview}
            inputActivity={selectedInputActivity}
            isSnapshotMode={isSelectedSnapshotMode}
            isSnapshotRefreshing={isSelectedSnapshotRefreshing}
            isDiscoveringHostTargets={isDiscoveringHostTargets}
            onPreviewFpsChange={handlePreviewFpsChange}
            onSnapshotModeChange={setSelectedSnapshotMode}
            onSnapshotRefresh={refreshSelectedSnapshot}
            onSelectHierarchyNode={setSelectedHierarchyNode}
            onInput={handleInput}
          />
          <aside className="hub-devtools" aria-label="右侧开发者工具">
            <DevtoolsTabs
              activePanel={activeDevtoolsPanel}
              language={displayLanguage}
              onSelectPanel={setActiveDevtoolsPanel}
            />
            <div className="devtools-panel-stack">
              <Inspector
                hidden={activeDevtoolsPanel !== "config"}
                target={selectedWithScreenshot}
                events={selectedEvents}
                bridge={bridge}
                selectedNode={selectedHierarchyNodeData}
                selectedNodeDraft={selectedHierarchyNodeDraft}
                onSelectedNodeDraftChange={updateSelectedHierarchyNodeDraft}
                onSelectedNodeDraftReset={resetSelectedHierarchyNodeDraft}
              />
              <NetworkStrip
                id="network-evidence-panel"
                hidden={activeDevtoolsPanel !== "network"}
                language={displayLanguage}
                events={selectedEvents}
              />
              <LogStrip
                id="logs-evidence-panel"
                hidden={activeDevtoolsPanel !== "logs"}
                language={displayLanguage}
                entries={selectedLogs}
              />
              <SettingsPanel
                id="settings-panel"
                hidden={activeDevtoolsPanel !== "settings"}
                language={displayLanguage}
                onLanguageChange={setDisplayLanguage}
              />
            </div>
          </aside>
        </section>
      </section>
    </main>
  );
}

function resolveFrameOrientation(
  target: DeviceTarget,
  screenshot?: { pixelWidth: number | null; pixelHeight: number | null }
): DeviceFrameOrientation {
  if (screenshot?.pixelWidth && screenshot.pixelHeight) {
    return screenshot.pixelWidth >= screenshot.pixelHeight ? "landscape" : "portrait";
  }
  if (target.realSource === "ios-simulator") {
    return target.frameOrientation ?? "unknown";
  }
  return target.frameOrientation ?? "landscape";
}

function isRealTarget(target: DeviceTarget) {
  return target.scope === "real" || target.kind === "real-device";
}

function targetKindLabel(target: DeviceTarget) {
  if (target.scope === "real" || target.kind === "real-device" || target.realSource?.endsWith("real-device")) {
    return "真机";
  }
  return platformDetail[target.platform];
}

function commandOutputsToLogs(outputs: BridgeCommandOutput[]): LogEntry[] {
  return outputs.map((output) =>
    makeLog(output.ok ? "info" : "warn", `${output.command} exit=${output.exitCode ?? "?"} ${summarizeOutput(output.stdout || output.stderr)}`)
  );
}

function hostNetworkEvidenceForTarget(target: DeviceTarget): NetworkEvent[] {
  if (!target.realSource) return [];
  const selector = target.targetSelector ?? target.udid ?? target.id;
  return [
    {
      id: `host-network-${target.id}`,
      method: "GET",
      path: `/readonly/${target.platform}/${selector}/network-not-exposed`,
      status: 204,
      latencyMs: 0,
      mode: "off",
    },
  ];
}

function hostLogsForTarget(target: DeviceTarget): LogEntry[] {
  if (!target.realSource) return [];
  const selector = target.targetSelector ?? target.udid ?? target.id;
  const blocked = target.blockedReasons?.length ? ` blocked=${target.blockedReasons.join(",")}` : "";
  return [
    makeLog("info", `${target.platform} target ${selector} selected from readonly host discovery`),
    makeLog("warn", `${target.platform} network/app runtime evidence not exposed by CLI DTO${blocked}`),
  ];
}

function makeLog(level: LogEntry["level"], message: string): LogEntry {
  return {
    id: `${level}-${Date.now()}-${Math.random().toString(16).slice(2)}`,
    time: new Date().toLocaleTimeString("en-GB", { hour12: false }),
    level,
    message,
  };
}

function summarizeOutput(output: string) {
  const compact = output.replace(/\s+/g, " ").trim();
  if (!compact) return "no output";
  const parsed = parseJSONOutput(compact);
  if (parsed && typeof parsed === "object") {
    const record = parsed as Record<string, unknown>;
    const error = record.error;
    if (error && typeof error === "object") {
      const errorRecord = error as Record<string, unknown>;
      return compactMessage(
        [
          typeof errorRecord.code === "string" ? errorRecord.code : undefined,
          typeof errorRecord.message === "string" ? errorRecord.message : undefined,
          typeof errorRecord.hint === "string" ? errorRecord.hint : undefined,
        ].filter(Boolean).join(" · ")
      );
    }
    if (typeof record.message === "string") {
      return compactMessage(record.message);
    }
    if (typeof record.ok === "boolean") {
      return record.ok ? "ok" : "failed";
    }
  }
  return compactMessage(compact);
}

function parseJSONOutput(output: string) {
  try {
    return JSON.parse(output);
  } catch {
    return null;
  }
}

function compactMessage(message: string) {
  const compact = message.replace(/\s+/g, " ").trim();
  return compact.length > 180 ? `${compact.slice(0, 177)}...` : compact;
}

function localizeLogEntry(entry: LogEntry, language: DisplayLanguage): LocalizedLogEntry {
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

function platformName(platform: string) {
  const normalized = platform.toLowerCase();
  if (normalized === "ios") return "iOS";
  if (normalized === "android") return "Android";
  if (normalized === "harmony") return "Harmony";
  return platform;
}

function filterTargetsBySearch(targets: DeviceTarget[], query: string) {
  const normalizedQuery = query.trim().toLowerCase();
  if (!normalizedQuery) return targets;
  return targets.filter((target) => {
    const haystacks = [target.name, target.appName].filter(Boolean).map((value) => value.toLowerCase());
    return haystacks.some((value) => value.includes(normalizedQuery));
  });
}

function localizeStatusLabel(label: string) {
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

function DeviceHubToolbar({
  target,
  targets,
  bridgeSubtitle,
  isSidebarVisible,
  isRefreshing,
  isTargetMenuOpen,
  onToggleSidebar,
  onRefresh,
  onToggleTargetMenu,
  onCloseTargetMenu,
  onSelectTarget,
}: {
  target: DeviceTarget;
  targets: DeviceTarget[];
  bridgeSubtitle: string;
  isSidebarVisible: boolean;
  isRefreshing: boolean;
  isTargetMenuOpen: boolean;
  onToggleSidebar: () => void;
  onRefresh: () => void;
  onToggleTargetMenu: () => void;
  onCloseTargetMenu: () => void;
  onSelectTarget: (targetId: string) => void;
}) {
  const menuRef = useRef<HTMLDivElement | null>(null);
  const toolbarSubtitle = bridgeSubtitle === "Readonly host targets" ? target.os : bridgeSubtitle;

  useEffect(() => {
    if (!isTargetMenuOpen) return;

    const handlePointerDown = (event: MouseEvent) => {
      if (event.target instanceof Node && menuRef.current?.contains(event.target)) {
        return;
      }
      onCloseTargetMenu();
    };
    const handleKeyDown = (event: globalThis.KeyboardEvent) => {
      if (event.key === "Escape") {
        onCloseTargetMenu();
      }
    };

    document.addEventListener("mousedown", handlePointerDown);
    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("mousedown", handlePointerDown);
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [isTargetMenuOpen, onCloseTargetMenu]);

  return (
    <header className="hub-toolbar">
      <IconTool
        label={isSidebarVisible ? "收起侧边栏" : "展开侧边栏"}
        icon={PanelLeft}
        variant="solo"
        className={isSidebarVisible ? "is-active" : ""}
        onClick={onToggleSidebar}
      />

      <div className="toolbar-title-shell" ref={menuRef}>
        <button
          className="toolbar-title"
          type="button"
          aria-label="切换设备"
          aria-haspopup="listbox"
          aria-expanded={isTargetMenuOpen}
          onClick={onToggleTargetMenu}
        >
          <strong>{target.name}</strong>
          <span>{toolbarSubtitle}</span>
          <ChevronDown size={14} aria-hidden="true" />
        </button>
        {isTargetMenuOpen ? (
          <div className="toolbar-target-menu" role="listbox" aria-label="切换设备">
            {targets.map((candidate) => (
              <button
                key={candidate.id}
                className="toolbar-target-option"
                type="button"
                role="option"
                aria-selected={candidate.id === target.id}
                onClick={() => onSelectTarget(candidate.id)}
              >
                <strong>{candidate.name}</strong>
                <span>{candidate.appName}</span>
                <em>
                  {platformLabel[candidate.platform]} · {candidate.os}
                </em>
              </button>
            ))}
          </div>
        ) : null}
      </div>

      <div className="toolbar-cluster inspector-tools" aria-label="检查器工具">
        <IconTool
          label={isRefreshing ? "正在刷新全局数据" : "刷新全局数据"}
          icon={RefreshCw}
          className={isRefreshing ? "is-spinning" : ""}
          disabled={isRefreshing}
          onClick={onRefresh}
        />
      </div>
    </header>
  );
}

function IconTool({
  label,
  icon: Icon,
  variant,
  className,
  disabled,
  onClick,
}: {
  label: string;
  icon: LucideIcon;
  variant?: "solo";
  className?: string;
  disabled?: boolean;
  onClick?: () => void;
}) {
  return (
    <button
      className={`icon-tool ${variant === "solo" ? "is-solo" : ""} ${className ?? ""}`}
      type="button"
      aria-label={label}
      title={label}
      disabled={disabled}
      onClick={onClick}
    >
      <Icon size={17} strokeWidth={2.2} />
    </button>
  );
}

function TargetNavigator({
  selected,
  targets: visibleTargets,
  hierarchy,
  activePanel,
  searchValue,
  isSearching,
  onSearchChange,
  onPanelChange,
  onSelect,
  selectedHierarchyNode,
  onSelectHierarchyNode,
}: {
  selected: DeviceTarget;
  targets: DeviceTarget[];
  hierarchy?: HierarchyCacheEntry;
  activePanel: SidebarPanel;
  searchValue: string;
  isSearching: boolean;
  onSearchChange: (value: string) => void;
  onPanelChange: (panel: SidebarPanel) => void;
  onSelect: (id: string) => void;
  selectedHierarchyNode: string | null;
  onSelectHierarchyNode: (nodeId: string | null) => void;
}) {
  return (
    <aside className="hub-sidebar" aria-label="设备">
      <label className="sidebar-search">
        <Search size={16} />
        <input
          placeholder="搜索"
          value={searchValue}
          onChange={(event) => onSearchChange(event.target.value)}
        />
      </label>

      <div className="sidebar-panel-switch" role="tablist" aria-label="侧边面板">
        <button
          className={activePanel === "devices" ? "is-active" : ""}
          type="button"
          role="tab"
          aria-selected={activePanel === "devices"}
          onClick={() => onPanelChange("devices")}
        >
          设备
        </button>
        <button
          className={activePanel === "view-tree" ? "is-active" : ""}
          type="button"
          role="tab"
          aria-selected={activePanel === "view-tree"}
          onClick={() => onPanelChange("view-tree")}
        >
          视图树
        </button>
      </div>

      {activePanel === "devices" ? (
        <DeviceListPanel selected={selected} targets={visibleTargets} isSearching={isSearching} onSelect={onSelect} />
      ) : (
        <ViewTreePanel
          selected={selected}
          hierarchy={hierarchy}
          selectedHierarchyNode={selectedHierarchyNode}
          onSelectHierarchyNode={onSelectHierarchyNode}
        />
      )}
    </aside>
  );
}

function DeviceListPanel({
  selected,
  targets: visibleTargets,
  isSearching,
  onSelect,
}: {
  selected: DeviceTarget;
  targets: DeviceTarget[];
  isSearching: boolean;
  onSelect: (id: string) => void;
}) {
  return (
    <section className="sidebar-panel" aria-label="设备列表面板">
      <div className="sidebar-section-title">运行中</div>
      <div className="device-list">
        {visibleTargets.map((target) => {
          const appLabel = target.appName || "前台 App 未识别";
          const detailLabel = appLabel;

          return (
            <button
              className={`device-row ${target.id === selected.id ? "is-selected" : ""}`}
              key={target.id}
              onClick={() => onSelect(target.id)}
              type="button"
            >
              <span className="device-row-copy">
                <strong>{target.name}</strong>
                <span title={detailLabel}>{detailLabel}</span>
              </span>
              <span className="device-row-meta">
                <span className="device-platform-badge" style={{ color: target.accent }}>
                  {platformLabel[target.platform]}
                </span>
                <span className="device-version">{target.os.replace(/^[A-Za-z ]+/, "")}</span>
              </span>
            </button>
          );
        })}

        {visibleTargets.length === 0 ? (
          <p className="empty-devices">{isSearching ? "未找到匹配 target" : "暂无运行中的设备"}</p>
        ) : null}
      </div>
    </section>
  );
}

function ViewTreePanel({
  selected,
  hierarchy,
  selectedHierarchyNode,
  onSelectHierarchyNode,
}: {
  selected: DeviceTarget;
  hierarchy?: HierarchyCacheEntry;
  selectedHierarchyNode: string | null;
  onSelectHierarchyNode: (nodeId: string | null) => void;
}) {
  const hierarchyScene = hierarchy?.scene;
  const treeNodes = useMemo(() => (hierarchyScene ? viewTreeNodesForScene(hierarchyScene) : []), [hierarchyScene]);
  const defaultSelection = hierarchyScene ? defaultViewTreeSelection(hierarchyScene) : null;
  const selectedNode = selectedHierarchyNode ?? defaultSelection;

  return (
    <section className="sidebar-panel view-tree-panel" aria-label="视图层级面板">
      {hierarchy?.loading ? (
        <p className="view-tree-empty">正在读取实时视图层级...</p>
      ) : hierarchy?.error ? (
        <p className="view-tree-empty" title={hierarchy.error}>
          未拿到实时视图层级
        </p>
      ) : hierarchyScene ? (
        <div className="view-tree-list" role="tree" aria-label={`${selected.appName} 视图层级`}>
          {treeNodes.map((node) => (
            <ViewTreeRow key={node.id} node={node} depth={0} selectedNode={selectedNode} onSelect={onSelectHierarchyNode} />
          ))}
        </div>
      ) : (
        <p className="view-tree-empty">暂无实时视图层级</p>
      )}
    </section>
  );
}

function ViewTreeRow({
  node,
  depth,
  selectedNode,
  onSelect,
}: {
  node: ViewTreeNode;
  depth: number;
  selectedNode: string | null;
  onSelect: (id: string) => void;
}) {
  const hasChildren = Boolean(node.children?.length);
  const displayType = readableViewTreeLabel(node.type);
  const displayName = readableViewTreeName(displayType, node.name ? readableViewTreeLabel(node.name) : null);
  const fullLabel = [node.type, node.name].filter(Boolean).join(" ");

  return (
    <>
      <button
        className={`view-tree-row ${selectedNode === node.id ? "is-selected" : ""}`}
        style={{ "--tree-depth": depth } as CSSProperties}
        type="button"
        role="treeitem"
        aria-selected={selectedNode === node.id}
        aria-expanded={hasChildren ? true : undefined}
        data-node-id={node.id}
        onClick={() => onSelect(node.id)}
      >
        <span className="tree-disclosure">{hasChildren ? "▾" : "·"}</span>
        <span className="tree-node-copy" title={fullLabel}>
          <strong>{displayType}</strong>
          {displayName ? <span>{displayName}</span> : null}
        </span>
      </button>
      {node.children?.map((child) => (
        <ViewTreeRow key={child.id} node={child} depth={depth + 1} selectedNode={selectedNode} onSelect={onSelect} />
      ))}
    </>
  );
}

function DeviceCanvas({
  target,
  hierarchyScene,
  selectedHierarchyNode,
  selectedHierarchyNodeDraft,
  screenshotError,
  livePreview,
  inputActivity,
  isSnapshotMode,
  isSnapshotRefreshing,
  isDiscoveringHostTargets,
  onPreviewFpsChange,
  onSnapshotModeChange,
  onSnapshotRefresh,
  onSelectHierarchyNode,
  onInput,
}: {
  target: DeviceTarget;
  hierarchyScene?: HierarchyScene;
  selectedHierarchyNode: string | null;
  selectedHierarchyNodeDraft?: HierarchyNodeHotEditDraft;
  screenshotError?: string;
  livePreview?: LivePreviewState;
  inputActivity?: InputActivity;
  isSnapshotMode: boolean;
  isSnapshotRefreshing: boolean;
  isDiscoveringHostTargets: boolean;
  onPreviewFpsChange: (fps: number) => void;
  onSnapshotModeChange: (enabled: boolean) => void;
  onSnapshotRefresh: () => Promise<void>;
  onSelectHierarchyNode: (nodeId: string | null) => void;
  onInput: (input: ReadonlyInputIntent) => Promise<HostInputResponse | null>;
}) {
  const screenRef = useRef<HTMLDivElement | null>(null);
  const keyboardRelayRef = useRef<HTMLInputElement | null>(null);
  const keyboardRelayValue = useRef("");
  const previewControlRef = useRef<HTMLDivElement | null>(null);
  const activeGesturePointers = useRef<Map<number, GesturePoint>>(new Map());
  const singleGesture = useRef<SingleGestureState | null>(null);
  const pinchGesture = useRef<PinchGestureState | null>(null);
  const gestureClearTimer = useRef<number | undefined>(undefined);
  const longPressPreviewTimer = useRef<number | undefined>(undefined);
  const [gesturePreview, setGesturePreview] = useState<GesturePreview | null>(null);
  const [keyboardRelay, setKeyboardRelay] = useState<KeyboardRelayState | null>(null);
  const [keyboardRelayText, setKeyboardRelayText] = useState("");
  const [isPreviewFpsOpen, setIsPreviewFpsOpen] = useState(false);
  const selectedNodeHighlight = hierarchyScene ? viewNodeHighlightForScene(hierarchyScene, selectedHierarchyNode, selectedHierarchyNodeDraft) : null;
  const controllerBadge = resolveControllerShellBadge(hierarchyScene, selectedHierarchyNode);
  const orientation = target.frameOrientation ?? "landscape";
  const aspectRatio =
    target.screenshotPixelWidth && target.screenshotPixelHeight
      ? `${target.screenshotPixelWidth} / ${target.screenshotPixelHeight}`
      : undefined;
  const frameStyle =
    target.screenshotPixelWidth && target.screenshotPixelHeight
      ? {
          "--screen-aspect-ratio": aspectRatio,
        } as CSSProperties
      : undefined;
  const orientationLabel =
    target.screenshotPixelWidth && target.screenshotPixelHeight
      ? `${orientation} ${target.screenshotPixelWidth} x ${target.screenshotPixelHeight}`
      : target.realSource
        ? `${orientation} placeholder`
        : orientation;
  const canSendInput = Boolean(
    !isSnapshotMode &&
    target.realSource &&
      target.canInput &&
      target.screenshotDataUrl &&
      target.targetSelector &&
      target.screenshotPixelWidth &&
      target.screenshotPixelHeight
  );
  const isWaitingForRealScreenshot = Boolean(target.realSource && target.canScreenshot && !target.screenshotDataUrl);
  const pendingScreenshotState = screenshotPendingState(target, screenshotError);
  const canSelectSnapshotNode = Boolean(isSnapshotMode && hierarchyScene);

  useEffect(() => {
    return () => {
      if (gestureClearTimer.current) {
        window.clearTimeout(gestureClearTimer.current);
      }
      if (longPressPreviewTimer.current) {
        window.clearTimeout(longPressPreviewTimer.current);
      }
    };
  }, []);

  useEffect(() => {
    setIsPreviewFpsOpen(false);
    setKeyboardRelay(null);
    setKeyboardRelayText("");
    keyboardRelayValue.current = "";
  }, [target.id]);

  useEffect(() => {
    if (!keyboardRelay) return;
    keyboardRelayRef.current?.focus({ preventScroll: true });
  }, [keyboardRelay]);

  useEffect(() => {
    if (!isPreviewFpsOpen) return;

    const handlePointerDownOutside = (event: globalThis.PointerEvent) => {
      const targetNode = event.target;
      if (targetNode instanceof Node && previewControlRef.current?.contains(targetNode)) {
        return;
      }
      setIsPreviewFpsOpen(false);
    };

    window.addEventListener("pointerdown", handlePointerDownOutside);
    return () => {
      window.removeEventListener("pointerdown", handlePointerDownOutside);
    };
  }, [isPreviewFpsOpen]);

  useEffect(() => {
    if (isSnapshotMode) {
      setIsPreviewFpsOpen(false);
      setKeyboardRelay(null);
    }
  }, [isSnapshotMode]);

  const clearGesturePreviewSoon = () => {
    if (gestureClearTimer.current) {
      window.clearTimeout(gestureClearTimer.current);
    }
    gestureClearTimer.current = window.setTimeout(() => {
      setGesturePreview(null);
    }, 620);
  };

  const clearLongPressPreviewTimer = () => {
    if (longPressPreviewTimer.current) {
      window.clearTimeout(longPressPreviewTimer.current);
      longPressPreviewTimer.current = undefined;
    }
  };

  const mapPointer = (event: PointerEvent<HTMLDivElement>) => {
    const screen = screenRef.current;
    if (!screen || !target.screenshotPixelWidth || !target.screenshotPixelHeight) return null;
    const rect = screen.getBoundingClientRect();
    const x = Math.max(0, Math.min(target.screenshotPixelWidth, ((event.clientX - rect.left) / rect.width) * target.screenshotPixelWidth));
    const y = Math.max(0, Math.min(target.screenshotPixelHeight, ((event.clientY - rect.top) / rect.height) * target.screenshotPixelHeight));
    const xPercent = Math.max(0, Math.min(100, ((event.clientX - rect.left) / rect.width) * 100));
    const yPercent = Math.max(0, Math.min(100, ((event.clientY - rect.top) / rect.height) * 100));
    return { x, y, xPercent, yPercent };
  };

  const pinchSnapshot = (points: GesturePoint[]): PinchSnapshot | null => {
    if (points.length < 2) return null;
    const [first, second] = points;
    return {
      centerX: (first.x + second.x) / 2,
      centerY: (first.y + second.y) / 2,
      centerXPercent: (first.xPercent + second.xPercent) / 2,
      centerYPercent: (first.yPercent + second.yPercent) / 2,
      distance: Math.hypot(second.x - first.x, second.y - first.y),
    };
  };

  const updatePinchPreview = (current: PinchSnapshot) => {
    const start = pinchGesture.current?.start ?? current;
    const scale = start.distance > 0 ? current.distance / start.distance : 1;
    setGesturePreview({
      kind: "pinch",
      centerXPercent: current.centerXPercent,
      centerYPercent: current.centerYPercent,
      startDistance: start.distance,
      endDistance: current.distance,
      scale,
    });
  };

  const handlePointerDown = (event: PointerEvent<HTMLDivElement>) => {
    if (isSnapshotMode) {
      screenRef.current?.focus({ preventScroll: true });
      const start = mapPointer(event);
      if (!start || !hierarchyScene) return;
      const hitNode = hierarchyNodeAtPoint(hierarchyScene, start.xPercent, start.yPercent);
      if (hitNode) {
        onSelectHierarchyNode(hitNode.id);
      }
      return;
    }
    if (!canSendInput) return;
    screenRef.current?.focus({ preventScroll: true });
    const start = mapPointer(event);
    if (!start) return;
    activeGesturePointers.current.set(event.pointerId, start);
    if (start) {
      if (gestureClearTimer.current) {
        window.clearTimeout(gestureClearTimer.current);
      }
      if (activeGesturePointers.current.size === 1) {
        singleGesture.current = {
          pointerId: event.pointerId,
          start,
          startedAt: Date.now(),
        };
        pinchGesture.current = null;
        setGesturePreview({
          kind: "tap",
          xPercent: start.xPercent,
          yPercent: start.yPercent,
        });
        clearLongPressPreviewTimer();
        longPressPreviewTimer.current = window.setTimeout(() => {
          const single = singleGesture.current;
          const current = activeGesturePointers.current.get(event.pointerId);
          if (!single || !current) return;
          const distance = Math.hypot(current.x - single.start.x, current.y - single.start.y);
          if (distance >= tapDistanceThreshold) return;
          setGesturePreview({
            kind: "longPress",
            xPercent: single.start.xPercent,
            yPercent: single.start.yPercent,
          });
        }, longPressThresholdMs);
      } else {
        clearLongPressPreviewTimer();
        setKeyboardRelay(null);
        setKeyboardRelayText("");
        keyboardRelayValue.current = "";
        singleGesture.current = null;
        const current = pinchSnapshot(Array.from(activeGesturePointers.current.values()).slice(0, 2));
        if (current) {
          pinchGesture.current = {
            start: pinchGesture.current?.start ?? current,
            startedAt: Date.now(),
            dispatched: false,
          };
          updatePinchPreview(current);
        }
      }
    }
    try {
      event.currentTarget.setPointerCapture(event.pointerId);
    } catch {
      // Synthetic pointer events used by browser smoke tests may not have an active pointer.
    }
  };

  const handlePointerMove = (event: PointerEvent<HTMLDivElement>) => {
    if (isSnapshotMode) return;
    if (!canSendInput) return;
    const current = mapPointer(event);
    if (!current) return;
    if (activeGesturePointers.current.has(event.pointerId)) {
      activeGesturePointers.current.set(event.pointerId, current);
    }
    if (activeGesturePointers.current.size >= 2) {
      clearLongPressPreviewTimer();
      const pinch = pinchSnapshot(Array.from(activeGesturePointers.current.values()).slice(0, 2));
      if (!pinch) return;
      if (!pinchGesture.current) {
        pinchGesture.current = { start: pinch, startedAt: Date.now(), dispatched: false };
      }
      updatePinchPreview(pinch);
      return;
    }
    const start = singleGesture.current?.start;
    if (!start) return;
    const distance = Math.hypot(current.x - start.x, current.y - start.y);
    if (distance < 10) {
      if (Date.now() - (singleGesture.current?.startedAt ?? 0) < longPressThresholdMs) {
        setGesturePreview({
          kind: "tap",
          xPercent: current.xPercent,
          yPercent: current.yPercent,
        });
      }
      return;
    }
    clearLongPressPreviewTimer();
    setGesturePreview({
      kind: "swipe",
      startXPercent: start.xPercent,
      startYPercent: start.yPercent,
      endXPercent: current.xPercent,
      endYPercent: current.yPercent,
      distance,
    });
  };

  const handlePointerCancel = () => {
    activeGesturePointers.current.clear();
    singleGesture.current = null;
    pinchGesture.current = null;
    clearLongPressPreviewTimer();
    clearGesturePreviewSoon();
  };

  const handlePointerUp = (event: PointerEvent<HTMLDivElement>) => {
    if (isSnapshotMode) return;
    if (!canSendInput || !target.targetSelector) return;
    const end = mapPointer(event);
    if (end && activeGesturePointers.current.has(event.pointerId)) {
      activeGesturePointers.current.set(event.pointerId, end);
    }
    if (activeGesturePointers.current.size >= 2 && pinchGesture.current && !pinchGesture.current.dispatched) {
      const current = pinchSnapshot(Array.from(activeGesturePointers.current.values()).slice(0, 2));
      if (current) {
        const start = pinchGesture.current.start;
        const scale = start.distance > 0 ? current.distance / start.distance : 1;
        pinchGesture.current.dispatched = true;
        setGesturePreview({
          kind: "pinch",
          centerXPercent: current.centerXPercent,
          centerYPercent: current.centerYPercent,
          startDistance: start.distance,
          endDistance: current.distance,
          scale,
        });
        clearGesturePreviewSoon();
        onInput({
          action: "pinch",
          platform: target.platform,
          target: target.targetSelector,
          centerX: roundedGestureValue(current.centerX),
          centerY: roundedGestureValue(current.centerY),
          startDistance: roundedGestureValue(start.distance),
          endDistance: roundedGestureValue(current.distance),
          scale: roundedGestureValue(scale),
          width: target.screenshotPixelWidth ?? undefined,
          height: target.screenshotPixelHeight ?? undefined,
          duration: 0.25,
        });
      }
      activeGesturePointers.current.clear();
      singleGesture.current = null;
      pinchGesture.current = null;
      clearLongPressPreviewTimer();
      return;
    }

    const start = singleGesture.current?.start;
    const startedAt = singleGesture.current?.startedAt ?? Date.now();
    activeGesturePointers.current.delete(event.pointerId);
    singleGesture.current = null;
    clearLongPressPreviewTimer();
    if (!start || !end) return;
    const distance = Math.hypot(end.x - start.x, end.y - start.y);
    if (distance < tapDistanceThreshold) {
      setKeyboardRelay(null);
      setKeyboardRelayText("");
      keyboardRelayValue.current = "";
      clearGesturePreviewSoon();
      const duration = (Date.now() - startedAt) / 1000;
      if (duration >= longPressThresholdMs / 1000) {
        setGesturePreview({
          kind: "longPress",
          xPercent: start.xPercent,
          yPercent: start.yPercent,
        });
        void onInput({
          action: "longPress",
          platform: target.platform,
          target: target.targetSelector,
          x: roundedGestureValue(start.x),
          y: roundedGestureValue(start.y),
          width: target.screenshotPixelWidth ?? undefined,
          height: target.screenshotPixelHeight ?? undefined,
          duration: roundedGestureValue(Math.max(duration, longPressThresholdMs / 1000)),
        });
        return;
      }
      setGesturePreview({
        kind: "tap",
        xPercent: start.xPercent,
        yPercent: start.yPercent,
      });
      void onInput({
        action: "tap",
        platform: target.platform,
        target: target.targetSelector,
        x: start.x,
        y: start.y,
        width: target.screenshotPixelWidth ?? undefined,
        height: target.screenshotPixelHeight ?? undefined,
      }).then((result) => {
        if (!shouldShowKeyboardRelay(result)) return;
        setKeyboardRelay({
          xPercent: start.xPercent,
          yPercent: start.yPercent,
        });
      });
      return;
    }
    setGesturePreview({
      kind: "swipe",
      startXPercent: start.xPercent,
      startYPercent: start.yPercent,
      endXPercent: end.xPercent,
      endYPercent: end.yPercent,
      distance,
    });
    clearGesturePreviewSoon();
    onInput({
      action: "swipe",
      platform: target.platform,
      target: target.targetSelector,
      startX: start.x,
      startY: start.y,
      endX: end.x,
      endY: end.y,
      width: target.screenshotPixelWidth ?? undefined,
      height: target.screenshotPixelHeight ?? undefined,
      duration: 0.25,
    });
  };

  const handleKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    if (!canSendInput) return;
    if (event.metaKey || event.ctrlKey || event.altKey) return;
    if (event.key === "Backspace" || event.key === "Delete") {
      event.preventDefault();
      onInput({ action: "deleteBackward" });
      return;
    }
    if (event.key.length !== 1) return;
    event.preventDefault();
    onInput({ action: "type", text: event.key });
  };

  const handlePaste = (event: ClipboardEvent<HTMLDivElement>) => {
    if (!canSendInput) return;
    const text = event.clipboardData.getData("text");
    if (!text) return;
    event.preventDefault();
    onInput({ action: "paste", text });
  };

  const setRelayText = (text: string) => {
    keyboardRelayValue.current = text;
    setKeyboardRelayText(text);
  };

  const handleRelayChange = (event: ChangeEvent<HTMLInputElement>) => {
    if (!canSendInput) return;
    const next = event.currentTarget.value;
    const previous = keyboardRelayValue.current;
    setRelayText(next);

    if (next === previous) return;
    if (next.startsWith(previous)) {
      const inserted = next.slice(previous.length);
      if (inserted) {
        onInput({ action: "type", text: inserted });
      }
      return;
    }

    if (previous.startsWith(next)) {
      const deletedCount = previous.length - next.length;
      for (let index = 0; index < deletedCount; index += 1) {
        onInput({ action: "deleteBackward" });
      }
      return;
    }

    const deletedCount = previous.length;
    for (let index = 0; index < deletedCount; index += 1) {
      onInput({ action: "deleteBackward" });
    }
    if (next) {
      onInput({ action: "type", text: next });
    }
  };

  const handleRelayKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
    if (!canSendInput) return;
    if (event.key === "Escape") {
      event.preventDefault();
      setKeyboardRelay(null);
      return;
    }
    if ((event.key === "Backspace" || event.key === "Delete") && keyboardRelayValue.current.length === 0) {
      event.preventDefault();
      onInput({ action: "deleteBackward" });
    }
  };

  const handleRelayPaste = (event: ClipboardEvent<HTMLInputElement>) => {
    if (!canSendInput) return;
    const text = event.clipboardData.getData("text");
    if (!text) return;
    event.preventDefault();

    const input = event.currentTarget;
    const selectionStart = input.selectionStart ?? keyboardRelayValue.current.length;
    const selectionEnd = input.selectionEnd ?? selectionStart;
    const next = keyboardRelayValue.current.slice(0, selectionStart) + text + keyboardRelayValue.current.slice(selectionEnd);
    setRelayText(next);
    onInput({ action: "paste", text });
  };

  const shouldShowKeyboardRelay = (result: HostInputResponse | null) => {
    if (!result?.ok) return false;
    const classNames = [result.targetClassName, result.matchedClassName, result.activationClassName].filter(Boolean) as string[];
    return classNames.some((className) => isEditableInputClassName(className));
  };

  if (isDiscoveringHostTargets) {
    return (
      <section className="hub-canvas" aria-label="设备画布">
        <div className="device-discovery-pending" role="status" aria-live="polite">
          <span />
          <strong>正在发现本机设备</strong>
          <em>triton sim list · triton device list</em>
        </div>
      </section>
    );
  }

  return (
    <section className={`hub-canvas ${isSnapshotMode ? "tool-snapshot" : "tool-point"}`} aria-label="设备画布">
      {target.realSource && target.canScreenshot ? (
        <div className={`live-preview-control ${isPreviewFpsOpen ? "is-open" : ""} ${isSnapshotMode ? "is-snapshot" : ""}`} ref={previewControlRef}>
          <div className="canvas-mode-switch" aria-label="设备画布模式">
            <button
              className={!isSnapshotMode ? "is-active" : ""}
              type="button"
              aria-pressed={!isSnapshotMode}
              onClick={() => onSnapshotModeChange(false)}
            >
              实时
            </button>
            <button
              className={isSnapshotMode ? "is-active" : ""}
              type="button"
              aria-pressed={isSnapshotMode}
              onClick={() => onSnapshotModeChange(true)}
            >
              快照
            </button>
          </div>
          {isSnapshotMode ? (
            <button
              className="snapshot-refresh-button"
              type="button"
              aria-label="手动刷新快照"
              disabled={isSnapshotRefreshing}
              onClick={() => {
                void onSnapshotRefresh();
              }}
            >
              <RefreshCw size={13} />
              <span>{isSnapshotRefreshing ? "刷新中" : "刷新"}</span>
            </button>
          ) : target.screenshotDataUrl ? (
            <button
              className={`live-preview-badge ${livePreview?.status === "error" ? "is-error" : ""}`}
              type="button"
              aria-label={isPreviewFpsOpen ? "收起实时预览帧率控制" : "展开实时预览帧率控制"}
              aria-expanded={isPreviewFpsOpen}
              onClick={() => setIsPreviewFpsOpen((current) => !current)}
            >
              <span />
              <strong>{livePreview?.status === "error" ? "流已暂停" : "实时"}</strong>
              <em>{target.fps} fps</em>
            </button>
          ) : null}
          {!isSnapshotMode && isPreviewFpsOpen ? (
            <>
            <label className="preview-fps-control">
              <span>刷新率</span>
              <input
                type="range"
                min={previewFpsMin}
                max={previewFpsMax}
                step="1"
                value={target.fps}
                aria-label="调整实时预览帧率"
                onChange={(event) => onPreviewFpsChange(Number(event.currentTarget.value))}
              />
            </label>
            <div className="preview-fps-stepper" aria-label="实时预览帧率步进">
              <button
                type="button"
                aria-label="降低实时预览帧率"
                disabled={target.fps <= previewFpsMin}
                onClick={() => onPreviewFpsChange(target.fps - 1)}
              >
                <Minus size={13} />
              </button>
              <button
                type="button"
                aria-label="提高实时预览帧率"
                disabled={target.fps >= previewFpsMax}
                onClick={() => onPreviewFpsChange(target.fps + 1)}
              >
                <Plus size={13} />
              </button>
            </div>
            </>
          ) : null}
        </div>
      ) : null}

      <div className="device-stage" aria-label="设备镜像区域">
        <div
          className={`device-frame orientation-${orientation} ${aspectRatio ? "has-real-frame" : ""}`}
          style={frameStyle}
        >
          {hierarchyScene?.platform === "ios" ? (
            <div
              className={`controller-shell-badge ${controllerBadge?.isFallback ? "is-fallback" : ""}`}
              title={controllerBadge?.stack.length ? controllerBadge.stack.join(" > ") : controllerBadge?.className ?? "UIViewController 未暴露"}
            >
              <span>UIViewController</span>
              <strong>{controllerBadge?.name ?? "未暴露"}</strong>
              {controllerBadge?.isFallback ? <em>fallback</em> : null}
            </div>
          ) : null}
          <div className="device-side left" />
          <div className="device-side top" />
          <div className="device-side bottom" />
          <div
            className={`device-screen orientation-${orientation} ${target.screenshotTone} ${isSnapshotMode ? "tool-snapshot" : "tool-point"} ${canSendInput || canSelectSnapshotNode ? "is-interactive" : ""}`}
            aria-label={isSnapshotMode ? "设备画面，当前工具 快照选节点" : "设备画面，当前工具 点选"}
            tabIndex={canSendInput || canSelectSnapshotNode ? 0 : undefined}
            onPointerDown={handlePointerDown}
            onPointerMove={handlePointerMove}
            onPointerUp={handlePointerUp}
            onPointerCancel={handlePointerCancel}
            onKeyDown={handleKeyDown}
            onPaste={handlePaste}
            ref={screenRef}
          >
              {target.screenshotDataUrl ? (
                <img className="real-screenshot" src={target.screenshotDataUrl} alt={`${target.name} 截图`} />
              ) : isWaitingForRealScreenshot ? (
                <div className={`real-screenshot-pending ${pendingScreenshotState.kind === "error" ? "is-error" : ""}`} role="status" aria-live="polite">
                  {pendingScreenshotState.kind === "error" ? <Info size={28} /> : <span />}
                  <strong>{pendingScreenshotState.title}</strong>
                  <em>{pendingScreenshotState.detail}</em>
                  {pendingScreenshotState.command ? <code>{pendingScreenshotState.command}</code> : null}
                </div>
              ) : (
                <>
                  <div className="screen-island" />
                  <div className="screen-hero">
                    <span>目标</span>
                    <strong>{target.appName}</strong>
                    <button type="button">{target.realSource ? localizeStatusLabel(target.statusLabel) : "检查"}</button>
                  </div>
                  <div className="screen-content">
                    <div>
                      <h2>{targetKindLabel(target)}</h2>
                      <p>{target.device}</p>
                    </div>
                    <div className="screen-card-row">
                      <ScreenMini label="帧" value={target.screenSize} />
                      <ScreenMini label="方向" value={orientationLabel} />
                      <ScreenMini label="传输" value={target.transport} />
                    </div>
                  </div>
                </>
              )}
              {selectedNodeHighlight ? (
                <div
                  className={`view-node-highlight ${selectedNodeHighlight.isHiddenDraft ? "is-hidden-draft" : ""}`}
                  data-node-id={selectedNodeHighlight.node.id}
                  data-node-type={selectedNodeHighlight.node.type}
                  data-hot-hidden={selectedNodeHighlight.isHiddenDraft ? "true" : "false"}
                  aria-label={`选中视图区域 ${selectedNodeHighlight.node.type}${selectedNodeHighlight.node.name ? ` ${selectedNodeHighlight.node.name}` : ""}`}
                  style={selectedNodeHighlight.style}
                />
              ) : null}
              {gesturePreview ? <GestureOverlay gesture={gesturePreview} /> : null}
              {inputActivity ? <InputActivityBadge activity={inputActivity} /> : null}
              {keyboardRelay ? (
                <label
                  className="keyboard-relay"
                  style={{
                    "--relay-x": `${keyboardRelay.xPercent}%`,
                    "--relay-y": `${keyboardRelay.yPercent}%`,
                  } as CSSProperties}
                >
                  <Keyboard size={13} />
                  <input
                    ref={keyboardRelayRef}
                    value={keyboardRelayText}
                    aria-label="设备键盘输入"
                    autoCapitalize="none"
                    autoComplete="off"
                    autoCorrect="off"
                    spellCheck={false}
                    inputMode="text"
                    placeholder="输入到设备"
                    onChange={handleRelayChange}
                    onKeyDown={handleRelayKeyDown}
                    onPaste={handleRelayPaste}
                  />
                </label>
              ) : null}
          </div>
        </div>
      </div>
      {screenshotError ? <p className="canvas-error">{screenshotError}</p> : null}
    </section>
  );
}

function screenshotPendingState(target: DeviceTarget, screenshotError?: string) {
  const isIOSRuntimeMirror = target.platform === "ios" && target.scope === "real" && target.screenshotSource === "runtime";
  if (screenshotError && isIOSRuntimeMirror) {
    const serverUnavailable = screenshotError.includes("server_unavailable") || screenshotError.includes("app_runtime_unavailable");
    return {
      kind: "error" as const,
      title: serverUnavailable ? "App runtime 未连接" : "实时画面不可用",
      detail: serverUnavailable
        ? "真机实时画面依赖 Debug App 内嵌 TritonKit runtime。"
        : conciseBridgeError(screenshotError),
      command: serverUnavailable ? "triton serve --host 127.0.0.1 --port 19421" : undefined,
    };
  }

  return {
    kind: "loading" as const,
    title: "正在获取实时画面",
    detail: target.transport,
    command: undefined,
  };
}

function conciseBridgeError(error: string) {
  const firstLine = error.split("\n").map((line) => line.trim()).find(Boolean) ?? error;
  return firstLine.length > 96 ? `${firstLine.slice(0, 93)}...` : firstLine;
}

function ScreenMini({ label, value }: { label: string; value: string }) {
  return (
    <div className="screen-mini">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function isEditableInputClassName(className: string) {
  return /(TextField|TextView|SearchBarTextField|TextInput|SecureText)/i.test(className);
}

function roundedGestureValue(value: number) {
  return Number(value.toFixed(3));
}

function GestureOverlay({ gesture }: { gesture: GesturePreview }) {
  if (gesture.kind === "tap" || gesture.kind === "longPress") {
    return (
      <div
        className={`gesture-touch ${gesture.kind === "longPress" ? "is-long-press" : "is-tap"}`}
        style={{
          "--gesture-x": `${gesture.xPercent}%`,
          "--gesture-y": `${gesture.yPercent}%`,
        } as CSSProperties}
      />
    );
  }

  if (gesture.kind === "pinch") {
    const startDiameter = Math.max(22, Math.min(160, gesture.startDistance * 0.18));
    const endDiameter = Math.max(28, Math.min(190, gesture.endDistance * 0.18));
    return (
      <div
        className="gesture-pinch"
        aria-hidden="true"
        style={{
          "--gesture-x": `${gesture.centerXPercent}%`,
          "--gesture-y": `${gesture.centerYPercent}%`,
          "--pinch-start": `${startDiameter}px`,
          "--pinch-end": `${endDiameter}px`,
        } as CSSProperties}
      >
        <span />
        <strong>{gesture.scale >= 1 ? "zoom" : "pinch"}</strong>
      </div>
    );
  }

  const deltaX = gesture.endXPercent - gesture.startXPercent;
  const deltaY = gesture.endYPercent - gesture.startYPercent;
  const angle = Math.atan2(deltaY, deltaX) * (180 / Math.PI);
  const length = Math.max(16, Math.hypot(deltaX, deltaY));

  return (
    <div className="gesture-swipe" aria-hidden="true">
      <div
        className="gesture-trail"
        style={{
          "--gesture-x": `${gesture.startXPercent}%`,
          "--gesture-y": `${gesture.startYPercent}%`,
          "--gesture-angle": `${angle}deg`,
          "--gesture-length": `${length}%`,
        } as CSSProperties}
      />
      <div
        className="gesture-touch is-start"
        style={{
          "--gesture-x": `${gesture.startXPercent}%`,
          "--gesture-y": `${gesture.startYPercent}%`,
        } as CSSProperties}
      />
      <div
        className="gesture-touch is-end"
        style={{
          "--gesture-x": `${gesture.endXPercent}%`,
          "--gesture-y": `${gesture.endYPercent}%`,
        } as CSSProperties}
      />
    </div>
  );
}

function InputActivityBadge({ activity }: { activity: InputActivity }) {
  return (
    <div className={`input-activity-badge is-${activity.status}`} role="status" aria-live="polite">
      <span />
      <strong>{activity.label}</strong>
    </div>
  );
}

function Inspector({
  hidden,
  target,
  events,
  bridge,
  selectedNode,
  selectedNodeDraft,
  onSelectedNodeDraftChange,
  onSelectedNodeDraftReset,
}: {
  hidden?: boolean;
  target: DeviceTarget;
  events: NetworkEvent[];
  bridge: BridgeState;
  selectedNode: HierarchyLayerNode | null;
  selectedNodeDraft?: HierarchyNodeHotEditDraft;
  onSelectedNodeDraftChange: (patch: HierarchyNodeHotEditDraft) => void;
  onSelectedNodeDraftReset: () => void;
}) {
  const errorCount = events.filter((event) => event.status >= 400).length;

  return (
    <aside className="hub-inspector" aria-label="检查器" hidden={hidden}>
      <section className="app-tile" aria-label="当前应用">
        <div className="app-icon">
          <Activity size={18} />
        </div>
        <div>
          <strong>{target.appName}</strong>
          <span>{target.bundleId}</span>
        </div>
        <em>{localizeStatusLabel(target.statusLabel)}</em>
      </section>

      <div className="metric-stack">
        <Metric icon={Gauge} label="帧率" value={target.fps.toString()} />
        <Metric icon={Clock3} label="延迟" value={`${target.latencyMs} 毫秒`} />
        <Metric icon={Braces} label="AX 节点" value={target.hierarchyNodes.toString()} />
        <Metric icon={DatabaseZap} label="HTTP 错误" value={errorCount.toString()} />
      </div>

      <SelectedNodeHotEditPanel
        node={selectedNode}
        draft={selectedNodeDraft}
        onDraftChange={onSelectedNodeDraftChange}
        onReset={onSelectedNodeDraftReset}
      />

      <dl className="inspector-details">
        <div>
          <dt>设备</dt>
          <dd>{target.device}</dd>
        </div>
        {target.udid ? (
          <div>
            <dt>UDID</dt>
            <dd>{target.udid}</dd>
          </div>
        ) : null}
        <div>
          <dt>传输</dt>
          <dd>{target.transport}</dd>
        </div>
        <div>
          <dt>来源</dt>
          <dd>{target.realSource ? bridge.sourceCommands.join(" · ") || target.transport : target.proxyLabel}</dd>
        </div>
      </dl>

      <div className="inspector-footer">
        <Search size={15} />
        <span>过滤</span>
        <strong>开发者</strong>
        <ChevronDown size={14} />
      </div>
    </aside>
  );
}

function SelectedNodeHotEditPanel({
  node,
  draft,
  onDraftChange,
  onReset,
}: {
  node: HierarchyLayerNode | null;
  draft?: HierarchyNodeHotEditDraft;
  onDraftChange: (patch: HierarchyNodeHotEditDraft) => void;
  onReset: () => void;
}) {
  if (!node) {
    return (
      <section className="selected-node-panel is-empty" aria-label="选中视图节点">
        <div className="selected-node-heading">
          <strong>选中视图节点</strong>
          <span>在左侧视图树中选择节点后显示配置</span>
        </div>
      </section>
    );
  }

  const frame = resolveHotEditFrame(node, draft);
  const opacity = resolveHotEditOpacity(node, draft);
  const cornerRadius = resolveHotEditCornerRadius(node, draft);
  const backgroundColor = resolveHotEditBackgroundColor(node, draft);
  const hidden = resolveHotEditHidden(node, draft);
  const hasDraft = hasHierarchyNodeDraft(draft);
  const nodeName = node.name ? readableViewTreeLabel(node.name) : "";
  const typeLabel = readableViewTreeLabel(node.type);

  return (
    <section className="selected-node-panel" aria-label="选中视图节点">
      <div className="selected-node-heading">
        <div>
          <strong>{typeLabel}</strong>
          {nodeName ? <span>{nodeName}</span> : null}
        </div>
        <em>{hasDraft ? "本地热修改预览" : "Runtime DTO"}</em>
      </div>

      <dl className="selected-node-summary">
        <div>
          <dt>ID</dt>
          <dd>{node.id}</dd>
        </div>
        <div>
          <dt>Frame</dt>
          <dd>{`${formatInspectorNumber(frame.x)}, ${formatInspectorNumber(frame.y)}, ${formatInspectorNumber(frame.width)} x ${formatInspectorNumber(frame.height)}`}</dd>
        </div>
        <div>
          <dt>Depth</dt>
          <dd>{node.depth}</dd>
        </div>
        <div>
          <dt>State</dt>
          <dd>{hidden ? "隐藏" : node.interactive ? "可交互" : "可见"}</dd>
        </div>
      </dl>

      <div className="hot-edit-grid" aria-label="热修改预览">
        <HotEditNumber
          label="X"
          value={frame.x}
          onChange={(value) => onDraftChange({ frame: { x: value } })}
        />
        <HotEditNumber
          label="Y"
          value={frame.y}
          onChange={(value) => onDraftChange({ frame: { y: value } })}
        />
        <HotEditNumber
          label="Width"
          min={1}
          value={frame.width}
          onChange={(value) => onDraftChange({ frame: { width: Math.max(1, value) } })}
        />
        <HotEditNumber
          label="Height"
          min={1}
          value={frame.height}
          onChange={(value) => onDraftChange({ frame: { height: Math.max(1, value) } })}
        />
        <HotEditNumber
          label="Opacity"
          max={1}
          min={0}
          step={0.05}
          value={opacity}
          onChange={(value) => onDraftChange({ opacity: Math.max(0, Math.min(1, value)) })}
        />
        <HotEditNumber
          label="Radius"
          min={0}
          value={cornerRadius}
          onChange={(value) => onDraftChange({ cornerRadius: Math.max(0, value) })}
        />
        <label className="hot-edit-control">
          <span>Color</span>
          <input
            aria-label="修改选中节点背景色"
            type="color"
            value={normalizeColorInput(backgroundColor)}
            onChange={(event) => onDraftChange({ backgroundColor: event.currentTarget.value })}
          />
        </label>
        <label className="hot-edit-toggle">
          <input
            aria-label="隐藏选中节点预览"
            checked={hidden}
            type="checkbox"
            onChange={(event) => onDraftChange({ hidden: event.currentTarget.checked })}
          />
          <span>Hidden</span>
        </label>
      </div>

      <div className="hot-edit-footer">
        <span>本地预览，未写回 App runtime</span>
        <button type="button" disabled={!hasDraft} onClick={onReset}>重置</button>
      </div>
    </section>
  );
}

function HotEditNumber({
  label,
  max,
  min,
  step = 1,
  value,
  onChange,
}: {
  label: string;
  max?: number;
  min?: number;
  step?: number;
  value: number;
  onChange: (value: number) => void;
}) {
  return (
    <label className="hot-edit-control">
      <span>{label}</span>
      <input
        aria-label={`修改选中节点 ${label}`}
        max={max}
        min={min}
        step={step}
        type="number"
        value={formatInputNumber(value)}
        onChange={(event) => {
          const next = Number(event.currentTarget.value);
          if (Number.isFinite(next)) {
            onChange(next);
          }
        }}
      />
    </label>
  );
}

function hasHierarchyNodeDraft(draft?: HierarchyNodeHotEditDraft) {
  if (!draft) return false;
  if (draft.frame && Object.keys(draft.frame).length > 0) return true;
  return draft.opacity !== undefined || draft.cornerRadius !== undefined || draft.backgroundColor !== undefined || draft.hidden !== undefined;
}

function formatInspectorNumber(value: number) {
  return Number.isInteger(value) ? value.toString() : value.toFixed(2);
}

function formatInputNumber(value: number) {
  return Number.isInteger(value) ? value.toString() : Number(value.toFixed(3)).toString();
}

function normalizeColorInput(value: string) {
  const trimmed = value.trim();
  if (/^#[0-9a-f]{6}$/i.test(trimmed)) return trimmed;
  if (/^#[0-9a-f]{3}$/i.test(trimmed)) {
    return `#${trimmed[1]}${trimmed[1]}${trimmed[2]}${trimmed[2]}${trimmed[3]}${trimmed[3]}`;
  }
  return "#64d26a";
}

function DevtoolsTabs({
  activePanel,
  language,
  onSelectPanel,
}: {
  activePanel: DevtoolsPanel;
  language: DisplayLanguage;
  onSelectPanel: (panel: DevtoolsPanel) => void;
}) {
  const tabs: Array<{ id: DevtoolsPanel; label: string }> = [
    { id: "config", label: language === "zh-CN" ? "配置" : "Config" },
    { id: "network", label: language === "zh-CN" ? "网络" : "Network" },
    { id: "logs", label: language === "zh-CN" ? "日志" : "Logs" },
    { id: "settings", label: language === "zh-CN" ? "设置" : "Settings" },
  ];

  return (
    <div className="inspector-tabs" role="tablist" aria-label={language === "zh-CN" ? "右侧工具分区" : "Right-side tool sections"}>
      {tabs.map((tab) => (
        <button
          key={tab.id}
          className={activePanel === tab.id ? "is-active" : ""}
          type="button"
          role="tab"
          aria-selected={activePanel === tab.id}
          onClick={() => onSelectPanel(tab.id)}
        >
          {tab.label}
        </button>
      ))}
    </div>
  );
}

function Metric({
  icon: Icon,
  label,
  value,
}: {
  icon: LucideIcon;
  label: string;
  value: string;
}) {
  return (
    <div className="metric">
      <Icon size={16} />
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function SettingsPanel({
  id,
  hidden,
  language,
  onLanguageChange,
}: {
  id?: string;
  hidden?: boolean;
  language: DisplayLanguage;
  onLanguageChange: (language: DisplayLanguage) => void;
}) {
  const isChinese = language === "zh-CN";

  return (
    <section
      id={id}
      className="settings-panel"
      role={id ? "tabpanel" : undefined}
      aria-label={isChinese ? "设置" : "Settings"}
      hidden={hidden}
    >
      <div className="settings-heading">
        <Settings2 size={17} />
        <div>
          <strong>{isChinese ? "设置" : "Settings"}</strong>
          <span>{isChinese ? "仅影响本机 Web 展示偏好" : "Local Web display preferences only"}</span>
        </div>
      </div>

      <div className="settings-group">
        <div className="settings-copy">
          <strong>{isChinese ? "语言偏好" : "Language preference"}</strong>
          <span>
            {isChinese
              ? "用于右侧工具区标签、日志和展示层格式化；不改变 CLI / HTTP 机器可读契约。"
              : "Used for right-side tool labels, logs, and display formatting. CLI / HTTP contracts remain unchanged."}
          </span>
        </div>

        <div className="language-options" role="radiogroup" aria-label={isChinese ? "语言偏好" : "Language preference"}>
          {displayLanguageOptions.map((option) => (
            <label className={language === option.id ? "is-selected" : ""} key={option.id}>
              <input
                checked={language === option.id}
                name="display-language"
                onChange={() => onLanguageChange(option.id)}
                type="radio"
                value={option.id}
              />
              <span>
                <strong>{option.label}</strong>
                <em>{option.detail}</em>
              </span>
            </label>
          ))}
        </div>
      </div>

      <p className="settings-footnote">
        {isChinese
          ? "偏好保存在当前浏览器的 localStorage，刷新页面后继续生效。"
          : "The preference is stored in this browser's localStorage and survives refreshes."}
      </p>
    </section>
  );
}

function NetworkStrip({
  id,
  hidden,
  language,
  events,
}: {
  id?: string;
  hidden?: boolean;
  language: DisplayLanguage;
  events: NetworkEvent[];
}) {
  return (
    <section
      id={id}
      className="evidence-strip"
      role={id ? "tabpanel" : undefined}
      aria-label={language === "zh-CN" ? "网络证据" : "Network evidence"}
      hidden={hidden}
    >
      <div className="strip-heading">
        <Network size={16} />
        <strong>{language === "zh-CN" ? "网络" : "Network"}</strong>
      </div>
      <div className="network-rows">
        {events.map((event) => (
          <div className="network-row" key={event.id}>
            <span className="method">{event.method}</span>
            <span className="path">{event.path}</span>
            <span className={event.status >= 400 ? "code is-error" : "code"}>{event.status}</span>
            <span>{event.latencyMs} 毫秒</span>
            <span>{modeLabel[language][event.mode]}</span>
          </div>
        ))}
      </div>
    </section>
  );
}

function LogStrip({
  id,
  hidden,
  language,
  entries,
}: {
  id?: string;
  hidden?: boolean;
  language: DisplayLanguage;
  entries: LogEntry[];
}) {
  return (
    <section
      id={id}
      className="evidence-strip log-strip"
      role={id ? "tabpanel" : undefined}
      aria-label={language === "zh-CN" ? "运行日志" : "Runtime logs"}
      hidden={hidden}
    >
      <div className="strip-heading">
        <TerminalSquare size={16} />
        <strong>{language === "zh-CN" ? "日志" : "Logs"}</strong>
      </div>
      <div className="log-rows">
        {entries.map((entry) => {
          const localized = localizeLogEntry(entry, language);
          return (
            <div className={`log-row log-${entry.level}`} key={entry.id} title={localized.originalMessage}>
              <span className="log-time">{localized.timeLabel}</span>
              <strong>{localized.levelLabel}</strong>
              <em>{localized.sourceLabel}</em>
              <p>{localized.messageLabel}</p>
            </div>
          );
        })}
      </div>
    </section>
  );
}
