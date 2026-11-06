# SP-274 — issue 277 resize capability host input

## 边界

处理 #277：当 Xcode `devicectl device info appResize` 对精确 Simulator 返回绑定设备的 CoreDeviceError 1001，且明确声明不支持 `com.apple.coredevice.feature.resizableappmanagement` 时，将该状态用于 host tap 与 primary LCD still capture 的安全路由。未知、冲突、超时、缺失或活动 Resize 会继续拒绝。

影响层为 CLI/shared core；不依赖私有 App、人工 IME 或真实设备验收。真实 simulator 输入仍需独立记录为未执行，fixture 不替代真实用户现场。

## BDD

- Given 精确 target-bound capability rejection 1001，When 执行 host tap guard，Then 允许通过 Resize 门禁并继续现有 DTUHID、屏幕和坐标校验；诊断模型仍保留 `unknown/unsupportedDevice` 原因。
- Given 同一 rejection，When 执行 primary LCD still route，Then 使用已验证单 LCD topology，保留 `resizeState=unknown` 与 `resizeReason=unsupportedDevice` 证据，不授予 stream 或额外 display 权限。
- Given 非绑定、错误域、错误 feature、活动 session、超时或 malformed JSON，Then 保持现有 fail-closed 行为。

## 验收记录

- 先运行失败测试，证明 #277 当前回归。
- 运行 CLI focused tests、`swift test --package-path CLI --no-parallel` 及受影响 local gate。
- 真实 simulator host tap/截图留作范围外运行验收，不能宣称已完成。
