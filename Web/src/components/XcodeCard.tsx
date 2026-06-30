import React from "react";
import { Card, Tag, Flex, Button, message } from "antd";
import { Wrench } from "lucide-react";

export function XcodeCard() {
  return (
    <Card
      size="small"
      title={
        <Flex align="center" gap={6}>
          <Wrench size={14} color="#1677ff" />
          <span>Xcode 项目构建</span>
        </Flex>
      }
      extra={<Tag color="blue">C4</Tag>}
      className="bento-card theme-blue"
    >
      <div className="card-content-wrapper">
        <div className="card-body">
          <p><span>工作空间:</span> <span className="label-val" style={{ fontSize: "10px" }}>Triton.xcworkspace</span></p>
          <p><span>构建 Scheme:</span> <span className="label-val">TritonDevDebug</span></p>
          <p><span>编译架构:</span> <span className="label-val">Simulator arm64</span></p>
          <p><span>配置环境:</span> <span className="label-val">Debug (调试)</span></p>
        </div>
        <div className="card-actions">
          <Flex gap={4}>
            <Button type="primary" size="small" style={{ flexGrow: 1 }} onClick={() => message.loading("正在拉取依赖并编译项目...")}>构建部署</Button>
            <Button size="small" style={{ flexGrow: 1 }} onClick={() => message.info("正在执行本地 Xcode 单元测试...")}>单测</Button>
          </Flex>
        </div>
      </div>
    </Card>
  );
}
