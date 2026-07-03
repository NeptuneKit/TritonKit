import React from "react";
import { Card, Tag, Flex, Button, message } from "antd";
import { Activity } from "lucide-react";

export function DoctorCard() {
  return (
    <Card
      size="small"
      title={
        <Flex align="center" gap={6}>
          <Activity size={14} color="#52c41a" />
          <span>运行环境自检与更新</span>
        </Flex>
      }
      extra={<Tag color="success">C10</Tag>}
      className="bento-card theme-green"
    >
      <div className="card-content-wrapper">
        <div className="card-body">
          <p><span>命令行版本:</span> <span className="label-val">v0.2.5</span></p>
          <p><span>体检状态:</span> <span className="label-val" style={{ color: "#52c41a", fontWeight: "bold" }}>健康</span></p>
          <p><span>自更新服务:</span> <span className="label-val">正常连通</span></p>
        </div>
        <div className="card-actions">
          <Flex gap={4}>
            <Button type="primary" size="small" style={{ flexGrow: 1 }} onClick={() => message.success("自检结果: Xcode OK, HDC OK, ADB OK.")}>Doctor 诊断</Button>
            <Button size="small" style={{ flexGrow: 1 }} onClick={() => message.info("当前 Triton 已经是最新版本 v0.2.5")}>检查更新</Button>
          </Flex>
        </div>
      </div>
    </Card>
  );
}
