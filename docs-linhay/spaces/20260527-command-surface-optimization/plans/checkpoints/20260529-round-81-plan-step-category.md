# Round 81: Plan Step Category

## 目标

让 `triton plan` 不只输出可执行命令，也直接告诉 agent 每个步骤属于哪个恢复/工作流阶段。agent 应能读取 `plan.steps[].category`，而不是重新解析 `steps[].command` 的 root command。

## 变更

- `TKWorkflowPlanStep` 新增 `category` 字段。
- `category` 默认按 `TKCommandRecoveryCommand.rootCommand(in:)` 与 `category(forRootCommand:)` 自动派生。
- `TKWorkflowPlanStep` 的 decoder 对旧 JSON 兼容：缺少 `category` 时按 `command` 派生。
- `plan.next-steps` output contract 新增 `steps[].id`、`steps[].command` 与 `steps[].category` 字段说明。
- 新增 `SchemaFactSourceTests.workflowPlanStepsExposeStableRecoveryCategories`，要求 plan step category 非空、落在 recovery taxonomy，且与 command root category 一致。
- 同步更新 agent-facing CLI 文档、AI CLI 当前契约文档、三份 public skill 和 memory。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/workflowPlanStepsExposeStableRecoveryCategories`
- `swift test --package-path CLI --filter SchemaFactSourceTests/agentBootstrapSchemasExposeRecoveryCommandsAndOutputContracts`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：

- 聚焦 plan step category 测试通过。
- plan output contract 聚焦测试通过。
- `SchemaFactSourceTests` 71 项通过。
- CLI 全量 142 项通过。

## 后续

- 检查 `capabilities[].nextAction` 是否也需要暴露 category，避免 agent 在 capability 恢复入口上重新解析 command root。
- 或继续按剩余高优先级 failure family 收紧命令级 recovery category 覆盖。

## 提交状态

未提交，未 push，未 tag，未 release。
