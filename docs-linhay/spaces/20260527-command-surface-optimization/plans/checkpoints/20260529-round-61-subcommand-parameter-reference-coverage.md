# Round 61: Subcommand Parameter Reference Coverage

## 目标

继续收紧 schema 的 agent 可发现性，确保 `subcommands[]` 中声明的参数要求都能回到父命令 schema 中解析。

## 改动

- 新增 `SchemaFactSourceTests.subcommandParameterReferencesStayCoveredByParentSchema`。
- 新增 `schemaKnownParameterKeys(_:)` helper，汇总父命令 `options[]` 中的 flag key 和 `argumentForms[]` 中的位置参数 key。
- 测试覆盖 `subcommands[].requiredOptions[]`、`optionalOptions[]` 与 `oneOfRequiredOptions[]`。
- 首次红灯暴露 `xcode discover:--path`、`xctrace record:--template`、`xctrace record:--output`、`coverage report:--xcresult` 和 `coverage report:--output` 只被子命令引用，父 schema 未声明。
- 修正 `CLISchemaXcodeCommands.swift`，在对应父命令 schema 中补齐 `--path`、`--template`、`--output` 与 `--xcresult`。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/subcommandParameterReferencesStayCoveredByParentSchema`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：全部通过。CLI 全量测试当前为 122 个 Swift Testing 用例通过。

## 风险与后续

- 本轮只补齐 schema 事实源和不变量，不改变命令 runtime 行为。
- 下一步建议 Round 62 治理命令级 requirement 的机器可读表达，避免 `requiredOptions[]` 中残留 `workspace defaults or --workspace|--project + --scheme` 这类人读摘要。
