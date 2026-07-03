import React from "react";
import { Card, Tag, Flex, Button, message } from "antd";
import { Target } from "lucide-react";

export function TargetCard() {
  return (
    <Card
      size="small"
      title={
        <Flex align="center" gap={6}>
          <Target size={14} color="#1677ff" />
          <span>目标探测器</span>
        </Flex>
      }
      extra={<Tag color="blue">C1</Tag>}
      className="bento-card theme-blue"
    >
      <div className="card-content-wrapper">
        <div className="card-body">
          <p><span>当前设备:</span> <span className="label-val">iPhone 16 Pro</span></p>
          <p><span>连接状态:</span> <Tag color="success" style={{ margin: 0 }}>已连接</Tag></p>
          <p><span>本地 IP:</span> <span className="label-val">127.0.0.1:19421</span></p>
          <p><span>应用标识:</span> <span className="label-val" style={{ fontSize: "10px" }}>com.triton.demo</span></p>
          <p><span>运行期能力:</span></p>
          <div className="sub-list">
            <div>└─ 视图层级: 正常</div>
            <div>└─ 无障碍 AX: 正常</div>
            <div>└─ 输入模拟: 正常</div>
          </div>
        </div>
        <div className="card-actions">
          <Button type="primary" size="small" block onClick={() => message.info("正在刷新活跃调试目标...")}>
            刷新目标
          </Button>
        </div>
      </div>
    </Card>
  );
}
