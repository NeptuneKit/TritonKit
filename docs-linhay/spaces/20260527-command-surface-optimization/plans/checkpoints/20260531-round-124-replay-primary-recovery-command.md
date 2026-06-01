# Round 124 - replay primary recovery command

## 本切片目标

把 replay 顶层 failure surface 的“首选恢复命令”从 `recoveryCommands[]` 的隐式首元素提升成显式字段，让 agent 不再需要先读完整恢复命令数组再决定第一步。

## 完成结果

- `TKReplayResult` 新增顶层字段：
  - `failurePrimaryRecoveryCommand: TKCommandRecoveryCommand?`
- 该字段支持两类回填：
  - shared model 默认构造时回退到 `recoveryCommands.first`
  - 旧 JSON 解码时若缺字段，也回退到 `recoveryCommands.first`
- `replay.result` schema output contract 已同步暴露：
  - `failurePrimaryRecoveryCommand`
  - `failurePrimaryRecoveryCommand.command`
  - `failurePrimaryRecoveryCommand.category`
- 新增 shared / CLI / schema tests，覆盖：
  - 真实 replay result 派生出的 primary recovery command
  - 旧 payload 从 `recoveryCommands[]` 回填 `failurePrimaryRecoveryCommand`
  - `failureError.nextAction` 驱动的首选恢复命令与顶层单值字段保持一致
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

- 当前 replay 顶层已经有首选 workflow lane、recovery lane、artifact 和 recovery command，但仍没有单值“首选建议字符串”；如果外部消费方只处理 `suggestedCommands[]` 而不解析 structured recovery command，仍然要自己取首元素。
- `failurePrimaryRecoveryCommand` 只是 `recoveryCommands[]` 的显式首元素，不额外记录排序依据；若后续要做更强解释，可再把来源标成 `nextAction` / `derived` / `family-bridge` 一类枚举。

## 下一步

继续考虑是否给 replay 顶层补“primary suggested command string”或“primary diagnostic hint”字段，进一步减少 agent 在错误恢复前的数组和对象推断成本。
