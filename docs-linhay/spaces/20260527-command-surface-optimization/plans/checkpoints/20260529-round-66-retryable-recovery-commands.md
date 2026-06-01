# Round 66: Retryable Recovery Commands

## 目标

让 `retryable=true` 具备可执行恢复路径，避免 agent 只看到“可重试”但不知道下一步该做什么。

## 改动

- 新增 `SchemaFactSourceTests.retryableSchemasExposeRecoveryCommands`。
- 测试要求 command 级和 subcommand 级 `retryable=true` 时必须暴露非空 `nextCommands[]`。
- 首次红灯暴露：`xcode discover/use/schemes/status/wait-idle/settings`、`xctrace` / `xctrace record`、`coverage` / `coverage report` 缺少恢复建议。
- 补齐 Xcode 子命令恢复路径：
  - `discover` 后建议 `xcode use`。
  - `use` 后建议 `schemes` / `settings`。
  - `schemes` 后建议 `xcode use`。
  - `status` 后建议 `wait-idle`。
  - `wait-idle` 后建议 `status`。
  - `settings` 后建议 `build` / `run`。
- 补齐 `xctrace` 与 `coverage` command/subcommand 的 evidence 归档建议。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/retryableSchemasExposeRecoveryCommands`
- `swift test --package-path CLI --filter SchemaFactSourceTests/subcommandNextCommandsStayAlignedWithCommandSchemas`
- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaNextCommandsStayAlignedWithCommandSchemas`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：全部通过。CLI 全量测试当前为 127 个 Swift Testing 用例通过。

## 风险与后续

- 本轮只保证 retryable schema 有 schema-backed 下一步建议，不验证每条 next command 在真实项目中一定成功。
- 下一步建议 Round 67 检查 `nextCommands[]` 与 `retryable` / `failureCodes[]` 的语义密度，例如失败码存在但没有对应恢复命令的命令面。
