# Round 77: Project Failure Project Recovery

## 目标

把 Project / Xcode failure family 从“可分类”推进到“命令级可恢复”：凡是 command / subcommand 声明工程或 Xcode 上下文类失败码，都必须在 `recoveryCommands[]` 中暴露 `project` category。

覆盖失败码：

- `ambiguous_workspace`
- `invalid_workspace_path`
- `scheme_not_found`
- `workspace_not_found`
- `xcode_not_idle`

## 变更

- 新增 `SchemaFactSourceTests.projectFailureCodesExposeProjectRecoveryCategories`。
- 将 schema fact source 的 target recovery enrichment 扩展为 failure family recovery enrichment。
- 声明 Project / Xcode 失败码的 schema 自动补齐 `triton xcode discover --path . --json`。
- 保持 `nextCommands[]` 去重，并继续让 `recoveryCommands[]` 从最终 `nextCommands[]` 派生。
- 同步更新 agent-facing CLI 文档、AI CLI 当前契约文档、三份 public skill 和 memory。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/projectFailureCodesExposeProjectRecoveryCategories`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：

- 聚焦 Project / Xcode failure recovery 测试通过。
- `SchemaFactSourceTests` 67 项通过。
- CLI 全量 138 项通过。

## 后续

- 继续按单一 failure family 收紧恢复覆盖，例如 action / step failure 必须导向 `act`。
- 或检查 `recoveryCommands[]` 与 `capabilities[].nextAction` / `plan.steps[]` 的恢复分类一致性。

## 提交状态

未提交，未 push，未 tag，未 release。
