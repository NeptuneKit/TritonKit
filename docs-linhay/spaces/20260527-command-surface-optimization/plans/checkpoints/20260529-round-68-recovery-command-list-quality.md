# Round 68: Recovery Command List Quality

## 目标

继续收紧 `nextCommands[]` 的 agent 可消费质量。Round 67 已要求 failure code 能导向恢复路径；本轮确保恢复建议列表本身没有空项和同层重复项。

## 改动

- 新增 `SchemaFactSourceTests.schemaRecoveryCommandListsStayClean`。
- 测试覆盖 command 级和 subcommand 级 `nextCommands[]`。
- 测试要求同一层级的恢复建议不能包含空字符串。
- 测试要求同一层级的恢复建议不能重复，避免 agent 对候选恢复动作做额外去重。
- 当前 schema 直接满足该不变量，本轮不修改 schema 数据或 runtime 行为。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaRecoveryCommandListsStayClean`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：全部通过。`SchemaFactSourceTests` 当前为 58 个 Swift Testing 用例通过；CLI 全量测试当前为 129 个 Swift Testing 用例通过。

## 风险与后续

- 本轮只检查列表质量，不判断某条恢复建议与某个具体 failure code 的精确语义映射。
- 下一步建议 Round 69：抽取 recovery command taxonomy，或建立 failure code -> recovery category 的轻量映射规则。
