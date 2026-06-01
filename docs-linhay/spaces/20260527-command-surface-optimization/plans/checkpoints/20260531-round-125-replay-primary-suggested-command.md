# Round 125 - replay primary suggested command

## 本切片目标

把 replay 顶层 failure surface 的“首选建议命令字符串”从 `suggestedCommands[]` 的隐式首元素提升成显式字段，兼容只消费字符串命令、不解析 structured recovery command 的 agent。

## 完成结果

- `TKReplayResult` 新增顶层字段：
  - `failurePrimarySuggestedCommand: String?`
- 该字段支持两类回填：
  - shared model 默认构造时回退到 `suggestedCommands.first`
  - 旧 JSON 解码时若缺字段，也回退到 `suggestedCommands.first`
- `replay.result` schema output contract 已同步暴露：
  - `failurePrimarySuggestedCommand`
- 新增 shared / CLI / schema tests，覆盖：
  - 真实 replay result 派生出的 primary suggested command
  - `failureError.nextAction` 驱动的首选建议字符串与顶层单值字段保持一致
  - 旧 payload 从 `suggestedCommands[]` 回填 `failurePrimarySuggestedCommand`
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

- `failurePrimarySuggestedCommand` 只是 `suggestedCommands[]` 的显式首元素，不额外说明排序来源；如果后续要区分它来自 `nextAction`、failure family 还是显式注入，还需要额外来源字段。
- 当前顶层同时暴露 `failurePrimarySuggestedCommand` 与 `failurePrimaryRecoveryCommand`，消费方仍需自己决定优先采用纯字符串入口还是结构化入口。

## 下一步

继续考虑是否给 replay 顶层补“primary diagnostic hint”或“primary nextAction”快捷字段，进一步减少 agent 在恢复前的对象解包成本。
