import React, { useState, useEffect } from "react";
import { Card, Tag, Flex, Button } from "antd";
import { Eye, RotateCcw } from "lucide-react";

export function TimelineCard() {
  const [isPlaying, setIsPlaying] = useState(false);
  const [timelineProgress, setTimelineProgress] = useState(45);

  useEffect(() => {
    let interval: any;
    if (isPlaying) {
      interval = setInterval(() => {
        setTimelineProgress(prev => (prev >= 135 ? 0 : prev + 1));
      }, 1000);
    }
    return () => clearInterval(interval);
  }, [isPlaying]);

  return (
    <Card
      size="small"
      title={
        <Flex align="center" gap={6}>
          <Eye size={14} color="#faad14" />
          <span>调试证据与回放</span>
        </Flex>
      }
      extra={<Tag color="warning">C7</Tag>}
      className="bento-card theme-orange"
    >
      <div className="card-content-wrapper">
        <div className="card-body">
          <p><span>连续时长:</span> <span className="label-val">02:15</span></p>
          <p><span>网络 API:</span> <span className="label-val">12 次请求 (Mocked)</span></p>
          <p><span>捕获手势:</span> <span className="label-val">14 组点击轨迹</span></p>
          <p><span>系统日志:</span> <span className="label-val">已解析 450 行</span></p>
          <p><span>当前进度:</span> <span className="label-val">00:{timelineProgress.toString().padStart(2, '0')}</span></p>
        </div>
        <div className="card-actions">
          <Flex gap={4}>
            <Button type="primary" size="small" style={{ flexGrow: 2 }} onClick={() => setIsPlaying(!isPlaying)}>
              {isPlaying ? "⏸ 暂停" : "▶ 播放"}
            </Button>
            <Button size="small" style={{ flexGrow: 1 }} onClick={() => setTimelineProgress(45)}>
              <RotateCcw size={10} />
            </Button>
          </Flex>
        </div>
      </div>
    </Card>
  );
}
