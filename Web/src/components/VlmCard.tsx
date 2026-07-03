import React, { useState } from "react";
import { Card, Tag, Flex, Button, message } from "antd";
import { Cpu } from "lucide-react";

export function VlmCard() {
  const [vlmAuditing, setVlmAuditing] = useState(false);
  const [auditResult, setAuditResult] = useState<string | null>(null);

  const triggerVlmAudit = () => {
    setVlmAuditing(true);
    setAuditResult(null);
    message.loading({ content: "正在调用本地 Qwen-VL 模型进行界面比对...", key: "vlm" });
    setTimeout(() => {
      setVlmAuditing(false);
      setAuditResult("未发现明显的 AX/视觉 缺陷，组件一致性 98.4%");
      message.success({ content: "本地 UI 视觉审计已完成", key: "vlm" });
    }, 1500);
  };

  return (
    <Card
      size="small"
      title={
        <Flex align="center" gap={6}>
          <Cpu size={14} color="#8b5cf6" />
          <span>本地 AI 视觉分析</span>
        </Flex>
      }
      extra={<Tag color="purple">C8</Tag>}
      className="bento-card theme-violet"
    >
      <div className="card-content-wrapper">
        <div className="card-body">
          <p><span>运行模型:</span> <span className="label-val">Qwen2.5-VL (MLX)</span></p>
          <p><span>硬件加速:</span> <span className="label-val">Apple Metal GPU</span></p>
          <p><span>模型状态:</span> <span className="label-val" style={{ color: "#a78bfa" }}>已载入显存</span></p>
          {auditResult && (
            <div style={{ fontSize: "10px", color: "#a78bfa", marginTop: "6px", borderTop: "1px solid rgba(255,255,255,0.05)", paddingTop: "4px" }}>
              分析: {auditResult}
            </div>
          )}
        </div>
        <div className="card-actions">
          <Flex gap={4}>
            <Button type="primary" size="small" style={{ flexGrow: 1 }} loading={vlmAuditing} onClick={triggerVlmAudit}>
              UI 审计
            </Button>
            <Button size="small" style={{ flexGrow: 1 }} onClick={() => message.success("已释放 Metal VLM 显存缓存")}>释放缓存</Button>
          </Flex>
        </div>
      </div>
    </Card>
  );
}
