# Round 67: Failure Code Recovery Path

## 目标

让稳定失败码和恢复建议形成闭环。只声明 `failureCodes[]` 只能帮助 agent 分类错误；本轮要求 agent 还能从同一份 schema 找到下一条可执行恢复命令。

## 改动

- 新增 `SchemaFactSourceTests.failureCodesExposeARecoveryCommandPath`。
- 测试要求有 `failureCodes[]` 的 command 必须有非空命令级 `nextCommands[]`。
- 测试要求有 `failureCodes[]` 的 subcommand 如果自身没有 `nextCommands[]`，父命令必须提供可继承的恢复路径。
- 首次红灯暴露：`serve`、`ax`、`swipe`、`type`、`paste`、`clear`、`press` 有失败面但缺少恢复建议。
- 补齐 `serve` 恢复建议：`status`、`doctor`、`capabilities`。
- 补齐 `ax` 恢复建议：`observe current`、`screenshot`、`evidence`。
- 补齐 `swipe`、`type`、`paste`、`clear` 恢复建议：`status`、`ax`、`evidence`。
- 补齐 `press` 恢复建议：`status`、`schema --command press`、`evidence`。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/failureCodesExposeARecoveryCommandPath`
- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaNextCommandsStayAlignedWithCommandSchemas`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：全部通过。CLI 全量测试当前为 128 个 Swift Testing 用例通过。

## 风险与后续

- 本轮验证恢复建议存在且能被 schema 解释，不验证每个 failure code 都由一条特定建议精确覆盖。
- 下一步建议 Round 68 检查恢复建议语义密度，或先抽取 recovery taxonomy / helper，避免恢复契约测试继续膨胀。
