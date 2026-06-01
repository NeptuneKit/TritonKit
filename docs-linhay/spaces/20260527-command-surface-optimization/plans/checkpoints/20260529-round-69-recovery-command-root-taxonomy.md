# Round 69: Recovery Command Root Taxonomy

## 目标

把 `nextCommands[]` 的根命令收敛到固定 recovery taxonomy。恢复建议不应只是“schema-backed 任意命令”，还应属于明确的诊断、发现、目标选择、工程/Xcode、观察、动作、断言、证据、replay 或 smoke 入口。

## 改动

- 新增 `SchemaFactSourceTests.schemaRecoveryCommandRootsStayWithinRecoveryTaxonomy`。
- 新增 `recoveryCommandRootTaxonomy()` 测试 helper，固定当前可作为恢复建议根命令的集合。
- 新增 `tritonRootCommand(in:)` helper，用于从 `nextCommands[]` 的单条 `triton ...` invocation 中提取 root command。
- 测试覆盖 command 级和 subcommand 级 `nextCommands[]`。
- 当前 schema 直接满足该不变量；本轮不修改 schema 数据或 runtime 行为。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaRecoveryCommandRootsStayWithinRecoveryTaxonomy`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：全部通过。`SchemaFactSourceTests` 当前为 59 个 Swift Testing 用例通过；CLI 全量测试当前为 130 个 Swift Testing 用例通过。

## 风险与后续

- taxonomy 当前按 root command 粒度约束，不区分同一 root 下不同子命令的恢复角色。
- 下一步建议 Round 70：继续把 recovery taxonomy 拆成轻量 category，例如 `diagnose`、`discover`、`prepare-target`、`observe`、`verify`、`archive`，再逐步映射到 failure code 类型。
