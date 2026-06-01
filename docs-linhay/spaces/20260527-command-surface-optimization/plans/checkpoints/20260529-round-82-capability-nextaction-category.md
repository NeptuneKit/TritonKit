# Round 82: Capability NextAction Category

## 目标

让 `triton capabilities --json` 中的 `capabilities[].nextAction` 不只告诉 agent 可执行命令，也直接暴露该命令所属的恢复/工作流阶段。agent 应能读取 `nextAction.category`，而不是重新解析 `nextAction.command`。

## 变更

- `TKCLINextAction` 新增 `category` 字段。
- `category` 默认按 `TKCommandRecoveryCommand.category(forRootCommand:)` 从 `command` 自动派生。
- `TKCLINextAction` 的 decoder 对旧 JSON 兼容：缺少 `category` 时按 `command` 派生。
- `capabilities` output contract 新增 `capabilities[].nextAction.category` 字段说明。
- 新增 `SchemaFactSourceTests.capabilityNextActionsExposeStableRecoveryCategories`，要求 capability nextAction category 非空、落在 recovery taxonomy，且与 command root category 一致。
- 同步更新 agent-facing CLI 文档、AI CLI 当前契约文档、三份 public skill 和 memory。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/capabilityNextActionsExposeStableRecoveryCategories`
- `swift test --package-path CLI --filter SchemaFactSourceTests/agentBootstrapSchemasExposeRecoveryCommandsAndOutputContracts`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：

- 聚焦 capability nextAction category 测试通过。
- capabilities output contract 聚焦测试通过。
- `SchemaFactSourceTests` 72 项通过。
- CLI 全量 143 项通过。

## 后续

- 检查 `doctor.checks[].nextAction` 是否也需要 output contract 中显式暴露 `category`。
- 或继续按剩余高优先级 failure family 收紧命令级 recovery category 覆盖。

## 提交状态

未提交，未 push，未 tag，未 release。
