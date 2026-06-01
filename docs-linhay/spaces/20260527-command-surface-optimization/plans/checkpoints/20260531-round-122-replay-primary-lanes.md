# Round 122 - replay primary lanes

## 本切片目标

把 replay 顶层 failure surface 的“首选 lane”从隐式数组首元素变成显式字段，让 agent 不再每次都自己从 `failureWorkflowCategories[]` 和 `failureRecoveryCategories[]` 推断第一优先级。

## 完成结果

- `TKReplayResult` 新增两个顶层字段：
  - `failurePrimaryWorkflowCategory: String?`
  - `failurePrimaryRecoveryCategory: String?`
- 这两个字段都支持 shared model 默认构造与旧 JSON 解码回填：
  - 若 payload 未提供，则分别回退到 `failureWorkflowCategories.first` 和 `failureRecoveryCategories.first`
  - 因此旧 replay 结果不会因为缺字段而失去首选 lane 语义
- `replay.result` schema output contract 已同步暴露这两个字段。
- 新增 shared / CLI / schema tests，覆盖：
  - replay result 运行时派生出的 primary workflow / recovery lane
  - 旧 payload 解码回填
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

- 现在 replay 顶层已经同时有“单值首选 lane”和“完整 lane 数组”，但 artifact 侧仍只有数组语义；如果后续 agent 需要一跳拿到最先该看的 artifact，可能还要继续补 `failurePrimaryArtifact` 一类字段。
- 当前顶层 lane 只是 arrays 的显式首选值，不携带“为什么它是第一”的解释；若后续 agent 需要更强的可解释规划，还可以再把排序依据结构化。

## 下一步

继续考虑是否给 replay failure surface 补更显式的“首选证据面”或“首选下一命令”字段，进一步减少 agent 对数组排序和推断规则的依赖。
