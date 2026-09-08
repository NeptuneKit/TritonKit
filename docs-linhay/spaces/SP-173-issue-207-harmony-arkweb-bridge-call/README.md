# SP-173：Harmony ArkWeb bridge-call host-side provider

## 边界

- 对应 GitHub issue：#207 `[Feature] Add Harmony ArkWeb bridge-call provider`
- 影响层：CLI Harmony host-side runtime（`Sources/TritonKitCLI/CLIHostHarmonyRuntime.swift`）、WebView 命令族（`Sources/TritonKitCLI/CLIWebViewCommands.swift`、`CLIWebViewRuntime.swift`、`CLIWebViewModels.swift`）、schema（`CLISchemaObservationCommands.swift` / `CLISchemaActionCommands.swift` 中 webview 相关 contract）、focused tests；不新增 HTTP/Web/Wails 控制面。
- 工作目录：`../TritonKit-worktrees/SP-173-issue-207-harmony-arkweb-bridge-call/`
- 分支：`feat/SP-173-issue-207-harmony-arkweb-bridge-call`
- 基线：`main@a56d7d6a`
- 目标：为 Harmony ArkWeb 提供 host-side bridge-call 能力：通过 HDC 端口转发连接 ArkWeb DevTools CDP endpoint（`webview_devtools_remote_<pid>`），在显式选中的可见 ArkWeb 页面调用显式命名的方法（allowlist 语义：仅调用页面主动注册在 `window.__tritonBridge.methods` 上的 own function；调用方点名本身不授予权限），返回结构化 callback 结果 envelope；与既有 iOS embedded `webview bridge-call` 契约（`TKRuntimeWebViewProvider.bridgeCallScript`）的命令面与错误语义对齐。

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

- 实现完成（2026-08-21）：Harmony host-side ArkWeb bridge-call 经 HDC fport + CDP evaluate 调用 allowlisted 页面方法并等待异步 callback；显式 `--webview-id` 消歧；typed 错误族覆盖 provider missing / method not allowed / timeout / ambiguous / webview not found。`webview list` 在 CDP 可达时不再把 `webview.bridge-call` 报成永久 missing。离线 fixture 覆盖 discovery → invoke → callback → typed errors，不启动真实 HDC。真实 DevEco/HDC smoke 保留为风险。

## 2026-09-08 审计补充 BDD

- 显式传入不存在的 WebView ID，即使只有一个页面也返回 `webview_id_not_found`。
- 页面 allowlist 不包含 prototype 继承函数；实际执行 JavaScript fixture 验证拒绝与异步 callback，不能仅检查脚本文本。
- HDC 默认转发探测到的 Unix socket；清理必须同时携带 local/remote node，不抢占其它转发。多个 socket 未消歧时失败关闭。
- CDP 解析真实嵌套 exceptionDetails / protocol error；事件流不得重置绝对超时。

### 页面接入约定

allowlist 是页面代码主动注册的 `window.__tritonBridge.methods` 自有函数表，CLI 的 `--method` 只做选择。继承函数与 getter 不属于 allowlist。页面应仅在 Debug 构建注册所需方法，避免对外开放任意执行器。

```javascript
window.__tritonBridge = {
  methods: {
    getRouteState: (params) => Promise.resolve({ code: 200 }),
    callbackState: (params, complete) => {
      existingAppBridge(params, (value) => complete(value));
    }
  }
};
```

返回普通 JSON 值或 Promise 的方法按返回值完成；返回 `undefined` 的 callback 方法等待第二参数 `complete(value)`，第三参数 `reject(error)` 可报告错误。页面没有主动注册时返回 `webview_method_not_allowed`，不会自动将私有 App 的任意 bridge 方法加入白名单。

### 契约依据

- [OpenHarmony hdc 官方文档](https://raw.githubusercontent.com/openharmony/docs/master/en/application-dev/dfx/hdc.md)：设备支持 `localabstract`，删除转发需 localnode 和 remotenode 两个字段。
- [Chrome DevTools Runtime.evaluate 官方协议](https://chromedevtools.github.io/devtools-protocol/tot/Runtime/#method-evaluate)：返回的 `exceptionDetails` 与 remote object `result` 位于响应 `result` 内；CDP 协议错误在顶层 `error`。

## 2026-09-08 主控集成验收

2026-09-08 用户已授权提交、合入 main、推送和关闭 issue；各实现分支已串行合入本地 main，正在等待 push/CI 后远端收口。最终 CLI 全量 977/977、根包 269/269、专用 iOS 26.5 Simulator UIKit 46/46 通过；本地总门禁通过。UIKit 覆盖包含 collection selection、longPress fail-closed、富文本 run 和实际 trait；Harmony 为离线 CDP/HDC fixture，不声称真实 DevEco smoke。详细证据与失败→修补过程见 ../SP-176-open-issues-integration/plans/20260908-issue-audit.md。
