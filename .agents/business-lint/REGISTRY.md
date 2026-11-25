# TritonKit 业务 lint 注册表

## iOS Simulator 宿主输入

| 规则 ID | 必须核对的触发条件 | Lint 文件 |
| --- | --- | --- |
| `SIM-HID-ADMISSION` | 改变宿主触摸的目标、几何、设备所有权判定、首次发送前拒绝或发送后不确定性的对外证据 | [宿主输入与诊断](sim-hid-admission.lint.md) |

## 设备录屏会话

| 规则 ID | 必须核对的触发条件 | Lint 文件 |
| --- | --- | --- |
| `RECORDING-START-OWNERSHIP` | 改变录屏启动、同目标排他、超时后重试或输出文件归属 | [录屏启动与归属](recording-start-ownership.lint.md) |
