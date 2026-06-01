# Round 85: Plan Step Execution Metadata

## 目标

把 `triton plan --json` 从“命令序列 + 人读说明”继续推进为 agent 可执行、可审计的任务计划。每个 `steps[]` 除了 `command` 和 `category`，还必须暴露机器可读的前置条件、预期证据和停止条件。

## 变更

- `TKWorkflowPlanStep` 新增 `requires`、`expectedArtifacts` 与 `stopConditions` wire 字段。
- 新字段有默认派生逻辑：
  - `requires` 至少包含 `cli.available`，并按 `requiresServer/requiresTarget` 补充 `server.reachable`、`target.ready`、`runtime.connected`。
  - `expectedArtifacts` 至少包含 `stdout-json`，并按命令 root 补充 `target-resolution`、`wait-result`、`assertion-result`、`evidence-bundle`、`smoke-summary`、`xcode-log` 等。
  - `stopConditions` 至少包含 `command.failed`，并按 server/target 和命令 root 补充 `server.unavailable`、`target.unavailable`、`timeout`、`assertion.failed`、`artifact.write-failed` 或 `step.failed`。
- decoder 对旧 JSON 缺失这些字段时自动派生默认值。
- `plan.next-steps` output contract 新增 `steps[].requires`、`steps[].expectedArtifacts` 与 `steps[].stopConditions`。
- 新增 `SchemaFactSourceTests.workflowPlanStepsExposeStructuredExecutionMetadata`，要求所有 plan fixture step 都暴露非空结构化执行元数据，且 key 使用稳定点分 / kebab 语法。
- 共享模型测试补充 plan JSON roundtrip 后的新字段断言。
- 同步更新 agent-facing CLI 文档、AI CLI 当前契约文档、三份 public skill 和 memory。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/workflowPlanStepsExposeStructuredExecutionMetadata`
- `swift test --package-path CLI --filter SchemaFactSourceTests/agentBootstrapSchemasExposeRecoveryCommandsAndOutputContracts`
- `swift test --filter TKCLITransportModelsTests/workflowPlanShape`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`
- `swift test`
- `swift run --package-path CLI triton plan --json`

结果：

- 新增 plan metadata 测试先因缺字段红灯，补齐 wire model / contract 后通过。
- `SchemaFactSourceTests` 75 项通过。
- CLI 全量 146 项通过。
- 根包全量 126 项通过。
- 实际 `triton plan --json` 输出已包含 `steps[].requires`、`steps[].expectedArtifacts` 与 `steps[].stopConditions`。

## 后续

- 继续细化 task plan 的 `expectedArtifacts` 与 `stopConditions` taxonomy，必要时把这些值与 evidence artifact taxonomy / failure code taxonomy 对齐。
- 或推进 `plan inspect` / `.tritonplan` 与 `triton plan` 的字段口径统一。

## 提交状态

未提交，未 push，未 tag，未 release。
