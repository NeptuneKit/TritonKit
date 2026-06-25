import { Card, Descriptions, Tag } from "antd";
import { Activity, Braces, ChevronDown, Clock3, DatabaseZap, Gauge, Search } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { resolveEvidenceSources } from "../data/hierarchyMaterialPolicy";
import {
  localizeStatusLabel,
  readableViewTreeLabel,
  type BridgeState,
  type HierarchyNodeHotEditDraft,
} from "./inspectorWorkspaceModel";
import type {
  DeviceTarget,
  HierarchyLayerNode,
  NetworkEvent,
} from "../types";

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

function formatInspectorNumber(value: number) {
  return Number.isInteger(value) ? value.toString() : value.toFixed(2);
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
