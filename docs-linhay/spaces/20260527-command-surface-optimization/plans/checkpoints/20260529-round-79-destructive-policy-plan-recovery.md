# Round 79: Destructive Policy Plan Recovery

## 目标

把 destructive / confirmation failure family 从“可分类”推进到“命令级可恢复”：凡是 command / subcommand 声明破坏性策略或确认失败码，都必须在 `recoveryCommands[]` 中暴露 `plan` category。

覆盖失败码：

- `confirmation_required`
- `destructive_action_requires_policy`

## 变更

- 新增 `SchemaFactSourceTests.destructivePolicyFailureCodesExposePlanRecoveryCategories`。
- 将 schema fact source 的 failure family recovery enrichment 扩展到 destructive / confirmation failure。
- 声明 destructive / confirmation 失败码的 schema 自动补齐 `triton plan --format json`。
- 保持 `nextCommands[]` 去重，并继续让 `recoveryCommands[]` 从最终 `nextCommands[]` 派生。
- 同步更新 agent-facing CLI 文档、AI CLI 当前契约文档、三份 public skill 和 memory。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/destructivePolicyFailureCodesExposePlanRecoveryCategories`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：

- 聚焦 destructive / confirmation failure recovery 测试通过。
- `SchemaFactSourceTests` 69 项通过。
- CLI 全量 140 项通过。

## 后续

- 继续按单一 failure family 收紧恢复覆盖，例如 JavaScript / WebView failure 必须导向 `observe` 或 `diagnose`。
- 或检查 `recoveryCommands[]` 与 `capabilities[].nextAction` / `plan.steps[]` 的恢复分类一致性。

## 提交状态

未提交，未 push，未 tag，未 release。
