# SP-219 实现记录（2026-10-21）

## 变更

- 新增 `resizeAwareSimulatorRecordingCommand`：每次 `simctl io recordVideo` 前使用 fresh、目标绑定的 `appResize` probe；已确认 `Resizable` display 时注入同一 `--display=<displayUniqueID>`。
- 已提供显式 display 时要求与 fresh identity 完全一致；跨目标/伪造 display 返回 `identityMismatch`。
- Resize 状态未知、超时、身份不一致继续 fail-closed，未创建录制进程。
- `runHostSimulatorRecordingCommand` 使用路由后的 command，普通 inactive 状态保持原行为。

## 文件

- `Sources/TritonKitCLI/CLIHostSimulatorResizeCapture.swift`
- `Sources/TritonKitCLI/CLIHostSimulatorRecordingRuntime.swift`
- `CLI/Tests/TritonKitCLITests/SimulatorResizeCaptureRoutingTests.swift`

## 验证

命令：`swift test --package-path CLI --no-parallel --filter SimulatorResizeCaptureRoutingTests`

结果：通过，5 tests / 1 suite；只使用离线 fixture，无设备和第三方代码执行。

真实 Simulator/Xcode 录制未执行，作为后续用户验收边界。AX/HID 仍保留现有拒绝路径，因为当前 host adapter 没有经验证的 Resizable display transport；本切片没有冒险扩大到未证明的输入路由。
