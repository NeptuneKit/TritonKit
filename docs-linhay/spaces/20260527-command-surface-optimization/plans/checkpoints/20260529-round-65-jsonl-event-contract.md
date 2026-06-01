# Round 65: JSONL Event Contract

## 目标

稳定长任务 JSONL 事件契约，让 agent 能依赖 `jsonlEvents[]` 与 `finalEventKind` 判断进度事件和最终 summary。

## 改动

- 新增 `SchemaFactSourceTests.schemaJSONLEventsExposeStableEventKeys`。
- 新增 `isAgentEventKey(_:allowingPlaceholders:)` helper。
- 测试要求 command 级和 subcommand 级 `jsonlEvents[]` 不重复，使用稳定点分 event key。
- command 级 event key 允许完整 token 占位符，例如 `xcode.<action>.summary`；subcommand 级 event key 必须使用具体 action，例如 `xcode.build.summary`。
- `finalEventKind` 必须出现在同层级 `jsonlEvents[]` 中。
- 声明 JSONL event 的 command 必须在 `outputFormats[]` 中暴露 `jsonl`。
- 当前 schema 直接满足该不变量；本轮不修改 runtime 行为或 schema 数据。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaJSONLEventsExposeStableEventKeys`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：全部通过。CLI 全量测试当前为 126 个 Swift Testing 用例通过。

## 风险与后续

- 当前只验证 schema 事件名和 final 覆盖关系，不验证实际 JSONL runtime 是否逐行发出所有事件。
- 下一步建议 Round 66 检查 `retryable` 与 failure code / next command 的关系，避免声明可重试但没有恢复路径。
