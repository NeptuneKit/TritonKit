# P23 CLI Product Surface Re-architecture

## 背景

TritonKit CLI 当前已经覆盖本机服务、自检、target / device / simulator / app、Xcode workflow、runtime observe / action / assert、evidence、replay、test、App Map 与 VLM 等能力。盘点结论是：当前问题主要不是能力缺失，而是产品暴露层设计不足。

现有顶层命令中混合了三类不同层级：

1. 用户与 AI agent 的 workflow 入口，例如 target、app、tap、assert、evidence。
2. 诊断与规划入口，例如 doctor、schema、capabilities、plan。
3. Raw Engine / Runtime 入口，例如 hierarchy、nodes、attrs、object、geometry、runtime、state、ledger。

这会让 CLI 看起来像直接暴露 Engine API，而不是从用户真实 workflow 长出的产品界面。

## North Star

TritonKit 是面向 AI agent 的本机 App 自动化控制面，通过机器可读 CLI / HTTP 契约完成目标发现、App 启动、界面观察、动作执行、断言验证和证据复跑。

## 目标

1. 不删除既有能力，先重排 CLI 暴露层与命令心智。
2. 将 observe、act、verify 定义为 TritonKit 产品主轴，而不是让 hierarchy、tap、assert 分别代表不同抽象层。
3. 明确 Workflow CLI、Diagnostic CLI、Raw Engine CLI 三层边界。
4. 定义 P23-A 到 P23-D 的迁移切片，第一刀只证明新产品语言成立。
5. 后续所有代码迁移必须同步 triton schema、help、plan、docs 与测试。

## 非目标

1. P23-A 不修改 Swift CLI 实现。
2. P23-A 不做全量迁移。
3. P23 最终不保留旧 root 兼容入口；已迁移能力只通过 workflow / debug surface 暴露。
4. 不恢复 Web / Wails 业务控制入口。
5. 不引入远端 agent、设备云、多租户或云端控制面。
6. 不改变当前本机 CLI + HTTP + host-side adapter + embedded runtime 的产品边界。

## BDD 验收场景

### 场景一：形成 CLI IA 裁决文档

- Given 当前 CLI 命令面已经盘点完成
- When P23-A 完成
- Then plans/cli-information-architecture.md 必须定义 North Star、Command Layering、Five Core Workflows、First Success Path、New Top-level Surface、Raw / Debug Surface、Migration Table、Schema Contract 与 P23 迁移切片

### 场景二：后续代码迁移有最小切片

- Given P23-A 只做文档裁决
- When 进入 P23-B / P23-C / P23-D
- Then 第一刀只新增 observe / act / verify 命令壳，并接入少量高频命令
- And 不从全量迁移开始

### 场景三：产品语言优先于 Engine API

- Given 用户或 agent 要完成查看当前界面、点击登录、验证首页、导出证据
- When 读取 P23 IA 文档
- Then 首选命令语言应是 observe current、act tap、verify text-exists、evidence capture
- And hierarchy、tap、assert 只被视为实现能力，不作为可见 root 入口

## 计划

- P23-A：写 CLI IA 裁决文档。
- P23-B：新增 observe / act / verify 命令壳，不先搬所有实现。
- P23-C：把高频命令接入新壳：observe current、act tap、act type、verify text-exists。
- P23-D：更新 help / schema / plan，让新 surface 成为主入口。
- P23-E：为 schema 增加 surface metadata，明确 workflow / diagnostic / raw-engine 分层，并从 schema inventory 隐藏已退休 root。
- P23-F：新增 debug root，承接 raw-engine 能力。
- P23-G：把 evidence capture 做成 Prove workflow 的产品子命令入口。
- P23-H：按“不需要兼容入口”裁决移除已迁移旧 root 的 root help / parser / schema 暴露。

## 当前实现状态（2026-06-21）

- P23-A 已完成：已新增本 space 和 `plans/cli-information-architecture.md`。
- P23-B 已完成第一刀：`observe` 作为既有 workflow surface 保留，新增 `act` 与 `verify` 顶层产品壳。
- P23-C 已完成第一批高频接入：`act tap --text`、`act type`、`verify text-exists`、`verify text-not-exists` 可用；`act` 同时披露并委托 `find/tap/type/paste/clear/swipe/press/focus/set-text/select-segment/set-switch/input`。
- P23-D 已完成第一刀：`triton schema --command act/verify --json`、`act/verify --help`、capability nextAction、workflow plan argv 已切到新产品语言。
- P23-E 已完成第一刀：`TKCommandSchema` 新增 `surfaceLayer`、`deprecatedForMainPath`、`replacementCommand`、`rawDebugCommand`、`surfaceRationale`；schema inventory 只暴露产品 surface，已迁移旧 root 不再可查询。
- P23-F 已完成第一刀：新增 `triton debug` root 壳，挂接 `runtime/state/snapshot/hierarchy/nodes/node/attrs/object/geometry/ax/hit/ledger` raw-engine 命令。
- P23-G 已完成第一刀：新增 `triton evidence capture --case <case> --output <path> --json` 产品入口；不新增 `triton evidence --name/--output ...` 默认入口；`evidence inspect/summary/redact/project-workspace/project-screens` 也作为真实子命令挂接。
- P23-H 已完成第一刀：`runtime/state/snapshot/hierarchy/nodes/node/attrs/object/geometry/ax/hit/ledger/find/tap/type/paste/clear/swipe/press/focus/set-text/select-segment/set-switch/input/assert/capture` 不再出现在 root help、schema inventory 或 parser 入口；能力改由 `debug`、`act`、`verify`、`evidence capture` 承接。
- `wait` 与 `screenshot` 暂保留为 workflow root，后续再单独决定是否并入 `verify/observe`。

## 本轮验证

- `swift test --package-path CLI --filter EvidenceBundleTests --filter ReplayCommandTests`：28 tests / 2 suites passed。
- `swift test --package-path CLI --filter SchemaFactSourceTests --filter SchemaFactSourcePlanTests --filter SchemaFactSourceCapabilityTests --filter SchemaFactSourceSurfaceContractTests --filter SimulatorAdvancedControlsTests`：126 tests / 2 suites passed。
- `swift test --package-path CLI --filter DeviceCrossPlatformTests`：80 tests / 1 suite passed。
- `CLI/.build/debug/triton schema --command act --json`：返回 `act` schema，12 个子命令。
- `CLI/.build/debug/triton schema --command verify --json`：返回 `verify` schema，2 个子命令。
- `CLI/.build/debug/triton debug --help`：返回 raw-engine debug root，并列出第一批 debug 子命令。
- `CLI/.build/debug/triton debug hierarchy --help`、`CLI/.build/debug/triton debug runtime --help`：确认 debug 子命令可解析。
- `CLI/.build/debug/triton schema --command debug --json`：返回 `surfaceLayer=raw-engine`、`deprecatedForMainPath=false`，且包含第一批 raw-engine 子命令。
- `CLI/.build/debug/triton evidence --help`、`CLI/.build/debug/triton evidence capture --help`：确认 evidence 产品子命令面可见。
- `CLI/.build/debug/triton evidence capture --case p23-g --output /tmp/triton-p23-g-invalid.tritonevidence --include bogus --json`：返回单个 JSON validation envelope。
- `CLI/.build/debug/triton evidence --name p23-g --output /tmp/triton-p23-g-removed.tritonevidence --include bogus --json`：返回 ArgumentParser unknown option，确认未保留 `evidence --name/--output` 默认兼容入口。
- `CLI/.build/debug/triton schema --command evidence --json`：返回 `evidence capture` 子命令、`--case` option 与 `evidence.manifest` output selector。
- `CLI/.build/debug/triton schema --command capture --json`：返回 `unknown_command_schema`，确认旧 root 不再暴露。
- `CLI/.build/debug/triton act tap --text 登录 --json`：无 runtime 时返回单个 JSON failure envelope。
- `CLI/.build/debug/triton verify text-exists 首页 --json`：无 runtime 时返回单个 JSON failure envelope。
- `CLI/.build/debug/triton schema --command tap --json`：返回 `unknown_command_schema`，确认旧 action root 不再暴露。
- `CLI/.build/debug/triton schema --command hierarchy --json`：返回 `unknown_command_schema`，确认 raw root 不再暴露。
- `CLI/.build/debug/triton tap --help`、`CLI/.build/debug/triton runtime --help`：返回 exit 64 unknown subcommand，确认 parser 入口不兼容。
- `swift test --package-path CLI`：403 tests / 34 suites passed。

## 关联文档

- CLI Information Architecture: plans/cli-information-architecture.md
- Agent-facing CLI Information Architecture: docs-linhay/dev/agent-facing-cli-information-architecture.md
- AI CLI Readable Control: docs-linhay/dev/ai-cli-readable-control.md
