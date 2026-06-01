# Round 50 - output contract format taxonomy

## 目标

锁定 `triton schema` 中 `outputContracts[].format` 的 agent-facing 格式 taxonomy，避免 schema 中出现临时自由字符串。

## 完成结果

- 新增 `SchemaFactSourceTests.schemaOutputContractFormatsStayWithinAgentTaxonomy`。
- 固定允许的 output contract format 为 `json`、`jsonl`、`archive`。
- 当前 schema 已满足该不变量，没有发现越界格式。
- 同步更新 agent-facing CLI 信息架构文档、AI CLI 控制文档，以及三个 public skill 的输出格式契约说明。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaOutputContractFormatsStayWithinAgentTaxonomy`：通过，1 个 Swift Testing 用例通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests`：通过，41 个 Swift Testing 用例通过。
- `swift test --package-path CLI`：通过，112 个 Swift Testing 用例通过。

## 风险与后续

- 当前只约束 `outputContracts[].format`；命令级 `outputFormats[]` 仍可在后续单独收敛 taxonomy。
- 下一轮可继续检查 `outputContracts[].kind` taxonomy，或检查 contract fields 的 `type` 是否进入固定类型集合。

## 提交状态

未提交。
