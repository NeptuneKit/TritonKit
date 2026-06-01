# Round 116 - replay error subfield contract

## 本切片目标

把 replay output contract 中的 `steps[].error` 从对象占位推进到显式子字段，和顶层 `failureError.*` 保持一致，方便 agent 直接做字段级读取和索引。

## 完成结果

- `SchemaFactSourceTests` 现在要求 `steps[].error.code/message/endpoint/hint/nextAction.command/args/requiresLongRunningProcess` 全部出现在 `replay.result` contract。
- `replayResultOutputContract()` 已补对应字段说明。
- dev 文档与 memory 已同步更新，明确 replay 顶层与 step-level error surface 需要保持同一套稳定子字段口径。

## 影响文件

- `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`
- `Sources/TritonKitCLI/CLISchemaContracts.swift`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- `docs-linhay/memory/2026-05-31.md`

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests`

## 剩余风险

- 当前 success shape 仍用 `error?` 省略号表达，尚未把每个嵌套字段完全写进 `successShape` 字符串。
- 文本输出仍只打印 `failureError: <code> <message>`，没有把 hint/nextAction 展开到 text 模式。

## 下一步

继续考虑是否要把 `failureError.nextAction` 与 `recoveryCommands[]` 做一致性约束，避免两个恢复入口各说各话。
