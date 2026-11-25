# SIM-HID-ADMISSION 宿主触摸与诊断

业务真源为 [CLI 控制契约](../../docs-linhay/dev/ai-cli-readable-control.md)与 [#284 验收](../../docs-linhay/spaces/SP-294-issue-284-hid-admission-diagnostics/README.md)。

适用于 iOS Simulator 宿主 HID 的 preflight、驱动接线、发送和 CLI JSON。嵌入式语义点击、截图和真机 Runner 独立验收。

1. 归属、主屏身份、方向或几何未明确通过时，首次触摸前拒绝。有效的公开 fixture 通过原有发送链。驱动尺寸不符和发送前状态变化的反例均须观察到零触摸。
2. 拒绝须保留类型、当次阶段及原因，发送后变化须标明送达可能不完整。非零 helper 结果须保留单个失败 envelope、选定目标和只读恢复指令。未知送达禁止自动重放。
3. Doctor 主屏快照与 HID 预检结果独立。预检通过或拒绝均保持 `inputDispatchVerified=false`，无法归因此前的请求时明确说明。

通过 `swift test --package-path CLI --no-parallel --filter 'NativeHIDRuntimeTests|DTUHIDTransportTests|SimulatorDoctorDiagnosticsTests|SimulatorResizeFailurePropagationTests'` 校验上述路由与回执。任何发送条件变化还须在任务自有 Simulator 验证触摸前后状态。诊断字段改动使用同一生产准入函数的 fixture 取证，真实设备的已发生结果需有独立回执。
