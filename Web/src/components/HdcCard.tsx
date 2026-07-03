import React from "react";
import { Card, Tag, Flex, Button, message } from "antd";
import { Cpu } from "lucide-react";

export function HdcCard() {
  return (
    <Card
      size="small"
      title={
        <Flex align="center" gap={6}>
          <Cpu size={14} color="#1677ff" />
          <span>鸿蒙与安卓桥接</span>
        </Flex>
      }
      extra={<Tag color="blue">C3</Tag>}
      className="bento-card theme-blue"
    >
      <div className="card-content-wrapper">
        <div className="card-body">
          <p><span>调试平台:</span> <span className="label-val">HarmonyOS / HDC</span></p>
          <p><span>桥接服务:</span> <span className="label-val">HDC Adapter</span></p>
          <p><span>端口监听:</span> <span className="label-val">5037</span></p>
          <p><span>应用入口:</span> <span className="label-val" style={{ fontSize: "10px" }}>com.huawei.app.entry</span></p>
        </div>
        <div className="card-actions">
          <Flex gap={4}>
            <Button type="primary" size="small" style={{ flexGrow: 1 }} onClick={() => message.loading("正在打包并部署 APK/HAP 包...")}>安装包</Button>
            <Button size="small" style={{ flexGrow: 1 }} onClick={() => message.success("应用沙盒已初始化")}>清缓存</Button>
          </Flex>
        </div>
      </div>
    </Card>
  );
}
