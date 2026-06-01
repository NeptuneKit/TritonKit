# Round 127 - replay primary next action

## 本切片目标

把 replay 顶层 failure surface 的“首选结构化 next action”从 `failureError.nextAction` 的隐式子字段提升成显式字段，让 agent 不解包 `TKCLIErrorDetail` 也能直接读取恢复动作。

## 完成结果

- `TKReplayResult` 新增顶层字段：
  - `failurePrimaryNextAction: TKCLINextAction?`
- 该字段支持两类回填：
  - shared model 默认构造时回退到 `failureError?.nextAction`
  - 旧 JSON 解码时若缺字段，也回退到 `failureError?.nextAction`
- `replay.result` schema output contract 已同步暴露：
  - `failurePrimaryNextAction`
  - `failurePrimaryNextAction.command`
  - `failurePrimaryNextAction.args`
  - `failurePrimaryNextAction.category`
  - `failurePrimaryNextAction.requiresLongRunningProcess`
- 新增 shared / CLI / schema tests，覆盖：
  - 真实 replay result 从 `failureError.nextAction` 派生出的 primary next action
  - 旧 payload 从 `failureError.nextAction` 回填 `failurePrimaryNextAction`
  - 没有 next action 的场景保持 `nil`
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

- `failurePrimaryNextAction` 只是 `failureError.nextAction` 的单值快捷字段，不额外解释动作来源；如果未来需要区分 runtime transport、validation 或 artifact-write 来源，还需要 provenance 字段。
- 当前 replay 顶层 failure surface 的单值摘要已经较完整，但仍未提供“首选 endpoint”或“首选 nearest candidates”这类更窄诊断快捷字段。

## 下一步

继续评估是否要为 replay 顶层失败面补更多“只读快捷摘要”，或暂停 replay failure surface 收紧，转到其他 agent-facing command surface 缺口。
