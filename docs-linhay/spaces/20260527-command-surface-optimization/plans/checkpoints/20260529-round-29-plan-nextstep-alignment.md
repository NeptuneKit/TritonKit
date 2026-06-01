# Round 29: Plan Next Step Alignment

## 目标

确保 `triton plan` 顶层 `nextStep` 可以直接定位到同一响应中的 `steps[].id`。

## 红灯

新增 `SchemaFactSourceTests.workflowPlanNextStepPointsToAnEmittedStep` 后，聚焦测试失败：

- 已连接 runtime 的通用 plan 返回 `nextStep=observe`。
- 但 steps 中只有 `geometry`、`ax`、`wait`、`hit`、`input`、`screenshot`、`export`，没有 `id=observe`。

## 修复

- 已连接 runtime 的通用 plan 改为 `nextStep=geometry`，指向首个实际观察步骤。
- 新测试覆盖 server 不可达、server 可达但无 target、已连接 target，以及 `ios-smoke/open-url/webview-check` 三类任务 plan。
- 更新 agent-facing CLI 信息架构文档、AI CLI 可读控制文档和 public skills。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/workflowPlanNextStepPointsToAnEmittedStep` 通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests` 通过，25 个 Swift Testing 用例。
- `swift test --package-path CLI` 通过，96 个 Swift Testing 用例。

## 风险

- 本轮只校验 `nextStep` 指针存在，不校验该 step 是否一定适合当前运行环境；这由 capabilities 和 step 的 `requiresServer/requiresTarget` 继续辅助判断。

## 后续

Round 30 建议减少测试重复：抽取 workflow plan fixtures，避免 Round 18/28/29 三处重复构造同一批 plans。
