# XcodeBuildMCP Reference

## 来源

- GitHub: `https://github.com/getsentry/XcodeBuildMCP`
- 文档: `https://www.xcodebuildmcp.com/docs/tools`
- 架构: `https://www.xcodebuildmcp.com/docs/architecture`
- 输出格式: `https://www.xcodebuildmcp.com/docs/output-formats`

## 项目定位

XcodeBuildMCP 是 Sentry 维护的 Model Context Protocol server 和 CLI，用于让 AI agent 处理 iOS / macOS 项目中的 Xcode 构建、运行、测试、模拟器管理、设备管理、日志、调试和 UI 自动化。它同时提供终端 CLI 和 MCP server 两种入口，并支持通过 Homebrew 或 npm 安装。

## 对 TritonKit 的参考价值

1. **双入口但同一能力层**：XcodeBuildMCP 同时暴露 CLI 与 MCP server，适合参考其“工具能力和用户入口分离”的结构。TritonKit 应保持 CLI/HTTP schema 为事实契约，未来如提供 MCP，只应做薄适配层。
2. **workflow 分组**：其能力按 simulator、simulator-management、ui-automation、debugging、device 等 workflow 管理。TritonKit 可以采用类似分组，但命名应面向 agent 的稳定任务：`sim`、`app`、`host`、`logs`、`perf`、`runtime`。
3. **共享 handler**：公开架构强调 CLI 和 MCP 复用同一批 command handler，避免两套实现分叉。TritonKit 的 CLI、HTTP 和未来 MCP 也应复用同一 domain service。
4. **结构化输出与进度事件**：XcodeBuildMCP 文档将工具输出分为 structured、streaming、JSONL progress 等形态。TritonKit 应延续已有 JSON envelope，并为长任务使用 JSONL event。
5. **workspace-scoped daemon**：XcodeBuildMCP CLI 为日志、调试等状态型能力使用 per-workspace daemon。TritonKit 已有 `triton serve`，可扩展为 simulator session daemon，而不是让每个命令各自维护状态。
6. **默认值与 session state**：XcodeBuildMCP 有 session defaults，用于避免反复传 project、scheme、simulator。TritonKit 应提供 `triton sim use` / `triton config set defaultSimulator` 类能力，减少 agent 高频参数。

## 不直接复用的原因

1. TritonKit 的核心产品入口是 `triton` CLI/HTTP 机器可读契约，不应把用户暴露给第二套 CLI 或 MCP 工具名。
2. XcodeBuildMCP 主要围绕 Xcode project build/run/test 与 MCP 工具调用；TritonKit 还需要和 embedded runtime、`.tritonplan`、evidence、AX、in-app 控制闭环合并。
3. TritonKit 需要控制 DEBUG-only runtime 边界和对业务 App 的接入方式；这部分不属于 XcodeBuildMCP 的职责。
4. 直接依赖 Node 生态会改变 TritonKit 当前 Swift CLI 的发布和运行时边界。可以参考架构，也可以在未来做 optional bridge，但首选实现应在 `triton` 内部。

## 可借鉴能力清单

- 官方文档截至 2026-05-20 显示 v2.5.2、79 个 tools、15 个 workflows；TritonKit 以 workflow 能力对齐，不逐个复刻 MCP tool name。
- Project / workspace discovery。
- Simulator build、run、test。
- Simulator boot、open、erase、appearance、location。
- App install、launch、terminate、logs。
- UI automation：截图、层级、点击、滑动、输入、按键。
- LLDB 调试、断点、堆栈和变量。
- Xcode result / test result 报告。
- Code coverage：从 xcresult 读取 target 摘要和函数级未覆盖行。
- Swift Package Manager：build、test、run，并通过 daemon 管理后台进程。
- Project scaffolding：从模板创建 iOS / macOS 项目。
- Workflow discovery / session management：按 agent 任务动态控制工具面和默认 project、scheme、simulator。

## TritonKit 采纳原则

1. 借鉴 workflow 和 handler 结构，不复制工具命名。
2. 所有能力先进入 `triton schema --json`，再进入 README / skills 示例。
3. 所有长任务输出 JSONL progress，最终输出 summary envelope。
4. 可以调用 `xcrun`、`xcodebuild`、`devicectl` 等官方工具作为底层执行，不要求复刻 XcodeBuildMCP 的 Node 实现。
5. 如果未来提供 MCP server，应是 `triton` CLI/HTTP 的适配器，不重新定义业务能力。

## 源码深挖结论

本次本地源码快照位于 `/tmp/xcodebuildmcp`，重点阅读路径：

- `src/core/manifest/schema.ts`
- `src/runtime/tool-catalog.ts`
- `src/types/domain-fragments.ts`
- `src/types/domain-results.ts`
- `src/utils/xcodebuild-line-parsers.ts`
- `src/utils/xcodebuild-domain-results.ts`
- `src/utils/xcodebuild-pipeline.ts`
- `src/utils/derived-data-path.ts`
- `src/utils/app-path-resolver.ts`
- `src/utils/bundle-id.ts`
- `src/utils/simulator-steps.ts`
- `src/utils/test-preflight.ts`
- `src/utils/xcresult-test-failures.ts`
- `src/mcp/tools/coverage/get_coverage_report.ts`
- `src/mcp/tools/coverage/get_file_coverage.ts`
- `src/mcp/tools/swift-package/*.ts`
- `src/mcp/tools/debugging/*.ts`
- `src/daemon/*.ts`

关键架构点：

1. **Manifest 是能力元数据，不是业务实现**：tool manifest 声明 workflow、availability、routing、structured output schema、next-step params；runtime tool catalog 再按 CLI/MCP/daemon 过滤和解析。
2. **Domain fragment 与 final result 分层**：长任务 streaming 先产出 `DomainFragment`，例如 build stage、compiler diagnostic、test progress、test failure；结束后再产出 `ToolDomainResult`，例如 build-result、test-result、coverage-result。
3. **JSONL 是 domain fragment 的投影**：它不是 raw stdout/stderr 的直接转储，而是渲染层把 domain fragment 映射成可读事件名。
4. **DerivedData scoped by workspace**：默认 DerivedData 不依赖 Xcode 全局位置，而是按 workspace identity 落到工具管理目录，便于 artifact 归档和清理。
5. **App path 从 build settings 解析**：通过 `BUILT_PRODUCTS_DIR + FULL_PRODUCT_NAME` 得到 `.app` 路径；bundle id 从 Info.plist 读取。
6. **xcresult 优先于 stdout parser**：test counts / failure details 优先用 `xcresulttool get test-results ...`，stdout parser 作为 streaming 和 fallback。
7. **coverage 基于 xccov**：target summary 用 `xccov view --report --json`，函数级覆盖用 `--functions-for-file`，未覆盖行区间从 `--archive --file` 解析。
8. **logs 是两路 capture**：simulator app stdout/stderr 用 `simctl launch --console-pty`，OSLog 用 `simctl spawn <udid> log stream --predicate subsystem == bundleId`。
9. **SwiftPM background run 依赖 daemon 活动租约**：后台进程通过 process registry 管理 PID，daemon idle shutdown 不应杀掉活跃进程。
10. **debug 是独立有状态系统**：`DebuggerManager` 支持 `lldb-cli` 与 DAP backend，管理 session、current session、breakpoints、stack、variables；UI automation guard 会在 app paused 时阻断或警告 UI 操作。

对 TritonKit 的具体吸收：

1. 建立 Swift-native capability descriptor，支撑 `triton schema --json`、CLI、HTTP 和 future MCP。
2. 为 `xcode build/test/run` 新增统一 progress event 与 final summary model。
3. P0 只做 discovery/use/schemes/settings/build/test/run/xcresult；coverage/logs/evidence include xcode 放 P1；SwiftPM/device 放 P2；debug/macOS/host UI 放 P3。
4. 复用现有 `triton sim/app` host adapter 完成 `xcode run` 的 install/launch，不重复封装 simctl。
5. 不引入 XcodeBuildMCP daemon、YAML manifest、Node runtime 或 Xcode IDE Bridge 作为 TritonKit 默认依赖。

## Xcode Workflow Takeover

- Space：`docs-linhay/spaces/20260520-xcode-workflow-takeover/README.md`
- 技术设计：`docs-linhay/spaces/20260520-xcode-workflow-takeover/technical-design.md`
- 深度技术调研：`docs-linhay/spaces/20260520-xcode-workflow-takeover/deep-technical-research-20260520.md`
- 项目 skill：`.agents/skills/tritonkit-xcode-workflow-takeover/SKILL.md`

采纳结论：能进入真实开发/回归闭环的能力尽量吃进 `triton`，包括 discovery、session defaults、build/test/run、xcresult、coverage、logs、SwiftPM、device/macOS workflow、LLDB 和必要 host UI；不适合作为 TritonKit 产品契约的部分不吃，包括 XcodeBuildMCP tool name、Node runtime 必依赖、MCP workflow gating、Xcode IDE Bridge 作为首期依赖，以及会替代 embedded runtime 语义的 UI 自动化。
