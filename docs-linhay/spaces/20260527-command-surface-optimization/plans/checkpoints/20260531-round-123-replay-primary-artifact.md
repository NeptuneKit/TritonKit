# Round 123 - replay primary artifact

## 本切片目标

把 replay 顶层 failure surface 的“首选证据面”从数组首元素提升成显式字段，让 agent 不再必须扫描 `failurePrimaryArtifacts[]` 才知道优先看哪个 artifact。

## 完成结果

- `TKReplayResult` 新增顶层字段：
  - `failurePrimaryArtifact: TKEvidenceArtifactSummary?`
- 该字段支持两类回填：
  - shared model 默认构造时回退到 `failurePrimaryArtifacts.first`
  - 旧 JSON 解码时若缺字段，也回退到 `failurePrimaryArtifacts.first`
- `replay.result` schema output contract 已同步暴露该字段。
- 新增 shared / schema tests，覆盖：
  - 真实 replay result 派生出的 primary artifact
  - 旧 payload 从 `failurePrimaryArtifacts[]` 回填 `failurePrimaryArtifact`
  - schema fact source 中 `replay.result` 字段集合同步更新

## 影响文件

- `Sources/TritonKitShared/TKReplayPlanModels.swift`
- `Sources/TritonKitCLI/CLISchemaContracts.swift`
- `Tests/TritonKitSharedTests/TKReplayPlanModelsTests.swift`
- `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- `docs-linhay/memory/2026-05-31.md`

## 验证

- `swift test --filter TKReplayPlanModelsTests`
- `swift test --package-path CLI --filter SchemaFactSourceTests`

## 剩余风险

- 当前 replay 顶层已经有首选 workflow lane、recovery lane 和 artifact，但仍没有单值“首选下一命令”；若 agent 需要完全避免 `recoveryCommands[]` 的数组扫描，后续还可以考虑补 `failurePrimaryRecoveryCommand` 一类字段。
- `failurePrimaryArtifact` 只是 `failurePrimaryArtifacts[]` 的显式首元素，不额外说明排序原因；如后续要做更强的可解释审计，可再把排序依据结构化。

## 下一步

继续考虑是否把 replay 顶层“首选下一命令”也显式化，进一步减少 agent 对 `recoveryCommands[]` 与 `suggestedCommands[]` 的排序依赖。
