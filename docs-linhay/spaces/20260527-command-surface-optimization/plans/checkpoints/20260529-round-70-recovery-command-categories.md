# Round 70: Recovery Command Categories

## 目标

在 Round 69 的 recovery root taxonomy 上继续增加恢复阶段分类。agent 不只要知道某个 root command 能作为恢复建议，还要知道它属于诊断、发现、准备目标、观察、动作、验证、归档、replay、smoke 还是 plan。

## 改动

- 新增 `SchemaFactSourceTests.schemaRecoveryCommandRootsExposeStableCategories`。
- 新增 `recoveryCommandCategoryTaxonomy()`，固定 category 集合：
  - `diagnose`
  - `discover`
  - `prepare-target`
  - `project`
  - `observe`
  - `act`
  - `verify`
  - `archive`
  - `replay`
  - `smoke`
  - `plan`
- 新增 `recoveryCommandRootCategoryMap()`，要求 recovery root taxonomy 和 category map 一一覆盖。
- 测试覆盖 command 级和 subcommand 级 `nextCommands[]` 实际使用的 root command。
- 当前 schema 直接满足该不变量；本轮不修改 schema 数据或 runtime 行为。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaRecoveryCommandRootsExposeStableCategories`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：全部通过。`SchemaFactSourceTests` 当前为 60 个 Swift Testing 用例通过；CLI 全量测试当前为 131 个 Swift Testing 用例通过。

## 风险与后续

- 当前 category 仍是测试 helper 级事实源，尚未进入 `triton schema --json` 的 wire model。
- 下一步建议 Round 71：评估是否把 recovery category 暴露到 schema wire model，或先建立 failure code family 到 recovery category 的测试映射。
