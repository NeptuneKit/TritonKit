import { useCallback, useEffect, useMemo, useRef, useState, type ChangeEvent, type ClipboardEvent, type CSSProperties, type KeyboardEvent, type PointerEvent } from "react";
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
  Grid3X3,
  Home,
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
import { logs, networkEvents, targets } from "./data/mockData";
import { describeHostBridgePresentation } from "./data/hostBridgePresentation";
import { fetchHostLogs, fetchHostScreenshot, fetchHostTargets, sendHostInput } from "./data/iosSimulatorClient";
import type {
  BridgeCommandOutput,
  DeviceFrameOrientation,
  DeviceTarget,
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

type GesturePreview =
  | {
      kind: "tap";
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
    };

type KeyboardRelayState = {
  xPercent: number;
  yPercent: number;
};

type SidebarPanel = "devices" | "view-tree";

type ViewTreeNode = {
  id: string;
  type: string;
  name?: string;
  children?: ViewTreeNode[];
};

const canvasZoomLevels = [0.75, 0.9, 1, 1.15, 1.3, 1.5] as const;
const previewFpsMin = 1;
const previewFpsMax = 60;

const iosViewTreeNodes: ViewTreeNode[] = [
  {
    id: "scene",
    type: "UIWindowScene",
    name: "mainScene",
    children: [
      {
        id: "window",
        type: "UIWindow",
        name: "keyWindow",
        children: [
          {
            id: "root",
            type: "UIView",
            name: "rootView",
            children: [
              {
                id: "nav",
                type: "UINavigationBar",
                name: "topBar",
                children: [
                  { id: "back", type: "UIButton", name: "backButton" },
                  { id: "title", type: "UILabel", name: "titleLabel" },
                ],
              },
              {
                id: "scroll",
                type: "UIScrollView",
                name: "contentScroll",
                children: [
                  {
                    id: "stack",
                    type: "UIStackView",
                    name: "questionList",
                    children: [
                      { id: "question-0", type: "UIButton", name: "caseOption[0]" },
                      { id: "question-1", type: "UIButton", name: "caseOption[1]" },
                      { id: "question-2", type: "UIButton", name: "caseOption[2]" },
                      { id: "question-3", type: "UIButton", name: "caseOption[3]" },
                      { id: "question-4", type: "UIButton", name: "caseOption[4]" },
                    ],
                  },
                ],
              },
              {
                id: "tabbar",
                type: "UITabBar",
                name: "tabBar",
                children: [
                  { id: "home-tab", type: "UIButton", name: "homeTab" },
                  { id: "message-tab", type: "UIButton", name: "messageTab" },
                  { id: "profile-tab", type: "UIButton", name: "profileTab" },
                ],
              },
            ],
          },
        ],
      },
    ],
  },
];

const harmonyViewTreeNodes: ViewTreeNode[] = [
  {
    id: "ability-window",
    type: "UIAbilityWindow",
    name: "EntryAbility",
    children: [
      {
        id: "arkui-root",
        type: "ArkUIRoot",
        name: "Index",
        children: [
          {
            id: "navigation",
            type: "Navigation",
            name: "developerSettings",
            children: [
              { id: "back-image", type: "Image", name: "back" },
              { id: "title-text", type: "Text", name: "开发者设置" },
            ],
          },
          {
            id: "scroll",
            type: "Scroll",
            name: "settingsScroll",
            children: [
              {
                id: "content-column",
                type: "Column",
                name: "settingsContent",
                children: [
                  {
                    id: "server-row",
                    type: "Row",
                    name: "服务器环境",
                    children: [
                      { id: "env-dev", type: "Button", name: "dev" },
                      { id: "env-test", type: "Button", name: "test" },
                      { id: "env-uat", type: "Button", name: "uat" },
                      { id: "env-prd", type: "Button", name: "prd" },
                    ],
                  },
                  { id: "switch-proxy", type: "Toggle", name: "代理配置" },
                  { id: "debug-link", type: "TextInput", name: "调试链接" },
                  {
                    id: "codepush-row",
                    type: "Row",
                    name: "CodePush",
                    children: [
                      { id: "update-button", type: "Button", name: "更新" },
                      { id: "custom-button", type: "Button", name: "自定义" },
                      { id: "clear-button", type: "Button", name: "清除" },
                    ],
                  },
                ],
              },
            ],
          },
        ],
      },
    ],
  },
];

const androidViewTreeNodes: ViewTreeNode[] = [
  {
    id: "decor-view",
    type: "DecorView",
    name: "MainActivity",
    children: [
      {
        id: "content",
        type: "FrameLayout",
        name: "android.R.id.content",
        children: [
          {
            id: "compose-root",
            type: "AndroidComposeView",
            name: "root",
            children: [
              { id: "top-app-bar", type: "Toolbar", name: "deviceToolbar" },
              { id: "lazy-column", type: "RecyclerView", name: "settingsList" },
              { id: "bottom-nav", type: "BottomNavigationView", name: "navigationBar" },
            ],
          },
        ],
      },
    ],
  },
];

function viewTreeNodesForTarget(target: DeviceTarget): ViewTreeNode[] {
  if (target.platform === "harmony") return harmonyViewTreeNodes;
  if (target.platform === "android") return androidViewTreeNodes;
  return iosViewTreeNodes;
}

function defaultViewTreeSelection(target: DeviceTarget): string {
  if (target.platform === "harmony") return "content-column";
  if (target.platform === "android") return "lazy-column";
  return "stack";
}

function normalizePreviewFps(value: number) {
  if (!Number.isFinite(value)) return previewFpsMin;
  return Math.max(previewFpsMin, Math.min(previewFpsMax, Math.round(value)));
}

function fpsToRefreshIntervalMs(fps: number) {
  return Math.max(1000 / previewFpsMax, Math.round(1000 / normalizePreviewFps(fps)));
}

export function App() {
  const [selectedId, setSelectedId] = useState(targets[0].id);
  const [hostTargets, setHostTargets] = useState<DeviceTarget[]>([]);
  const [targetSearch, setTargetSearch] = useState("");
  const [bridge, setBridge] = useState<BridgeState>({ loading: true, sourceCommands: [] });
  const [bridgeOutputs, setBridgeOutputs] = useState<BridgeCommandOutput[]>([]);
  const [interactionLogs, setInteractionLogs] = useState<LogEntry[]>([]);
  const [isNetworkVisible, setIsNetworkVisible] = useState(true);
  const [isLogsVisible, setIsLogsVisible] = useState(true);
  const [isSidebarVisible, setIsSidebarVisible] = useState(true);
  const [sidebarPanel, setSidebarPanel] = useState<SidebarPanel>("devices");
  const [canvasZoom, setCanvasZoom] = useState(1);
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

  const handleInput = async (input: ReadonlyInputIntent) => {
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
      return;
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
    if (input.action === "swipe") {
      return Math.round(input.startX) + "," + Math.round(input.startY) + " -> " + Math.round(input.endX) + "," + Math.round(input.endY);
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
          bridgeSubtitle={bridgePresentation.toolbarLabel}
          isSidebarVisible={isSidebarVisible}
          isRefreshing={isRefreshingAll}
          onToggleSidebar={() => setIsSidebarVisible((current) => !current)}
          onRefresh={handleRefreshAll}
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
            onInput={handleInput}
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
  bridgeSubtitle,
  isSidebarVisible,
  isRefreshing,
  onToggleSidebar,
  onRefresh,
}: {
  target: DeviceTarget;
  bridgeSubtitle: string;
  isSidebarVisible: boolean;
  isRefreshing: boolean;
  onToggleSidebar: () => void;
  onRefresh: () => void;
}) {
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

      <div className="toolbar-title">
        <strong>{target.name}</strong>
        <span>{bridgeSubtitle === "Readonly host targets" ? target.os : bridgeSubtitle}</span>
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
}: {
  selected: DeviceTarget;
  targets: DeviceTarget[];
  activePanel: SidebarPanel;
  searchValue: string;
  isSearching: boolean;
  onSearchChange: (value: string) => void;
  onPanelChange: (panel: SidebarPanel) => void;
  onSelect: (id: string) => void;
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
        <ViewTreePanel selected={selected} targets={visibleTargets} onSelect={onSelect} />
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
}: {
  selected: DeviceTarget;
  targets: DeviceTarget[];
  onSelect: (id: string) => void;
}) {
  const treeNodes = useMemo(() => viewTreeNodesForTarget(selected), [selected]);
  const defaultSelection = defaultViewTreeSelection(selected);
  const [selectedNode, setSelectedNode] = useState(defaultSelection);

  useEffect(() => {
    setSelectedNode(defaultSelection);
  }, [defaultSelection, selected.id]);

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
          <ViewTreeRow key={node.id} node={node} depth={0} selectedNode={selectedNode} onSelect={setSelectedNode} />
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
  onInput,
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
  onInput: (input: ReadonlyInputIntent) => Promise<void>;
}) {
  const screenRef = useRef<HTMLDivElement | null>(null);
  const keyboardRelayRef = useRef<HTMLInputElement | null>(null);
  const keyboardRelayValue = useRef("");
  const previewControlRef = useRef<HTMLDivElement | null>(null);
  const gestureStart = useRef<GesturePoint | null>(null);
  const gestureClearTimer = useRef<number | undefined>(undefined);
  const [gesturePreview, setGesturePreview] = useState<GesturePreview | null>(null);
  const [keyboardRelay, setKeyboardRelay] = useState<KeyboardRelayState | null>(null);
  const [keyboardRelayText, setKeyboardRelayText] = useState("");
  const [isPreviewFpsOpen, setIsPreviewFpsOpen] = useState(false);
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

  useEffect(() => {
    return () => {
      if (gestureClearTimer.current) {
        window.clearTimeout(gestureClearTimer.current);
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

  const clearGesturePreviewSoon = () => {
    if (gestureClearTimer.current) {
      window.clearTimeout(gestureClearTimer.current);
    }
    gestureClearTimer.current = window.setTimeout(() => {
      setGesturePreview(null);
    }, 620);
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

  const handlePointerDown = (event: PointerEvent<HTMLDivElement>) => {
    if (!canSendInput) return;
    screenRef.current?.focus({ preventScroll: true });
    const start = mapPointer(event);
    gestureStart.current = start;
    if (start) {
      if (gestureClearTimer.current) {
        window.clearTimeout(gestureClearTimer.current);
      }
      setGesturePreview({
        kind: "tap",
        xPercent: start.xPercent,
        yPercent: start.yPercent,
      });
    }
    try {
      event.currentTarget.setPointerCapture(event.pointerId);
    } catch {
      // Synthetic pointer events used by browser smoke tests may not have an active pointer.
    }
  };

  const handlePointerMove = (event: PointerEvent<HTMLDivElement>) => {
    if (!canSendInput) return;
    const start = gestureStart.current;
    const current = mapPointer(event);
    if (!start || !current) return;
    const distance = Math.hypot(current.x - start.x, current.y - start.y);
    if (distance < 10) {
      setGesturePreview({
        kind: "tap",
        xPercent: current.xPercent,
        yPercent: current.yPercent,
      });
      return;
    }
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
    gestureStart.current = null;
    clearGesturePreviewSoon();
  };

  const handlePointerUp = (event: PointerEvent<HTMLDivElement>) => {
    if (!canSendInput || !target.targetSelector) return;
    const start = gestureStart.current;
    const end = mapPointer(event);
    gestureStart.current = null;
    if (!start || !end) return;
    const distance = Math.hypot(end.x - start.x, end.y - start.y);
    if (distance < 18) {
      setGesturePreview({
        kind: "tap",
        xPercent: start.xPercent,
        yPercent: start.yPercent,
      });
      setKeyboardRelay({
        xPercent: start.xPercent,
        yPercent: start.yPercent,
      });
      clearGesturePreviewSoon();
      onInput({
        action: "tap",
        platform: target.platform,
        target: target.targetSelector,
        x: start.x,
        y: start.y,
        width: target.screenshotPixelWidth ?? undefined,
        height: target.screenshotPixelHeight ?? undefined,
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
    <section className="hub-canvas" aria-label="设备画布">
      {target.screenshotDataUrl ? (
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
        <div
          className={`device-frame orientation-${orientation} ${aspectRatio ? "has-real-frame" : ""}`}
          style={frameStyle}
        >
          <div className="device-side left" />
          <div className="device-side top" />
          <div className="device-side bottom" />
          <div
            className={`device-screen orientation-${orientation} ${target.screenshotTone} ${canSendInput ? "is-interactive" : ""}`}
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
              <div className="real-screenshot-pending" role="status" aria-live="polite">
                <span />
                <strong>正在获取实时画面</strong>
                <em>{target.transport}</em>
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
      </div>
      <DeviceControls
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

function ScreenMini({ label, value }: { label: string; value: string }) {
  return (
    <div className="screen-mini">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function GestureOverlay({ gesture }: { gesture: GesturePreview }) {
  if (gesture.kind === "tap") {
    return (
      <div
        className="gesture-touch is-tap"
        style={{
          "--gesture-x": `${gesture.xPercent}%`,
          "--gesture-y": `${gesture.yPercent}%`,
        } as CSSProperties}
      />
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
  target,
  isNetworkVisible,
  isLogsVisible,
  onToggleNetwork,
  onToggleLogs,
}: {
  target: DeviceTarget;
  isNetworkVisible: boolean;
  isLogsVisible: boolean;
  onToggleNetwork: () => void;
  onToggleLogs: () => void;
}) {
  const actions = [
    { label: "应用", Icon: Grid3X3 },
    { label: "点选", Icon: MousePointer2 },
    { label: "探测", Icon: Crosshair },
    ...(supportsSystemHomeControl(target) ? [{ label: "主屏幕", Icon: Home }] : []),
    { label: target.frameOrientation === "portrait" ? "竖屏" : "横屏", Icon: ScanLine },
  ];

  return (
    <section className="device-controls" aria-label="设备控制">
      <div className="control-pill">
        {actions.map(({ label, Icon }) => (
          <button key={label} type="button" aria-label={label} title={label}>
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

function supportsSystemHomeControl(target: DeviceTarget) {
  if (target.screenshotSource === "runtime") {
    return false;
  }
  return target.canInput !== false;
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
