# SP-220 主控验证（2026-10-21）

## 候选与合并

- 候选提交：`51cd20ddb0139d09ac6464cdfb39f54aa9a63bfc`
- 当前主线：`b6fea1682d4f8106b379565714e93d243d786527`
- 本地合并提交：`f9399e5e`（候选提交为其父提交）
- 实际产品文件：`CLI/Tests/TritonKitCLITests/SimulatorResizeCaptureRoutingTests.swift`、`Sources/TritonKitCLI/CLIHostSimulatorResizeCapture.swift`、`Sources/TritonKitCLI/CLIHostSimulatorRecordingRuntime.swift`

## 验收

- `swift test --package-path CLI --no-parallel --filter SimulatorResizeCaptureRoutingTests`：5 tests / 1 suite 通过。
- 合并后 `swift test --package-path CLI --no-parallel`：1509 tests / 153 suites 通过。
- focused 场景覆盖 fresh display identity、unknown fail-closed、伪造/跨目标 display 拒绝；没有创建录制进程的负例保持离线验证。
- 未执行真实 Simulator/Xcode、AX/HID 设备动作、第三方代码、依赖安装、签名、DDI、推送或发布。

## 会话事实

`create_thread` 显式传 `model="gpt-6.1-sol"` 仍被桌面接口模型校验拒绝，未产生 thread ID；当前主控按已授权流程完成候选审核与本地合并，未使用回退模型。
