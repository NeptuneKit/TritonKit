import { InputNumber, Tag } from "antd";
import type { HierarchyLayerNode } from "../types";

export type LayoutInfoChangeCallback = (field: string, value: number) => void;

export function LayoutInfo({
  node,
  frame = node.frame,
  onChange,
}: {
  node: HierarchyLayerNode;
  frame?: HierarchyLayerNode["frame"];
  onChange?: LayoutInfoChangeCallback;
}) {
  return (
    <div className="layout-info">
      <div className="layout-info-header">
        <strong>layout</strong>
        <Tag color="default" style={{ fontSize: 10 }}>readonly</Tag>
      </div>

      <div className="layout-info-section">
        <span className="layout-info-section-label">frame</span>
        <div className="layout-info-row">
          <LayoutInput label="x" value={frame.x} field="frame.x" onChange={onChange} />
          <LayoutInput label="y" value={frame.y} field="frame.y" onChange={onChange} />
        </div>
        <div className="layout-info-row">
          <LayoutInput label="w" value={frame.width} field="frame.width" onChange={onChange} />
          <LayoutInput label="h" value={frame.height} field="frame.height" onChange={onChange} />
        </div>
      </div>

      <div className="layout-info-section">
        <span className="layout-info-section-label">bounds</span>
        <div className="layout-info-row">
          <LayoutInput label="x" value={frame.x} field="bounds.x" onChange={onChange} />
          <LayoutInput label="y" value={frame.y} field="bounds.y" onChange={onChange} />
        </div>
        <div className="layout-info-row">
          <LayoutInput label="w" value={frame.width} field="bounds.width" onChange={onChange} />
          <LayoutInput label="h" value={frame.height} field="bounds.height" onChange={onChange} />
        </div>
      </div>
    </div>
  );
}

function LayoutInput({
  label,
  value,
  field,
  onChange,
}: {
  label: string;
  value: number;
  field: string;
  onChange?: LayoutInfoChangeCallback;
}) {
  return (
    <div className="layout-input">
      <span className="layout-input-label">{label}</span>
      <InputNumber
        size="small"
        value={value}
        onChange={(v) => { if (v !== null && onChange) onChange(field, v); }}
        disabled={!onChange}
        style={{ width: "100%" }}
        controls={false}
      />
    </div>
  );
}
