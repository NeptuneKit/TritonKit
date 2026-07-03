import React, { useState } from "react";
import { Card, Tag, Flex, Button, message } from "antd";
import { Radio } from "lucide-react";

export function RecorderCard() {
  const [isRecording, setIsRecording] = useState(false);
  const [activeStepCount, setActiveStepCount] = useState(8);

  const handleRecordToggle = () => {
    setIsRecording(!isRecording);
    if (!isRecording) {
      setActiveStepCount(prev => prev + 1);
      message.info("开始录制开发者操作手势");
    } else {
      message.success("操作手势已捕获并保存");
    }
  };

  return (
    <Card
      size="small"
      title={
        <Flex align="center" gap={6}>
          <Radio size={14} color="#ff4d4f" />
          <span>用例录制与网络 Mock</span>
        </Flex>
      }
      extra={<Tag color="error">C9</Tag>}
      className="bento-card theme-red"
    >
      <div className="card-content-wrapper">
        <div className="card-body">
          <p><span>捕获状态:</span> <span className="label-val" style={{ color: isRecording ? "#ff4d4f" : "#94a3b8" }}>
            {isRecording ? "● 录制中" : "待机"}
          </span></p>
          <p><span>动作步数:</span> <span className="label-val">{activeStepCount} 步已捕获</span></p>
          <p><span>Mock API 缓存:</span> <span className="label-val">12 个 API</span></p>
        </div>
        <div className="card-actions">
          <Flex gap={4}>
            <Button danger={isRecording} type={isRecording ? "primary" : "default"} size="small" style={{ flexGrow: 1.5 }} onClick={handleRecordToggle}>
              {isRecording ? "停止录制" : "录制操作"}
            </Button>
            <Button size="small" style={{ flexGrow: 1 }} onClick={() => message.loading("正在生成 BDD Swift 测试脚本...")}>编译</Button>
          </Flex>
        </div>
      </div>
    </Card>
  );
}
