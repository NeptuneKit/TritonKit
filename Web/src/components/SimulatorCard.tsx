import React, { useState } from "react";
import { Card, Tag, Flex, Button, message } from "antd";
import { Smartphone } from "lucide-react";

export function SimulatorCard() {
  const [isSimBooted, setIsSimBooted] = useState(true);

  const handleSimBoot = () => {
    setIsSimBooted(true);
    message.success("iOS 模拟器启动指令已成功发送");
  };

  const handleSimShutdown = () => {
    setIsSimBooted(false);
    message.warning("iOS 模拟器已强制关闭");
  };

  return (
    <Card
      size="small"
      title={
        <Flex align="center" gap={6}>
          <Smartphone size={14} color="#1677ff" />
          <span>iOS 模拟器控制</span>
        </Flex>
      }
      extra={<Tag color="blue">C2</Tag>}
      className="bento-card theme-blue"
    >
      <div className="card-content-wrapper">
        <div className="card-body">
          <p><span>运行状态:</span> <Tag color={isSimBooted ? "success" : "error"} style={{ margin: 0 }}>
            {isSimBooted ? "活跃" : "关闭"}
          </Tag></p>
          <p><span>缓存沙盒:</span> <span className="label-val">准备就绪</span></p>
          <p><span>屏幕比例:</span> <span className="label-val">2.0x</span></p>
          <p style={{ fontSize: "10px", color: "#64748b", marginTop: "10px" }}>
            路径: /CoreSimulator/Devices/...
          </p>
        </div>
        <div className="card-actions">
          <Flex gap={4}>
            <Button size="small" disabled={isSimBooted} onClick={handleSimBoot} style={{ flexGrow: 1 }}>启动</Button>
            <Button size="small" disabled={!isSimBooted} onClick={handleSimShutdown} style={{ flexGrow: 1 }}>关机</Button>
            <Button danger size="small" onClick={() => message.loading("正在清理应用沙盒数据...")} style={{ flexGrow: 1 }}>清理</Button>
          </Flex>
        </div>
      </div>
    </Card>
  );
}
