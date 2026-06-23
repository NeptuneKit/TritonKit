import { useEffect, useMemo, useRef, useState, type CSSProperties, type PointerEvent } from "react";
import { Button, Card, Descriptions, Input, Tabs, Tag, Tree } from "antd";
import type { DataNode } from "antd/es/tree";
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
import { resolveEvidenceSources } from "../data/hierarchyMaterialPolicy";
import {
  defaultViewTreeSelection,
  displayLanguageOptions,
  hierarchyNodeAtPoint,
  localizeLogEntry,
  localizeStatusLabel,
  modeLabel,
  platformLabel,
  platformName,
  previewFpsMax,
  previewFpsMin,
  readableViewTreeLabel,
  readableViewTreeName,
  resolveControllerShellBadge,
  targetKindLabel,
  viewNodeHighlightForScene,
  viewTreeNodesForScene,
  type BridgeState,
  type DevtoolsPanel,
  type DisplayLanguage,
  type HierarchyCacheEntry,
  type HierarchyNodeHotEditDraft,
  type LivePreviewState,
  type SidebarPanel,
  type ViewTreeNode,
} from "./inspectorWorkspaceModel";
import type {
  DeviceTarget,
  HierarchyLayerNode,
  HierarchyScene,
  LogEntry,
  NetworkEvent,
} from "../types";

export type DeviceCanvasTapInput = {
  x: number;
  y: number;
  width: number;
  height: number;
  xPercent: number;
  yPercent: number;
};

type DeviceCanvasPointerPoint = {
  x: number;
  y: number;
  xPercent: number;
  yPercent: number;
};

const tapMoveThreshold = 18;
const tapDurationThresholdMs = 520;

export function DeviceHubToolbar({
  target,
  targets,
  bridgeSubtitle,
  isSidebarVisible,
  isDevtoolsVisible,
  isRefreshing,
  isTargetMenuOpen,
  onToggleSidebar,
  onToggleDevtools,
  onOpenSettings,
  onRefresh,
  onToggleTargetMenu,
  onCloseTargetMenu,
  onSelectTarget,
}: {
  target: DeviceTarget;
  targets: DeviceTarget[];
  bridgeSubtitle: string;
  isSidebarVisible: boolean;
  isDevtoolsVisible: boolean;
  isRefreshing: boolean;
  isTargetMenuOpen: boolean;
  onToggleSidebar: () => void;
  onToggleDevtools: () => void;
  onOpenSettings: () => void;
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
          label={isDevtoolsVisible ? "收起右侧面板" : "展开右侧面板"}
          icon={PanelRight}
          className={isDevtoolsVisible ? "is-active" : ""}
          onClick={onToggleDevtools}
        />
        <IconTool
          label="打开设置"
          icon={Settings2}
          onClick={onOpenSettings}
        />
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
    <Button
      className={`icon-tool ${variant === "solo" ? "is-solo" : ""} ${className ?? ""}`}
      aria-label={label}
      title={label}
      disabled={disabled}
      type="text"
      shape="circle"
      icon={<Icon size={17} strokeWidth={2.2} />}
      onClick={onClick}
    />
  );
}

export function TargetNavigator({
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
      <Input
        className="sidebar-search"
        prefix={<Search size={16} />}
        placeholder="搜索"
        value={searchValue}
        allowClear
        onInput={(event) => onSearchChange((event.target as HTMLInputElement).value)}
        onChange={(event) => onSearchChange(event.target.value)}
      />

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
    <Card className="sidebar-panel" aria-label="设备列表面板" size="small" title="运行中">
      <div className="device-list ant-list">
        {visibleTargets.map((target) => {
          const appLabel = target.appName || "前台 App 未识别";
          const detailLabel = appLabel;

          return (
            <div className="ant-list-item" key={target.id}>
              <button
                className={`device-row ${target.id === selected.id ? "is-selected" : ""}`}
                onClick={() => onSelect(target.id)}
                type="button"
              >
                <span className="device-row-copy">
                  <strong>{target.name}</strong>
                  <span title={detailLabel}>{detailLabel}</span>
                </span>
                <span className="device-row-meta">
                  <Tag className="device-platform-badge" color="blue">
                    {platformLabel[target.platform]}
                  </Tag>
                  <span className="device-version">{target.os.replace(/^[A-Za-z ]+/, "")}</span>
                </span>
              </button>
            </div>
          );
        })}
        {visibleTargets.length === 0 ? (
          <p className="empty-devices">{isSearching ? "未找到匹配 target" : "暂无运行中的设备"}</p>
        ) : null}
      </div>
    </Card>
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
  const isStale = Boolean(hierarchyScene && (hierarchy?.stale || hierarchy?.error));
  const treeNodes = useMemo(() => (hierarchyScene ? viewTreeNodesForScene(hierarchyScene) : []), [hierarchyScene]);
  const defaultSelection = hierarchyScene ? defaultViewTreeSelection(hierarchyScene) : null;
  const selectedNode = selectedHierarchyNode ?? defaultSelection;
  const treeData = useMemo<DataNode[]>(() => {
    const toTreeData = (node: ViewTreeNode, depth: number): DataNode => {
      const hasChildren = Boolean(node.children?.length);
      const displayType = readableViewTreeLabel(node.type);
      const displayName = readableViewTreeName(displayType, node.name ? readableViewTreeLabel(node.name) : null);
      const fullLabel = [node.type, node.name].filter(Boolean).join(" ");

      return {
        key: node.id,
        title: (
          <button
            className={`view-tree-row ${selectedNode === node.id ? "is-selected" : ""}`}
            style={{ "--tree-depth": depth } as CSSProperties}
            type="button"
            role="treeitem"
            aria-level={depth + 1}
            aria-selected={selectedNode === node.id}
            aria-expanded={hasChildren ? true : undefined}
            data-node-id={node.id}
            onClick={(event) => {
              event.stopPropagation();
              onSelectHierarchyNode(node.id);
            }}
          >
            <span className="tree-disclosure">{hasChildren ? "▾" : "·"}</span>
            <span className="tree-node-copy" title={fullLabel}>
              <strong>{displayType}</strong>
              {displayName ? <span>{displayName}</span> : null}
            </span>
          </button>
        ),
        children: node.children?.map((child) => toTreeData(child, depth + 1)),
      };
    };

    return treeNodes.map((node) => toTreeData(node, 0));
  }, [onSelectHierarchyNode, selectedNode, treeNodes]);

  return (
    <Card className="sidebar-panel view-tree-panel" aria-label="视图层级面板" size="small">
      {hierarchy?.loading && !hierarchyScene ? (
        <p className="view-tree-empty">正在读取实时视图层级...</p>
      ) : hierarchy?.error && !hierarchyScene ? (
        <div className="view-tree-empty" title={hierarchy.error}>
          <p>未拿到实时视图层级</p>
          <small>{hierarchy.error}</small>
        </div>
      ) : hierarchyScene ? (
        <>
          <div className={`view-tree-status ${isStale ? "is-stale" : ""}`} title={hierarchy?.error}>
            <strong>{isStale ? "缓存视图层级" : hierarchy?.loading ? "正在刷新实时视图层级" : "实时视图层级"}</strong>
            {hierarchy?.error ? <small>{hierarchy.error}</small> : null}
          </div>
          <div className="view-tree-list" aria-label={`${selected.appName} 视图层级`}>
            <Tree
              blockNode
              expandedKeys={hierarchyScene.nodes.map((node) => node.id)}
              selectedKeys={selectedNode ? [selectedNode] : []}
              treeData={treeData}
              onSelect={(keys) => onSelectHierarchyNode(String(keys[0] ?? ""))}
            />
          </div>
        </>
      ) : (
        <p className="view-tree-empty">暂无实时视图层级</p>
      )}
    </Card>
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
        aria-level={depth + 1}
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
      {node.children?.length ? (
        <div className="view-tree-group" role="group">
          {node.children.map((child) => (
            <ViewTreeRow key={child.id} node={child} depth={depth + 1} selectedNode={selectedNode} onSelect={onSelect} />
          ))}
        </div>
      ) : null}
    </>
  );
}

export function DeviceCanvas({
  target,
  hierarchyScene,
  hierarchyStale,
  selectedHierarchyNode,
  selectedHierarchyNodeDraft,
  screenshotError,
  livePreview,
  isSnapshotMode,
  isSnapshotRefreshing,
  isDiscoveringHostTargets,
  isInputDispatching,
  onPreviewFpsChange,
  onSnapshotModeChange,
  onSnapshotRefresh,
  onSelectHierarchyNode,
  onTap,
}: {
  target: DeviceTarget;
  hierarchyScene?: HierarchyScene;
  hierarchyStale?: boolean;
  selectedHierarchyNode: string | null;
  selectedHierarchyNodeDraft?: HierarchyNodeHotEditDraft;
  screenshotError?: string;
  livePreview?: LivePreviewState;
  isSnapshotMode: boolean;
  isSnapshotRefreshing: boolean;
  isDiscoveringHostTargets: boolean;
  isInputDispatching?: boolean;
  onPreviewFpsChange: (fps: number) => void;
  onSnapshotModeChange: (enabled: boolean) => void;
  onSnapshotRefresh: () => Promise<void>;
  onSelectHierarchyNode: (nodeId: string | null) => void;
  onTap?: (target: DeviceTarget, input: DeviceCanvasTapInput) => Promise<void>;
}) {
  const screenRef = useRef<HTMLDivElement | null>(null);
  const previewControlRef = useRef<HTMLDivElement | null>(null);
  const tapCandidateRef = useRef<{ pointerId: number; start: DeviceCanvasPointerPoint; startedAt: number; moved: boolean } | null>(null);
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
  const isWaitingForRealScreenshot = Boolean(target.realSource && target.canScreenshot && !target.screenshotDataUrl);
  const pendingScreenshotState = screenshotPendingState(target, screenshotError);
  const canDispatchTap = Boolean(
    target.realSource &&
    target.canInput &&
    !target.readonly &&
    target.screenshotDataUrl &&
    !isSnapshotMode &&
    onTap
  );
  const canSelectSnapshotNode = Boolean(hierarchyScene && !canDispatchTap);

  useEffect(() => {
    setIsPreviewFpsOpen(false);
  }, [target.id]);

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
    }
  }, [isSnapshotMode]);

  const mapPointer = (event: PointerEvent<HTMLDivElement>): DeviceCanvasPointerPoint | null => {
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
    if (!canSelectSnapshotNode && !canDispatchTap) return;
    screenRef.current?.focus({ preventScroll: true });
    const start = mapPointer(event);
    if (!start) return;
    if (canDispatchTap) {
      tapCandidateRef.current = {
        pointerId: event.pointerId,
        start,
        startedAt: Date.now(),
        moved: false,
      };
      return;
    }
    if (hierarchyScene) {
      const hitNode = hierarchyNodeAtPoint(hierarchyScene, start.xPercent, start.yPercent);
      if (hitNode) {
        onSelectHierarchyNode(hitNode.id);
      }
    }
  };

  const handlePointerMove = (event: PointerEvent<HTMLDivElement>) => {
    const candidate = tapCandidateRef.current;
    if (!candidate || candidate.pointerId !== event.pointerId) return;
    const current = mapPointer(event);
    if (!current) return;
    const distance = Math.hypot(current.x - candidate.start.x, current.y - candidate.start.y);
    if (distance > tapMoveThreshold) {
      tapCandidateRef.current = { ...candidate, moved: true };
    }
  };

  const handlePointerUp = (event: PointerEvent<HTMLDivElement>) => {
    const candidate = tapCandidateRef.current;
    if (!candidate || candidate.pointerId !== event.pointerId) return;
    tapCandidateRef.current = null;
    const end = mapPointer(event);
    if (!end || candidate.moved || Date.now() - candidate.startedAt > tapDurationThresholdMs || isInputDispatching) {
      return;
    }
    void onTap?.(target, {
      x: Math.round(end.x),
      y: Math.round(end.y),
      width: target.screenshotPixelWidth ?? 0,
      height: target.screenshotPixelHeight ?? 0,
      xPercent: end.xPercent,
      yPercent: end.yPercent,
    });
  };

  const handlePointerCancel = (event: PointerEvent<HTMLDivElement>) => {
    const candidate = tapCandidateRef.current;
    if (candidate?.pointerId === event.pointerId) {
      tapCandidateRef.current = null;
    }
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
    <section className="hub-canvas tool-inspect" aria-label="Inspect Session 设备画布">
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
        {hierarchyScene?.platform === "ios" ? (
          <div
            className={`controller-shell-badge ${controllerBadge?.isFallback ? "is-fallback" : ""} ${hierarchyStale ? "is-stale" : ""}`}
            title={controllerBadge?.stack.length ? controllerBadge.stack.join(" > ") : controllerBadge?.className ?? "UIViewController 未暴露"}
          >
            <strong>{controllerBadge?.name ?? "未暴露"}</strong>
            <em>{hierarchyStale ? "缓存" : "实时"}</em>
          </div>
        ) : null}
        <div
          className={`device-frame orientation-${orientation} ${aspectRatio ? "has-real-frame" : ""}`}
          style={frameStyle}
        >
          <div className="device-side left" />
          <div className="device-side top" />
          <div className="device-side bottom" />
          <div
            className={`device-screen orientation-${orientation} ${target.screenshotTone} tool-inspect ${canSelectSnapshotNode || canDispatchTap ? "is-interactive" : ""} ${canDispatchTap ? "can-dispatch-tap" : ""}`}
            aria-label={canDispatchTap ? "设备画面，点击会发送 tap 到目标设备" : "设备画面，当前工具 Inspect node"}
            tabIndex={canSelectSnapshotNode || canDispatchTap ? 0 : undefined}
            onPointerDown={handlePointerDown}
            onPointerMove={handlePointerMove}
            onPointerUp={handlePointerUp}
            onPointerCancel={handlePointerCancel}
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
              {isInputDispatching ? (
                <div className="input-activity-badge is-dispatching" role="status" aria-live="polite">
                  <span />
                  <strong>正在发送点击</strong>
                </div>
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
      command: serverUnavailable ? "triton serve --host 0.0.0.0 --port 19421；真机 Debug App 设置 TRITON_HOST=<Mac 局域网 IP>" : undefined,
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

export function Inspector({
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
      <Card className="app-tile" aria-label="当前应用" size="small">
        <div className="app-icon">
          <Activity size={18} />
        </div>
        <div>
          <strong>{target.appName}</strong>
          <span>{target.bundleId}</span>
        </div>
        <Tag color={target.actionResult === "failed" ? "red" : target.actionResult === "warning" ? "gold" : "blue"}>
          {localizeStatusLabel(target.statusLabel)}
        </Tag>
      </Card>

      <div className="metric-stack">
        <Metric icon={Gauge} label="帧率" value={target.fps.toString()} />
        <Metric icon={Clock3} label="延迟" value={`${target.latencyMs} 毫秒`} />
        <Metric icon={Braces} label="AX 节点" value={target.hierarchyNodes.toString()} />
        <Metric icon={DatabaseZap} label="HTTP 错误" value={errorCount.toString()} />
      </div>

      <SelectedNodeEvidencePanel
        node={selectedNode}
      />

      <Descriptions
        className="inspector-details"
        column={1}
        size="small"
        bordered
        items={[
          { key: "device", label: "设备", children: target.device },
          ...(target.udid ? [{ key: "udid", label: "UDID", children: target.udid }] : []),
          { key: "action", label: "最近动作", children: `${target.actionResult}: ${target.lastAction}` },
          { key: "transport", label: "传输", children: target.transport },
          { key: "source", label: "来源", children: target.realSource ? bridge.sourceCommands.join(" · ") || target.transport : target.proxyLabel },
        ]}
      />

      <div className="inspector-footer">
        <Search size={15} />
        <span>过滤</span>
        <strong>开发者</strong>
        <ChevronDown size={14} />
      </div>
    </aside>
  );
}

function SelectedNodeEvidencePanel({
  node,
}: {
  node: HierarchyLayerNode | null;
}) {
  if (!node) {
    return (
      <Card className="selected-node-panel is-empty" aria-label="选中视图节点" size="small">
        <div className="selected-node-heading">
          <strong>选中视图节点</strong>
          <span>在视图树或截图叠层中选择节点后显示 evidence</span>
        </div>
      </Card>
    );
  }

  const frame = node.frame;
  const evidenceSources = resolveEvidenceSources(node);
  const visualSourceSummary = evidenceSources.map((source) => source.kind).join(" · ") || "none";
  const nodeName = node.name ? readableViewTreeLabel(node.name) : "";
  const typeLabel = readableViewTreeLabel(node.type);

  return (
    <Card className="selected-node-panel" aria-label="选中视图节点" size="small">
      <div className="selected-node-heading">
        <div>
          <strong>{typeLabel}</strong>
          {nodeName ? <span>{nodeName}</span> : null}
        </div>
        <Tag color="blue">Runtime DTO</Tag>
      </div>

      <Descriptions
        className="selected-node-summary"
        column={1}
        size="small"
        bordered
        items={[
          { key: "id", label: "ID", children: node.id },
          { key: "frame", label: "Frame", children: `${formatInspectorNumber(frame.x)}, ${formatInspectorNumber(frame.y)}, ${formatInspectorNumber(frame.width)} x ${formatInspectorNumber(frame.height)}` },
          { key: "depth", label: "Depth", children: node.depth },
          { key: "state", label: "State", children: node.visible ? (node.interactive ? "可交互" : "可见") : "隐藏" },
          { key: "source", label: "Source", children: node.source ?? node.raw?.source ?? "runtime" },
          { key: "ax", label: "AX", children: node.view?.accessibilityLabel ?? node.view?.accessibilityIdentifier ?? "未暴露" },
        ]}
      />

      <div className="node-evidence-grid" aria-label="Visual evidence">
        <div>
          <span>Visual evidence</span>
          <strong>{visualSourceSummary}</strong>
        </div>
        <div>
          <span>Layer</span>
          <strong>{node.layer ? "available" : "not exposed"}</strong>
        </div>
        <div>
          <span>Style</span>
          <strong>{node.style?.display ?? node.renderHints?.preferredMode ?? "not exposed"}</strong>
        </div>
        <div>
          <span>Raw role</span>
          <strong>{node.raw?.role ?? "not exposed"}</strong>
        </div>
      </div>
    </Card>
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

export function DevtoolsTabs({
  activePanel,
  language,
  onSelectPanel,
}: {
  activePanel: DevtoolsPanel;
  language: DisplayLanguage;
  onSelectPanel: (panel: DevtoolsPanel) => void;
}) {
  const tabs: Array<{ id: DevtoolsPanel; label: string }> = [
    { id: "config", label: language === "zh-CN" ? "证据" : "Evidence" },
    { id: "network", label: language === "zh-CN" ? "Trace" : "Trace" },
    { id: "logs", label: language === "zh-CN" ? "日志" : "Logs" },
  ];

  return (
    <Tabs
      activeKey={activePanel}
      className="inspector-tabs"
      role="tablist"
      aria-label={language === "zh-CN" ? "右侧工具分区" : "Right-side tool sections"}
      items={tabs.map((tab) => ({ key: tab.id, label: tab.label }))}
      onChange={(key) => onSelectPanel(key as DevtoolsPanel)}
    />
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

export function SettingsPage({
  language,
  onBack,
  onLanguageChange,
}: {
  language: DisplayLanguage;
  onBack: () => void;
  onLanguageChange: (language: DisplayLanguage) => void;
}) {
  const isChinese = language === "zh-CN";

  return (
    <main className="settings-page-shell">
      <section className="settings-page" aria-label={isChinese ? "设置" : "Settings"}>
        <div className="settings-page-topbar">
          <button
            aria-label={isChinese ? "返回 Inspect Session" : "Back to Inspect Session"}
            className="settings-back-button"
            type="button"
            onClick={onBack}
          >
            ← {isChinese ? "返回 Inspect Session" : "Back to Inspect Session"}
          </button>
          <span>{isChinese ? "Web 本地偏好" : "Local Web preferences"}</span>
        </div>

        <div className="settings-heading">
          <Settings2 size={22} />
          <div>
            <strong>{isChinese ? "设置" : "Settings"}</strong>
            <span>{isChinese ? "独立页面，仅影响本机 Web 展示偏好" : "Dedicated page for local Web display preferences only"}</span>
          </div>
        </div>

        <div className="settings-group">
          <div className="settings-copy">
            <strong>{isChinese ? "语言偏好" : "Language preference"}</strong>
            <span>
              {isChinese
                ? "用于工具区标签、日志和展示层格式化；不改变 CLI / HTTP 机器可读契约。"
                : "Used for tool labels, logs, and display formatting. CLI / HTTP contracts remain unchanged."}
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
    </main>
  );
}

export function NetworkStrip({
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
      aria-label={language === "zh-CN" ? "Trace 证据" : "Trace evidence"}
      hidden={hidden}
    >
      <div className="strip-heading">
        <Network size={16} />
        <strong>Trace</strong>
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

export function LogStrip({
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
