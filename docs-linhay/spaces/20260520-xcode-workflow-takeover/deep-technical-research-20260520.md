# Xcode Workflow Takeover Deep Technical Research

## 调研范围

本次调研对象是 XcodeBuildMCP v2.5.2 官方文档与源码快照，重点不是复刻 79 个工具名，而是拆解其能被 TritonKit 吸收的架构能力：

1. manifest / workflow / tool catalog 如何组织能力面。
2. CLI、MCP、daemon 如何共享同一 handler。
3. `xcodebuild` build/test/run 如何产出稳定 JSON、JSONL 和 artifact。
4. discovery、session defaults、DerivedData、app path、bundle id、xcresult、coverage、logs、SwiftPM、LLDB 的关键实现。
5. 哪些能力适合进入 TritonKit P0/P1，哪些只能后期或不应引入。

官方文档截至 2026-05-20 显示 XcodeBuildMCP v2.5.2、79 tools、15 workflows。官方文档确认其 CLI 与 MCP 共享同一能力层，CLI 支持 `text/json/jsonl/raw` 输出，MCP 通过 structured content 返回同形结构化结果；workflow gating 主要服务 MCP 工具曝光，CLI 不按 workflow gate。

## 核心结论

TritonKit 应该“吃能力，不吃 API”。更具体地说：

1. 吃 XcodeBuildMCP 的能力切面：discovery、session defaults、build/test/run、xcresult、coverage、logs、SwiftPM、device/macOS、debug、host UI。
2. 吃内部设计思想：manifest-like capability registry、domain fragment、final domain result、renderer 分层、workspace-scoped daemon、artifact lifecycle。
3. 不吃 public API：不暴露 `build_run_sim`、`list_schemes` 等 MCP tool name；TritonKit 的产品入口仍是 `triton xcode|xcresult|coverage|logs|spm|debug|device`。
4. 不吃 Node runtime 依赖：XcodeBuildMCP 可以作为参考实现或可选 bridge，但默认实现应留在 TritonKit Swift CLI / host adapter 内。
5. 不吃 Xcode IDE Bridge 首期依赖：IDE bridge 适合后期实验，不适合作为真实项目回归闭环的基础设施。
6. 不让 host UI automation 替代 embedded runtime：host UI 只能补 SpringBoard、Simulator.app、系统弹窗等 App 外能力。

## XcodeBuildMCP 架构拆解

### Manifest / Workflow / Tool Catalog

源码中 `src/core/manifest/schema.ts` 定义 manifest schema，工具 manifest 负责声明 name、description、workflow、availability、routing、output schema、next-step 模板和 predicate。`src/runtime/tool-catalog.ts` 再负责加载 manifest，按 runtime、workflow、predicate 过滤，并把 MCP name 映射到 CLI name。

对 TritonKit 的启发：

1. `triton schema --json` 不应该只是 CLI 参数反射，应升级为能力注册表。
2. 每个命令需要声明 `namespace`、`action`、`stability`、`riskLevel`、`outputSchema`、`progressEvents`、`artifacts`、`nextActions`。
3. CLI/HTTP/future MCP 只消费同一份 capability registry，不再各自维护命令说明。
4. workflow 可以作为内部分组和 future MCP 曝光策略，但不是用户面对的主控制面。

建议 TritonKit 内部模型：

```swift
struct TKHostCapabilityDescriptor: Codable, Sendable {
    var namespace: String
    var action: String
    var summary: String
    var stability: String
    var riskLevel: String
    var requiresDaemon: Bool
    var outputSchema: String
    var progressEvents: [String]
    var artifactKinds: [String]
    var nextActions: [TKNextActionTemplate]
}
```

### Runtime Boundary

XcodeBuildMCP 的 runtime boundary 有三类：MCP stdio、CLI in-process、CLI -> daemon Unix socket。所有路径最终进入同一个 tool handler。daemon 用于 debug session、video capture、SwiftPM background process、Xcode IDE bridge 等需要跨短命 CLI 进程保留状态的能力。

TritonKit 已经有 `triton serve` 与 HTTP 管理 API，因此不需要照搬 daemon CLI；但需要吸收其状态归属原则：

1. 短命能力走 CLI 直接执行：discover、schemes、settings、build、test、xcresult、coverage。
2. 长生命周期能力走 daemon / serve：logs stream、debug session、video record、background SwiftPM run、runtime target binding。
3. daemon 状态必须 workspace-scoped，不能全局混用不同项目的 scheme、simulator、log capture。
4. 每个长任务都要有 activity lease，避免 idle shutdown 杀掉活跃 debug/log/run。

### Domain Fragment 与 Final Result

XcodeBuildMCP 源码把长任务输出拆成两层：

1. `DomainFragment`：运行中的 typed progress，例如 `build-stage`、`compiler-diagnostic`、`test-progress`、`test-failure`、`process-line`。
2. `ToolDomainResult`：最终结构化结果，例如 `build-result`、`build-run-result`、`test-result`、`coverage-result`、`debug-session-action`。

JSONL 不是直接吐 raw stdout，而是把 fragment 机械投影成事件名。最终 JSON 走 tagged schema，并带 `didError/error/diagnostics/artifacts`。

对 TritonKit 的建议：

1. 新增统一 host progress event，不要让每个命令自定义形状。
2. JSONL 只输出 domain event；raw transcript 只作为 `--raw` 或 evidence artifact，不作为 agent 默认解析对象。
3. final envelope 要统一带 `ok/action/request/summary/artifacts/diagnostics/errorCode`，并允许 domain failure 仍返回 domain schema。
4. `xcodebuild` parser 只负责把文本归一到 domain fragment，不直接决定 UI 文案。

建议事件名：

```text
xcode.invocation
xcode.package-resolve
xcode.compile
xcode.link
xcode.diagnostic
xcode.test-discovery
xcode.test-case
xcode.test-progress
xcode.test-failure
xcode.summary
xcode.run.phase
process.command
process.stdout
process.stderr
process.exit
```

## 关键能力源码评估

### Project Discovery

XcodeBuildMCP 的 `discover_projs.ts` 递归扫描 `.xcodeproj` / `.xcworkspace`，默认最大深度 3，跳过 `build`、`DerivedData`、`Pods`、`.git`、`node_modules`，避免 symlink 和 workspace root 外路径。

TritonKit P0 应采纳：

1. 默认 depth 3，允许 `--max-depth`。
2. 固定 ignore list，允许 `.triton/config` 后续扩展。
3. 输出 projects、workspaces、packages、warnings、ambiguous candidates。
4. 发现 `.xcworkspace` 时优先提示 workspace，发现单一 candidate 时才允许 `use --auto`。

### Schemes 与 Build Settings

`list_schemes.ts` 调 `xcodebuild -list -project|-workspace` 并解析 `Schemes:` 区块。`show_build_settings.ts` 调 `xcodebuild -showBuildSettings`，解析 `KEY = VALUE` entries，同时剥离 preamble 并归档 error diagnostics。

TritonKit P0 应采纳：

1. `triton xcode schemes` 输出 `schemes[]` 与 source artifact。
2. `triton xcode settings` 输出 ordered entries，同时提供常用字段 shortcut：`BUILT_PRODUCTS_DIR`、`FULL_PRODUCT_NAME`、`PRODUCT_BUNDLE_IDENTIFIER`、`TARGET_BUILD_DIR`、`SDKROOT`。
3. errors 必须区分 `xcodebuild_not_found`、`invalid_project_path`、`scheme_not_found`、`ambiguous_workspace`。

### DerivedData 与 App Path

XcodeBuildMCP 不直接使用全局默认 DerivedData，而是按 workspace key 生成 scoped DerivedData path；`app-path-resolver.ts` 通过 `xcodebuild -showBuildSettings` 读取 `BUILT_PRODUCTS_DIR` 和 `FULL_PRODUCT_NAME` 得到 `.app` 路径。bundle id 优先用 `defaults read <app>/Info CFBundleIdentifier`，失败时 fallback 到 PlistBuddy。

TritonKit 应采纳：

1. 默认 DerivedData 放 `.triton/DerivedData/<project-name>-<hash>` 或用户指定路径。
2. `.app` path 只能从 build settings / build result 推导，不猜 `Build/Products/...`。
3. bundle id 读取要走 plist API 或 `/usr/libexec/PlistBuddy` fallback。
4. final artifacts 必须包含 `derivedDataPath`、`appPath`、`bundleID`、`buildLogPath`。

### Build / Test / Run Pipeline

XcodeBuildMCP 的 build/test/run 共同使用 `xcodebuild-pipeline`：

1. 先 emit invocation fragment。
2. 解析 stdout/stderr，识别 package resolve、compile、link、test prepare、run tests、summary。
3. 捕获 compiler warning/error、test case、totals、failure diagnostic、xcresult path。
4. 结束时生成 final domain result，包含 summary、artifacts、diagnostics。

`build_run_sim.ts` 在 build 成功后串联 app path、simulator boot、install、bundle id、launch 与 logging。`test_sim.ts` 支持 `onlyTesting/skipTesting`、`resultBundlePath`、test preflight，并在可用时用 xcresult 修正 test counts。

TritonKit P0 应实现同等闭环：

```text
xcode build:
  resolve defaults -> argv -> run xcodebuild -> parse progress -> final build summary

xcode test:
  resolve defaults -> optional preflight -> argv/resultBundle -> parse progress -> xcresult summary -> final test summary

xcode run:
  resolve defaults -> build -> app path -> sim boot/install -> bundle id -> launch -> optional runtime wait
```

关键注意：

1. `launchArgs` 和 `extraArgs` 必须分开：前者给 app 进程，后者给 `xcodebuild` / build settings。
2. `xcode run` 只能声明 build/install/launch 成功，不能声明业务场景 ready。
3. test counts 首选 `xcresulttool get test-results summary`，stdout parser 只做 fallback。
4. build/test raw log 需要入 evidence artifact。

### Test Preflight

XcodeBuildMCP 的 `test-preflight.ts` 会读取 shared scheme、workspace 中引用的 `.xcodeproj`、test plan，再扫描 Swift 文件静态发现测试；支持 `-only-testing` / `-skip-testing` 过滤。它的完整性可能是 `complete`、`partial`、`unresolved`。

TritonKit 可以 P1 吸收，不必挡 P0：

1. P0 只需透传 `--only-testing` / `--skip-testing` 并输出 result。
2. P1 再做 preflight，用于提前告诉 agent 选中的测试数量和无法解析原因。
3. Swift test 静态发现不要作为是否可运行的前置门禁，只作为提示与 evidence 附加信息。

### xcresult

XcodeBuildMCP 已使用新版 `xcrun xcresulttool get test-results summary/tests --path ...` 读取测试汇总和失败树，并把 failure message 解析为 `location + message`。

TritonKit P0 应采纳：

1. `triton xcresult summary --path`：counts、duration、status、result path。
2. `triton xcresult failures --path`：suite、test、message、location、attachments candidate。
3. `triton xcode test` final summary 应内联 failures top N，并保存完整结果到 artifact。
4. 需要保留 `xcresulttool` 版本兼容层，因为 Xcode 版本间子命令与 JSON shape 可能变化。

### Coverage

XcodeBuildMCP coverage 使用：

1. `xcrun xccov view --report --only-targets --json <xcresult>` 做 target summary。
2. `xcrun xccov view --report --functions-for-file <file> --json <xcresult>` 做函数级覆盖。
3. `xcrun xccov view --archive --file <file> <xcresult>` 解析未覆盖行区间。

TritonKit P1 应采纳：

1. `coverage summary` 支持 target filter 与 `--show-files`。
2. `coverage uncovered` 支持 source file / target filter，输出未覆盖函数和 line ranges。
3. 覆盖率没有数据时要返回稳定 error code，不让 agent 误判为 0%。

### Logs

XcodeBuildMCP 的 simulator launch with logging 使用两路：

1. `simctl launch --console-pty --terminate-running-process` 捕获 stdout/stderr 到文件。
2. `simctl spawn <udid> log stream --level=debug --predicate 'subsystem == "<bundleId>"'` 捕获 OSLog。

并通过 owner pid / helper pid 命名，注册后台 log stream session，避免泄漏。

TritonKit P1 应采纳：

1. `xcode run` 可默认生成 runtime stdout/stderr log artifact。
2. `logs stream/collect` 需要区分 app console log 与 OSLog。
3. log stream 是有状态任务，应走 `triton serve` activity lease。
4. `bundleId` 作为 log subsystem predicate 前必须校验字符集。

### SwiftPM

XcodeBuildMCP 的 SwiftPM 工具覆盖 build/test/run/list/clean/stop/coverage。`swift_package_run` 支持 foreground timeout 与 background process，background process 由 daemon 记录 PID、packagePath、releaseActivity，`stop` 可优雅终止。

TritonKit P2 可采纳：

1. `triton spm build/test/run` 输出同 xcodebuild 风格 JSONL。
2. `spm run --background` 必须要求 daemon，并提供 `spm stop --pid`。
3. background process 进入 evidence 时只能记录 metadata，不默认采集 stdout 全量。
4. SwiftPM 是库项目 adoption 的重要入口，但不应阻塞 iOS app P0。

### LLDB Debug

XcodeBuildMCP debug 层抽象了 `DebuggerManager`，支持 `lldb-cli` 与 `dap` backend。manager 管理 session、current session、attach/detach、breakpoint、stack、variables、continue、raw command，并用 activity lease 防止 daemon idle shutdown。UI automation guard 会在 app paused 时阻止或警告 UI 操作。

TritonKit P3 再吃：

1. 先实现 `debug attach/detach/continue/stack/eval` 最小闭环。
2. debug session 必须显式 opt-in，不进入默认 smoke。
3. UI automation 需要检查 debug session 状态，paused 时默认阻止 runtime/host UI 操作或返回明确 warning。
4. DAP backend 价值高，但实现复杂；首期可先用 `xcrun lldb --no-lldbinit` CLI backend。

### Device / macOS / Host UI / Scaffolding

device 与 macOS workflow 能力完整，但签名、provisioning、真实设备连接、平台差异都会显著放大测试成本。host UI automation 与 embedded runtime 存在语义重叠，scaffolding 属于低频辅助。

分期建议：

1. Device：P2/P3，先做 list/use/install/launch，再做 build/test；签名只读诊断，不自动改账号资产。
2. macOS：P3，复用 xcodebuild pipeline，但 target = macos。
3. Host UI：P3，只处理系统 UI、SpringBoard、Simulator.app，不处理 App 内常规 AX。
4. Scaffolding：P4，作为模板生成辅助，不进真实回归主路径。

## TritonKit 目标技术方案

### Internal Service Layout

```text
TritonKitCLI
  +-- XcodeWorkflowCommands
  +-- XcresultCommands
  +-- CoverageCommands
  +-- LogsCommands
  +-- SwiftPMCommands
  +-- DebugCommands

TritonKitShared
  +-- TKHostCapabilityDescriptor
  +-- TKXcodeDiscoveryModels
  +-- TKXcodeBuildModels
  +-- TKXcresultModels
  +-- TKCoverageModels
  +-- TKHostProgressEvent

Host Services
  +-- TKXcodeWorkflowService
  +-- TKXcodebuildRunner
  +-- TKXcodebuildParser
  +-- TKXcresultReader
  +-- TKCoverageReader
  +-- TKLogCaptureService
  +-- TKDebugSessionService
```

### P0 Command Contract

P0 最小闭环应只包含：

```bash
triton xcode discover --path . --json
triton xcode use --workspace App.xcworkspace --scheme App --configuration Debug --simulator <udid> --json
triton xcode schemes --workspace App.xcworkspace --json
triton xcode settings --workspace App.xcworkspace --scheme App --json
triton xcode build --jsonl
triton xcode test --result-bundle /tmp/App.xcresult --jsonl
triton xcode run --jsonl
triton xcresult summary --path /tmp/App.xcresult --json
triton xcresult failures --path /tmp/App.xcresult --json
```

P0 暂不做 coverage/log stream/debug/device/macOS。`xcode run` 可以复用已实现的 `triton sim/app` host adapter 能力，避免再造 simctl install/launch。

### Artifact Layout

默认写入：

```text
.triton/
  host-defaults.json
  DerivedData/
    <project>-<hash>/
  artifacts/
    xcode/
      <timestamp>-build.log
      <timestamp>-test.log
      <timestamp>-result.xcresult
    logs/
      <bundle-id>-console-<timestamp>.log
      <bundle-id>-oslog-<timestamp>.log
```

允许用户显式指定 `/tmp` 或其他 output path。禁止把 build/test/log 产物散落在 repo root。

### Error Code

P0 至少稳定以下错误：

```text
xcode_not_available
xcodebuild_failed
xcresulttool_failed
xccov_failed
invalid_workspace_path
invalid_project_path
ambiguous_workspace
ambiguous_scheme
scheme_not_found
simulator_not_found
app_path_unresolved
bundle_id_unresolved
result_bundle_not_found
coverage_not_available
```

### Test Fixture Strategy

1. discovery fixtures：多 workspace、多 project、Pods/DerivedData 忽略、symlink root escape。
2. `xcodebuild -list` fixtures：正常 schemes、空 schemes、错误输出。
3. `-showBuildSettings` fixtures：标准 key/value、preamble、missing app path fields。
4. build/test stdout fixtures：compile、link、warning/error、test case、summary、xcresult path。
5. xcresult reader：用 JSON fixture 先测 parser，再用本机 smoke 测真实 `xcresulttool`。
6. coverage reader：用 `xccov --json` fixture 先测 parser，真实 coverage 作为可选 smoke。
7. CLI schema tests：`schema --command xcode|xcresult|coverage|logs|spm|debug`。

## 不建议直接整合的部分

1. 不引入 XcodeBuildMCP YAML manifest 文件格式作为 TritonKit 外部配置。可以做 Swift 内部 descriptor。
2. 不把 `xcodebuildmcp daemon` 与 TritonKit `triton serve` 并存为两个常驻服务。
3. 不把 `raw` transcript 作为默认 agent 输出；raw 只能作为调试和 evidence artifact。
4. 不首期引入 Xcode IDE Bridge。它依赖 IDE 内部 MCP bridge，风险和环境耦合高。
5. 不让 UI automation workflow 覆盖 Triton embedded runtime 的 App 内 find/tap/assert。
6. 不在 P0 处理 signing mutation、device provisioning mutation、runtime disk image 管理、project scaffolding。

## 实施顺序

1. 先补 shared models：discovery、defaults、build/test event、summary、diagnostics、artifacts。
2. 实现 pure parser 与 fixture tests：discovery、scheme list、build settings、xcodebuild line parser、xcresult summary/failure parser。
3. 接 CLI P0：discover/use/schemes/settings/build/test/run/xcresult。
4. 让 build/test/run 产物进入 `.tritonevidence`。
5. 补 P1：coverage、logs、evidence include xcode。
6. P2 再进入 SwiftPM/device；P3 再进入 debug/macOS/host UI。

## 风险

1. Xcode 输出随版本变化：必须保留 raw log artifact，并把 parser 设计成 best-effort。
2. `xcresulttool` 子命令变化：需要按 Xcode version 做兼容层。
3. signing / device 权限不可控：P0 不进入 device build/test。
4. daemon 生命周期：logs/debug/background run 必须有 activity lease 与清理策略。
5. 真实项目多 scheme / 多 workspace：P0 必须宁可返回 ambiguous，也不要自动猜错。
6. 与 embedded runtime 语义冲突：host run 只证明进程启动，不证明业务 ready。
