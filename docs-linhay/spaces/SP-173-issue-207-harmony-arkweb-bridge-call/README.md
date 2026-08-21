# SP-173：Harmony ArkWeb bridge-call host-side provider

## 边界

- 对应 GitHub issue：#207 `[Feature] Add Harmony ArkWeb bridge-call provider`
- 影响层：CLI Harmony host-side runtime（`Sources/TritonKitCLI/CLIHostHarmonyRuntime.swift`）、WebView 命令族（`Sources/TritonKitCLI/CLIWebViewCommands.swift`、`CLIWebViewRuntime.swift`、`CLIWebViewModels.swift`）、schema（`CLISchemaObservationCommands.swift` / `CLISchemaActionCommands.swift` 中 webview 相关 contract）、focused tests；不新增 HTTP/Web/Wails 控制面。
- 工作目录：`../TritonKit-worktrees/SP-173-issue-207-harmony-arkweb-bridge-call/`
- 分支：`feat/SP-173-issue-207-harmony-arkweb-bridge-call`
- 基线：`main@a56d7d6a`
- 目标：为 Harmony ArkWeb 提供 host-side bridge-call 能力：通过 HDC 端口转发连接 ArkWeb DevTools CDP endpoint（`webview_devtools_remote_<pid>`），在显式选中的可见 ArkWeb 页面调用显式命名的方法（allowlist 语义：只调用调用方点名的方法与 JSON 参数），返回结构化 callback 结果 envelope；与既有 iOS embedded `webview bridge-call` 契约（`TKRuntimeWebViewProvider.bridgeCallScript`）的命令面与错误语义对齐。

## 非目标

- 不做任意 JS eval 产品面：只暴露显式命名方法的 bridge-call；CDP 连接是 host-side adapter 实现细节，不是对外命令面。
- 不改 iOS embedded runtime 的 bridge-call 实现；不触碰 `Sources/TritonKit/`（除非共享 DTO 需要极小同步，需在报告中单列）。
- 不连接真实 DevEco Emulator / HDC 设备；真实 Harmony smoke 保留为风险，与 SP-160/161/164 同口径。
- 不新增 HTTP/Web/Wails 表面；不触碰其他 worktree 或 main 仓库。

## BDD 验收

### 场景 1：可见 ArkWeb 上的显式 bridge 调用

- Given DevEco Emulator 上一个可见 ArkWeb 页面与已注册的页面 bridge 方法
- When 执行 `triton webview bridge-call --platform harmony --target <harmony-target> --webview-id <id> --method <method> --params '{"k":"v"}' --json`
- Then host adapter 经 HDC fport + CDP evaluate 触发页面 bridge 调用，等待异步 callback，返回 `ok:true` 的结构化结果（含 method、params echo、callback payload、duration/source 元数据）。

### 场景 2：typed 错误族

- Then 以下情况分别返回稳定 typed error：无 CDP provider/socket（provider missing）、方法不存在或未回调（missing method / timeout）、多 WebView 未消歧（ambiguous selection）、WebView 不存在（webview_id_not_found 等既有命名优先）。

### 场景 3：schema 与 capability 对齐

- Given `triton schema --json` 的 webview / observation contract
- Then Harmony bridge-call 能力、failureCodes 与 output contract 挂载齐全，与 iOS 侧命名一致；`webview list` 的 Harmony 路径不再把 bridge-call 报成永久 missing provider（在 provider 可用时）。

### 场景 4：离线 fixture

- Then 离线 fixture 覆盖 discovery → invoke → async callback → typed errors 全链路（CDP 会话以注入/假 socket 模拟），不启动真实 HDC。

## 验收命令

```bash
swift test --package-path CLI --scratch-path .build/cli --filter WebView
swift test --package-path CLI --scratch-path .build/cli --filter Harmony
swift test --package-path CLI --scratch-path .build/cli --filter Schema
swift build --package-path CLI --scratch-path .build/cli-release -c release --product triton
.build/cli-release/release/triton schema --command webview --json
docs-linhay/scripts/check-docs.sh
git diff --check
```

真实 DevEco/HDC smoke 不作为本次验收前置；以离线 fixture 与 contract 测试验证。

## 当前状态

- 执行中：space 已建立，等待实现。
