import { Card, Descriptions, Tag } from "antd";
import { resolveEvidenceSources } from "../data/hierarchyMaterialPolicy";
import {
  readableViewTreeLabel,
  type HierarchyNodeHotEditDraft,
} from "./inspectorWorkspaceModel";
import type {
  HierarchyLayerNode,
} from "../types";

export function Inspector({
  hidden,
  selectedNode,
}: {
  hidden?: boolean;
  selectedNode: HierarchyLayerNode | null;
}) {
  return (
    <aside className="hub-inspector" aria-label="检查器" hidden={hidden}>
      <SelectedNodeEvidencePanel
        node={selectedNode}
      />
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
