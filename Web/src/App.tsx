import { useCallback, useEffect, useMemo, useRef, useState, type CSSProperties, type PointerEvent } from "react";
import { ConfigProvider, Layout, theme as antTheme } from "antd";
import {
  Activity,
  Braces,
  ChevronDown,
  Clock3,
  DatabaseZap,
  Gauge,
  Info,
  Minus,
  Network,
  PanelLeft,
  PanelRight,
  Plus,
  RefreshCw,
  Search,
  Settings2,
  TerminalSquare,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { HostBridgeNotice } from "./components/HostBridgeNotice";
import {
  DeviceCanvas,
  DeviceHubToolbar,
  DevtoolsTabs,
  Inspector,
  LogStrip,
  NetworkStrip,
  SettingsPage,
  TargetNavigator,
  type DeviceCanvasTapInput,
} from "./components/InspectorWorkspace";
import { hierarchyScenes, logs, networkEvents, targets as mockTargets } from "./data/mockData";
import { describeHostBridgePresentation } from "./data/hostBridgePresentation";
import { resolveEvidenceSources } from "./data/hierarchyMaterialPolicy";
import { fetchHostHierarchy, fetchHostLogs, fetchHostScreenshot, fetchHostTargets, sendHostInput } from "./data/iosSimulatorClient";
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

type SidebarPanel = "devices" | "view-tree";
type DevtoolsPanel = "config" | "network" | "logs";
type DisplayLanguage = "zh-CN" | "en-US";
type AppRoute = "inspect" | "settings";

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
  stale?: boolean;
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
const liveHierarchyRefreshIntervalMs = 1000;
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

function readAppRoute(): AppRoute {
  if (typeof window === "undefined") return "inspect";
  return window.location.pathname === "/settings" ? "settings" : "inspect";
}

function currentInspectURL() {
  if (typeof window === "undefined") return "/inspect";
  const path = window.location.pathname === "/settings" ? "/inspect" : window.location.pathname || "/inspect";
  return `${path}${window.location.search}${window.location.hash}`;
}

function readInspectorDemoMode() {
  if (typeof window === "undefined") return false;
  return new URL(window.location.href).searchParams.get("__tritonkit_inspector_demo") === "1";
}

function readonlyInspectorDemoTargets(): DeviceTarget[] {
  return mockTargets.map((target) => ({
    ...target,
    readonly: true,
    canInput: false,
    canScreenshot: false,
    realSource: undefined,
    targetSelector: target.id,
    transport: "readonly fixture",
    lastAction: "Observed runtime evidence",
    actionResult: "ok",
    proxyLabel: target.proxyMode === "mock" ? "Mock evidence" : target.proxyLabel,
  }));
}

function readonlyInspectorDemoHierarchyById(targets: DeviceTarget[]): Record<string, HierarchyCacheEntry> {
  return Object.fromEntries(
    targets.map((target) => [
      target.id,
      {
        loading: false,
        scene: hierarchyScenes[target.platform],
      },
    ])
  );
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
  const [appRoute, setAppRoute] = useState<AppRoute>(() => readAppRoute());
  const [lastInspectURL, setLastInspectURL] = useState(() => currentInspectURL());
  const isInspectorDemo = useMemo(() => readInspectorDemoMode(), []);
  const [selectedId, setSelectedId] = useState(initialRoute.targetId ?? "");
  const [hostTargets, setHostTargets] = useState<DeviceTarget[]>([]);
  const [targetSearch, setTargetSearch] = useState("");
  const [bridge, setBridge] = useState<BridgeState>({ loading: true, sourceCommands: [] });
  const [bridgeOutputs, setBridgeOutputs] = useState<BridgeCommandOutput[]>([]);
  const [interactionLogs, setInteractionLogs] = useState<LogEntry[]>([]);
  const [activeDevtoolsPanel, setActiveDevtoolsPanel] = useState<DevtoolsPanel>("config");
  const [displayLanguage, setDisplayLanguage] = useState<DisplayLanguage>(() => readDisplayLanguagePreference());
  const [isSidebarVisible, setIsSidebarVisible] = useState(true);
  const [isDevtoolsVisible, setIsDevtoolsVisible] = useState(true);
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
  const [inputDispatchingByTargetId, setInputDispatchingByTargetId] = useState<Record<string, boolean>>({});
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
  const refreshHierarchy = useCallback(async (target: DeviceTarget, options: { showLoading?: boolean } = {}) => {
    if (target.id === emptyTargetId || !(target.targetSelector ?? target.udid ?? target.id)) return;
    if (options.showLoading ?? true) {
      setHierarchyById((entries) => ({
        ...entries,
        [target.id]: { ...entries[target.id], loading: true },
      }));
    }
    try {
      const scene = await fetchHostHierarchy(target);
      setHierarchyById((entries) => ({
        ...entries,
        [target.id]: { loading: false, scene, stale: false },
      }));
    } catch (error) {
      setHierarchyById((entries) => ({
        ...entries,
        [target.id]: {
          loading: false,
          error: error instanceof Error ? error.message : String(error),
          scene: entries[target.id]?.scene,
          stale: Boolean(entries[target.id]?.scene),
        },
      }));
      throw error;
    }
  }, []);

  useEffect(() => {
    const handlePopState = () => {
      const nextAppRoute = readAppRoute();
      setAppRoute(nextAppRoute);
      if (nextAppRoute !== "inspect") return;
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
    if (appRoute !== "inspect") return;
    if (selected.id === emptyTargetId) return;
    writeDeviceHubRoute({
      targetId: selected.id,
      panel: sidebarPanel,
      nodeId: selectedHierarchyNode ?? undefined,
    });
  }, [appRoute, selected.id, selectedHierarchyNode, sidebarPanel]);

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

    void refreshHierarchy(selected).catch(() => {
      // Error state is stored in hierarchy cache for the panel to render.
    });
  }, [hierarchyById, hierarchyReloadKey, refreshHierarchy, selected, sidebarPanel]);

  useEffect(() => {
    if (sidebarPanel !== "view-tree") return;
    if (!selected.realSource || selected.id === emptyTargetId || !(selected.targetSelector ?? selected.udid ?? selected.id)) return;
    if (isSelectedSnapshotMode) return;

    let cancelled = false;
    let timer: number | undefined;
    let inFlight = false;

    const tick = async () => {
      if (cancelled || inFlight) return;
      inFlight = true;
      try {
        await refreshHierarchy(selected, { showLoading: false });
      } catch {
        // Error state is stored in hierarchy cache; keep the live loop alive for recovery.
      } finally {
        inFlight = false;
        if (!cancelled) {
          timer = window.setTimeout(tick, liveHierarchyRefreshIntervalMs);
        }
      }
    };

    timer = window.setTimeout(tick, liveHierarchyRefreshIntervalMs);
    return () => {
      cancelled = true;
      if (timer) {
        window.clearTimeout(timer);
      }
    };
  }, [isSelectedSnapshotMode, refreshHierarchy, selected, sidebarPanel]);

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
    if (appRoute !== "inspect") {
      return () => {
        cancelled = true;
      };
    }
    if (isInspectorDemo) {
      const demoTargets = readonlyInspectorDemoTargets();
      const firstSelected = demoTargets.find((target) => target.id === initialSelectedId) ?? demoTargets[0];
      setHostTargets(demoTargets);
      setBridge({
        loading: false,
        capturedAt: new Date().toISOString(),
        sourceCommands: [
          "triton status --json",
          "triton capabilities --json",
          "triton hierarchy --json",
          "triton evidence --json",
        ],
      });
      setBridgeOutputs([
        {
          id: "inspector-demo-trace",
          platform: "host",
          command: "triton inspector demo fixture --readonly",
          ok: true,
          exitCode: 0,
          stdout: "readonly Inspect Session fixture loaded",
          stderr: "",
        },
      ]);
      setHierarchyById(readonlyInspectorDemoHierarchyById(demoTargets));
      setSidebarPanel("view-tree");
      setSelectedId(firstSelected.id);
      const firstScene = hierarchyScenes[firstSelected.platform];
      const initialNodeId = initialRoute.nodeId && firstScene.nodes.some((node) => node.id === initialRoute.nodeId)
        ? initialRoute.nodeId
        : firstScene.rootId;
      setSelectedHierarchyNode(initialNodeId);
      return () => {
        cancelled = true;
      };
    }
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
  }, [appRoute, isInspectorDemo]);

  const openSettingsPage = () => {
    const inspectURL = currentInspectURL();
    setLastInspectURL(inspectURL);
    window.history.pushState(null, "", "/settings");
    setAppRoute("settings");
  };

  const openInspectSession = () => {
    const nextURL = lastInspectURL && !lastInspectURL.startsWith("/settings") ? lastInspectURL : "/inspect";
    window.history.pushState(null, "", nextURL);
    setAppRoute("inspect");
  };

  useEffect(() => {
    if (selected.realSource !== "ios-simulator") {
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
    if (sidebarPanel === "view-tree" && selected.realSource === "ios-real-device") {
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
    sidebarPanel,
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

  const handleCanvasTap = async (target: DeviceTarget, input: DeviceCanvasTapInput) => {
    if (!target.canInput || target.readonly || !(target.targetSelector ?? target.udid ?? target.id)) {
      return;
    }
    const tapLabel = "tap x=" + input.x + " y=" + input.y;
    setInputDispatchingByTargetId((current) => ({
      ...current,
      [target.id]: true,
    }));
    setLastActionById((current) => ({
      ...current,
      [target.id]: {
        lastAction: "Dispatching " + tapLabel,
        actionResult: "warning",
      },
    }));
    setInteractionLogs((current) => [makeLog("info", "input " + target.id + " " + tapLabel), ...current]);

    try {
      const result = await sendHostInput(target, {
        type: "tap",
        x: input.x,
        y: input.y,
        width: input.width,
        height: input.height,
      });
      const ok = result.ok !== false;
      const message = result.message || (ok ? "Tap submitted" : "Tap failed");
      setLastActionById((current) => ({
        ...current,
        [target.id]: {
          lastAction: message,
          actionResult: ok ? "ok" : "failed",
        },
      }));
      setInteractionLogs((current) => [makeLog(ok ? "info" : "error", "input result " + target.id + " " + tapLabel + " · " + message), ...current]);
      await refreshScreenshot(target, { live: true });
      if (target.realSource && (sidebarPanel === "view-tree" || hierarchyById[target.id]?.scene)) {
        try {
          const scene = await fetchHostHierarchy(target);
          setHierarchyById((entries) => ({
            ...entries,
            [target.id]: { loading: false, scene },
          }));
        } catch (error) {
          const message = error instanceof Error ? error.message : String(error);
          setInteractionLogs((current) => [makeLog("warn", "hierarchy refresh after tap failed " + message), ...current]);
        }
      }
      if (target.platform === "ios") {
        fetchHostLogs(target)
          .then((result) => {
            setHostLogsById((current) => ({
              ...current,
              [target.id]: result.entries,
            }));
          })
          .catch(() => {});
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      setLastActionById((current) => ({
        ...current,
        [target.id]: {
          lastAction: message,
          actionResult: "failed",
        },
      }));
      setInteractionLogs((current) => [makeLog("error", "input failed " + target.id + " " + tapLabel + " · " + message), ...current]);
    } finally {
      setInputDispatchingByTargetId((current) => ({
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

  if (appRoute === "settings") {
    return (
      <SettingsPage
        language={displayLanguage}
        onBack={openInspectSession}
        onLanguageChange={setDisplayLanguage}
      />
    );
  }

  return (
    <ConfigProvider
      theme={{
        algorithm: antTheme.darkAlgorithm,
        token: {
          colorPrimary: "#1677FF",
          colorSuccess: "#52C41A",
          colorWarning: "#FAAD14",
          colorError: "#FF4D4F",
          colorBgBase: "#242424",
          colorBgLayout: "#2b2b2b",
          colorBgContainer: "#353535",
          colorBgElevated: "#3a3a3a",
          colorBorder: "#4a4a4a",
          colorBorderSecondary: "#404040",
          colorText: "#F5F5F5",
          colorTextSecondary: "#BFBFBF",
          colorTextTertiary: "#8C8C8C",
          borderRadius: 6,
          fontSize: 14,
          wireframe: false,
        },
        components: {
          Card: {
            borderRadiusLG: 8,
            colorBgContainer: "#353535",
            colorBorderSecondary: "#4a4a4a",
          },
          Tabs: {
            itemColor: "#BFBFBF",
            itemSelectedColor: "#69B1FF",
            inkBarColor: "#1677FF",
          },
          Tree: {
            nodeHoverBg: "#3f3f3f",
            nodeSelectedBg: "#E6F4FF",
          },
        },
      }}
    >
    <main className="device-hub-shell">
      <Layout
        className="device-hub-window"
        aria-label="Triton Inspector Inspect Session"
      >
        <DeviceHubToolbar
          target={selectedWithScreenshot}
          targets={pageTargets}
          bridgeSubtitle={bridgePresentation.toolbarLabel}
          isSidebarVisible={isSidebarVisible}
          isDevtoolsVisible={isDevtoolsVisible}
          isRefreshing={isRefreshingAll}
          isTargetMenuOpen={isToolbarTargetMenuOpen}
          onToggleSidebar={() => setIsSidebarVisible((current) => !current)}
          onToggleDevtools={() => setIsDevtoolsVisible((current) => !current)}
          onOpenSettings={openSettingsPage}
          onRefresh={handleRefreshAll}
          onToggleTargetMenu={() => setIsToolbarTargetMenuOpen((current) => !current)}
          onCloseTargetMenu={() => setIsToolbarTargetMenuOpen(false)}
          onSelectTarget={(targetId) => {
            setSelectedId(targetId);
            setIsToolbarTargetMenuOpen(false);
          }}
        />
        <Layout
          className={[
            "hub-body",
            isSidebarVisible ? "" : "is-sidebar-hidden",
            isDevtoolsVisible ? "" : "is-devtools-hidden",
          ].filter(Boolean).join(" ")}
        >
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
            hierarchyStale={Boolean(selectedHierarchy?.scene && (selectedHierarchy.stale || selectedHierarchy.error))}
            selectedHierarchyNode={selectedHierarchyNode}
            selectedHierarchyNodeDraft={selectedHierarchyNodeDraft}
            screenshotError={screenshotError}
            livePreview={selectedLivePreview}
            isSnapshotMode={isSelectedSnapshotMode}
            isSnapshotRefreshing={isSelectedSnapshotRefreshing}
            isDiscoveringHostTargets={isDiscoveringHostTargets}
            isInputDispatching={inputDispatchingByTargetId[selectedWithScreenshot.id] ?? false}
            onPreviewFpsChange={handlePreviewFpsChange}
            onSnapshotModeChange={setSelectedSnapshotMode}
            onSnapshotRefresh={refreshSelectedSnapshot}
            onSelectHierarchyNode={setSelectedHierarchyNode}
            onTap={handleCanvasTap}
          />
          {isDevtoolsVisible ? (
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
              </div>
            </aside>
          ) : null}
        </Layout>
      </Layout>
    </main>
    </ConfigProvider>
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
