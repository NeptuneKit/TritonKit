import { useMemo, useRef, type CSSProperties, type PointerEvent } from "react";
import { Alert, Button, InputNumber, Segmented, Tag, Typography } from "antd";
import { RefreshCw } from "lucide-react";
import {
  cycleHierarchyNodeAtPoint,
  hierarchyNodesAtPoint,
  localizeStatusLabel,
  previewFpsMax,
  previewFpsMin,
  resolveControllerShellBadge,
  targetKindLabel,
  viewNodeHighlightForScene,
  type HierarchyNodeHotEditDraft,
  type LivePreviewState,
} from "./inspectorWorkspaceModel";
import type {
  DeviceTarget,
  HierarchyScene,
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
    if (canDispatchTap && hierarchyScene && selectedHierarchyNode) {
      const isInsideSelectedNode = hierarchyNodesAtPoint(hierarchyScene, start.xPercent, start.yPercent)
        .some((node) => node.id === selectedHierarchyNode);
      if (isInsideSelectedNode) {
        const hitNode = cycleHierarchyNodeAtPoint(hierarchyScene, start.xPercent, start.yPercent, selectedHierarchyNode);
        if (hitNode && hitNode.id !== selectedHierarchyNode) {
          onSelectHierarchyNode(hitNode.id);
          return;
        }
      }
    }
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
      const hitNode = cycleHierarchyNodeAtPoint(hierarchyScene, start.xPercent, start.yPercent, selectedHierarchyNode);
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
      <div className="app-tile" hidden>
        <strong>{target.appName}</strong>
        <span>{target.bundleId}</span>
      </div>
      {target.realSource && target.canScreenshot ? (
        <div className={`live-preview-control ${isSnapshotMode ? "is-snapshot" : ""}`} ref={previewControlRef}>
          <Segmented
            size="small"
            options={[
              { label: "实时", value: false },
              { label: "快照", value: true },
            ]}
            value={isSnapshotMode}
            onChange={(value) => onSnapshotModeChange(Boolean(value))}
          />
          {isSnapshotMode ? (
            <Button
              className="snapshot-refresh-button"
              size="small"
              icon={<RefreshCw size={13} />}
              loading={isSnapshotRefreshing}
              onClick={() => {
                void onSnapshotRefresh();
              }}
            >
              {isSnapshotRefreshing ? "刷新中" : "刷新"}
            </Button>
          ) : (
            <InputNumber
              aria-label="调整实时预览帧率"
              size="small"
              min={previewFpsMin}
              max={previewFpsMax}
              value={target.fps}
              onChange={(value) => { if (value !== null) onPreviewFpsChange(value); }}
              suffix="fps"
              style={{ width: 100 }}
            />
          )}
        </div>
      ) : null}

      <div className="device-stage" aria-label="设备镜像区域">
        {hierarchyScene?.platform === "ios" ? (
          <Tag
            className="controller-shell-badge"
            color={controllerBadge?.isFallback ? "default" : hierarchyStale ? "warning" : "success"}
            title={controllerBadge?.stack.length ? controllerBadge.stack.join(" > ") : controllerBadge?.className ?? "UIViewController 未暴露"}
          >
            {controllerBadge?.name ?? "未暴露"} · {hierarchyStale ? "缓存" : "实时"}
          </Tag>
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
                <div className={`real-screenshot-pending is-${pendingScreenshotState.kind}`} role="status" aria-live="polite">
                  <Alert
                    type={pendingScreenshotState.kind === "error" ? "error" : "info"}
                    showIcon
                    title={pendingScreenshotState.title}
                    description={
                      <>
                        <Typography.Text type="secondary">{pendingScreenshotState.detail}</Typography.Text>
                        {pendingScreenshotState.command ? (
                          <div><Typography.Text code>{pendingScreenshotState.command}</Typography.Text></div>
                        ) : null}
                      </>
                    }
                  />
                </div>
              ) : (
                <>
                  <div className="screen-island" />
                  <div className="screen-hero">
                    <Typography.Text type="secondary">目标</Typography.Text>
                    <Typography.Title level={5} style={{ margin: 0 }}>{target.appName}</Typography.Title>
                    <Button size="small" type="primary">
                      {target.realSource ? localizeStatusLabel(target.statusLabel) : "检查"}
                    </Button>
                  </div>
                  <div className="screen-content">
                    <div>
                      <Typography.Title level={4} style={{ margin: 0 }}>{targetKindLabel(target)}</Typography.Title>
                      <Typography.Text type="secondary">{target.device}</Typography.Text>
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
                <Tag color="processing" className="input-activity-badge" role="status" aria-live="polite">
                  正在发送点击
                </Tag>
              ) : null}
          </div>
        </div>
      </div>
      {screenshotError ? (
        <Alert
          className="canvas-error"
          type="error"
          showIcon
          title={screenshotError}
          closable
        />
      ) : null}
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
