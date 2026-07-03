import React, { useState, useCallback, useRef, useEffect } from "react";
import { ConfigProvider, theme } from "antd";
import { StreamCard } from "./components/StreamCard";
import { XcodeCard } from "./components/XcodeCard";
import { VlmCard } from "./components/VlmCard";
import { TargetCard } from "./components/TargetCard";
import { TimelineCard } from "./components/TimelineCard";
import { DoctorCard } from "./components/DoctorCard";
import { SimulatorCard } from "./components/SimulatorCard";
import { RecorderCard } from "./components/RecorderCard";
import { HdcCard } from "./components/HdcCard";
import { InspectorCard } from "./components/InspectorCard";
import {
  Tv,
  Wrench,
  BrainCircuit,
  Target,
  History,
  Activity,
  Smartphone,
  Video,
  Layers,
  Search,
  RotateCcw,
  Columns,
  Rows,
  X
} from "lucide-react";
import { AppContextProvider } from "./AppContext";
import "./styles.css";

// ─── 布局树类型 ──────────────────────────────────────────────────────────────
export type CardType =
  | "stream"
  | "xcode"
  | "vlm"
  | "target"
  | "timeline"
  | "doctor"
  | "simulator"
  | "recorder"
  | "hdc"
  | "inspector";

export type LeafNode = {
  kind: "leaf";
  id: string;
  card: CardType | null; // null = 空槽
};

export type SplitNode = {
  kind: "split";
  id: string;
  direction: "v" | "h"; // v = 左右分割竖线, h = 上下分割横线
  ratio: number;         // first 子节点占的比例 (0~1)
  first: LayoutNode;
  second: LayoutNode;
};

export type LayoutNode = LeafNode | SplitNode;

// ─── ID 生成 ─────────────────────────────────────────────────────────────────
let _id = 0;
function nextId() {
  return String(++_id);
}
function setMaxId(root: LayoutNode) {
  const parseId = (id: string) => parseInt(id, 10) || 0;
  if (root.kind === "leaf") {
    _id = Math.max(_id, parseId(root.id));
  } else {
    _id = Math.max(_id, parseId(root.id));
    setMaxId(root.first);
    setMaxId(root.second);
  }
}

// ─── 初始状态：优先从 localStorage 加载，否则 StreamCard 独占全屏 ───────────────────────────
function makeInitialRoot(): LayoutNode {
  return { kind: "leaf", id: nextId(), card: "stream" };
}

function loadInitialRoot(): LayoutNode {
  try {
    const saved = localStorage.getItem("triton-layout");
    if (saved) {
      const parsed = JSON.parse(saved);
      if (parsed && typeof parsed === 'object' && parsed.id) {
        setMaxId(parsed as LayoutNode);
        return parsed as LayoutNode;
      }
    }
  } catch (e) {
    console.error("Failed to parse saved layout", e);
  }
  return makeInitialRoot();
}

// ─── 工具：按 ID 更新树中某个节点 ────────────────────────────────────────────
function updateNode(root: LayoutNode, id: string, fn: (n: LayoutNode) => LayoutNode): LayoutNode {
  if (root.id === id) return fn(root);
  if (root.kind === "split") {
    return {
      ...root,
      first: updateNode(root.first, id, fn),
      second: updateNode(root.second, id, fn),
    };
  }
  return root;
}

// ─── 工具：删除某个叶子节点（把其兄弟提升） ─────────────────────────────────
function removeLeaf(root: LayoutNode, id: string): LayoutNode | null {
  if (root.kind === "leaf") return root.id === id ? null : root;
  const first = removeLeaf(root.first, id);
  const second = removeLeaf(root.second, id);
  if (first === null) return second;
  if (second === null) return first;
  return { ...root, first, second };
}

// ─── 工具：分割某个叶子节点 ──────────────────────────────────────────────────
function splitLeaf(root: LayoutNode, id: string, dir: "v" | "h"): LayoutNode {
  return updateNode(root, id, (node) => {
    if (node.kind !== "leaf") return node;
    return {
      kind: "split",
      id: nextId(),
      direction: dir,
      ratio: 0.5,
      first: node, // 原来的卡片留在 first
      second: { kind: "leaf", id: nextId(), card: null }, // 新空槽在 second
    };
  });
}

// ─── 卡片注册配置表 ──────────────────────────────────────────────────────────
interface CardConfig {
  type: CardType;
  name: string;
  icon: React.ReactNode;
  description: string;
  color: string;
}

const CARD_CONFIGS: CardConfig[] = [
  { type: "stream",    name: "设备实时画面流", icon: <Tv size={16} />,        description: "实时获取模拟器或真机画面并进行手势控制", color: "#1677ff" },
  { type: "xcode",     name: "Xcode 构建控制", icon: <Wrench size={16} />,    description: "一件构建、测试并一键部署工程到指定模拟器", color: "#52c41a" },
  { type: "vlm",       name: "本地 AI 智能视觉", icon: <BrainCircuit size={16} />, description: "结合本地 MLX Qwen VLM 引擎进行辅助定位验证", color: "#722ed1" },
  { type: "target",    name: "目标探测器",     icon: <Target size={16} />,      description: "发现、解析并过滤当前活动调试靶目标", color: "#faad14" },
  { type: "timeline",   name: "动作时间线",     icon: <History size={16} />,     description: "回放、分析历史回放和断言过程中的时间痕迹", color: "#13c2c2" },
  { type: "doctor",     name: "环境自检诊断",   icon: <Activity size={16} />,    description: "自检端口、模拟器、SDK等并给出修复方案", color: "#eb2f96" },
  { type: "simulator",  name: "模拟器实例管理器", icon: <Smartphone size={16} />, description: "管理 iOS 模拟器实例的启动、关闭和清理", color: "#2f54eb" },
  { type: "recorder",   name: "用例录制面板",   icon: <Video size={16} />,       description: "录制操作并编译为 .tritonplan 测试用例", color: "#fa8c16" },
  { type: "hdc",        name: "桥接控制器",     icon: <Layers size={16} />,      description: "管理 Android / 鸿蒙等底座的底层调试桥接", color: "#fa541c" },
  { type: "inspector",  name: "界面 AX 审查器", icon: <Search size={16} />,      description: "树级审查、属性观察和无障碍辅助诊断工具", color: "#096dd9" },
];

// ─── 渲染卡片内容 ─────────────────────────────────────────────────────────────
function renderCardContent(card: CardType, nodeId: string): React.ReactNode {
  switch (card) {
    case "stream":    return <StreamCard nodeId={nodeId} />;
    case "xcode":     return <XcodeCard />;
    case "vlm":       return <VlmCard />;
    case "target":    return <TargetCard />;
    case "timeline":   return <TimelineCard />;
    case "doctor":     return <DoctorCard />;
    case "simulator":  return <SimulatorCard />;
    case "recorder":   return <RecorderCard />;
    case "hdc":        return <HdcCard />;
    case "inspector":  return <InspectorCard nodeId={nodeId} />;
  }
}

// ─── Pane 工具栏（悬停可见） ──────────────────────────────────────────────────
interface PaneToolbarProps {
  onSplitV: () => void;
  onSplitH: () => void;
  onUnload: () => void;
  onClose?: () => void;
}

function PaneToolbar({ onSplitV, onSplitH, onUnload, onClose }: PaneToolbarProps) {
  return (
    <div className="pane-toolbar">
      <button className="pane-btn" title="左右分割" onClick={onSplitV}>
        <Columns size={11} />
      </button>
      <button className="pane-btn" title="上下分割" onClick={onSplitH}>
        <Rows size={11} />
      </button>
      <button className="pane-btn" title="更换组件" onClick={onUnload}>
        <RotateCcw size={11} />
      </button>
      {onClose && (
        <button className="pane-btn close" title="关闭" onClick={onClose}>
          <X size={11} />
        </button>
      )}
    </div>
  );
}

// ─── 递归渲染树 ───────────────────────────────────────────────────────────────
interface NodeRendererProps {
  node: LayoutNode;
  onSplit: (id: string, dir: "v" | "h") => void;
  onClose: (id: string) => void;
  onUnload: (id: string) => void;
  onSelectCard: (id: string, card: CardType) => void;
  onDividerDrag: (id: string, delta: number, dir: "v" | "h") => void;
  isRoot: boolean;
}

function NodeRenderer({
  node,
  onSplit,
  onClose,
  onUnload,
  onSelectCard,
  onDividerDrag,
  isRoot
}: NodeRendererProps) {
  const dividerRef = useRef<HTMLDivElement>(null);

  if (node.kind === "leaf") {
    const hasCard = node.card !== null;
    return (
      <div className="leaf-node">
        {hasCard ? (
          <div className="filled-pane">
            <PaneToolbar
              onSplitV={() => onSplit(node.id, "v")}
              onSplitH={() => onSplit(node.id, "h")}
              onUnload={() => onUnload(node.id)}
              onClose={isRoot ? undefined : () => onClose(node.id)}
            />
            {renderCardContent(node.card!, node.id)}
          </div>
        ) : (
          /* 空插槽：精美的大网格列表，点击可挑选卡片 */
          <div className="empty-pane-picker">
            <div className="picker-header">
              <span className="picker-title">选择插槽组件</span>
              <span className="picker-subtitle">请选择需要在当前窗格中载入的功能卡片</span>
            </div>
            <div className="picker-grid">
              {CARD_CONFIGS.map((cfg) => {
                return (
                  <div
                    key={cfg.type}
                    className="picker-item"
                    onClick={() => onSelectCard(node.id, cfg.type)}
                  >
                    <div
                      className="picker-item-icon"
                      style={{
                        color: cfg.color,
                        borderColor: `${cfg.color}33`,
                      }}
                    >
                      {cfg.icon}
                    </div>
                    <div className="picker-item-info">
                      <span className="picker-item-name">
                        {cfg.name}
                      </span>
                      <span className="picker-item-desc">
                        {cfg.description}
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>
            {!isRoot && (
              <button className="picker-cancel-btn" onClick={() => onClose(node.id)}>
                关闭当前窗格 ✕
              </button>
            )}
          </div>
        )}
      </div>
    );
  }

  // Split 节点
  const { direction, ratio, first, second } = node;
  const isVertical = direction === "v"; // 竖分割线 → 左右布局

  const handleDividerMouseDown = (e: React.MouseEvent) => {
    e.preventDefault();
    const startPos = isVertical ? e.clientX : e.clientY;
    const container = dividerRef.current?.parentElement;
    if (!container) return;
    const totalSize = isVertical ? container.offsetWidth : container.offsetHeight;

    const onMove = (me: MouseEvent) => {
      const currentPos = isVertical ? me.clientX : me.clientY;
      const delta = (currentPos - startPos) / totalSize;
      onDividerDrag(node.id, delta, direction);
    };
    const onUp = () => {
      window.removeEventListener("mousemove", onMove);
      window.removeEventListener("mouseup", onUp);
    };
    window.addEventListener("mousemove", onMove);
    window.addEventListener("mouseup", onUp);
  };

  const firstStyle: React.CSSProperties = isVertical
    ? { width: `${ratio * 100}%`, minWidth: 0 }
    : { height: `${ratio * 100}%`, minHeight: 0 };
  const secondStyle: React.CSSProperties = isVertical
    ? { width: `${(1 - ratio) * 100}%`, minWidth: 0 }
    : { height: `${(1 - ratio) * 100}%`, minHeight: 0 };

  return (
    <div className={`split-node split-${isVertical ? "v" : "h"}`}>
      <div style={{ ...firstStyle, display: "flex", minWidth: 0, minHeight: 0 }}>
        <NodeRenderer
          node={first}
          onSplit={onSplit}
          onClose={onClose}
          onUnload={onUnload}
          onSelectCard={onSelectCard}
          onDividerDrag={onDividerDrag}
          isRoot={false}
        />
      </div>

      <div
        ref={dividerRef}
        className={`split-divider divider-${isVertical ? "v" : "h"}`}
        onMouseDown={handleDividerMouseDown}
      />

      <div style={{ ...secondStyle, display: "flex", minWidth: 0, minHeight: 0 }}>
        <NodeRenderer
          node={second}
          onSplit={onSplit}
          onClose={onClose}
          onUnload={onUnload}
          onSelectCard={onSelectCard}
          onDividerDrag={onDividerDrag}
          isRoot={false}
        />
      </div>
    </div>
  );
}

// ─── App ──────────────────────────────────────────────────────────────────────
export default function App() {
  const [root, setRoot] = useState<LayoutNode>(loadInitialRoot);

  useEffect(() => {
    localStorage.setItem("triton-layout", JSON.stringify(root));
  }, [root]);

  const handleSplit = useCallback((id: string, dir: "v" | "h") => {
    setRoot((prev) => splitLeaf(prev, id, dir));
  }, []);

  const handleClose = useCallback((id: string) => {
    setRoot((prev) => {
      const next = removeLeaf(prev, id);
      return next ?? makeInitialRoot();
    });
  }, []);

  const handleUnload = useCallback((id: string) => {
    setRoot((prev) =>
      updateNode(prev, id, (node) => {
        if (node.kind !== "leaf") return node;
        return { ...node, card: null };
      })
    );
  }, []);

  const handleSelectCard = useCallback((id: string, card: CardType) => {
    setRoot((prev) =>
      updateNode(prev, id, (node) => {
        if (node.kind !== "leaf") return node;
        return { ...node, card };
      })
    );
  }, []);

  const handleDividerDrag = useCallback((id: string, delta: number, dir: "v" | "h") => {
    setRoot((prev) =>
      updateNode(prev, id, (node) => {
        if (node.kind !== "split") return node;
        const newRatio = Math.min(0.9, Math.max(0.1, node.ratio + delta));
        return { ...node, ratio: newRatio };
      })
    );
  }, []);

  return (
    <AppContextProvider layoutRoot={root}>
      <ConfigProvider
        theme={{
          algorithm: theme.darkAlgorithm,
          token: {
            colorPrimary: "#1677ff",
            colorSuccess: "#52c41a",
            colorWarning: "#faad14",
            colorError: "#ff4d4f",
            borderRadius: 8,
            fontSize: 12,
          },
        }}
      >
        <div className="triton-app">
          {/* ── Header ── */}
          <header className="triton-header">
            <div className="header-brand">
              <span className="header-logo">TRITON</span>
              <div className="header-divider" />
              <span className="header-subtitle">开发者控制台</span>
            </div>
            <div className="header-meta">
              <div className="status-pill">
                <div className="status-dot" />
                服务运行中 · 127.0.0.1:19421
              </div>
            </div>
          </header>

          {/* ── Canvas ── */}
          <div className="canvas-root">
            <NodeRenderer
              node={root}
              onSplit={handleSplit}
              onClose={handleClose}
              onUnload={handleUnload}
              onSelectCard={handleSelectCard}
              onDividerDrag={handleDividerDrag}
              isRoot={true}
            />
          </div>
        </div>
      </ConfigProvider>
    </AppContextProvider>
  );
}
