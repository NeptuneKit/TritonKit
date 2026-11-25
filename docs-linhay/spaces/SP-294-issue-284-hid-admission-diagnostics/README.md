# SP-294 Simulator HID 显示准入诊断

[GitHub #284](https://github.com/NeptuneKit/TritonKit/issues/284) · macOS CLI `act tap` / `sim tap|swipe` / `device doctor`，沿用现有共享 JSON 错误模型。

- Given `devicectl` 报告主屏，且 `simctl io enumerate` 失败或屏幕不符合 HID 要求，When 请求坐标动作，Then 在接触前拒绝并返回当次阶段、原因和目标绑定诊断入口。
- Given 原生驱动点尺寸不一致或发送前快照变化，When 执行动作，Then 返回可区分的原因且不提交触摸。发送后重查失败仍是部分送达未知。
- Given doctor 只采集当前快照，When 查看兼容性，Then 显示独立预检的阶段和结果，保留 `inputDispatchVerified=false`，无法追溯此前动作时明确说明。

原始动作在 v0.2.46 只留下聚合错误码，具体拒绝原因未知。#224 的 App Resize 查询失败独立归 [SP-235](../SP-235-issue-224-simulator-resize-query/README.md)。

## 2026-11-25 验收

本地实现为 `b9e8d960`。联合门禁见[本轮记录](../../memory/2026-11-25.md)。

- 用生产准入函数的夹具区分 `hid-screen-enumeration`、`hid-driver-admission`、`hid-pre-dispatch` 和 `hid-post-dispatch`。目标绑定的单一失败 envelope 保留阶段、原因与可用退出码。输出不复制原生 stdout/stderr。
- 负例先在修复前失败。恢复旧版通用提示并叠加当次提示后，现存 Device Hub 失败契约与新增诊断共同通过。发送前拒绝观察到零触摸，发送后变化保持可能部分送达。
- `SIM-HID-ADMISSION` 专项通过。见 `NativeHIDRuntimeTests`、`DTUHIDTransportTests`、`DeviceHubHIDFailureTests`、`SimulatorDoctorDiagnosticsTests` 和 `SimulatorResizeFailurePropagationTests`。doctor 主屏为 `primary` 时仍可报告独立 HID 拒绝，`inputDispatchVerified=false`。当前主机没有已启动的同类 Simulator，本轮未复现原始场景。

2026-11-26：远端实现 `56a970c3` 已随 v0.2.47 发布，在自有 iPhone 17 上用正式制品通过本项范围的复验后 [回复并关闭](https://github.com/NeptuneKit/TritonKit/issues/284#issuecomment-7169322982)。详见 [SP-296](../SP-296-release-v0-2-47/README.md)。
