# SP-254-simulator-dtuhid-transport — Simulator DTUHID transport

状态：已评估，待分派。影响CLI host隔离helper；不修改embedded/Web/真机。

来源：[Loupe固定增量](https://github.com/heoblitz/Loupe/commit/180c60584867500b93b43ca6c8b556995bf8be7b)，MIT全文已核；涉及协议来源另核许可/通知。main44e81f5d仅legacy client。

## BDD与验收

- 服务可用且无事件barrier应答后才同连接发送typed down/move/up，完成barrier有界；consumed不是业务成功。
- 只有明确unsupported可走legacy；连接/未知lookup/超时/发送失败不fallback、不重放输入；错误单JSON。
- 坐标、目标、display、Resize拒绝沿用原策略；partial/cancel副作用保持unknown，不扩大secondary/真机。
- 离线失败测试→最小实现→focused/完整CLI→主控diff复核及合后门禁；真实设备未授权、未执行，不能据fixture声称实际兼容。

执行：SP-254-simulator-dtuhid-transport；主控：SP-255-dtuhid-integration，复用当前长期聊天。证据归plans；主控负责本地合并、证据归档、清理及执行聊天关闭，不push/tag/release。
