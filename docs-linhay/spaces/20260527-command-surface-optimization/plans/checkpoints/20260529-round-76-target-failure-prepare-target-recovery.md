# Round 76: Target Failure Prepare-Target Recovery

## 目标

把 target failure family 从“可分类”推进到“命令级可恢复”：凡是 command / subcommand 声明 target 类失败码，都必须在 `recoveryCommands[]` 中暴露 `prepare-target` category。

覆盖失败码：

- `ambiguous_target`
- `device_not_ready`
- `simulator_not_found`
- `target_not_found`
- `target_offline`
- `target_unavailable`

## 变更

- 新增 `SchemaFactSourceTests.targetFailureCodesExposePrepareTargetRecoveryCategories`。
- 在 `commandSchemas()` fact source 层新增 target failure recovery enrichment：声明上述失败码的 schema 自动补齐 `triton target resolve <selector> --json`。
- 保持 `nextCommands[]` 去重，并继续让 `recoveryCommands[]` 从最终 `nextCommands[]` 派生。
- 同步更新 agent-facing CLI 文档、AI CLI 当前契约文档、三份 public skill 和 memory。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/targetFailureCodesExposePrepareTargetRecoveryCategories`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：

- 聚焦 target failure recovery 测试通过。
- `SchemaFactSourceTests` 66 项通过。
- CLI 全量 137 项通过。

## 后续

- 继续按单一 failure family 收紧恢复覆盖，例如 project / Xcode failure 必须导向 `project`。
- 或检查 `recoveryCommands[]` 与 `capabilities[].nextAction` / `plan.steps[]` 的恢复分类一致性。

## 提交状态

未提交，未 push，未 tag，未 release。
