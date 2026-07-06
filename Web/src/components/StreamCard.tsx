import React, { useState, useEffect, useCallback, useRef } from "react";
import { Tag, Button, Select, message, Radio } from "antd";
import { Smartphone, Wifi, WifiOff, RefreshCw } from "lucide-react";

import { useAppContext } from "../AppContext";
import { filterEffectivelyVisibleNodes, findDescendantAtPoint } from "../hierarchyVisibility";
import {
  createGestureSession,
  finishGestureSession,
  longPressFromSession,
  LONG_PRESS_THRESHOLD_MS,
  mapPointerToDevicePoint,
  webHostInputQueryForGesture,
  type DevicePoint,
  type StreamGestureInput,
  type StreamGestureSession,
} from "../streamGestureModel";

// ── 类型 ───────────────────────────────────────────────────────
interface SimTarget {
  id: string;
  target: string;
  name: string;
  platform: "ios" | "android" | "harmony";
  ready: boolean;
  runtime?: string;
}

export function StreamCard({ nodeId }: { nodeId: string }) {
  const [connected, setConnected]     = useState(false);
  const [connectTime, setConnectTime] = useState(0);
  const [targets,   setTargets]       = useState<SimTarget[]>([]);
  const [selectedUdid, setSelectedUdid] = useState<string | null>(null);
  const [fps,    setFps]              = useState(0);
  const [targetFps, setTargetFps]     = useState(15);
  const [refreshing, setRefreshing]   = useState(false);
  const [overlayMode, setOverlayMode] = useState<"none" | "view" | "ax">("none");
  const [gestureStatus, setGestureStatus] = useState<string | null>(null);

  const frameCount    = useRef(0);
  const lastFpsTs     = useRef(Date.now());
  const hasConnectedRef = useRef(false);
  const gestureSessionRef = useRef<StreamGestureSession | null>(null);
  const gesturePointRef = useRef<DevicePoint | null>(null);
  const longPressTimerRef = useRef<number | null>(null);

  const imgRef = useRef<HTMLImageElement>(null);
  const viewportRef = useRef<HTMLDivElement>(null);
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
    selectedNodeId,
    setSelectedNodeId,
    hoveredNodeId,
    setHoveredNodeId,
    hierarchyScenes,
    fetchHierarchy
  } = useAppContext();

  // ── 获取设备列表 ───────────────────────────────────────────────
  const fetchTargets = useCallback(async () => {
    try {
      const res  = await fetch("/web/host-targets");
      const data = await res.json();
      if (data.ok || data.targets) {
        const booted: SimTarget[] = (data.targets ?? []).filter(
          (s: SimTarget) => s.ready
        );
        setTargets(booted);
        if (booted.length > 0) {
          const firstUdid = booted[0].target;
          setSelectedUdid((prev) => {
            if (!prev) return firstUdid;
            return prev;
          });
          // 仅在首次加载且未连接时自动连接到第一个已启动的模拟器
          if (!hasConnectedRef.current) {
            setConnected(true);
            setConnectTime(Date.now());
            hasConnectedRef.current = true;
          }
        }
      }
    } catch { /* 静默失败 */ }
  }, []);

  // ── 连接 / 断开 ────────────────────────────────────────────────
  const handleConnect = useCallback(async () => {
    if (!selectedUdid) { message.warning("请先选择一个活跃的调试设备"); return; }
    setConnectTime(Date.now());
    setConnected(true);
    message.success("画面流已成功连接（实时流模式）");
  }, [selectedUdid]);

  const handleDisconnect = useCallback(() => {
    setConnected(false);
    setFps(0);
    message.info("画面流已断开");
  }, []);

  const handleRefresh = useCallback(async () => {
    setRefreshing(true);
    await fetchTargets();
    const targetObj = targets.find(t => t.target === selectedUdid);
    if (connected && selectedUdid && targetObj) {
      try {
        await fetchHierarchy(selectedUdid, targetObj.platform);
      } catch { /* 静默失败 */ }
    }
    setRefreshing(false);
  }, [fetchTargets, connected, selectedUdid, targets, fetchHierarchy]);

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

    console.log("updateImageLayout details:", {
      containerWidth,
      containerHeight,
      naturalWidth,
      naturalHeight
    });

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

    console.log("Calculated layout:", { width, height, left, top });

    setImgLayout({ width, height, left, top, naturalWidth, naturalHeight });
  }, []);

  // ── img 事件：每当 MJPEG 接收到一帧渲染完毕时计算一次 FPS ──────
  const handleImgLoad = useCallback(() => {
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

  let streamUrl = "";
  if (connected && selectedUdid) {
    if (platform === "android") {
      streamUrl = `/web/android/mjpeg?udid=${selectedUdid}&fps=${targetFps}&t=${connectTime}`;
    } else if (platform === "harmony") {
      streamUrl = `/web/harmony/mjpeg?udid=${selectedUdid}&fps=${targetFps}&t=${connectTime}`;
    } else {
      streamUrl = `/web/ios-simulator/mjpeg?udid=${selectedUdid}&fps=${targetFps}&t=${connectTime}`;
    }
  }

  // Sync to global context
  useEffect(() => {
    if (selectedTarget) {
      registerStream({
        nodeId,
        udid: selectedTarget.target,
        name: selectedTarget.name,
        platform: selectedTarget.platform
      });
    }
    return () => {
      unregisterStream(nodeId);
    };
  }, [nodeId, selectedTarget, registerStream, unregisterStream]);

  // ── 自动加载节点层级数据 ───────────────────────────────────────────
  useEffect(() => {
    if (connected && selectedUdid && overlayMode !== "none" && selectedTarget) {
      const existing = hierarchyScenes[selectedUdid];
      if (!existing || existing.length === 0) {
        fetchHierarchy(selectedUdid, selectedTarget.platform).catch(() => {});
      }
    }
  }, [connected, selectedUdid, overlayMode, selectedTarget, hierarchyScenes, fetchHierarchy]);

  const clearLongPressTimer = useCallback(() => {
    if (longPressTimerRef.current != null) {
      window.clearTimeout(longPressTimerRef.current);
      longPressTimerRef.current = null;
    }
  }, []);

  useEffect(() => clearLongPressTimer, [clearLongPressTimer]);

  const pointFromPointerEvent = useCallback((event: React.PointerEvent<HTMLDivElement>) => {
    if (!viewportRef.current || !imgLayout) return null;
    return mapPointerToDevicePoint(
      { clientX: event.clientX, clientY: event.clientY },
      viewportRef.current.getBoundingClientRect(),
      imgLayout,
    );
  }, [imgLayout]);

  const sendGestureInput = useCallback(async (gesture: StreamGestureInput) => {
    if (!selectedUdid || !selectedTarget) return;
    const query = webHostInputQueryForGesture({
      platform: selectedTarget.platform,
      target: selectedUdid,
      gestureType: gesture.type,
    });
    if (!query) {
      setGestureStatus(`${gesture.type} 当前平台暂不支持`);
      return;
    }
    setGestureStatus(`${gesture.type} 发送中...`);
    try {
      const res = await fetch(`/web/host-input?${query}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(gesture),
      });
      const body = await res.json().catch(() => null);
      if (!res.ok || body?.ok === false) {
        throw new Error(body?.error?.message || body?.message || `HTTP ${res.status}`);
      }
      setGestureStatus(formatGestureStatus(gesture));
      await fetchHierarchy(selectedUdid, selectedTarget.platform);
    } catch (error) {
      setGestureStatus(`输入失败：${(error as Error).message}`);
    }
  }, [fetchHierarchy, selectedTarget, selectedUdid]);

  const handleViewportPointerDown = useCallback((event: React.PointerEvent<HTMLDivElement>) => {
    if (!connected || !selectedUdid || overlayMode !== "none") return;
    const point = pointFromPointerEvent(event);
    if (!point) {
      setGestureStatus("未命中设备画面");
      return;
    }
    event.preventDefault();
    event.currentTarget.setPointerCapture(event.pointerId);
    const session = createGestureSession({
      pointerId: event.pointerId,
      point,
      startedAt: performance.now(),
    });
    gestureSessionRef.current = session;
    gesturePointRef.current = point;
    clearLongPressTimer();
    longPressTimerRef.current = window.setTimeout(() => {
      const current = gestureSessionRef.current;
      if (!current || current.pointerId !== event.pointerId) return;
      const gesture = longPressFromSession(current, {
        now: performance.now(),
        currentPoint: gesturePointRef.current,
      });
      if (gesture) {
        void sendGestureInput(gesture);
      }
    }, LONG_PRESS_THRESHOLD_MS);
  }, [clearLongPressTimer, connected, overlayMode, pointFromPointerEvent, selectedUdid, sendGestureInput]);

  const handleViewportPointerMove = useCallback((event: React.PointerEvent<HTMLDivElement>) => {
    const session = gestureSessionRef.current;
    if (!session || session.pointerId !== event.pointerId) return;
    gesturePointRef.current = pointFromPointerEvent(event);
  }, [pointFromPointerEvent]);

  const handleViewportPointerUp = useCallback((event: React.PointerEvent<HTMLDivElement>) => {
    const session = gestureSessionRef.current;
    if (!session || session.pointerId !== event.pointerId) return;
    event.preventDefault();
    clearLongPressTimer();
    const point = pointFromPointerEvent(event);
    const gesture = finishGestureSession(session, {
      point,
      endedAt: performance.now(),
    });
    gestureSessionRef.current = null;
    gesturePointRef.current = null;
    if (event.currentTarget.hasPointerCapture(event.pointerId)) {
      event.currentTarget.releasePointerCapture(event.pointerId);
    }
    if (gesture) {
      void sendGestureInput(gesture);
    }
  }, [clearLongPressTimer, pointFromPointerEvent, sendGestureInput]);

  const handleViewportPointerCancel = useCallback((event: React.PointerEvent<HTMLDivElement>) => {
    const session = gestureSessionRef.current;
    if (!session || session.pointerId !== event.pointerId) return;
    clearLongPressTimer();
    gestureSessionRef.current = null;
    gesturePointRef.current = null;
  }, [clearLongPressTimer]);

  // ─── 计算需要渲染的节点 (按面积从大到小排序，确保小元素层叠在顶部易于交互) ─────────────────────
  const flatNodes = selectedUdid ? (hierarchyScenes[selectedUdid] || []) : [];
  const visibleNodes = filterEffectivelyVisibleNodes(flatNodes);

  // 获取逻辑屏幕宽高以抵消 Retina 缩放倍率的偏差 (iPhone 17等一般为 @3x)
  const rootNode = flatNodes[0];
  const deviceWidth = rootNode?.frame?.width || 390;
  const deviceHeight = rootNode?.frame?.height || 844;

  const nodesToRender = visibleNodes.filter((node) => {
    if (overlayMode === "none") return false;
    if (overlayMode === "ax") {
      const identifier = node.view?.accessibilityIdentifier || "";
      const axText = node.view?.accessibilityLabel || node.style?.text || "";
      return axText !== "" || identifier !== "" || node.interactive;
    }
    return true; // view mode
  });

  const sortedNodes = [...nodesToRender].sort((a, b) => {
    const areaA = (a.frame?.width || 0) * (a.frame?.height || 0);
    const areaB = (b.frame?.width || 0) * (b.frame?.height || 0);
    return areaB - areaA;
  });

  return (
    <div
      className="stream-card"
      onClick={() => setFocusedNodeId(nodeId)}
      onMouseEnter={() => setFocusedNodeId(nodeId)}
    >
      {/* ── Header ── */}
      <div className="stream-card-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div className="stream-card-title">
          <Smartphone size={12} color="#64748b" />
          设备实时画面流
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 8, paddingRight: 100 }}>
          <Radio.Group
            size="small"
            value={overlayMode}
            onChange={(e) => setOverlayMode(e.target.value)}
            optionType="button"
            buttonStyle="solid"
          >
            <Radio.Button value="none" style={{ fontSize: 10, padding: "0 6px", height: 20, lineHeight: "18px" }}>无</Radio.Button>
            <Radio.Button value="view" style={{ fontSize: 10, padding: "0 6px", height: 20, lineHeight: "18px" }}>视图</Radio.Button>
            <Radio.Button value="ax" style={{ fontSize: 10, padding: "0 6px", height: 20, lineHeight: "18px" }}>AX</Radio.Button>
          </Radio.Group>
          <Tag
            color={connected ? "success" : "default"}
            style={{ fontSize: 9, lineHeight: "14px", borderRadius: 20, margin: 0, padding: "0 6px" }}
          >
            {connected ? "● LIVE" : "○ 离线"}
          </Tag>
        </div>
      </div>

      {/* ── 设备选择 ── */}
      <div className="stream-device-bar">
        <Select
          size="small"
          style={{ flex: 1 }}
          placeholder="选择调试设备..."
          value={selectedUdid}
          onChange={setSelectedUdid}
          options={targets.map((t) => ({ value: t.target, label: `[${t.platform.toUpperCase()}] ${t.name}` }))}
          notFoundContent={<span style={{ fontSize: 11, color: "rgba(255,255,255,0.25)" }}>未发现可用设备</span>}
        />
        <Select
          size="small"
          style={{ width: 90 }}
          value={targetFps}
          onChange={setTargetFps}
          options={[
            { value: 1, label: "1 FPS" },
            { value: 5, label: "5 FPS" },
            { value: 15, label: "15 FPS" },
            { value: 30, label: "30 FPS" },
            { value: 60, label: "60 FPS" },
            { value: 120, label: "120 FPS" },
          ]}
        />
        <button className="stream-icon-btn" title="刷新设备列表" onClick={handleRefresh}>
          <RefreshCw size={10} className={refreshing ? "spin" : ""} />
        </button>
      </div>

      {/* ── 画面视口 ── */}
      <div
        className="stream-viewport"
        ref={viewportRef}
        style={{ position: "relative" }}
        onPointerDown={handleViewportPointerDown}
        onPointerMove={handleViewportPointerMove}
        onPointerUp={handleViewportPointerUp}
        onPointerCancel={handleViewportPointerCancel}
      >
        {connected && selectedUdid ? (
          <>
            <img
              ref={imgRef}
              src={streamUrl}
              alt="live simulator stream"
              onLoad={handleImgLoad}
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
                      style={{
                        position: "absolute",
                        left: x,
                        top: y,
                        width: w,
                        height: h,
                        border: isSelected
                          ? "2px solid #1677ff"
                          : isHovered
                          ? "1.5px dashed #40a9ff"
                          : "1px solid rgba(22, 119, 255, 0.25)",
                        background: isSelected
                          ? "rgba(22, 119, 255, 0.15)"
                          : isHovered
                          ? "rgba(64, 169, 255, 0.1)"
                          : "transparent",
                        pointerEvents: "auto",
                        cursor: "pointer",
                      }}
                      onMouseEnter={() => setHoveredNodeId(node.id)}
                      onMouseLeave={() => setHoveredNodeId(null)}
                      onClick={(e) => {
                        e.stopPropagation();
                        if (selectedNodeId === node.id) {
                          const rect = e.currentTarget.parentElement?.getBoundingClientRect();
                          if (rect) {
                            const x = ((e.clientX - rect.left) / imgLayout.width) * deviceWidth;
                            const y = ((e.clientY - rect.top) / imgLayout.height) * deviceHeight;
                            const child = findDescendantAtPoint(nodesToRender, node.id, x, y);
                            setSelectedNodeId(child?.id || node.id);
                            return;
                          }
                        }
                        setSelectedNodeId(node.id);
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
          <div className="stream-offline-view">
            <WifiOff size={28} color="rgba(255,255,255,0.1)" />
            <span>选择模拟器后点击连接</span>
          </div>
        )}
      </div>

      {/* ── 控制栏 ── */}
      <div className="stream-controls">
        <div className="stream-metrics">
          <span className="metric">
            <span className="metric-val" style={{ color: fps >= 3 ? "#52c41a" : connected ? "#faad14" : undefined }}>
              {connected ? (fps || "…") : "—"}
            </span>
            <span className="metric-label">FPS</span>
          </span>
          <div className="metric-divider" />
          <span className="metric">
            <span className="metric-val" style={{ color: "#1677ff" }}>19421</span>
            <span className="metric-label">端口</span>
          </span>
          {gestureStatus && (
            <>
              <div className="metric-divider" />
              <span className="metric stream-gesture-status">
                <span className="metric-val">{gestureStatus}</span>
              </span>
            </>
          )}
        </div>

        <div className="stream-actions">
          <Button
            size="small"
            type={connected ? "default" : "primary"}
            danger={connected}
            icon={connected ? <WifiOff size={10} /> : <Wifi size={10} />}
            onClick={connected ? handleDisconnect : handleConnect}
            style={{ fontSize: 10, height: 22, padding: "0 8px", borderRadius: 5, display: "flex", alignItems: "center", gap: 4 }}
          >
            {connected ? "断开" : "连接"}
          </Button>
        </div>
      </div>
    </div>
  );
}

function formatGestureStatus(gesture: StreamGestureInput) {
  if (gesture.type === "swipe") {
    return `swipe ${gesture.startX},${gesture.startY} → ${gesture.endX},${gesture.endY}`;
  }
  return `${gesture.type} ${gesture.x},${gesture.y}`;
}
