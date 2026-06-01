# Round 57: Failure Code Key Style

## 目标

收紧 agent-facing schema 的失败诊断契约：`failureCodes[]` 不仅要存在并保持父子覆盖，还必须是可直接映射恢复分支的稳定机器 key。

## 改动

- 新增 `SchemaFactSourceTests.schemaFailureCodesUseStableSnakeCase`。
- 要求 command 与 subcommand 的 `failureCodes[]` 全部使用 lower_snake_case。
- 要求同一 command 或 subcommand 内的 `failureCodes[]` 不重复。
- 新增 `isSnakeCaseKey(_:)` 测试 helper，和 selector / kind 的 kebab key helper 分开表达。
- 同步更新 agent-facing CLI 信息架构、AI CLI 可读控制文档，以及三个 public skills 的失败码契约口径。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaFailureCodesUseStableSnakeCase`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：全部通过。CLI 全量测试当前为 118 个 Swift Testing 用例通过。

## 风险与后续

- 本轮只新增测试和文档约束，不改变 runtime 行为。
- 下一轮可继续检查 command / subcommand / option 名称风格，或把 key grammar helper 进一步整理成更明确的测试工具层。
