import React, { useState, useEffect, useCallback, useRef } from "react";
import { Tag, Button, Select, message } from "antd";
import { Smartphone, Wifi, WifiOff, RefreshCw } from "lucide-react";

// ── 类型 ───────────────────────────────────────────────────────
interface SimTarget {
  id: string;
  target: string;
  name: string;
  platform: "ios" | "android" | "harmony";
  ready: boolean;
  runtime?: string;
}

export function StreamCard() {
  const [connected, setConnected]     = useState(false);
  const [connectTime, setConnectTime] = useState(0);
  const [targets,   setTargets]       = useState<SimTarget[]>([]);
  const [selectedUdid, setSelectedUdid] = useState<string | null>(null);
  const [fps,    setFps]              = useState(0);
  const [targetFps, setTargetFps]     = useState(15);
  const [refreshing, setRefreshing]   = useState(false);

  const frameCount    = useRef(0);
  const lastFpsTs     = useRef(Date.now());
  const hasConnectedRef = useRef(false);

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
    setRefreshing(false);
  }, [fetchTargets]);

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
  }, []);

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

  return (
    <div className="stream-card">
      {/* ── Header ── */}
      <div className="stream-card-header">
        <div className="stream-card-title">
          <Smartphone size={12} color="#64748b" />
          设备实时画面流
        </div>
        <Tag
          color={connected ? "success" : "default"}
          style={{ fontSize: 9, lineHeight: "14px", borderRadius: 20, margin: 0, padding: "0 6px" }}
        >
          {connected ? "● LIVE" : "○ 离线"}
        </Tag>
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
      <div className="stream-viewport">
        {connected && selectedUdid ? (
          <img
            src={streamUrl}
            alt="live simulator stream"
            onLoad={handleImgLoad}
            style={{
              position: "absolute",
              inset: 0,
              width: "100%",
              height: "100%",
              objectFit: "contain",
              display: "block",
            }}
          />
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
