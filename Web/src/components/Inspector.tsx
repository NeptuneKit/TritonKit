import { Tag } from "antd";
import { resolveEvidenceSources } from "../data/hierarchyMaterialPolicy";
import {
  readableViewTreeLabel,
  type HierarchyNodeHotEditDraft,
} from "./inspectorWorkspaceModel";
import type {
  HierarchyLayerNode,
} from "../types";
import { LayoutInfo, type LayoutInfoChangeCallback } from "./LayoutInfo";

export function Inspector({
  hidden,
  selectedNode,
  selectedNodeDraft,
  onLayoutChange,
}: {
  hidden?: boolean;
  selectedNode: HierarchyLayerNode | null;
  selectedNodeDraft?: HierarchyNodeHotEditDraft;
  onLayoutChange?: (nodeId: string, field: string, value: number) => void;
}) {
  return (
    <aside className="hub-inspector" aria-label="检查器" hidden={hidden}>
      <SelectedNodeEvidencePanel
        node={selectedNode}
        draft={selectedNodeDraft}
        onLayoutChange={onLayoutChange}
      />
    </aside>
  );
}

function SelectedNodeEvidencePanel({
  node,
  draft,
  onLayoutChange,
}: {
  node: HierarchyLayerNode | null;
  draft?: HierarchyNodeHotEditDraft;
  onLayoutChange?: (nodeId: string, field: string, value: number) => void;
}) {
  if (!node) {
    return (
      <div className="selected-node-panel is-empty" aria-label="选中视图节点">
        <div className="selected-node-heading">
          <strong>选中视图节点</strong>
          <span>在视图树或截图叠层中选择节点后显示 evidence</span>
        </div>
      </div>
    );
  }

  const frame = { ...node.frame, ...draft?.frame };
  const evidenceSources = resolveEvidenceSources(node);
  const visualSourceSummary = evidenceSources.map((source) => source.kind).join(" · ") || "none";
  const nodeName = node.name ? readableViewTreeLabel(node.name) : "";
  const typeLabel = readableViewTreeLabel(node.type);

  const classHierarchy = node.raw?.classHierarchy ?? [];

  return (
    <div className="selected-node-panel" aria-label="选中视图节点">
      <div className="selected-node-heading">
        <div>
          <strong>{typeLabel}</strong>
          {nodeName ? <span>{nodeName}</span> : null}
        </div>
        <Tag color="blue">Runtime DTO</Tag>
      </div>

      <div className="node-identity">
        <div className="node-identity-row">
          <span className="node-identity-label">变量名</span>
          <code className="node-identity-value">{node.name || "未命名"}</code>
        </div>
        {classHierarchy.length > 0 ? (
          <div className="node-identity-row">
            <span className="node-identity-label">继承</span>
            <code className="node-identity-value node-identity-hierarchy">
              {classHierarchy.map((cls, index) => (
                <span key={index}>
                  {index > 0 && <span className="hierarchy-arrow"> → </span>}
                  <span className={cls === node.type ? "parent-node-current" : ""}>{cls}</span>
                </span>
              ))}
            </code>
          </div>
        ) : null}
      </div>

      <LayoutInfo
        node={node}
        frame={frame}
        onChange={(field, value) => onLayoutChange?.(node.id, field, value)}
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
    </div>
  );
}
