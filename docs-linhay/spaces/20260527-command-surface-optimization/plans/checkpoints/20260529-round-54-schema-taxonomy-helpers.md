# Round 54 - schema taxonomy helpers

## 目标

降低 `SchemaFactSourceTests` 中固定 taxonomy 集合的维护成本，避免 capability group、workflow、evidence、output contract format/kind 和 command output format 分散在多个测试方法内。

## 完成结果

- 新增测试 helper：
  - `capabilityGroupTaxonomy()`
  - `capabilityWorkflowTaxonomy()`
  - `capabilityEvidenceTaxonomy()`
  - `outputContractFormatTaxonomy()`
  - `outputContractKindTaxonomy()`
  - `commandOutputFormatTaxonomy()`
- 替换对应测试内的 inline `Set<String>`。
- 测试语义保持不变，后续新增 taxonomy 值时有单一修改入口。
- 本轮不改变 CLI runtime、schema 数据或 public skill 契约。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests`：通过，44 个 Swift Testing 用例通过。
- `swift test --package-path CLI`：通过，115 个 Swift Testing 用例通过。

## 风险与后续

- 这是测试维护性改动，不改变对外行为。
- 下一轮可继续抽取 schema issue collection helpers，或新增一个更高价值的 schema 不变量。

## 提交状态

未提交。
