# 20260520 Xcode Workflow Takeover

## 结论

本 space 的目标是把 XcodeBuildMCP 中适合 TritonKit 的能力吃进 `triton`，但不照搬 XcodeBuildMCP 的 MCP tool name、Node runtime、workflow gating 或会和 embedded runtime 冲突的语义。

采用策略：

1. **吃能力**：project discovery、scheme/build settings、build/test/run、xcresult、coverage、logs、SwiftPM、device/macOS workflow、LLDB 和必要的 host UI 能力都进入 TritonKit 长期路线。
2. **不吃 API**：外部只暴露 `triton xcode`、`triton xcresult`、`triton coverage`、`triton logs`、`triton spm`、`triton debug`、`triton device` 等稳定命令，不暴露 XcodeBuildMCP tool 名。
3. **不吃运行时依赖**：首选 Swift 原生 host adapter 封装 Apple 官方 CLI；必要时短期 bridge 只能作为内部 fallback，输出必须转成 Triton JSON/JSONL envelope。
4. **不替换 runtime**：App 内 AX、tap/type/wait/assert/evidence/replay 仍由 Triton embedded runtime 主导；Xcode/host UI 只补 build/test、系统 UI、日志、调试和宿主侧证据。

## 参考

- XcodeBuildMCP GitHub：`https://github.com/getsentry/XcodeBuildMCP`
- XcodeBuildMCP docs：`https://www.xcodebuildmcp.com/docs`
- XcodeBuildMCP tools：`https://www.xcodebuildmcp.com/docs/tools`
- XcodeBuildMCP workflows：`https://www.xcodebuildmcp.com/docs/workflows`
- 本地参考归档：`docs-linhay/references/xcodebuildmcp.md`
- Harness 参考：`docs-linhay/references/harness.md`
- 深度技术调研：`docs-linhay/spaces/20260520-xcode-workflow-takeover/deep-technical-research-20260520.md`
- Simulator takeover：`docs-linhay/spaces/20260520-simulator-takeover/README.md`

截至 2026-05-20，XcodeBuildMCP 文档显示 v2.5.2、79 个 tools、15 个 workflows。本 space 按 workflow 能力拆解，而不是按 MCP tool name 逐个复刻。

## 目标

1. 让 agent 可以从“拿到一个 iOS/macOS/SwiftPM repo”开始，通过 `triton` 完成发现、选择、构建、运行、测试、日志、结果、覆盖率和证据归档。
2. 把 Xcode project、simulator、installed app、embedded runtime target 绑定成同一个可审计 target graph。
3. 所有长任务输出 JSONL progress，最终输出 summary envelope。
4. build/test/log/coverage 结果进入 `.tritonevidence`，可被 issue、回归报告和 `.tritonplan` 复用。
5. 保留 XcodeBuildMCP 的好设计：workflow 分组、session defaults、共享 handler、structured output、workspace daemon。

## 非目标

1. 不把 XcodeBuildMCP MCP server 作为 TritonKit 的默认运行依赖。
2. 不向用户暴露 XcodeBuildMCP 的 tool name 或 workflow 配置文件。
3. 不用 XcodeBuildMCP 替换 Triton embedded runtime 的 App 内观察和控制。
4. 不默认启用破坏性 simulator/runtime 维护命令。
5. 不首期做 Xcode IDE Bridge；IDE 内部 bridge 不是 agent 回归闭环的必要条件。
6. 不把 project scaffolding 放在真实项目回归主路径；它只作为低频辅助能力。

## 能力矩阵

| XcodeBuildMCP 能力 | TritonKit 决策 | 目标命令面 | 备注 |
| --- | --- | --- | --- |
| Project / workspace discovery | 吃进来 | `triton xcode discover/list-schemes/settings` | P0，agent 进入未知 repo 的第一步 |
| Session defaults | 吃进来 | `triton xcode use ...`、`.triton/host-defaults.json` | 复用 `triton sim use` 思路 |
| Simulator build | 吃进来 | `triton xcode build --jsonl` | P0/P1，封装 `xcodebuild` |
| Simulator test | 吃进来 | `triton xcode test --result-bundle ... --jsonl` | P0/P1，结果交给 `xcresult` |
| Build-run 一体化 | 吃进来 | `triton xcode run --jsonl` | build -> install -> launch -> optional runtime wait |
| App install/launch/terminate | 已部分吃进来 | `triton app install/launch/terminate` | 已有 P0，后续和 `xcode run` 串联 |
| Simulator lifecycle | 已部分吃进来 | `triton sim list/use/boot/shutdown/screenshot` | 后续补 privacy/location/ui/logs |
| Logs capture/stream | 吃进来 | `triton logs stream/collect --jsonl` | P1，回归证据核心 |
| xcresult summary | 吃进来 | `triton xcresult summary/failures/attachments` | P1，测试失败定位 |
| Coverage | 吃进来 | `triton coverage report` | P1/P2，覆盖率报告 artifact |
| Instruments trace | 吃进来 | `triton xctrace record` | P1/P2，性能 trace 作为 host artifact，不证明业务成功 |
| SwiftPM build/test/run | 吃进来 | `triton spm build/test/run --jsonl` | P2，适合库项目和 CLI 项目 |
| Physical device workflow | 吃进来但延后 | `triton device list/use/install/launch/build/test` | P2/P3，基于 `devicectl`，签名复杂度高 |
| macOS app workflow | 吃进来但延后 | `triton macos build/test/run` 或并入 `triton xcode` | P3，非 iOS 回归主路径 |
| LLDB debugging | 吃进来但显式 opt-in | `triton debug attach/breakpoint/stack/eval` | P3，不能成为默认 smoke |
| Host UI automation | 吃进来但边界独立 | `triton host ui snapshot/tap/type/press` | 只处理系统 UI / SpringBoard，不替代 embedded runtime |
| Simulator advanced management | 部分吃进来 | `triton sim erase/clone/rename/runtime/pair` | P4，默认不推荐，破坏性命令需显式策略 |
| Project scaffolding | 可选低频 | `triton scaffold ios/macos` | P4，不进真实项目回归主路径 |
| Xcode IDE Bridge | 不吃 | 无 | IDE 内部桥接不是稳定 CLI/HTTP 契约 |
| MCP tool registry / workflow gating | 不吃 API | 未来 `triton mcp` 只做薄适配 | Triton schema 才是事实契约 |
| Node/TS runtime implementation | 不吃依赖 | 无 | 可参考，不做默认依赖 |

## 验收场景

### 场景一：未知仓库发现

- Given agent 进入一个 iOS/macOS repo
- When 执行 `triton xcode discover --path . --json`
- Then 输出 workspace/project/package、schemes、bundle id 候选、默认 simulator 推荐和下一步命令
- And 多候选时返回 candidates，不默认猜测

### 场景二：设置 Xcode session defaults

- Given repo 有 workspace、scheme 和 simulator
- When 执行 `triton xcode use --workspace App.xcworkspace --scheme App --configuration Debug --simulator <udid> --json`
- Then `.triton/host-defaults.json` 记录 workspace、scheme、configuration、simulator
- And 后续 `xcode build/test/run` 可省略重复参数

### 场景三：构建并运行 App

- Given defaults 已配置
- When 执行 `triton xcode run --jsonl`
- Then 依次输出 build、install、launch progress
- And 最终 summary 包含 `.app` path、bundle id、simulator udid、pid、log artifact
- And 若 embedded runtime 连接成功，返回 runtime target binding

### 场景四：测试与 xcresult 汇总

- Given project 有可运行 test scheme
- When 执行 `triton xcode test --result-bundle /tmp/app.xcresult --jsonl`
- Then JSONL 输出 build/test progress
- And summary 包含 passed/failed/skipped、失败测试、result bundle path
- When 执行 `triton xcresult failures --path /tmp/app.xcresult --json`
- Then 返回可供 issue 直接引用的失败摘要

### 场景五：覆盖率

- Given test result 含 coverage
- When 执行 `triton coverage report --xcresult /tmp/app.xcresult --output /tmp/coverage.json --json`
- Then 输出机器可读 artifact envelope
- And 完整 coverage JSON 只写入 artifact，不内嵌到 CLI summary

### 场景六：Instruments trace

- Given agent 需要宿主侧性能证据
- When 执行 `triton xctrace record --template "Time Profiler" --device <udid> --time-limit 5s --output /tmp/app.trace --json`
- Then 返回机器可读 artifact envelope
- And `.trace` 只作为证据，不等价于业务 ready 或测试通过

### 场景七：证据包整合

- Given build/test/run 已执行
- When 执行 `triton capture --case login --include host,xcode,runtime --output /tmp/login.tritonevidence --json`
- Then evidence 包含 build log、test summary、xcresult summary、coverage summary、host screenshot、runtime ax/screenshot 和 action trace

## 分期

### 当前实现状态（2026-05-23）

P0 最小 `triton xcode` 入口已落地：

- `triton xcode discover --path . --json`
- `triton xcode use --workspace <path>|--project <path> --scheme <scheme> --configuration Debug --simulator <udid> --json`
- `triton xcode schemes --json`
- `triton xcode status --json`
- `triton xcode wait-idle --workspace <workspace> --timeout <seconds> --json`
- `triton xcode settings --jsonl --timeout <seconds>`
- `triton xcode build --jsonl --timeout <seconds>`
- `triton xcode test --result-bundle /tmp/App.xcresult --jsonl`
- `triton xcode run --jsonl`
- `triton xctrace record --template "Time Profiler" --device <udid> --time-limit 5s --output /tmp/App.trace --json`
- `triton coverage report --xcresult /tmp/App.xcresult --output /tmp/coverage.json --json`

执行边界：

1. XcodeBuildMCP 继续作为能力参考，不再作为默认 agent 执行入口；agent 面优先使用 `triton xcode`。
2. `xcode run` 只覆盖 build、simulator install、simulator launch，不声明业务 ready；后续必须接 `triton status/wait/find/assert/screenshot/evidence`。
3. `xcode settings/build/test/run --jsonl` 已输出 invocation、stdout/stderr sample、heartbeat、summary，以及 stdout/stderr log path 和 byte count；真实项目卡住时先看这些 artifact，不再盲等。
4. `xcode build` 的成功 summary 是纯 build 结束边界；它不再在 summary 后隐式执行 `xcodebuild -showBuildSettings -json`。需要 `.app` 路径时使用 `xcode settings` 或 `xcode run`，其中 `xcode run --jsonl` 会把 settings 解析暴露为 `xcode.run.settings.*` 进度事件。
5. `xcode status/wait-idle` 是只读 best-effort host 诊断：先用 `pgrep` 缩小 Xcode build/test 相关 PID，再用 `ps -p` 采样，避免全量进程输出卡住；无法可靠推断的 workspace/scheme/destination 字段保持为空或低置信度。
6. `xctrace record` 和 `coverage report` 已先落为 artifact 型契约：Triton 只返回 artifact path、bytes/truncation 或 source command 摘要，不把大型 `.trace` / coverage JSON 当作 inline 输出。
7. `xcresult` summary/failures/attachments、coverage 语义汇总和 evidence 深度整合仍在后续切片，不在本次内宣称完成。

### P0：Xcode workflow 最小闭环

- `triton xcode discover`
- `triton xcode use`
- `triton xcode schemes`
- `triton xcode status`
- `triton xcode wait-idle`
- `triton xcode settings`
- `triton xcode build --jsonl`
- `triton xcode test --jsonl --result-bundle`
- `triton xcode run --jsonl`
- `triton xcresult summary/failures`

### P1：真实回归报告闭环

- `triton coverage report`
- `triton xctrace record`
- `triton logs stream/collect`
- `capture/evidence --include xcode,host`
- build/test/run 进入 `.tritonplan`
- test failure issue template 输出

### P2：SwiftPM 与真机

- `triton spm build/test/run`
- `triton device list/use/install/launch`
- 真机 build/test/run
- signing / provisioning 诊断只做读取和提示，不自动改账号资产

### P3：调试、macOS、host UI

- `triton debug attach/breakpoint/stack/eval`
- macOS app build/test/run
- host UI snapshot/tap/type/press
- record video / diagnose / performance trace

### P4：低频辅助

- project scaffolding
- simulator runtime maintenance
- watch pair / multi-device topology
- Xcode MCP bridge 兼容层

## 完成定义

1. `triton schema --command xcode --json` 可发现 P0 命令。
2. 未知 repo 能通过 `discover -> use -> build/test/run` 完成闭环。
3. `xcresult` 失败摘要和 coverage 能进入 `.tritonevidence`。
4. 所有命令有稳定 JSON/JSONL 和 error code。
5. XcodeBuildMCP 只作为参考或内部 bridge，不成为用户-facing API。
