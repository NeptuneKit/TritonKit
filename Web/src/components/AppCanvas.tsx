import React, { useRef } from "react";
import {
  Activity,
  BrainCircuit,
  Columns,
  History,
  Layers,
  RotateCcw,
  Rows,
  Search,
  Smartphone,
  Target,
  Tv,
  Video,
  Wrench,
  X,
} from "lucide-react";
import type { CardType, LayoutNode } from "../layoutModel";
import { DoctorCard } from "./DoctorCard";
import { HdcCard } from "./HdcCard";
import { InspectorCard } from "./InspectorCard";
import { RecorderCard } from "./RecorderCard";
import { SimulatorCard } from "./SimulatorCard";
import { StreamCard } from "./StreamCard";
import { TargetCard } from "./TargetCard";
import { TimelineCard } from "./TimelineCard";
import { VlmCard } from "./VlmCard";
import { XcodeCard } from "./XcodeCard";

interface CardConfig {
  type: CardType;
  name: string;
  icon: React.ReactNode;
  description: string;
  color: string;
}

const CARD_CONFIGS: CardConfig[] = [
  { type: "stream", name: "设备实时画面流", icon: <Tv size={16} />, description: "实时获取模拟器或真机画面并进行手势控制", color: "#1677ff" },
  { type: "xcode", name: "Xcode 构建控制", icon: <Wrench size={16} />, description: "一件构建、测试并一键部署工程到指定模拟器", color: "#52c41a" },
  { type: "vlm", name: "本地 AI 智能视觉", icon: <BrainCircuit size={16} />, description: "结合本地 MLX Qwen VLM 引擎进行辅助定位验证", color: "#722ed1" },
  { type: "target", name: "目标探测器", icon: <Target size={16} />, description: "发现、解析并过滤当前活动调试靶目标", color: "#faad14" },
  { type: "timeline", name: "动作时间线", icon: <History size={16} />, description: "回放、分析历史回放和断言过程中的时间痕迹", color: "#13c2c2" },
  { type: "doctor", name: "环境自检诊断", icon: <Activity size={16} />, description: "自检端口、模拟器、SDK等并给出修复方案", color: "#eb2f96" },
  { type: "simulator", name: "模拟器实例管理器", icon: <Smartphone size={16} />, description: "管理 iOS 模拟器实例的启动、关闭和清理", color: "#2f54eb" },
  { type: "recorder", name: "用例录制面板", icon: <Video size={16} />, description: "录制操作并编译为 .tritonplan 测试用例", color: "#fa8c16" },
  { type: "hdc", name: "桥接控制器", icon: <Layers size={16} />, description: "管理 Android / 鸿蒙等底座的底层调试桥接", color: "#fa541c" },
  { type: "inspector", name: "界面 AX 审查器", icon: <Search size={16} />, description: "树级审查、属性观察和无障碍辅助诊断工具", color: "#096dd9" },
];

function renderCardContent(card: CardType, nodeId: string): React.ReactNode {
  switch (card) {
    case "stream": return <StreamCard nodeId={nodeId} />;
    case "xcode": return <XcodeCard />;
    case "vlm": return <VlmCard />;
    case "target": return <TargetCard />;
    case "timeline": return <TimelineCard />;
    case "doctor": return <DoctorCard />;
    case "simulator": return <SimulatorCard />;
    case "recorder": return <RecorderCard />;
    case "hdc": return <HdcCard />;
    case "inspector": return <InspectorCard nodeId={nodeId} />;
  }
}

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

interface NodeRendererProps {
  node: LayoutNode;
  onSplit: (id: string, dir: "v" | "h") => void;
  onClose: (id: string) => void;
  onUnload: (id: string) => void;
  onSelectCard: (id: string, card: CardType) => void;
  onDividerDrag: (id: string, delta: number, dir: "v" | "h") => void;
  isRoot: boolean;
}

export function NodeRenderer({
  node,
  onSplit,
  onClose,
  onUnload,
  onSelectCard,
  onDividerDrag,
  isRoot,
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
          <div className="empty-pane-picker">
            <div className="picker-header">
              <span className="picker-title">选择插槽组件</span>
              <span className="picker-subtitle">请选择需要在当前窗格中载入的功能卡片</span>
            </div>
            <div className="picker-grid">
              {CARD_CONFIGS.map((cfg) => (
                <div key={cfg.type} className="picker-item" onClick={() => onSelectCard(node.id, cfg.type)}>
                  <div className="picker-item-icon" style={{ color: cfg.color, borderColor: `${cfg.color}33` }}>
                    {cfg.icon}
                  </div>
                  <div className="picker-item-info">
                    <span className="picker-item-name">{cfg.name}</span>
                    <span className="picker-item-desc">{cfg.description}</span>
                  </div>
                </div>
              ))}
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

  const { direction, ratio, first, second } = node;
  const isVertical = direction === "v";

  const handleDividerMouseDown = (event: React.MouseEvent) => {
    event.preventDefault();
    const startPos = isVertical ? event.clientX : event.clientY;
    const container = dividerRef.current?.parentElement;
    if (!container) return;
    const totalSize = isVertical ? container.offsetWidth : container.offsetHeight;

    const onMove = (moveEvent: MouseEvent) => {
      const currentPos = isVertical ? moveEvent.clientX : moveEvent.clientY;
      onDividerDrag(node.id, (currentPos - startPos) / totalSize, direction);
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
