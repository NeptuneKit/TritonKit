import React from "react";
import { Card, Tag, Flex, Button, message } from "antd";
import { Search } from "lucide-react";

export function InspectorCard() {
  return (
    <Card
      size="small"
      title={
        <Flex align="center" gap={6}>
          <Search size={14} color="#1677ff" />
          <span>界面与 AX 审查</span>
        </Flex>
      }
      extra={<Tag color="blue">C5</Tag>}
      className="bento-card theme-blue"
    >
      <div className="card-content-wrapper">
        <div className="card-body">
          <p><span>当前选中:</span> <span className="label-val" style={{ color: "#1677ff", fontWeight: "bold" }}>UIButton</span></p>
          <p><span>元素标识:</span> <span className="label-val">submit_btn</span></p>
          <p><span>AX 文本:</span> <span className="label-val">"确认订单"</span></p>
          <p><span>几何信息:</span></p>
          <div className="sub-list">
            <div>└─ 坐标 X/Y: (45, 230)</div>
            <div>└─ 尺寸 W/H: 120 x 45</div>
          </div>
        </div>
        <div className="card-actions">
          <Button type="primary" size="small" block onClick={() => message.success("选中节点的 DTO JSON 已复制到剪切板")}>
            复制 DTO JSON
          </Button>
        </div>
      </div>
    </Card>
  );
}
