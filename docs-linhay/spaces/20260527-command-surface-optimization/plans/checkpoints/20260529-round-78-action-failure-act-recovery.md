# Round 78: Action Failure Act Recovery

## 目标

把 action / step failure family 从“可分类”推进到“命令级可恢复”：凡是 command / subcommand 声明动作或步骤失败码，都必须在 `recoveryCommands[]` 中暴露 `act` category。

覆盖失败码：

- `action_failed`
- `step_failed`

## 变更

- 新增 `SchemaFactSourceTests.actionFailureCodesExposeActRecoveryCategories`。
- 将 schema fact source 的 failure family recovery enrichment 扩展到 action / step failure。
- 声明 action / step 失败码的 schema 自动补齐 `triton input --json --summary --strict`。
- 保持 `nextCommands[]` 去重，并继续让 `recoveryCommands[]` 从最终 `nextCommands[]` 派生。
- 同步更新 agent-facing CLI 文档、AI CLI 当前契约文档、三份 public skill 和 memory。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/actionFailureCodesExposeActRecoveryCategories`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：

- 聚焦 action / step failure recovery 测试通过。
- `SchemaFactSourceTests` 68 项通过。
- CLI 全量 139 项通过。

## 后续

- 继续按单一 failure family 收紧恢复覆盖，例如 destructive / confirmation failure 必须导向 `plan` 或 `diagnose`。
- 或检查 `recoveryCommands[]` 与 `capabilities[].nextAction` / `plan.steps[]` 的恢复分类一致性。

## 提交状态

未提交，未 push，未 tag，未 release。
