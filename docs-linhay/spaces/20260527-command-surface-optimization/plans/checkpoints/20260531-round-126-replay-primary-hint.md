# Round 126 - replay primary hint

## 本切片目标

把 replay 顶层 failure surface 的“首选诊断 hint”从 `failureError.hint` 的隐式子字段提升成显式字段，让 agent 不拆 `TKCLIErrorDetail` 也能直接读取恢复提示。

## 完成结果

- `TKReplayResult` 新增顶层字段：
  - `failurePrimaryHint: String?`
- 该字段支持两类回填：
  - shared model 默认构造时回退到 `failureError?.hint`
  - 旧 JSON 解码时若缺字段，也回退到 `failureError?.hint`
- `replay.result` schema output contract 已同步暴露：
  - `failurePrimaryHint`
- 新增 shared / CLI / schema tests，覆盖：
  - 真实 replay result 从 `failureError.hint` 派生出的 primary hint
  - 旧 payload 从 `failureError.hint` 回填 `failurePrimaryHint`
  - 没有 hint 的场景保持 `nil`
  - schema fact source 中 `replay.result` 字段集合同步更新

## 影响文件

- `Sources/TritonKitShared/TKReplayPlanModels.swift`
- `Sources/TritonKitCLI/CLISchemaContracts.swift`
- `Tests/TritonKitSharedTests/TKReplayPlanModelsTests.swift`
- `CLI/Tests/TritonKitCLITests/ReplayCommandTests.swift`
- `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- `docs-linhay/memory/2026-05-31.md`

## 验证

- `swift test --filter TKReplayPlanModelsTests`
- `swift test --package-path CLI --filter ReplayCommandTests`
- `swift test --package-path CLI --filter SchemaFactSourceTests`

## 剩余风险

- `failurePrimaryHint` 只是 `failureError.hint` 的单值快捷字段，不额外解释 hint 来源；如果未来需要区分 runtime transport、validation 或 artifact-write 来源，还需要额外 provenance 字段。
- 当前顶层仍没有单值 `failurePrimaryNextAction`；若外部消费方不想解析 `failureError.nextAction`，仍需依赖 `failurePrimarySuggestedCommand` 或 `failurePrimaryRecoveryCommand`。

## 下一步

继续考虑是否给 replay 顶层补 `failurePrimaryNextAction`，把结构化恢复动作也收敛成单值快捷入口。
