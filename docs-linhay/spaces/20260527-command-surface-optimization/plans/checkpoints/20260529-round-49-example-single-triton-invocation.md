# Round 49 - schema examples single Triton invocation

## 目标

锁定 `triton schema` 中 `examples[]` 的 agent 可复用边界：每条 example 必须恰好包含一个可抽取的 `triton` invocation。

## 完成结果

- 新增 `SchemaFactSourceTests.schemaExamplesContainOneTritonInvocationForAgentReuse`。
- 允许 example 为 stdin 或批量输入准备上下文，例如 `printf ... | triton input ...`。
- 禁止单条 example 包含多个 `triton` 调用，避免 agent 将多步 shell 流程误判为单步 argv 样本。
- 同步更新 agent-facing CLI 信息架构文档、AI CLI 控制文档，以及三个 public skill 的 schema/example 契约说明。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaExamplesContainOneTritonInvocationForAgentReuse`：通过，1 个 Swift Testing 用例通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests`：通过，40 个 Swift Testing 用例通过。
- `swift test --package-path CLI`：通过，111 个 Swift Testing 用例通过。

## 风险与后续

- 当前只约束 example 中 Triton invocation 数量；shell 上下文分类仍可继续细化。
- 下一轮可继续强化 `outputContracts[].format` taxonomy，或把 examples 的 shell 准备语义沉淀为更明确的 schema metadata。

## 提交状态

未提交。
