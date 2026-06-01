# Round 28: Plan Step Contract

## 目标

让 `triton plan` 的所有步骤都成为可执行、可校验的 agent command，而不是混入自然语言动作。

## 红灯

新增 `SchemaFactSourceTests.workflowPlanStepsExposeExecutableMetadata` 后，聚焦测试失败：

- 通用 plan 的 `connect-target` step 输出 `open the iOS app or run the simulator build that embeds TritonKit`。
- 该字符串不是 `triton ...` 命令，agent 无法直接执行，也无法通过 schema / failure code 做恢复。

## 修复

- `connect-target` step 改为 `triton xcode run --json`。
- 保留 `expected` 中对连接到 `ws://<host>:<port>/` 的说明，作为执行后的验收预期。
- 新测试覆盖 server 不可达、server 可达但未连接 target、已连接 target，以及 `ios-smoke/open-url/webview-check` 三类任务计划。
- 测试要求每个 step 的 `id`、`title`、`command`、`when`、`expected` 非空，同一 plan 内 step id 不重复，并且 `command` 能被 schema 解释。
- 更新 agent-facing CLI 信息架构文档、AI CLI 可读控制文档和 public skills。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/workflowPlanStepsExposeExecutableMetadata` 通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests` 通过，24 个 Swift Testing 用例。
- `swift test --package-path CLI` 通过，95 个 Swift Testing 用例。

## 风险

- `triton xcode run --json` 是默认推荐入口；如果工作区没有 Xcode project，agent 仍需根据 schema/failure code 改走 `app launch`、`smoke ios` 或外部构建流程。

## 后续

Round 29 建议检查 plan `nextStep` 是否能在 `steps[].id` 中找到，避免 plan 顶层恢复指针与步骤列表脱节。
