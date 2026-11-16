# SP-274 — issue 277 resize capability host input

## 边界

处理 #277：当 Xcode `devicectl device info appResize` 对精确 Simulator 返回绑定设备的 CoreDeviceError 1001，且明确声明不支持 `com.apple.coredevice.feature.resizableappmanagement` 时，将该状态用于 host tap 与 primary LCD still capture 的安全路由。未知、冲突、超时、缺失或活动 Resize 会继续拒绝。

影响层为 CLI/shared core。验收覆盖与原报告相同的 target-bound 1001 能力拒绝、实际 Host HID 触摸和同一主 LCD 的截图。

## BDD

- Given 精确 target-bound capability rejection 1001，When 执行 host tap guard，Then 允许通过 Resize 门禁并继续现有 DTUHID、屏幕和坐标校验；诊断模型仍保留 `unknown/unsupportedDevice` 原因。
- Given 同一 rejection，When 执行 primary LCD still route，Then 使用已验证 active primary integrated LCD；若清单还包含 inactive non-primary virtual display，仍可按该 LCD 截图，保留 `resizeState=unknown` 与 `resizeReason=unsupportedDevice` 证据，不授予 stream 或额外 display 权限。
- Given 非绑定、错误域、错误 feature、活动 session、超时或 malformed JSON，Then 保持现有 fail-closed 行为。

## 验收记录

- 先运行失败测试，证明 #277 当前回归。
- 运行 CLI focused tests、`swift test --package-path CLI --no-parallel` 及受影响 local gate。
- 2026-11-16 用正式 v0.2.45 arm64 包在自有 iPad Air（iOS 27.0 Simulator）验收。`device doctor` 返回 `unknown/unsupportedDevice`、`primary`，当次错误为 `com.apple.dt.CoreDeviceError` 1001。原报告同形的坐标 tap 返回 `host-hid`，同一 Simulator 中 UIKit 测试 App 独立读回计数从 0 增至 1。显式主 LCD 截图 2048×2732，保留 `unknown/unsupportedDevice`。
- [前置截图](./screenshots/20261116-host-hid-ipad-before-v1.png) · [动作后截图](./screenshots/20261116-host-hid-ipad-after-v1.png) · [GitHub 回帖](https://github.com/NeptuneKit/TritonKit/issues/277#issuecomment-6910310780)。GitHub 已核实为 `CLOSED/COMPLETED`。原报告的 iOS 26.5 iPhone 组合未复跑。
