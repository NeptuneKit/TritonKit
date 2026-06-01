# Round 80: Unsupported Failure Plan Recovery

## 目标

把 unsupported failure family 从“可分类”推进到“命令级可恢复”：凡是 command / subcommand 声明不支持能力、运行时范围或 WebView 方法失败码，都必须在 `recoveryCommands[]` 中暴露 `plan` category。

覆盖失败码：

- `action_not_supported`
- `unsupported_capability`
- `unsupported_runtime_scope`
- `webview_method_not_allowed`
- `webview_wait_unsupported`

## 变更

- 新增 `SchemaFactSourceTests.unsupportedFailureCodesExposePlanRecoveryCategories`。
- 将 schema fact source 的 failure family recovery enrichment 扩展到 unsupported failure。
- 声明 unsupported 失败码的 schema 自动补齐 `triton plan --format json`。
- 保持 `nextCommands[]` 去重，并继续让 `recoveryCommands[]` 从最终 `nextCommands[]` 派生。
- 同步更新 agent-facing CLI 文档、AI CLI 当前契约文档、三份 public skill 和 memory。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/unsupportedFailureCodesExposePlanRecoveryCategories`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：

- 聚焦 unsupported failure recovery 测试通过。
- `SchemaFactSourceTests` 70 项通过。
- CLI 全量 141 项通过。

## 后续

- 继续检查 `recoveryCommands[]` 与 `capabilities[].nextAction` / `plan.steps[]` 的恢复分类一致性。
- 或按剩余高优先级 failure family 继续收紧命令级 recovery category 覆盖。

## 提交状态

未提交，未 push，未 tag，未 release。
