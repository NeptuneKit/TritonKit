# GitHub issue batch: 2026-07-07

## 背景

本轮处理 GitHub 当前开放的三个 issue：

- #139：`doctor` / `plan` 在 Harmony host-side 验证场景下仍提示 iOS embedded runtime。
- #138：`triton act tap` 点击 CombineCocoa-backed `UIControl` 时触发 embedded iOS app 崩溃。
- #136：Demo WebView edge case 触发 WebKit / UIKit 内部 Auto Layout 噪声。

## 范围

- 修复 CLI 机器可读诊断和 plan 的 Harmony host-side 引导。
- 修复 iOS embedded runtime tap 分发对非 NSObject target/action 订阅对象的崩溃风险。
- 在 Demo WebView 内做最小输入辅助 / AutoFill 噪声缓解。
- 不恢复 Web/Wails 业务控制入口，不引入远端设备云，不处理未在本轮开放列表中的新 issue。

## BDD 验收

### 场景 1：Harmony host-side 诊断不误导到 iOS runtime

Given HDC 可用且 `triton device doctor --platform harmony --json` 能返回 host-side 能力
When 用户执行通用 `triton doctor --json` 或 `triton plan --json --platform harmony`
Then 输出应提示 Harmony host-side readiness / recovery path
And 不应只提示启动 `triton serve` 或连接 iOS app。

### 场景 2：CombineCocoa UIControl 点击不崩溃

Given UIKit `UIControl` target/action 列表中包含非 NSObject 的 CombineCocoa 订阅对象
When `triton act tap` 选择 runtime 控件 tap 分发策略
Then TritonKit 不应强制桥接该对象为 `NSObject`
And 应优先跳过不可安全分发的 target/action，必要时回退坐标点击路径。

### 场景 3：Demo WebView edge page 降低系统内部布局噪声

Given Demo `WebViewSmokePanel` 展示 edge WebView 页面
When 页面包含 password input
Then Demo 应关闭 WebView input assistant button groups
And password input 应显式关闭 autocomplete / autocorrect / autocapitalize / spellcheck，避免触发可避免的 AutoFill/input accessory 噪声。

## 验证计划

- 先补对应失败测试或 Demo 源码断言，再实现。
- 运行每个修复面对应的 focused Swift 测试。
- 构建 CLI 和 Demo 可编译面。
- 收尾运行 `git diff --check` 与 `docs-linhay/scripts/check-docs.sh`。

## 实现记录

### #139 Harmony host-side doctor / plan

- `doctor --platform harmony|android` 进入 platform-focused 诊断路径：host-side device readiness 成为首个 `host-device` check，`primaryWorkflowCategory=target`，`nextAction=triton device list --platform <platform> --json`。
- runtime server 未启动时不再把顶层 `error` 固定为 `server_unavailable`，而是降级为 `runtime-server` warning；提示只在需要 embedded runtime 状态时启动 `triton serve`。
- `plan --platform harmony|android` 的 general goal 进入 host-side task plan，步骤固定为 `device doctor/list/wait-ready`、`observe tree`、`device screenshot`，避免把本机 Harmony / Android 验证误导到 `triton serve` 或 `triton xcode run`。

### #138 CombineCocoa-backed UIControl tap

- 新增 `isSafeControlActionTarget(_:)`，把 target/action 枚举前的安全边界显式化：`nil` 与 `NSObject` target 可走 UIKit target/action 查询，非 NSObject Swift 对象跳过。
- `safeControlActionNames(for:target:event:)` 在 UIKit 分支中统一封装 `UIControl.actions(forTarget:forControlEvent:)`，避免 CombineCocoa 订阅对象触发强制桥接崩溃。
- 如果某个 control event 可用但 action 列表不可安全枚举，tap 分发会保留该 event 并回退到 `sendActions(for:)`，不再把非 NSObject target 当成可枚举 action target。

### #136 Demo WebView edge case

- Demo 当前 `WebViewSmokePanel` 已关闭 `WKWebView.inputAssistantItem` 左右按钮组，并在 edge case password input 上关闭 `autocomplete/autocorrect/autocapitalize/spellcheck`。
- `docs-linhay/scripts/verify-ios-webview-harness.sh` 新增 static guard 和 `TRITON_STATIC_ONLY=1` 模式，确保后续不会无声移除这些 WebView 噪声缓解点。

## 本轮验证

- 红灯：`swift test --filter TKRuntimeInputActionTargetSafetyTests` 在实现前失败，证明安全 helper 尚不存在。
- 红灯：`swift test --package-path CLI --filter SchemaFactSourceTests/doctorResponseExposesOrderedRecoveryChecks` 在实现前仍返回 `start-server` / `server_unavailable`。
- 绿灯：`swift test --filter TKRuntimeInputActionTargetSafetyTests`。
- 绿灯：`swift test --package-path CLI --filter SchemaFactSourceTests/doctorResponseExposesOrderedRecoveryChecks`。
- 绿灯：`swift test --package-path CLI --filter SchemaFactSourceTests/workflowPlanModeSeparatesBootstrapRecoveryFromTaskWorkflows`。
- CLI smoke：`triton doctor --platform harmony --json` 返回 `host-device` / `target` / `device list --platform harmony --json`。
- CLI smoke：`triton plan --platform harmony --device harmony-real:abc123 --json` 返回 host-side `device-doctor` 首步，且前三步为 `device-doctor/device-list/device-wait-ready`。
- Demo guard：`TRITON_STATIC_ONLY=1 docs-linhay/scripts/verify-ios-webview-harness.sh`。
- Triton-first Demo build：`triton schema --command xcode --json` 确认 schema 后，使用 `triton xcode build --project Examples/TritonKitDemo/TritonKitDemo.xcodeproj --scheme TritonKitDemo --configuration Debug --sdk iphonesimulator --derived-data-path /tmp/tritonkit-issue-batch-deriveddata --timeout 240 --jsonl` 构建通过。
