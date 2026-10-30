import React, { useState, useEffect, useCallback, useRef } from "react";
import { Badge, Button, Icon, IconButton, Inline, Notice, Popover, SegmentedControl, Select, Text } from "@linhey/rhine-design";
import "./streamPanel.css";
import { Smartphone, WifiOff } from "lucide-react";

import { useAppContext } from "../AppContext";
import { fetchHostTargets } from "../data/iosSimulatorClient";
import { deriveOverlayNodes } from "../inspect/hierarchyDerive";
import { hitTestHierarchyNode } from "../inspect/hitTest";
import { loadStreamTargetFps, saveStreamTargetFps } from "../streamPreferences";
import type { DeviceTarget } from "../types";
import { observeStreamVisibility, observeFirstStreamFrame, releaseStreamImage, attachStreamImage, hasCurrentStreamFrame } from "../streamVisibility";

// ── 类型 ───────────────────────────────────────────────────────
interface SimTarget {
  id: string;
  target: string;
  name: string;
  platform: "ios" | "android" | "harmony";
  ready: boolean;
  runtime?: string;
  scope?: string;
  kind?: string;
  source?: string;
  targetKey?: string;
}

export type StreamImageRequest = { platform: "ios" | "android" | "harmony"; target: string; fps: number; connectTime: number };
export function streamImageSource({ platform, target, fps, connectTime }: StreamImageRequest): string {
  const endpoint = platform === "ios" ? "ios-simulator" : platform;
  return `/web/${endpoint}/mjpeg?udid=${target}&fps=${fps}&t=${connectTime}`;
}
export type StreamPanelProps = {
  nodeId: string;
  headerActions?: React.ReactNode;
  streamImageUrl?: (request: StreamImageRequest) => string;
};

export function StreamPanel({ nodeId, headerActions, streamImageUrl = streamImageSource }: StreamPanelProps) {
  const [connected, setConnected]     = useState(false);
  const [connectTime, setConnectTime] = useState(0);
  const [targets,   setTargets]       = useState<SimTarget[]>([]);
  const [selectedUdid, setSelectedUdid] = useState<string | null>(null);
  const [fps,    setFps]              = useState(0);
  const [targetFps, setTargetFps]     = useState(loadStreamTargetFps);
  const [refreshing, setRefreshing]   = useState(false);
  const [previewVisible, setPreviewVisible] = useState(false);
  const [loadedStreamUrl, setLoadedStreamUrl] = useState("");
  const [failedStreamUrl, setFailedStreamUrl] = useState("");

  const frameCount    = useRef(0);
  const lastFpsTs     = useRef(Date.now());
  const hasConnectedRef = useRef(false);

  const imgRef = useRef<HTMLImageElement>(null);
  const viewportRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const viewport = viewportRef.current;
    if (!viewport) return;
    return observeStreamVisibility(viewport, (visible) => {
      if (!visible && imgRef.current) releaseStreamImage(imgRef.current);
      setPreviewVisible(visible);
      if (visible) setConnectTime((previous) => Math.max(Date.now(), previous + 1));
      frameCount.current = 0;
      lastFpsTs.current = Date.now();
      setFps(0);
    });
  }, []);
  const [imgLayout, setImgLayout] = useState<{
    width: number;
    height: number;
    left: number;
    top: number;
    naturalWidth: number;
    naturalHeight: number;
  } | null>(null);

  const {
    registerStream,
    unregisterStream,
    setFocusedNodeId,
    loadInspectTargets,
    setFocusedInspectTarget,
    getInspectSession,
    refreshInspectSession,
    setInspectOverlayMode,
    selectInspectNode,
    hoverInspectNode,
  } = useAppContext();

  useEffect(() => {
    saveStreamTargetFps(targetFps);
  }, [targetFps]);

  // ── 获取设备列表 ───────────────────────────────────────────────
  const fetchTargets = useCallback(async () => {
    try {
      const data = await fetchHostTargets();
      if (data.targets) {
        const readyDeviceTargets = data.targets
          .filter((target: DeviceTarget) => target.status === "ready" && target.targetSelector);
        const inspectTargets = loadInspectTargets(readyDeviceTargets);
        const readyTargets: SimTarget[] = readyDeviceTargets
          .map((target: DeviceTarget, index: number) => ({
            id: target.id,
            target: target.targetSelector ?? target.id,
            name: target.name,
            platform: target.platform,
            ready: true,
            runtime: target.os,
            scope: target.scope,
            kind: target.kind,
            source: target.screenshotSource ?? "host",
            targetKey: inspectTargets[index]?.key,
          }));
        setTargets(readyTargets);
        if (readyTargets.length > 0) {
          const firstUdid = readyTargets[0].target;
          const firstTargetKey = readyTargets[0].targetKey;
          setSelectedUdid((prev) => {
            if (!prev) return firstUdid;
            return prev;
          });
          if (firstTargetKey) setFocusedInspectTarget(firstTargetKey, nodeId);
          // 仅在首次加载且未连接时自动连接到第一个已启动的模拟器
          if (!hasConnectedRef.current) {
            setConnected(true);
            setConnectTime(Date.now());
            hasConnectedRef.current = true;
          }
        }
        return readyTargets;
      }
      return [];
    } catch { /* 静默失败 */ }
    return [];
  }, [loadInspectTargets, nodeId, setFocusedInspectTarget]);

  const handleRefresh = useCallback(async () => {
    setRefreshing(true);
    const nextTargets = await fetchTargets();
    const targetObj = (nextTargets.length > 0 ? nextTargets : targets).find(t => t.target === selectedUdid);
    if (connected && targetObj?.targetKey) {
      await refreshInspectSession(targetObj.targetKey, "manualRefresh");
    }
    setRefreshing(false);
  }, [fetchTargets, connected, selectedUdid, targets, refreshInspectSession]);

  // 计算图片拉伸比率与位置
  const updateImageLayout = useCallback(() => {
    if (!imgRef.current) return;
    const img = imgRef.current;
    const container = img.parentElement;
    if (!container) return;
    const containerWidth = container.clientWidth;
    const containerHeight = container.clientHeight;
    const naturalWidth = img.naturalWidth;
    const naturalHeight = img.naturalHeight;

    if (!naturalWidth || !naturalHeight) return;

    const containerRatio = containerWidth / containerHeight;
    const imageRatio = naturalWidth / naturalHeight;

    let width, height, left, top;
    if (imageRatio > containerRatio) {
      width = containerWidth;
      height = containerWidth / imageRatio;
      left = 0;
      top = (containerHeight - height) / 2;
    } else {
      height = containerHeight;
      width = containerHeight * imageRatio;
      left = (containerWidth - width) / 2;
      top = 0;
    }

    setImgLayout({ width, height, left, top, naturalWidth, naturalHeight });
  }, []);

  // ── img 事件：每当 MJPEG 接收到一帧渲染完毕时计算一次 FPS ──────
  const handleImgLoad = useCallback((event: React.SyntheticEvent<HTMLImageElement>) => {
    if (event.currentTarget !== imgRef.current || !hasCurrentStreamFrame(event.currentTarget)) return;
    const source = event.currentTarget.getAttribute("src") ?? "";
    if (!source.startsWith("/web/") && !source.startsWith("blob:")) return;
    setLoadedStreamUrl(source);
    setFailedStreamUrl("");
    frameCount.current += 1;
    const now     = Date.now();
    const elapsed = now - lastFpsTs.current;
    if (elapsed >= 1000) {
      setFps(Math.round((frameCount.current * 1000) / elapsed));
      frameCount.current = 0;
      lastFpsTs.current  = now;
    }
    updateImageLayout();
  }, [updateImageLayout]);

  // 监听容器大小改变重新计算缩放
  useEffect(() => {
    if (!viewportRef.current) return;
    const observer = new ResizeObserver(() => {
      updateImageLayout();
    });
    observer.observe(viewportRef.current);
    return () => observer.disconnect();
  }, [updateImageLayout]);

  // ── 初始化 ─────────────────────────────────────────────────────
  useEffect(() => {
    if (!connected) {
      fetchTargets();
    }

    // 未连接时每 3 秒轮询检测一次可用设备以实现无感直连
    const interval = setInterval(() => {
      if (!connected) {
        fetchTargets();
      }
    }, 3000);

    return () => {
      clearInterval(interval);
    };
  }, [connected, fetchTargets]);

  const selectedTarget = targets.find((t) => t.target === selectedUdid);
  const platform = selectedTarget?.platform ?? "ios";
  const selectedTargetKey = selectedTarget?.targetKey ?? null;
  const inspectSession = getInspectSession(selectedTargetKey);
  const overlayMode = inspectSession?.overlayMode ?? "none";
  const selectedNodeId = inspectSession?.selectedNodeId ?? null;
  const hoveredNodeId = inspectSession?.hoveredNodeId ?? null;

  const streamActive = connected && Boolean(selectedUdid) && previewVisible;
  const streamUrl = streamActive
    ? streamImageUrl({ platform, target: selectedUdid!, fps: targetFps, connectTime })
    : "";

  const setStreamImageRef = useCallback((image: HTMLImageElement | null) => {
    if (imgRef.current && imgRef.current !== image) releaseStreamImage(imgRef.current);
    imgRef.current = image;
    if (image) attachStreamImage(image, streamUrl);
  }, [streamUrl]);

  const hasFrame = streamActive && loadedStreamUrl === streamUrl;
  const previewState = !connected || !selectedUdid ? "offline" : !previewVisible ? "paused" : failedStreamUrl === streamUrl ? "error" : hasFrame ? "live" : "connecting";
  useEffect(() => {
    const image = imgRef.current;
    if (!streamUrl || !image) return;
    return observeFirstStreamFrame(image, () => {
      if (imgRef.current !== image || image.getAttribute("src") !== streamUrl) return;
      setLoadedStreamUrl(streamUrl);
      updateImageLayout();
    });
  }, [streamUrl, updateImageLayout]);

  // Sync to global context
  useEffect(() => {
    if (selectedTarget) {
      registerStream({
        nodeId,
        udid: selectedTarget.target,
        name: selectedTarget.name,
        platform: selectedTarget.platform,
        scope: selectedTarget.scope,
        kind: selectedTarget.kind,
        source: selectedTarget.source,
        targetKey: selectedTarget.targetKey
      });
      if (selectedTarget.targetKey) setFocusedInspectTarget(selectedTarget.targetKey, nodeId);
    }
    return () => {
      unregisterStream(nodeId);
    };
  }, [nodeId, selectedTarget, registerStream, unregisterStream, setFocusedInspectTarget]);

  // ── 自动加载节点层级数据 ───────────────────────────────────────────
  useEffect(() => {
    if (streamActive && overlayMode !== "none" && selectedTarget?.targetKey) {
      if (!inspectSession?.scene || inspectSession.stale) {
        refreshInspectSession(selectedTarget.targetKey, "overlayEnabled").catch(() => {});
      }
    }
  }, [streamActive, overlayMode, selectedTarget, inspectSession?.scene, inspectSession?.stale, refreshInspectSession]);

  // ─── 计算需要渲染的节点 (按面积从大到小排序，确保小元素层叠在顶部易于交互) ─────────────────────
  const flatNodes = inspectSession?.scene?.nodes ?? [];

  // 获取逻辑屏幕宽高以抵消 Retina 缩放倍率的偏差 (iPhone 17等一般为 @3x)
  const rootNode = flatNodes[0];
  const deviceWidth = rootNode?.frame?.width || 390;
  const deviceHeight = rootNode?.frame?.height || 844;

  const nodesToRender = deriveOverlayNodes(flatNodes, overlayMode);

  const sortedNodes = [...nodesToRender].sort((a, b) => {
    const areaA = (a.frame?.width || 0) * (a.frame?.height || 0);
    const areaB = (b.frame?.width || 0) * (b.frame?.height || 0);
    return areaB - areaA;
  });

  return (
    <section
      className="rhine-stream-panel"
      aria-label="设备实时画面流"
      data-preview-state={previewState}
      onClick={() => setFocusedNodeId(nodeId)}
      onMouseEnter={() => setFocusedNodeId(nodeId)}
    >
      <header className="rhine-stream-header">
        <Inline gap={2} className="rhine-stream-identity"><Smartphone size={18} aria-hidden="true" /><Text as="h2" variant="heading">设备预览</Text>
          <Badge tone={previewState === "error" ? "error" : hasFrame ? "success" : "neutral"}>
            {previewState === "paused" ? "预览已暂停" : previewState === "error" ? "读取失败" : previewState === "connecting" ? "连接中" : hasFrame ? "LIVE" : "离线"}
          </Badge>
        </Inline>
        <Inline gap={1} className="rhine-stream-header-actions">
          <Button variant="quiet" aria-label="刷新设备列表" busy={refreshing} busyLabel="正在刷新设备列表" onClick={() => { void handleRefresh(); }}><Icon name="refresh" /></Button>
          <Popover title="预览设置" trigger={<IconButton label={`预览设置，目标帧率 ${targetFps} FPS`} icon="settings" />}>
            <Select label="目标帧率" value={targetFps} onChange={(event) => setTargetFps(Number(event.target.value))}>
              {[1, 5, 15, 30, 60, 120].map((value) => <option key={value} value={value}>{value} FPS</option>)}
            </Select>
          </Popover>
          {headerActions}
        </Inline>
      </header>
      <div className="rhine-stream-controls">
        <Select className="rhine-stream-target" label="调试设备" value={selectedUdid ?? ""} onChange={(event) => {
          const target = event.target.value;
          setSelectedUdid(target);
          const nextTarget = targets.find((item) => item.target === target);
          if (nextTarget?.targetKey) setFocusedInspectTarget(nextTarget.targetKey, nodeId);
        }}>
          {!targets.length && <option value="">未发现可用设备</option>}
          {targets.map((target) => <option key={target.id} value={target.target}>[{target.platform.toUpperCase()}] {target.name}</option>)}
        </Select>
        <SegmentedControl label="叠加层" value={overlayMode} items={[{ value: "none", label: "无" }, { value: "view", label: "视图" }, { value: "ax", label: "AX" }]} onValueChange={(value) => {
          if (!selectedTargetKey) return;
          const mode = value as "none" | "view" | "ax";
          setInspectOverlayMode(selectedTargetKey, mode);
          if (mode !== "none" && (!inspectSession?.scene || inspectSession.stale)) {
            refreshInspectSession(selectedTargetKey, "overlayEnabled").catch(() => {});
          }
        }} />
      </div>
      {streamUrl && failedStreamUrl === streamUrl && <div className="rhine-stream-feedback"><Notice tone="error" title="画面读取失败" action={<Button variant="secondary" onClick={() => { setFailedStreamUrl(""); setConnectTime((previous) => Math.max(Date.now(), previous + 1)); }}>重试画面</Button>}>检查设备连接后重试；设备选择和叠加层保留。</Notice></div>}

      {/* ── 画面视口 ── */}
      <div
        className="rhine-stream-viewport"
        ref={viewportRef}
        style={{ position: "relative" }}
      >
        {streamActive ? (
          <>
            <img
              key={streamUrl}
              ref={setStreamImageRef}
              src={streamUrl}
              alt="live simulator stream"
              onLoad={handleImgLoad}
              onError={(event) => { if (event.currentTarget === imgRef.current && event.currentTarget.getAttribute("src") === streamUrl) setFailedStreamUrl(streamUrl); }}
              style={imgLayout ? {
                position: "absolute",
                left: imgLayout.left,
                top: imgLayout.top,
                width: imgLayout.width,
                height: imgLayout.height,
                objectFit: "fill",
                display: "block",
              } : {
                position: "absolute",
                inset: 0,
                width: "100%",
                height: "100%",
                objectFit: "contain",
                display: "block",
              }}
            />
            {/* ── Overlay Layers Mapping ── */}
            {imgLayout && overlayMode !== "none" && (
              <div
                style={{
                  position: "absolute",
                  left: imgLayout.left,
                  top: imgLayout.top,
                  width: imgLayout.width,
                  height: imgLayout.height,
                  pointerEvents: "none",
                  zIndex: 2,
                }}
              >
                {sortedNodes.map((node) => {
                  if (!node.frame) return null;
                  const x = (node.frame.x / deviceWidth) * imgLayout.width;
                  const y = (node.frame.y / deviceHeight) * imgLayout.height;
                  const w = (node.frame.width / deviceWidth) * imgLayout.width;
                  const h = (node.frame.height / deviceHeight) * imgLayout.height;

                  const isSelected = selectedNodeId === node.id;
                  const isHovered = hoveredNodeId === node.id;

                  return (
                    <div
                      key={node.id}
                      className="rhine-stream-overlay-node"
                      data-selected={isSelected}
                      data-hovered={isHovered}
                      data-node-id={node.id}
                      role="button"
                      tabIndex={0}
                      aria-label={`选择 ${node.name || node.type || node.className || "Unknown"}`}
                      aria-pressed={isSelected}
                      onKeyDown={(event) => {
                        if ((event.key === "Enter" || event.key === " ") && selectedTargetKey) {
                          event.preventDefault(); event.stopPropagation();
                          selectInspectNode(selectedTargetKey, node.id);
                        }
                      }}
                      style={{
                        position: "absolute",
                        left: x,
                        top: y,
                        width: w,
                        height: h,
                        pointerEvents: "auto",
                      }}
                      onMouseEnter={() => selectedTargetKey && hoverInspectNode(selectedTargetKey, node.id)}
                      onMouseLeave={() => selectedTargetKey && hoverInspectNode(selectedTargetKey, null)}
                      onClick={(e) => {
                        e.stopPropagation();
                        if (!selectedTargetKey) return;
                        const rect = e.currentTarget.parentElement?.getBoundingClientRect();
                        if (rect) {
                          const x = ((e.clientX - rect.left) / rect.width) * deviceWidth;
                          const y = ((e.clientY - rect.top) / rect.height) * deviceHeight;
                          const hit = hitTestHierarchyNode({
                            nodes: flatNodes,
                            mode: overlayMode,
                            point: { x, y },
                            selectedNodeId,
                          });
                          selectInspectNode(selectedTargetKey, hit.nodeId || node.id);
                          return;
                        }
                        selectInspectNode(selectedTargetKey, node.id);
                      }}
                      title={`${node.type || node.className || 'Unknown'} (${node.frame.width.toFixed(0)}x${node.frame.height.toFixed(0)})`}
                    />
                  );
                })}
              </div>
            )}
          </>
        ) : (
          /* 未连接 */
          <div className="rhine-stream-offline">
            <WifiOff size={28} aria-hidden="true" />
            <span>{previewState === "paused" ? "预览已暂停，显示后自动恢复" : "等待可用设备"}</span>
          </div>
        )}
      </div>

    </section>
  );
}
