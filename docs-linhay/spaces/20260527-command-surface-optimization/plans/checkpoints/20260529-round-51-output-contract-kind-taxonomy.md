# Round 51 - output contract kind taxonomy

## 目标

锁定 `triton schema` 中 `outputContracts[].kind` 的 agent-facing 语义分类，避免新增输出模型时写入未登记的临时 kind。

## 完成结果

- 新增 `SchemaFactSourceTests.schemaOutputContractKindsStayWithinAgentTaxonomy`。
- 将现有输出 contract kind 收敛为显式允许集合，覆盖 bootstrap、runtime、observe、action、assert、evidence、host、Xcode progress/final event 和 artifact envelope。
- 当前 schema 已满足该不变量，没有发现越界 kind。
- 同步更新 agent-facing CLI 信息架构文档、AI CLI 控制文档，以及三个 public skill 的输出 kind 契约说明。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaOutputContractKindsStayWithinAgentTaxonomy`：通过，1 个 Swift Testing 用例通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests`：通过，42 个 Swift Testing 用例通过。
- `swift test --package-path CLI`：通过，113 个 Swift Testing 用例通过。

## 风险与后续

- 该测试会让新增输出模型时必须同步登记 kind；这是预期的 agent-facing schema 变更门禁。
- 下一轮可继续收敛 command-level `outputFormats[]` taxonomy，或检查 output contract field `type` taxonomy。

## 提交状态

未提交。
