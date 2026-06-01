# Round 129 - replay error subfield completion

## 本切片目标

补齐 replay output contract 对 `TKCLIErrorDetail` 既有诊断子字段的显式声明，让 agent 不靠 DTO 猜测也知道 `nearestCandidates`、`suggestedCommands`、`candidateCount` 在 replay 顶层和 step-level error surface 上可读。

## 完成结果

- `replay.result` schema output contract 新增显式字段：
  - `failureError.nearestCandidates`
  - `failureError.suggestedCommands`
  - `failureError.candidateCount`
  - `steps[].error.nearestCandidates`
  - `steps[].error.suggestedCommands`
  - `steps[].error.candidateCount`
- 共享 model 无需改动：`TKCLIErrorDetail` 已经具备这些字段，本轮收的是 machine-readable contract，而不是 DTO 形状。
- `SchemaFactSourceTests` 已同步更新，锁定 `replay.result` 字段集合。

## 影响文件

- `Sources/TritonKitCLI/CLISchemaContracts.swift`
- `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- `docs-linhay/memory/2026-05-31.md`

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests`

## 剩余风险

- 当前补的是 replay contract；其他命令如果也暴露 `TKCLIErrorDetail`，仍可能存在类似“DTO 有字段、schema 没展开”的缺口。
- 顶层 replay failure surface 经过多轮收紧后已经较厚，后续更适合回到跨命令 schema/doctor/capabilities/plan 的职责边界整理，而不是只在 replay 上深挖。

## 下一步

继续评估是否把同类 error subfield contract 补到其他高频 agent-facing 命令，或转回 bootstrap / capability / plan 的信息架构收敛。
