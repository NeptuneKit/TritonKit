import { Card, Descriptions, Tag, Tree } from "antd";
import type { DataNode } from "antd/es/tree";
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

  const classHierarchy = node.raw?.classHierarchy ?? [];

  return (
    <Card className="selected-node-panel" aria-label="选中视图节点" size="small">
      <div className="selected-node-heading">
        <div>
          <strong>{typeLabel}</strong>
          {nodeName ? <span>{nodeName}</span> : null}
        </div>
        <Tag color="blue">Runtime DTO</Tag>
      </div>

      <div className="node-identity">
        <div className="node-identity-row">
          <span className="node-identity-label">类名</span>
          <code className="node-identity-value">{node.type}</code>
        </div>
        <div className="node-identity-row">
          <span className="node-identity-label">变量名</span>
          <code className="node-identity-value">{node.name || "未命名"}</code>
        </div>
      </div>

      {classHierarchy.length > 0 ? (
        <div className="node-parent-tree">
          <span className="node-parent-label">类继承</span>
          <Tree
            className="parent-hierarchy-tree"
            showLine
            defaultExpandAll
            treeData={buildClassHierarchyTree(classHierarchy, node.type)}
          />
        </div>
      ) : null}

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

function buildClassHierarchyTree(classHierarchy: string[], currentType: string): DataNode[] {
  if (classHierarchy.length === 0) return [];

  const buildTree = (classes: string[], depth: number): DataNode | null => {
    if (classes.length === 0) return null;

    const [current, ...rest] = classes;
    const isCurrent = current === currentType;
    const child = buildTree(rest, depth + 1);

    return {
      key: `${current}-${depth}`,
      title: (
        <span className={isCurrent ? "parent-node-current" : ""}>
          {current}
          {isCurrent ? <Tag color="blue" style={{ marginLeft: 4 }}>当前</Tag> : null}
        </span>
      ),
      children: child ? [child] : undefined,
    };
  };

  const root = buildTree(classHierarchy, 0);
  return root ? [root] : [];
}
