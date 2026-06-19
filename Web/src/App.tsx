import { useCallback, useEffect, useMemo, useRef, useState, type ChangeEvent, type ClipboardEvent, type CSSProperties, type KeyboardEvent, type PointerEvent, type WheelEvent } from "react";
import {
  Activity,
  Braces,
  ChevronDown,
  Clock3,
  Crosshair,
  DatabaseZap,
  EyeOff,
  FileText,
  Gauge,
  Info,
  Keyboard,
  Maximize2,
  Minus,
  MoreHorizontal,
  MousePointer2,
  Network,
  PanelLeft,
  Plus,
  RefreshCw,
  ScanLine,
  Search,
  Settings2,
  SlidersHorizontal,
  TerminalSquare,
  ZoomIn,
  ZoomOut,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { HostBridgeNotice } from "./components/HostBridgeNotice";
import { hierarchyScenes, logs, networkEvents, targets } from "./data/mockData";
import { describeHostBridgePresentation } from "./data/hostBridgePresentation";
import { computeParityClaim, getMaterialExplanation, resolveEvidenceSources } from "./data/hierarchyMaterialPolicy";
import { fetchHostHierarchyResponse, fetchHostLogs, fetchHostScreenshot, fetchHostTargets, type HostInputResponse, sendHostInput } from "./data/iosSimulatorClient";
import type {
  BridgeCommandOutput,
  DeviceFrameOrientation,
  DeviceTarget,
  HierarchyLayerNode,
  HierarchyScene,
  HierarchyVisualSource,
  HostHierarchyResponse,
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

const modeLabel = {
  record: "录制",
  mock: "Mock",
  blocked: "阻断",
  off: "关闭",
};

const logLevelLabel: Record<LogEntry["level"], string> = {
  info: "信息",
  warn: "警告",
  error: "错误",
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

type DeviceCanvasTool = "point" | "probe";

type HierarchyCaptureStatus = "idle" | "loading" | "ready" | "error";

type HierarchyCaptureState = {
  status: HierarchyCaptureStatus;
  capturedAt?: string;
  command?: string;
  method?: "GET" | "POST" | string;
  evidence?: HostHierarchyResponse["captureEvidence"];
  error?: string;
};

type SidebarPanel = "devices" | "view-tree";

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

const canvasZoomLevels = [0.75, 0.9, 1, 1.15, 1.3, 1.5] as const;
const previewFpsMin = 1;
const previewFpsMax = 60;
const longPressThresholdMs = 520;
const tapDistanceThreshold = 18;

function hierarchySceneForTarget(target: DeviceTarget): HierarchyScene {
  return hierarchyScenes[target.platform];
}

function hierarchyCaptureStateFromResponse(response: HostHierarchyResponse, fallbackMethod: "GET" | "POST"): HierarchyCaptureState {
  return {
    status: "ready",
    capturedAt: response.capturedAt,
    command: response.source.command,
    method: response.control?.method ?? fallbackMethod,
    evidence: response.captureEvidence,
  };
}

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

function normalizePreviewFps(value: number) {
  if (!Number.isFinite(value)) return previewFpsMin;
  return Math.max(previewFpsMin, Math.min(previewFpsMax, Math.round(value)));
}

function fpsToRefreshIntervalMs(fps: number) {
  return Math.max(1000 / previewFpsMax, Math.round(1000 / normalizePreviewFps(fps)));
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
  const [selectedId, setSelectedId] = useState(initialRoute.targetId ?? targets[0].id);
  const [hostTargets, setHostTargets] = useState<DeviceTarget[]>([]);
  const [targetSearch, setTargetSearch] = useState("");
  const [bridge, setBridge] = useState<BridgeState>({ loading: true, sourceCommands: [] });
  const [bridgeOutputs, setBridgeOutputs] = useState<BridgeCommandOutput[]>([]);
  const [interactionLogs, setInteractionLogs] = useState<LogEntry[]>([]);
  const [isNetworkVisible, setIsNetworkVisible] = useState(true);
  const [isLogsVisible, setIsLogsVisible] = useState(true);
  const [isSidebarVisible, setIsSidebarVisible] = useState(true);
  const [sidebarPanel, setSidebarPanel] = useState<SidebarPanel>(initialRoute.panel ?? (initialRoute.nodeId ? "view-tree" : "devices"));
  const [isToolbarTargetMenuOpen, setIsToolbarTargetMenuOpen] = useState(false);
  const [canvasZoom, setCanvasZoom] = useState(1);
  const [isHierarchySnapshotMode, setIsHierarchySnapshotMode] = useState(false);
  const [selectedHierarchyNode, setSelectedHierarchyNode] = useState<string | null>(initialRoute.nodeId ?? null);
  const [isRefreshingAll, setIsRefreshingAll] = useState(false);
  const [lastActionById, setLastActionById] = useState<
    Record<string, { lastAction: string; actionResult: DeviceTarget["actionResult"] }>
  >({});
  const [screenshotById, setScreenshotById] = useState<
    Record<string, { dataUrl: string; pixelWidth: number | null; pixelHeight: number | null }>
  >({});
  const [hostLogsById, setHostLogsById] = useState<Record<string, LogEntry[]>>({});
  const [livePreviewById, setLivePreviewById] = useState<Record<string, LivePreviewState>>({});
  const [previewFpsById, setPreviewFpsById] = useState<Record<string, number>>({});
  const [inputActivityById, setInputActivityById] = useState<Record<string, InputActivity | undefined>>({});
  const [screenshotError, setScreenshotError] = useState<string | undefined>();
  const pageTargets = useMemo(() => {
    return mergeHostTargetsWithMockFallback(hostTargets, targets);
  }, [hostTargets]);
  const filteredTargets = useMemo(() => filterTargetsBySearch(pageTargets, targetSearch), [pageTargets, targetSearch]);
  const bridgePresentation = useMemo(
    () => describeHostBridgePresentation(bridge, hostTargets.length),
    [bridge, hostTargets.length]
  );
  const selected = useMemo(
    () => pageTargets.find((target) => target.id === selectedId) ?? pageTargets[0] ?? targets[0],
    [pageTargets, selectedId]
  );
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
  const bottomPanelState = [
    isNetworkVisible ? "" : "is-network-hidden",
    isLogsVisible ? "" : "is-logs-hidden",
    !isNetworkVisible && !isLogsVisible ? "is-bottom-hidden" : "",
  ].filter(Boolean).join(" ");
  const isEvidenceVisible = isNetworkVisible || isLogsVisible;
  const windowEvidenceState = [
    isLogsVisible ? "" : "is-logs-hidden",
    isEvidenceVisible ? "" : "is-evidence-hidden",
  ].filter(Boolean).join(" ");

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
    writeDeviceHubRoute({
      targetId: selected.id,
      panel: sidebarPanel,
      nodeId: selectedHierarchyNode ?? undefined,
    });
  }, [selected.id, selectedHierarchyNode, sidebarPanel]);

  useEffect(() => {
    if (!selectedHierarchyNode) return;
    const scene = hierarchySceneForTarget(selected);
    if (!scene.nodes.some((node) => node.id === selectedHierarchyNode)) {
      setSelectedHierarchyNode(null);
    }
  }, [selected, selectedHierarchyNode]);

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
    if (isHierarchySnapshotMode) {
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
    isHierarchySnapshotMode,
  ]);

  const handleRefreshAll = async () => {
    setIsRefreshingAll(true);
    setBridge((current) => ({ ...current, loading: true, error: undefined }));
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

  const handleProbeMode = useCallback(() => {
    setIsHierarchySnapshotMode(true);
    setSidebarPanel("view-tree");
  }, []);

  const handlePointMode = useCallback(() => {
    setIsHierarchySnapshotMode(false);
  }, []);

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

  const canvasZoomIndex = canvasZoomLevels.findIndex((level) => level === canvasZoom);
  const canZoomOut = canvasZoomIndex > 0;
  const canZoomIn = canvasZoomIndex >= 0 && canvasZoomIndex < canvasZoomLevels.length - 1;
  const handleZoomOut = () => {
    if (canZoomOut) {
      setCanvasZoom(canvasZoomLevels[canvasZoomIndex - 1]);
    }
  };
  const handleResetZoom = () => setCanvasZoom(1);
  const handleZoomIn = () => {
    if (canZoomIn) {
      setCanvasZoom(canvasZoomLevels[canvasZoomIndex + 1]);
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
        className={`device-hub-window ${windowEvidenceState}`}
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
            screenshotError={screenshotError}
            livePreview={selectedLivePreview}
            inputActivity={selectedInputActivity}
            isNetworkVisible={isNetworkVisible}
            isLogsVisible={isLogsVisible}
            zoomLevel={canvasZoom}
            isDiscoveringHostTargets={isDiscoveringHostTargets}
            canZoomOut={canZoomOut}
            canZoomIn={canZoomIn}
            onToggleNetwork={() => setIsNetworkVisible((current) => !current)}
            onToggleLogs={() => setIsLogsVisible((current) => !current)}
            onZoomOut={handleZoomOut}
            onResetZoom={handleResetZoom}
            onZoomIn={handleZoomIn}
            onPreviewFpsChange={handlePreviewFpsChange}
            onProbeMode={handleProbeMode}
            onPointMode={handlePointMode}
            onInput={handleInput}
            selectedHierarchyNode={selectedHierarchyNode}
            onSelectHierarchyNode={setSelectedHierarchyNode}
          />
          <Inspector target={selectedWithScreenshot} events={selectedEvents} bridge={bridge} />
        </section>
        <section className={`hub-bottom ${bottomPanelState}`} aria-label="设备证据">
          {isNetworkVisible ? <NetworkStrip events={selectedEvents} onHide={() => setIsNetworkVisible(false)} /> : null}
          {isLogsVisible ? <LogStrip entries={selectedLogs} onHide={() => setIsLogsVisible(false)} /> : null}
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

function mergeHostTargetsWithMockFallback(hostTargets: DeviceTarget[], mockTargets: DeviceTarget[]) {
  if (hostTargets.length === 0) {
    return mockTargets;
  }
  return hostTargets;
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
      <div className="traffic-lights" aria-hidden="true">
        <span className="traffic-red" />
        <span className="traffic-yellow" />
        <span className="traffic-green" />
      </div>

      <div className="toolbar-cluster" aria-label="添加模拟器和设备">
        <IconTool label="添加目标" icon={Plus} />
        <IconTool label="筛选与排序" icon={SlidersHorizontal} />
      </div>

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

      <div className="toolbar-center">
        <div className="toolbar-cluster" aria-label="设备交互">
          <IconTool label="键盘" icon={Keyboard} />
          <IconTool label="屏幕布局" icon={ScanLine} />
        </div>
        <div className="toolbar-cluster" aria-label="压缩或展开窗口">
          <IconTool label="展开" icon={Maximize2} />
          <IconTool label="更多" icon={MoreHorizontal} />
        </div>
      </div>

      <div className="toolbar-cluster inspector-tools" aria-label="检查器工具">
        <IconTool
          label={isRefreshing ? "正在刷新全局数据" : "刷新全局数据"}
          icon={RefreshCw}
          className={isRefreshing ? "is-spinning" : ""}
          disabled={isRefreshing}
          onClick={onRefresh}
        />
        <IconTool label="调整" icon={Settings2} />
        <IconTool label="文档" icon={FileText} />
        <IconTool label="信息" icon={Info} />
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
        <ViewTreePanel selected={selected} targets={visibleTargets} onSelect={onSelect} selectedHierarchyNode={selectedHierarchyNode} onSelectHierarchyNode={onSelectHierarchyNode} />
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
  targets: visibleTargets,
  onSelect,
  selectedHierarchyNode,
  onSelectHierarchyNode,
}: {
  selected: DeviceTarget;
  targets: DeviceTarget[];
  onSelect: (id: string) => void;
  selectedHierarchyNode: string | null;
  onSelectHierarchyNode: (nodeId: string | null) => void;
}) {
  const hierarchyScene = hierarchySceneForTarget(selected);
  const treeNodes = useMemo(() => viewTreeNodesForScene(hierarchyScene), [hierarchyScene]);
  const defaultSelection = defaultViewTreeSelection(hierarchyScene);
  const selectedNode = selectedHierarchyNode ?? defaultSelection;

  useEffect(() => {
    onSelectHierarchyNode(null);
  }, [selected.id]);

  return (
    <section className="sidebar-panel view-tree-panel" aria-label="视图层级面板">
      <div className="view-tree-targets" aria-label="视图树 target 切换">
        <div className="sidebar-section-title">切换 target</div>
        <div className="view-tree-target-list">
          {visibleTargets.map((target) => (
            <button
              className={`view-tree-target-chip ${target.id === selected.id ? "is-selected" : ""}`}
              key={target.id}
              type="button"
              onClick={() => onSelect(target.id)}
            >
              <span className="view-tree-target-chip-platform">{platformLabel[target.platform]}</span>
              <strong>{target.name}</strong>
              <span>{target.appName}</span>
            </button>
          ))}
          {visibleTargets.length === 0 ? <p className="empty-devices">未找到匹配 target</p> : null}
        </div>
      </div>
      <div className="view-tree-title">
        <span>视图层级</span>
        <strong>{selected.appName}</strong>
      </div>
      <div className="view-tree-list" role="tree" aria-label={`${selected.appName} 视图层级`}>
        {treeNodes.map((node) => (
          <ViewTreeRow key={node.id} node={node} depth={0} selectedNode={selectedNode} onSelect={onSelectHierarchyNode} />
        ))}
      </div>
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
  selectedNode: string;
  onSelect: (id: string) => void;
}) {
  const hasChildren = Boolean(node.children?.length);

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
        <strong>{node.type}</strong>
        {node.name ? <span>{node.name}</span> : null}
      </button>
      {node.children?.map((child) => (
        <ViewTreeRow key={child.id} node={child} depth={depth + 1} selectedNode={selectedNode} onSelect={onSelect} />
      ))}
    </>
  );
}

function DeviceCanvas({
  target,
  screenshotError,
  livePreview,
  inputActivity,
  isNetworkVisible,
  isLogsVisible,
  zoomLevel,
  isDiscoveringHostTargets,
  canZoomOut,
  canZoomIn,
  onToggleNetwork,
  onToggleLogs,
  onZoomOut,
  onResetZoom,
  onZoomIn,
  onPreviewFpsChange,
  onProbeMode,
  onPointMode,
  onInput,
  selectedHierarchyNode,
  onSelectHierarchyNode,
}: {
  target: DeviceTarget;
  screenshotError?: string;
  livePreview?: LivePreviewState;
  inputActivity?: InputActivity;
  isNetworkVisible: boolean;
  isLogsVisible: boolean;
  zoomLevel: number;
  isDiscoveringHostTargets: boolean;
  canZoomOut: boolean;
  canZoomIn: boolean;
  onToggleNetwork: () => void;
  onToggleLogs: () => void;
  onZoomOut: () => void;
  onResetZoom: () => void;
  onZoomIn: () => void;
  onPreviewFpsChange: (fps: number) => void;
  onProbeMode: () => void;
  onPointMode: () => void;
  onInput: (input: ReadonlyInputIntent) => Promise<HostInputResponse | null>;
  selectedHierarchyNode: string | null;
  onSelectHierarchyNode: (nodeId: string | null) => void;
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
  const [activeTool, setActiveTool] = useState<DeviceCanvasTool>("point");
  const [isPreviewFpsOpen, setIsPreviewFpsOpen] = useState(false);
  const fallbackHierarchyScene = hierarchySceneForTarget(target);
  const [remoteHierarchyScene, setRemoteHierarchyScene] = useState<HierarchyScene | null>(null);
  const [hierarchyCapture, setHierarchyCapture] = useState<HierarchyCaptureState>({ status: "idle" });
  const hierarchyRequestTarget = useMemo(
    () => target,
    [target.id, target.kind, target.platform, target.scope, target.screenshotSource, target.targetSelector, target.udid]
  );
  const hierarchyScene = remoteHierarchyScene?.platform === target.platform ? remoteHierarchyScene : fallbackHierarchyScene;
  const orientation = target.frameOrientation ?? "landscape";
  const aspectRatio =
    target.screenshotPixelWidth && target.screenshotPixelHeight
      ? `${target.screenshotPixelWidth} / ${target.screenshotPixelHeight}`
      : undefined;
  const frameStyle =
    target.screenshotPixelWidth && target.screenshotPixelHeight
      ? {
          "--screen-aspect-ratio": aspectRatio,
          "--canvas-zoom": zoomLevel,
        } as CSSProperties
      : ({
          "--canvas-zoom": zoomLevel,
        } as CSSProperties);
  const orientationLabel =
    target.screenshotPixelWidth && target.screenshotPixelHeight
      ? `${orientation} ${target.screenshotPixelWidth} x ${target.screenshotPixelHeight}`
      : target.realSource
        ? `${orientation} placeholder`
        : orientation;
  const canSendInput = Boolean(
    target.realSource &&
      target.canInput &&
      target.screenshotDataUrl &&
      target.targetSelector &&
      target.screenshotPixelWidth &&
      target.screenshotPixelHeight
  );
  const isWaitingForRealScreenshot = Boolean(target.realSource && target.canScreenshot && !target.screenshotDataUrl);
  const pendingScreenshotState = screenshotPendingState(target, screenshotError);

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
    setActiveTool("point");
    onPointMode();
    setRemoteHierarchyScene(null);
    setHierarchyCapture({ status: "idle" });
  }, [onPointMode, target.id]);

  const captureHierarchy = useCallback(async (method: "GET" | "POST" = "GET") => {
    setHierarchyCapture((current) => ({
      ...current,
      status: "loading",
      method,
      error: undefined,
    }));
    try {
      const response = await fetchHostHierarchyResponse(hierarchyRequestTarget, { method });
      setRemoteHierarchyScene(response.scene);
      setHierarchyCapture(hierarchyCaptureStateFromResponse(response, method));
    } catch (error) {
      setRemoteHierarchyScene(null);
      setHierarchyCapture({
        status: "error",
        method,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }, [hierarchyRequestTarget]);

  useEffect(() => {
    if (activeTool !== "probe") return;
    void captureHierarchy("GET");
  }, [activeTool, captureHierarchy]);

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
    <section className={`hub-canvas tool-${activeTool}`} aria-label="设备画布">
      {target.screenshotDataUrl && activeTool !== "probe" ? (
        <div className={`live-preview-control ${isPreviewFpsOpen ? "is-open" : ""}`} ref={previewControlRef}>
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
          {isPreviewFpsOpen ? (
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

      <div className="device-stage" aria-label={`画布缩放 ${Math.round(zoomLevel * 100)}%`}>
        {activeTool === "probe" ? (
          <div
            className="hierarchy-stage tool-probe"
            style={frameStyle}
            aria-label={`3D 视图层级，当前工具 ${deviceToolLabel(activeTool)}`}
          >
            <HierarchySceneViewer
              scene={hierarchyScene}
              target={target}
              captureState={hierarchyCapture}
              onCapture={() => captureHierarchy("POST")}
              selectedNodeId={selectedHierarchyNode}
              onSelectNode={onSelectHierarchyNode}
            />
          </div>
        ) : (
          <div
            className={`device-frame orientation-${orientation} ${aspectRatio ? "has-real-frame" : ""}`}
            style={frameStyle}
          >
            <div className="device-side left" />
            <div className="device-side top" />
            <div className="device-side bottom" />
            <div
              className={`device-screen orientation-${orientation} ${target.screenshotTone} tool-${activeTool} ${canSendInput ? "is-interactive" : ""}`}
              aria-label={`设备画面，当前工具 ${deviceToolLabel(activeTool)}`}
              tabIndex={canSendInput ? 0 : undefined}
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
        )}
      </div>
      <DeviceControls
        activeTool={activeTool}
        onSelectTool={(tool) => {
          setActiveTool(tool);
          if (tool === "probe") {
            onProbeMode();
          } else {
            onPointMode();
          }
        }}
        target={target}
        isNetworkVisible={isNetworkVisible}
        isLogsVisible={isLogsVisible}
        onToggleNetwork={onToggleNetwork}
        onToggleLogs={onToggleLogs}
      />
      <CanvasZoomControls
        zoomLevel={zoomLevel}
        canZoomOut={canZoomOut}
        canZoomIn={canZoomIn}
        onZoomOut={onZoomOut}
        onResetZoom={onResetZoom}
        onZoomIn={onZoomIn}
      />
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

const HIERARCHY_FIXED_TILT_X = -18;
const HIERARCHY_INITIAL_YAW = 24;
const HIERARCHY_INITIAL_ZOOM = 1;
const HIERARCHY_MIN_ZOOM = 0.45;
const HIERARCHY_MAX_ZOOM = 2.4;

/**
 * 2D hit-test: find which hierarchy node was clicked by converting screen coordinates
 * back to scene space and checking node frames. Returns the deepest (highest depth) node
 * whose frame contains the click point, or null if no node was hit.
 */
function hitTestHierarchyNode(
  event: PointerEvent,
  scene: HierarchyScene,
  mountEl: HTMLDivElement | null,
): HierarchyLayerNode | null {
  if (!mountEl) return null;
  const rect = mountEl.getBoundingClientRect();
  const cx = event.clientX - rect.left;
  const cy = event.clientY - rect.top;
  const w = rect.width || 1;
  const h = rect.height || 1;

  const scale = Math.min(0.64, 280 / scene.viewport.width, 560 / scene.viewport.height);
  const tiltX = (HIERARCHY_FIXED_TILT_X * Math.PI) / 180;
  const zoom = 1; // use nominal zoom for hit-test

  // Approximate inverse: undo viewport normalization, then undo scale
  // The 3D scene centers nodes around (0,0) with (node.frame.x + w/2 - viewport.w/2) * scale
  // For hit-testing we approximate by mapping screen % back to viewport coordinates
  let best: HierarchyLayerNode | null = null;
  for (const node of scene.nodes) {
    if (!node.visible || node.depth === 0) continue;
    const nx = (node.frame.x / scene.viewport.width) * 100;
    const ny = (node.frame.y / scene.viewport.height) * 100;
    const nw = (node.frame.width / scene.viewport.width) * 100;
    const nh = (node.frame.height / scene.viewport.height) * 100;
    const px = (cx / w) * 100;
    const py = (cy / h) * 100;
    if (px >= nx && px <= nx + nw && py >= ny && py <= ny + nh) {
      if (!best || node.depth > best.depth) {
        best = node;
      }
    }
  }
  return best;
}

function clampCanvasSize(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, Math.round(value)));
}

function hierarchySliceKind(node: HierarchyLayerNode) {
  const display = node.style?.display?.toLowerCase();
  if (display === "bar" || display === "navigation" || display === "toolbar") return "bar";
  if (display === "tabbar") return "tabbar";
  if (display === "button" || display === "control" || display === "image") return "control";
  if (display === "text") return "text";
  if (display === "input") return "input";
  if (display === "card") return "card";
  if (display === "container" || display === "list") return "container";
  const type = node.type.toLowerCase();
  if (/(navigationbar|toolbar|navigation)/.test(type)) return "bar";
  if (/(tabbar|bottomnavigation|floatingbar)/.test(type)) return "tabbar";
  if (/(button|toggle|switch|image)/.test(type)) return "control";
  if (/(label|text)/.test(type)) return "text";
  if (/(textinput|textfield|edittext|search)/.test(type)) return "input";
  if (/(card|row|cell)/.test(type)) return "card";
  if (/(scroll|recycler|list|stack|column)/.test(type)) return "container";
  return node.interactive ? "control" : "view";
}

function drawRoundedRect(
  context: CanvasRenderingContext2D,
  x: number,
  y: number,
  width: number,
  height: number,
  radius: number
) {
  const safeRadius = Math.min(radius, width / 2, height / 2);
  context.beginPath();
  context.moveTo(x + safeRadius, y);
  context.lineTo(x + width - safeRadius, y);
  context.quadraticCurveTo(x + width, y, x + width, y + safeRadius);
  context.lineTo(x + width, y + height - safeRadius);
  context.quadraticCurveTo(x + width, y + height, x + width - safeRadius, y + height);
  context.lineTo(x + safeRadius, y + height);
  context.quadraticCurveTo(x, y + height, x, y + height - safeRadius);
  context.lineTo(x, y + safeRadius);
  context.quadraticCurveTo(x, y, x + safeRadius, y);
  context.closePath();
}

type HierarchySurfaceSource = {
  sliceImages?: Map<string, HTMLImageElement>;
};

type HierarchyRenderModel =
  | "main-snapshot-with-structure"
  | "structure-only-fallback"
  | "selected-slice-evidence";

function isNearFullscreenNode(node: HierarchyLayerNode, scene: HierarchyScene) {
  return node.frame.width >= scene.viewport.width * 0.96 && node.frame.height >= scene.viewport.height * 0.9;
}

function selectHierarchyEvidenceNode(scene: HierarchyScene) {
  const nodesWithSlice = scene.nodes.filter((node) =>
    node.visible &&
    node.depth > 0 &&
    resolveEvidenceSources(node).some((source) => "dataUrl" in source && Boolean(source.dataUrl))
  );
  return (
    nodesWithSlice.find((node) => node.interactive && !isNearFullscreenNode(node, scene)) ??
    nodesWithSlice.find((node) => !isNearFullscreenNode(node, scene)) ??
    nodesWithSlice[0] ??
    null
  );
}

function firstHierarchyVisualSourceDataUrl(source: HierarchyVisualSource | undefined) {
  return source && "dataUrl" in source ? source.dataUrl : undefined;
}

function selectedHierarchyEvidenceSource(node: HierarchyLayerNode | null) {
  if (!node) return undefined;
  return resolveEvidenceSources(node).find((source) => Boolean(firstHierarchyVisualSourceDataUrl(source)));
}

function hierarchyNumber(value: number | undefined) {
  return typeof value === "number" && Number.isFinite(value) ? Number(value.toFixed(2)).toString() : "—";
}

function hierarchyRectSummary(rect: { x: number; y: number; width: number; height: number } | undefined) {
  if (!rect) return "—";
  return `${hierarchyNumber(rect.x)}, ${hierarchyNumber(rect.y)} · ${hierarchyNumber(rect.width)}×${hierarchyNumber(rect.height)}`;
}

function drawHierarchyMainSurface(scene: HierarchyScene, image: HTMLImageElement) {
  const canvas = document.createElement("canvas");
  const width = clampCanvasSize(scene.viewport.width * 2, 260, 1200);
  const height = clampCanvasSize(scene.viewport.height * 2, 480, 1800);
  canvas.width = width;
  canvas.height = height;

  const context = canvas.getContext("2d");
  if (!context) return canvas;

  context.clearRect(0, 0, width, height);
  context.drawImage(image, 0, 0, width, height);
  context.strokeStyle = "rgba(37, 99, 235, 0.38)";
  context.lineWidth = 2;
  context.strokeRect(1, 1, Math.max(1, width - 2), Math.max(1, height - 2));
  return canvas;
}

function drawHierarchyNodeSlice(node: HierarchyLayerNode, surface?: HierarchySurfaceSource) {
  const canvas = document.createElement("canvas");
  const width = clampCanvasSize(node.frame.width * 2, 96, 900);
  const height = clampCanvasSize(node.frame.height * 2, 44, 620);
  const scaleX = width / Math.max(1, node.frame.width);
  const scaleY = height / Math.max(1, node.frame.height);
  canvas.width = width;
  canvas.height = height;

  const context = canvas.getContext("2d");
  if (!context) return canvas;

  context.scale(scaleX, scaleY);
  const w = node.frame.width;
  const h = node.frame.height;
  const kind = hierarchySliceKind(node);
  const label = node.name || node.type;
  const shortLabel = label.length > 34 ? label.slice(0, 31) + "..." : label;
  const accent = node.interactive ? node.color : "#94a3b8";

  context.clearRect(0, 0, w, h);

  const exactSliceImage = surface?.sliceImages?.get(node.id);
  if (exactSliceImage) {
    context.drawImage(exactSliceImage, 0, 0, w, h);
    context.strokeStyle = node.interactive ? "rgba(37, 99, 235, 0.72)" : "rgba(100, 116, 139, 0.32)";
    context.lineWidth = node.interactive ? 1.4 : 0.8;
    drawRoundedRect(context, 0.5, 0.5, Math.max(1, w - 1), Math.max(1, h - 1), Math.min(12, h / 2));
    context.stroke();
    return canvas;
  }

  context.shadowColor = "rgba(15, 23, 42, 0.06)";
  context.shadowBlur = Math.min(16, Math.max(2, h * 0.08));
  context.shadowOffsetY = 2;

  if (kind === "bar") {
    context.fillStyle = "rgba(248, 250, 252, 0.86)";
    drawRoundedRect(context, 0, 0, w, h, 14);
    context.fill();
    context.shadowColor = "transparent";
    context.strokeStyle = "rgba(148, 163, 184, 0.44)";
    context.stroke();
    context.fillStyle = "rgba(37, 99, 235, 0.16)";
    drawRoundedRect(context, 12, Math.max(6, h * 0.24), Math.min(32, h * 0.52), Math.min(32, h * 0.52), 999);
    context.fill();
    context.fillStyle = "#334155";
    context.font = `700 ${Math.max(10, Math.min(18, h * 0.28))}px ui-sans-serif, system-ui`;
    context.textAlign = "center";
    context.textBaseline = "middle";
    context.fillText(shortLabel, w / 2, h / 2, w * 0.6);
    return canvas;
  }

  if (kind === "tabbar") {
    context.fillStyle = "rgba(255, 255, 255, 0.9)";
    drawRoundedRect(context, 0, 0, w, h, 22);
    context.fill();
    context.shadowColor = "transparent";
    context.strokeStyle = "rgba(148, 163, 184, 0.44)";
    context.stroke();
    const itemCount = 4;
    for (let index = 0; index < itemCount; index += 1) {
      const centerX = ((index + 0.5) / itemCount) * w;
      context.fillStyle = index === 0 ? "rgba(37, 99, 235, 0.16)" : "rgba(100, 116, 139, 0.12)";
      drawRoundedRect(context, centerX - 16, h * 0.2, 32, Math.max(20, h * 0.3), 999);
      context.fill();
      context.fillStyle = index === 0 ? "#2563eb" : "#64748b";
      context.fillRect(centerX - 7, h * 0.6, 14, 2);
    }
    return canvas;
  }

  if (kind === "control") {
    context.fillStyle = node.interactive ? "rgba(37, 99, 235, 0.16)" : "rgba(255, 255, 255, 0.72)";
    drawRoundedRect(context, 0, 0, w, h, Math.min(16, h / 2));
    context.fill();
    context.shadowColor = "transparent";
    context.strokeStyle = node.interactive ? accent : "rgba(148, 163, 184, 0.48)";
    context.lineWidth = 1.3;
    context.stroke();
    context.fillStyle = node.interactive ? "#1d4ed8" : "#475569";
    context.font = `700 ${Math.max(9, Math.min(15, h * 0.28))}px ui-sans-serif, system-ui`;
    context.textAlign = "center";
    context.textBaseline = "middle";
    context.fillText(shortLabel, w / 2, h / 2, w - 12);
    return canvas;
  }

  if (kind === "input") {
    context.fillStyle = "rgba(255, 255, 255, 0.92)";
    drawRoundedRect(context, 0, 0, w, h, Math.min(12, h / 2));
    context.fill();
    context.shadowColor = "transparent";
    context.strokeStyle = "rgba(37, 99, 235, 0.42)";
    context.stroke();
    context.fillStyle = "#94a3b8";
    context.font = `500 ${Math.max(9, Math.min(14, h * 0.26))}px ui-sans-serif, system-ui`;
    context.textAlign = "left";
    context.textBaseline = "middle";
    context.fillText(shortLabel, 12, h / 2, w - 24);
    return canvas;
  }

  if (kind === "text") {
    context.fillStyle = "rgba(248, 250, 252, 0.74)";
    drawRoundedRect(context, 0, 0, w, h, 8);
    context.fill();
    context.shadowColor = "transparent";
    context.fillStyle = "#334155";
    context.font = `650 ${Math.max(9, Math.min(16, h * 0.36))}px ui-sans-serif, system-ui`;
    context.textAlign = "left";
    context.textBaseline = "middle";
    context.fillText(shortLabel, 8, h / 2, w - 16);
    return canvas;
  }

  if (kind === "card" || kind === "container") {
    context.fillStyle = kind === "card" ? "rgba(255, 255, 255, 0.78)" : "rgba(248, 250, 252, 0.38)";
    drawRoundedRect(context, 0, 0, w, h, kind === "card" ? 14 : 6);
    context.fill();
    context.shadowColor = "transparent";
    context.strokeStyle = kind === "card" ? "rgba(148, 163, 184, 0.5)" : "rgba(148, 163, 184, 0.28)";
    context.stroke();
    const rowCount = Math.max(2, Math.min(5, Math.floor(h / 26)));
    for (let index = 0; index < rowCount; index += 1) {
      const y = 10 + index * Math.max(16, (h - 20) / rowCount);
      context.fillStyle = index === 0 && kind === "card" ? "rgba(37, 99, 235, 0.18)" : "rgba(100, 116, 139, 0.18)";
      drawRoundedRect(context, 10, y, Math.max(18, w * (index === 0 ? 0.62 : 0.78)), Math.max(4, Math.min(8, h * 0.05)), 999);
      context.fill();
    }
    context.fillStyle = "#475569";
    context.font = `650 ${Math.max(8, Math.min(13, h * 0.14))}px ui-sans-serif, system-ui`;
    context.textAlign = "left";
    context.textBaseline = "bottom";
    context.fillText(shortLabel, 10, Math.max(14, h - 8), w - 20);
    return canvas;
  }

  context.fillStyle = "rgba(248, 250, 252, 0.2)";
  drawRoundedRect(context, 0, 0, w, h, 6);
  context.fill();
  context.shadowColor = "transparent";
  context.strokeStyle = "rgba(148, 163, 184, 0.24)";
  context.stroke();
  return canvas;
}

function clampHierarchyZoom(value: number) {
  return Math.max(HIERARCHY_MIN_ZOOM, Math.min(HIERARCHY_MAX_ZOOM, value));
}

function hierarchyPointerDistance(pointers: Map<number, { x: number; y: number }>) {
  const [first, second] = Array.from(pointers.values());
  if (!first || !second) return 0;
  return Math.hypot(second.x - first.x, second.y - first.y);
}

function HierarchySceneViewer({
  scene,
  target,
  captureState,
  onCapture,
  selectedNodeId,
  onSelectNode,
}: {
  scene: HierarchyScene;
  target: DeviceTarget;
  captureState: HierarchyCaptureState;
  onCapture: () => void;
  selectedNodeId: string | null;
  onSelectNode: (nodeId: string | null) => void;
}) {
  const mountRef = useRef<HTMLDivElement | null>(null);
  const dragStart = useRef<{ x: number; yaw: number } | null>(null);
  const activePointers = useRef(new Map<number, { x: number; y: number }>());
  const pinchStart = useRef<{ distance: number; zoom: number } | null>(null);
  const pointerDownPos = useRef<{ x: number; y: number } | null>(null);
  const threeRef = useRef<{
    renderer: import("three").WebGLRenderer;
    scene: import("three").Scene;
    camera: import("three").PerspectiveCamera;
    group: import("three").Group;
    THREE: typeof import("three");
  } | null>(null);
  const nodeObjectsRef = useRef<Map<string, { mesh: import("three").Mesh; edges: import("three").LineSegments }>>(new Map());
  const [yaw, setYaw] = useState(HIERARCHY_INITIAL_YAW);
  const [zoom, setZoom] = useState(HIERARCHY_INITIAL_ZOOM);
  const [hasWebGLScene, setHasWebGLScene] = useState(false);
  const [surfaceImage, setSurfaceImage] = useState<HTMLImageElement | null>(null);
  const [sliceImages, setSliceImages] = useState<Map<string, HTMLImageElement>>(new Map());
  const autoSelectedSliceNode = useMemo(() => selectHierarchyEvidenceNode(scene), [scene]);
  const selectedSliceNode = useMemo(() => {
    if (selectedNodeId) {
      const found = scene.nodes.find((n) => n.id === selectedNodeId && n.visible && n.depth > 0);
      if (found) return found;
    }
    return autoSelectedSliceNode;
  }, [selectedNodeId, scene, autoSelectedSliceNode]);
  const selectedVisualSource = useMemo(() => selectedHierarchyEvidenceSource(selectedSliceNode), [selectedSliceNode]);
  const selectedMaterialExplanation = useMemo(
    () => selectedSliceNode ? getMaterialExplanation(selectedSliceNode) : null,
    [selectedSliceNode]
  );
  const parityClaim = useMemo(() => computeParityClaim(scene), [scene]);
  const selectedVisualSourceDataUrl = firstHierarchyVisualSourceDataUrl(selectedVisualSource);
  const sliceImageSources = useMemo(
    () => selectedSliceNode && selectedVisualSourceDataUrl ? [[selectedSliceNode.id, selectedVisualSourceDataUrl] as const] : [],
    [selectedSliceNode, selectedVisualSourceDataUrl]
  );
  const layerCount = new Set(scene.nodes.map((node) => node.depth)).size;
  const interactiveCount = scene.nodes.filter((node) => node.interactive).length;
  const hasMainSnapshotSurface = Boolean(target.screenshotDataUrl);
  const hasSelectedSliceEvidence = Boolean(selectedVisualSourceDataUrl);
  const renderModel: HierarchyRenderModel = hasMainSnapshotSurface
    ? "main-snapshot-with-structure"
    : hasSelectedSliceEvidence
      ? "selected-slice-evidence"
      : "structure-only-fallback";
  const captureEvidenceMode = captureState.evidence?.source.nodeSlice === "real"
    ? "real-node-slices-available"
    : hasMainSnapshotSurface
      ? "main-snapshot-only"
      : captureState.evidence?.source.nodeSlice === "styled"
        ? "styled-fallback"
        : "structure-only";

  useEffect(() => {
    if (!target.screenshotDataUrl) {
      setSurfaceImage(null);
      return;
    }
    if (typeof Image === "undefined") {
      setSurfaceImage(null);
      return;
    }
    let cancelled = false;
    const image = new Image();
    image.onload = () => {
      if (!cancelled) setSurfaceImage(image);
    };
    image.onerror = () => {
      if (!cancelled) setSurfaceImage(null);
    };
    image.src = target.screenshotDataUrl;
    return () => {
      cancelled = true;
    };
  }, [target.screenshotDataUrl]);

  useEffect(() => {
    if (sliceImageSources.length === 0 || typeof Image === "undefined") {
      setSliceImages(new Map());
      return;
    }

    let cancelled = false;
    const loadedImages = new Map<string, HTMLImageElement>();
    setSliceImages(new Map());
    let pending = sliceImageSources.length;
    const finishOne = () => {
      pending -= 1;
      if (!cancelled && pending === 0) {
        setSliceImages(new Map(loadedImages));
      }
    };

    for (const [nodeId, dataUrl] of sliceImageSources) {
      const image = new Image();
      image.onload = () => {
        if (cancelled) return;
        loadedImages.set(nodeId, image);
        finishOne();
      };
      image.onerror = () => {
        if (cancelled) return;
        loadedImages.delete(nodeId);
        finishOne();
      };
      image.src = dataUrl;
    }

    return () => {
      cancelled = true;
    };
  }, [sliceImageSources]);

  useEffect(() => {
    setYaw(HIERARCHY_INITIAL_YAW);
    setZoom(HIERARCHY_INITIAL_ZOOM);
    setHasWebGLScene(false);
  }, [scene.platform, scene.rootId]);

  useEffect(() => {
    let disposed = false;
    const mount = mountRef.current;
    if (!mount) return;

    void import("three").then((THREE) => {
      if (disposed || !mountRef.current) return;
      const width = Math.max(1, mount.clientWidth || 360);
      const height = Math.max(1, mount.clientHeight || 640);

      try {
        const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
        renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
        renderer.setSize(width, height);
        renderer.domElement.className = "hierarchy-three-canvas";

        const threeScene = new THREE.Scene();
        const camera = new THREE.PerspectiveCamera(34, width / height, 1, 2400);
        camera.position.set(0, 0, 860);

        const group = new THREE.Group();
        const scale = Math.min(0.64, 280 / scene.viewport.width, 560 / scene.viewport.height);

        if (surfaceImage) {
          const mainTexture = new THREE.CanvasTexture(drawHierarchyMainSurface(scene, surfaceImage));
          mainTexture.colorSpace = THREE.SRGBColorSpace;
          mainTexture.anisotropy = Math.min(4, renderer.capabilities.getMaxAnisotropy());
          const mainGeometry = new THREE.PlaneGeometry(scene.viewport.width * scale, scene.viewport.height * scale);
          const mainMaterial = new THREE.MeshBasicMaterial({
            map: mainTexture,
            transparent: true,
            opacity: 0.84,
            side: THREE.DoubleSide,
            depthTest: false,
            depthWrite: false,
          });
          const mainSurface = new THREE.Mesh(mainGeometry, mainMaterial);
          mainSurface.position.set(0, 0, 0);
          mainSurface.renderOrder = 500;
          group.add(mainSurface);
        }

        nodeObjectsRef.current.clear();
        for (const node of scene.nodes) {
          if (!node.visible) continue;
          if (node.depth === 0) continue;
          const geometry = new THREE.PlaneGeometry(Math.max(8, node.frame.width * scale), Math.max(8, node.frame.height * scale));
          const material = new THREE.MeshBasicMaterial({
            color: node.color,
            transparent: true,
            opacity: node.interactive ? 0.12 : 0.06,
            side: THREE.DoubleSide,
            depthTest: false,
            depthWrite: false,
          });
          const mesh = new THREE.Mesh(geometry, material);
          const sliceRenderOrder = 800 + node.depth * 8;
          mesh.position.set(
            (node.frame.x + node.frame.width / 2 - scene.viewport.width / 2) * scale - node.depth * 5,
            -(node.frame.y + node.frame.height / 2 - scene.viewport.height / 2) * scale,
            node.depth * 18
          );
          mesh.renderOrder = sliceRenderOrder;
          group.add(mesh);

          const edges = new THREE.LineSegments(
            new THREE.EdgesGeometry(geometry),
            new THREE.LineBasicMaterial({
              color: node.interactive ? 0x2563eb : 0x94a3b8,
              transparent: true,
              opacity: node.interactive ? 0.52 : 0.32,
              depthTest: false,
              depthWrite: false,
            })
          );
          edges.position.copy(mesh.position);
          edges.position.z += 1.1;
          edges.renderOrder = sliceRenderOrder + 2;
          group.add(edges);

          nodeObjectsRef.current.set(node.id, { mesh, edges });
        }

        group.position.set(24, -4, -Math.max(140, layerCount * 22));
        threeScene.add(group);
        mountRef.current.replaceChildren(renderer.domElement);
        threeRef.current = { renderer, scene: threeScene, camera, group, THREE };
        setHasWebGLScene(true);
        renderHierarchyScene(yaw, zoom);
      } catch {
        setHasWebGLScene(false);
        threeRef.current = null;
      }
    });

    return () => {
      disposed = true;
      threeRef.current?.renderer.dispose();
      threeRef.current = null;
      setHasWebGLScene(false);
      mount.replaceChildren();
    };
  }, [scene, surfaceImage, sliceImages]);

  useEffect(() => {
    renderHierarchyScene(yaw, zoom);
  }, [yaw, zoom]);

  // Update node materials when selection changes (no scene rebuild)
  useEffect(() => {
    const objects = nodeObjectsRef.current;
    if (objects.size === 0) return;
    const three = threeRef.current;
    if (!three) return;
    const { THREE } = three;

    // Remove old slice meshes
    const toRemove: import("three").Object3D[] = [];
    three.group.children.forEach((child) => {
      if ((child as any).userData?.isSliceMesh) toRemove.push(child);
    });
    toRemove.forEach((obj) => {
      three.group.remove(obj);
      if ((obj as any).geometry) (obj as any).geometry.dispose();
      if ((obj as any).material) {
        const mat = (obj as any).material;
        if (mat.map) mat.map.dispose();
        mat.dispose();
      }
    });

    const sceneNodeMap = new Map(scene.nodes.map((n) => [n.id, n]));

    for (const [nodeId, { mesh, edges }] of objects) {
      const node = sceneNodeMap.get(nodeId);
      if (!node) continue;
      const isUserSelected = selectedNodeId === nodeId;
      const isAutoSelected = selectedSliceNode?.id === nodeId;

      // Update mesh material
      const mat = mesh.material as import("three").MeshBasicMaterial;
      mat.color.set(isUserSelected ? 0x2563eb : node.color);
      mat.opacity = isUserSelected ? 0.28 : node.interactive ? 0.12 : 0.06;

      // Update edge material
      const edgeMat = edges.material as import("three").LineBasicMaterial;
      edgeMat.color.set(isUserSelected ? 0x1d4ed8 : node.interactive ? 0x2563eb : 0x94a3b8);
      edgeMat.opacity = isUserSelected ? 0.88 : isAutoSelected ? 0.72 : node.interactive ? 0.52 : 0.32;

      // Add slice mesh for selected node
      if (isAutoSelected || isUserSelected) {
        const sliceCanvas = drawHierarchyNodeSlice(node, { sliceImages });
        const sliceTexture = new THREE.CanvasTexture(sliceCanvas);
        sliceTexture.colorSpace = THREE.SRGBColorSpace;
        const styledMaterial = new THREE.MeshBasicMaterial({
          map: sliceTexture,
          transparent: true,
          opacity: 0.92,
          side: THREE.DoubleSide,
          depthTest: false,
          depthWrite: false,
        });
        const styledSlice = new THREE.Mesh(mesh.geometry, styledMaterial);
        styledSlice.position.copy(mesh.position);
        styledSlice.position.z += 1.4;
        styledSlice.renderOrder = 1200 + node.depth * 8;
        (styledSlice as any).userData = { isSliceMesh: true };
        three.group.add(styledSlice);
      }
    }

    renderHierarchyScene(yaw, zoom);
  }, [selectedNodeId, selectedSliceNode, scene, sliceImages, yaw, zoom]);

  const renderHierarchyScene = (nextYaw: number, nextZoom: number) => {
    const three = threeRef.current;
    if (!three) return;
    three.group.rotation.x = (HIERARCHY_FIXED_TILT_X * Math.PI) / 180;
    three.group.rotation.y = (nextYaw * Math.PI) / 180;
    three.group.scale.setScalar(nextZoom);
    three.renderer.render(three.scene, three.camera);
  };

  const handlePointerDown = (event: PointerEvent<HTMLDivElement>) => {
    event.stopPropagation();
    activePointers.current.set(event.pointerId, { x: event.clientX, y: event.clientY });
    pointerDownPos.current = { x: event.clientX, y: event.clientY };
    if (activePointers.current.size >= 2) {
      const distance = hierarchyPointerDistance(activePointers.current);
      pinchStart.current = distance > 0 ? { distance, zoom } : null;
      dragStart.current = null;
    } else {
      pinchStart.current = null;
      dragStart.current = { x: event.clientX, yaw };
    }
    try {
      event.currentTarget.setPointerCapture(event.pointerId);
    } catch {
      // Browser smoke tests may synthesize pointer events without active capture state.
    }
  };

  const handlePointerMove = (event: PointerEvent<HTMLDivElement>) => {
    event.stopPropagation();
    if (activePointers.current.has(event.pointerId)) {
      activePointers.current.set(event.pointerId, { x: event.clientX, y: event.clientY });
    }
    if (activePointers.current.size >= 2 && pinchStart.current) {
      const distance = hierarchyPointerDistance(activePointers.current);
      if (distance > 0) {
        setZoom(clampHierarchyZoom(pinchStart.current.zoom * (distance / pinchStart.current.distance)));
      }
      return;
    }
    const start = dragStart.current;
    if (!start) return;
    setYaw(start.yaw + (event.clientX - start.x) * 0.42);
  };

  const handlePointerUp = (event: PointerEvent<HTMLDivElement>) => {
    event.stopPropagation();
    activePointers.current.delete(event.pointerId);
    pinchStart.current = null;

    // Click detection: if pointer didn't move much, treat as node selection
    const downPos = pointerDownPos.current;
    pointerDownPos.current = null;
    if (downPos && activePointers.current.size === 0) {
      const dx = event.clientX - downPos.x;
      const dy = event.clientY - downPos.y;
      if (Math.abs(dx) < 6 && Math.abs(dy) < 6) {
        const hitNode = hitTestHierarchyNode(event, scene, mountRef.current);
        onSelectNode(hitNode?.id ?? null);
      }
    }

    if (activePointers.current.size === 1) {
      const [remaining] = activePointers.current.values();
      dragStart.current = { x: remaining.x, yaw };
    } else {
      dragStart.current = null;
    }
  };

  const handleWheel = (event: WheelEvent<HTMLDivElement>) => {
    if (!event.ctrlKey && !event.metaKey) return;
    event.preventDefault();
    event.stopPropagation();
    const delta = event.deltaY < 0 ? 0.08 : -0.08;
    setZoom((current) => clampHierarchyZoom(current + delta));
  };

  return (
    <div
      className={`hierarchy-scene-viewer ${hasWebGLScene ? "has-webgl" : "is-dom-fallback"}`}
      data-render-model={renderModel}
      role="img"
      aria-label={`${platformLabel[target.platform]} ${target.appName} 3D 视图层级`}
      onPointerDown={handlePointerDown}
      onPointerMove={handlePointerMove}
      onPointerUp={handlePointerUp}
      onPointerCancel={handlePointerUp}
      onWheel={handleWheel}
    >
      <div className="hierarchy-scene-toolbar">
        <span>{platformLabel[target.platform]}</span>
        <strong>{target.appName}</strong>
        <em>{scene.nodes.length} nodes · {layerCount} layers · {interactiveCount} interactive</em>
        <button
          className="hierarchy-capture-button"
          type="button"
          aria-label="重新采集真实层级"
          disabled={captureState.status === "loading"}
          title={captureState.command}
          onPointerDown={(event) => event.stopPropagation()}
          onClick={(event) => {
            event.stopPropagation();
            onCapture();
          }}
        >
          {captureState.status === "loading" ? "采集中" : "重新采集"}
        </button>
      </div>
      {selectedSliceNode ? (
        <section className="hierarchy-node-inspector" aria-label="选中节点 Inspector">
          <div>
            <strong>Node</strong>
            <span>{selectedSliceNode.className ?? selectedSliceNode.type}</span>
          </div>
          <dl>
            <div>
              <dt>frame</dt>
              <dd>{hierarchyRectSummary(selectedSliceNode.frame)}</dd>
            </div>
            <div>
              <dt>depth</dt>
              <dd>{selectedSliceNode.depth}</dd>
            </div>
            <div>
              <dt>layer.zPosition</dt>
              <dd>{hierarchyNumber(selectedSliceNode.layer?.zPosition)}</dd>
            </div>
            <div>
              <dt>layer.opacity</dt>
              <dd>{hierarchyNumber(selectedSliceNode.layer?.opacity)}</dd>
            </div>
            <div>
              <dt>layer.masksToBounds</dt>
              <dd>{selectedSliceNode.layer?.masksToBounds === undefined ? "—" : String(selectedSliceNode.layer.masksToBounds)}</dd>
            </div>
            <div>
              <dt>layer.cornerRadius</dt>
              <dd>{hierarchyNumber(selectedSliceNode.layer?.cornerRadius)}</dd>
            </div>
            <div>
              <dt>visualSources</dt>
              <dd>{selectedMaterialExplanation?.evidenceSources.join(" / ") || "styledFallback"}</dd>
            </div>
            <div>
              <dt>defaultMaterial</dt>
              <dd>{selectedMaterialExplanation?.defaultMaterial ?? "none"}</dd>
            </div>
          </dl>
        </section>
      ) : null}
      <div className="hierarchy-scene-mount" ref={mountRef} />
      <div
        className="hierarchy-layer-stack"
        aria-label="3D hierarchy DOM fallback"
        style={{
          "--hierarchy-tilt-x": `${HIERARCHY_FIXED_TILT_X}deg`,
          "--hierarchy-rotate-y": `${yaw}deg`,
          "--hierarchy-zoom": zoom,
        } as CSSProperties}
      >
        {hasMainSnapshotSurface ? (
          <span
            className="is-main-snapshot"
            data-render-role="main-snapshot-surface"
            data-render-mode="main-snapshot"
            aria-hidden="true"
            style={{
              "--node-x": "0%",
              "--node-y": "0%",
              "--node-width": "100%",
              "--node-height": "100%",
              "--node-depth": 0,
              "--node-color": "#94a3b8",
            } as CSSProperties}
          />
        ) : null}
        {scene.nodes.filter((node) => node.visible).map((node) => {
          return (
            <span
              key={node.id}
              className={`${node.interactive ? "is-interactive" : ""} ${selectedNodeId === node.id ? "is-selected" : ""}`}
              data-node-id={node.id}
              data-platform={scene.platform}
              data-render-mode="structure"
              onClick={(e) => {
                e.stopPropagation();
                onSelectNode(selectedNodeId === node.id ? null : node.id);
              }}
              style={{
                "--node-x": `${(node.frame.x / scene.viewport.width) * 100}%`,
                "--node-y": `${(node.frame.y / scene.viewport.height) * 100}%`,
                "--node-width": `${(node.frame.width / scene.viewport.width) * 100}%`,
                "--node-height": `${(node.frame.height / scene.viewport.height) * 100}%`,
                "--node-depth": node.depth,
                "--node-color": node.color,
              } as CSSProperties}
            >
              {node.type}
              <small>{node.name}</small>
            </span>
          );
        })}
        {selectedSliceNode ? (
          <span
            className="is-selected-slice"
            data-node-id={selectedSliceNode.id}
            data-platform={scene.platform}
            data-render-mode="selected-slice"
            data-texture-source={selectedVisualSource?.kind ?? "unknown"}
            style={{
              "--node-x": `${(selectedSliceNode.frame.x / scene.viewport.width) * 100}%`,
              "--node-y": `${(selectedSliceNode.frame.y / scene.viewport.height) * 100}%`,
              "--node-width": `${(selectedSliceNode.frame.width / scene.viewport.width) * 100}%`,
              "--node-height": `${(selectedSliceNode.frame.height / scene.viewport.height) * 100}%`,
              "--node-depth": selectedSliceNode.depth + 0.12,
              "--node-color": selectedSliceNode.color,
            } as CSSProperties}
          >
            {selectedSliceNode.type}
            <small>{selectedSliceNode.name}</small>
          </span>
        ) : null}
      </div>
      <output className="hierarchy-rotation-state" aria-label="层级旋转状态">
        水平旋转 {Math.round(yaw)}° · 缩放 {Math.round(zoom * 100)}%
      </output>
      <output
        className="hierarchy-parity-state"
        aria-label="Lookin parity 状态"
        data-parity-level={parityClaim.level}
        data-lookin-parity={parityClaim.canClaimLookinParity ? "available" : "unavailable"}
        title={parityClaim.reasons.join("；")}
      >
        Snapshot Evidence Mode · Lookin parity {parityClaim.canClaimLookinParity ? "available" : "unavailable"}
      </output>
      {selectedMaterialExplanation ? (
        <output
          className="hierarchy-material-state"
          aria-label="当前节点视觉来源"
          data-default-material={selectedMaterialExplanation.defaultMaterial ?? "none"}
          data-evidence-sources={selectedMaterialExplanation.evidenceSources.join(",")}
        >
          当前节点视觉来源：{selectedMaterialExplanation.evidenceSources.join(" / ") || "styledFallback"}
        </output>
      ) : null}
      <output
        className={`hierarchy-capture-state is-${captureState.status}`}
        aria-label="层级采集状态"
        data-evidence={captureEvidenceMode}
      >
        {hierarchyCaptureStatusText(captureState, hasMainSnapshotSurface)}
      </output>
    </div>
  );
}

function hierarchyCaptureStatusText(captureState: HierarchyCaptureState, hasMainSnapshotSurface: boolean) {
  const hasRealNodeSlice = captureState.evidence?.source.nodeSlice === "real";
  if (captureState.status === "loading") return "正在采集快照…";
  if (captureState.status === "ready") {
    const source = captureState.method === "POST" ? "手动采集" : "现场采集";
    if (hasMainSnapshotSurface && hasRealNodeSlice) return `${source} · 真实截图切片可用`;
    if (hasMainSnapshotSurface) return `${source} · 节点切片不可用`;
    if (hasRealNodeSlice) return "结构快照 · 局部切片可用";
    if (captureState.evidence?.source.nodeSlice === "styled") return "样式化快照 · 非真实节点切片";
    return "样式化快照 · 非真实节点切片";
  }
  if (captureState.status === "error") {
    return "采集失败 · 已显示 fallback scene";
  }
  return "等待采集";
}

function isEditableInputClassName(className: string) {
  return /(TextField|TextView|SearchBarTextField|TextInput|SecureText)/i.test(className);
}

function roundedGestureValue(value: number) {
  return Number(value.toFixed(3));
}

function deviceToolLabel(tool: DeviceCanvasTool) {
  if (tool === "probe") return "探测";
  return "点选";
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
  target,
  events,
  bridge,
}: {
  target: DeviceTarget;
  events: NetworkEvent[];
  bridge: BridgeState;
}) {
  const errorCount = events.filter((event) => event.status >= 400).length;

  return (
    <aside className="hub-inspector" aria-label="检查器">
      <div className="inspector-tabs" role="tablist" aria-label="检查器分区">
        <button className="is-active" type="button">信息</button>
        <button type="button">应用</button>
        <button type="button">配置</button>
      </div>

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

function CanvasZoomControls({
  zoomLevel,
  canZoomOut,
  canZoomIn,
  onZoomOut,
  onResetZoom,
  onZoomIn,
}: {
  zoomLevel: number;
  canZoomOut: boolean;
  canZoomIn: boolean;
  onZoomOut: () => void;
  onResetZoom: () => void;
  onZoomIn: () => void;
}) {
  const zoomPercent = Math.round(zoomLevel * 100);

  return (
    <section className="canvas-zoom-controls" aria-label="画布缩放控制">
      <div className="control-pill">
        <button type="button" aria-label={`缩小 (${zoomPercent}%)`} title={`缩小 (${zoomPercent}%)`} disabled={!canZoomOut} onClick={onZoomOut}>
          <ZoomOut size={17} />
        </button>
        <button type="button" aria-label="实际大小 (100%)" title="实际大小 (100%)" disabled={zoomLevel === 1} onClick={onResetZoom}>
          <Search size={17} />
        </button>
        <button type="button" aria-label={`放大 (${zoomPercent}%)`} title={`放大 (${zoomPercent}%)`} disabled={!canZoomIn} onClick={onZoomIn}>
          <ZoomIn size={17} />
        </button>
      </div>
    </section>
  );
}

function DeviceControls({
  activeTool,
  onSelectTool,
  target,
  isNetworkVisible,
  isLogsVisible,
  onToggleNetwork,
  onToggleLogs,
}: {
  activeTool: DeviceCanvasTool;
  onSelectTool: (tool: DeviceCanvasTool) => void;
  target: DeviceTarget;
  isNetworkVisible: boolean;
  isLogsVisible: boolean;
  onToggleNetwork: () => void;
  onToggleLogs: () => void;
}) {
  const actions = [
    { label: "点选", tool: "point" as const, Icon: MousePointer2 },
    { label: "探测", tool: "probe" as const, Icon: Crosshair },
  ];

  return (
    <section className="device-controls" aria-label="设备控制">
      <div className="control-pill">
        {actions.map(({ label, tool, Icon }) => (
          <button
            key={label}
            className={tool && activeTool === tool ? "is-active" : ""}
            type="button"
            aria-label={label}
            aria-pressed={tool ? activeTool === tool : undefined}
            title={tool ? `${label}${activeTool === tool ? "（当前）" : ""}` : label}
            onClick={tool ? () => onSelectTool(tool) : undefined}
          >
            <Icon size={17} />
          </button>
        ))}
        <button
          className={isNetworkVisible ? "is-active" : ""}
          type="button"
          aria-label={isNetworkVisible ? "隐藏网络" : "显示网络"}
          title={isNetworkVisible ? "隐藏网络" : "显示网络"}
          onClick={onToggleNetwork}
        >
          <Network size={17} />
        </button>
        <button
          className={isLogsVisible ? "is-active" : ""}
          type="button"
          aria-label={isLogsVisible ? "隐藏日志" : "显示日志"}
          title={isLogsVisible ? "隐藏日志" : "显示日志"}
          onClick={onToggleLogs}
        >
          <TerminalSquare size={17} />
        </button>
      </div>
    </section>
  );
}

function NetworkStrip({ events, onHide }: { events: NetworkEvent[]; onHide: () => void }) {
  return (
    <section className="evidence-strip" aria-label="网络证据">
      <div className="strip-heading">
        <Network size={16} />
        <strong>网络</strong>
        <button className="strip-action" type="button" aria-label="隐藏网络证据" title="隐藏网络证据" onClick={onHide}>
          <EyeOff size={15} />
        </button>
      </div>
      <div className="network-rows">
        {events.map((event) => (
          <div className="network-row" key={event.id}>
            <span className="method">{event.method}</span>
            <span className="path">{event.path}</span>
            <span className={event.status >= 400 ? "code is-error" : "code"}>{event.status}</span>
            <span>{event.latencyMs} 毫秒</span>
            <span>{modeLabel[event.mode]}</span>
          </div>
        ))}
      </div>
    </section>
  );
}

function LogStrip({ entries, onHide }: { entries: LogEntry[]; onHide: () => void }) {
  return (
    <section className="evidence-strip log-strip" aria-label="运行日志">
      <div className="strip-heading">
        <TerminalSquare size={16} />
        <strong>日志</strong>
        <button className="strip-action" type="button" aria-label="隐藏日志" title="隐藏日志" onClick={onHide}>
          <EyeOff size={15} />
        </button>
      </div>
      <div className="log-rows">
        {entries.map((entry) => (
          <div className={`log-row log-${entry.level}`} key={entry.id}>
            <span>{entry.time}</span>
            <strong>{logLevelLabel[entry.level]}</strong>
            <p>{entry.message}</p>
          </div>
        ))}
      </div>
    </section>
  );
}
