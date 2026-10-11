# 专门平台 runner 执行切片（2026-10-11）

本切片把 watchOS/tvOS 的“公开 XCTest API fixture”推进到可审计的 Triton 执行边界，同时保留没有 runner 产物或专用 Simulator 时的失败关闭行为。

## 已实现

- `device platform-control` 增加显式 runner 参数：`--device`、`--xctestrun`、`--test-identifier`、`--result-bundle`、`--timeout`、`--audit-record`、`--execute-runner`、`--confirm`。
- 只接受完整 36 字符 Simulator UDID；拒绝 `booted`、`current`、名称、别名和 physical selector。
- 执行前读取 `simctl list devices --json`，精确绑定 UDID，并校验 watchOS/tvOS runtime family；不从设备名或旧 `ios` namespace 推断。
- 生成 `xcodebuild -xctestrun … -destination platform=<family> Simulator,id=<UDID> -resultBundlePath … -only-testing:… test-without-building`，风险为 automation，要求 timeout、target、artifactDir 和 audit record。
- 结果 JSON 必须同时匹配 platform、action、UDID、nonce、eventDelivered 和 postconditionVerified；普通 `xcodebuild` exit 0 或缺少结果只返回 `unknown`，不自动重试。
- xctestrun 必须是已存在的普通文件，result bundle 路径必须是新路径；不覆盖、不跟随符号链接。

## 本机验收边界

本机 Xcode 提供 watchOS 27、tvOS 27 SDK，但 `simctl list runtimes` 当前只有 iOS 27.0/27.1 可用，watchOS/tvOS Simulator runtime 为零；仓库也没有专用 UI-test target 或 `.xctestrun` 产物。因此本切片只完成 runner gate、命令构建、目标族绑定和严格结果 fixture 测试，不能称为真实输入验收。

## BDD

1. Given 完整显式 runner 请求，Then 生成目标绑定的 `test-without-building` argv，私有路径仅出现在 redacted source command。
2. Given `booted`、名称、错误 runtime family 或不可用 UDID，Then 在 xcodebuild 前返回稳定失败码。
3. Given 缺少 execute/confirm/audit/result bundle，Then 不调用 runner。
4. Given runner 返回错误 target、action、nonce 或缺少后置断言，Then 返回 `runner_result_mismatch`/`unknown`，不报告动作成功。
5. Given runner 超时或进程非零，Then 状态保持 unknown，禁止自动重试可能已经发送的输入。

## 下一步

准备一个隔离的 watchOS/tvOS UI-test target 和 build-for-testing 产物后，使用专用 Simulator 重跑真实 Crown/Action、remote/select/menu 后置断言；在此之前保持 fixture-only/unsupported 分层。
