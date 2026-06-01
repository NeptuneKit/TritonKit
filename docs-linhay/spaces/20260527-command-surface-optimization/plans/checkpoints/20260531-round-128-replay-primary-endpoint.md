# Round 128 - replay primary endpoint

## 本切片目标

把 replay 顶层 failure surface 的“首选 transport/runtime endpoint”从 `failureError.endpoint` 的隐式子字段提升成显式字段，让 agent 不解包 `TKCLIErrorDetail` 也能直接读取诊断端点。

## 完成结果

- `TKReplayResult` 新增顶层字段：
  - `failurePrimaryEndpoint: String?`
- 该字段支持两类回填：
  - shared model 默认构造时回退到 `failureError?.endpoint`
  - 旧 JSON 解码时若缺字段，也回退到 `failureError?.endpoint`
- `replay.result` schema output contract 已同步暴露：
  - `failurePrimaryEndpoint`
- 新增 shared / CLI / schema tests，覆盖：
  - 真实 replay result 从 `failureError.endpoint` 派生出的 primary endpoint
  - 旧 payload 从 `failureError.endpoint` 回填 `failurePrimaryEndpoint`
  - 没有 endpoint 的场景保持 `nil`
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

- `failurePrimaryEndpoint` 只是 `failureError.endpoint` 的单值快捷字段，不额外区分 transport、runtime request、host adapter 或本地文件端点来源。
- replay 顶层 failure surface 现在已经补了多组单值快捷字段，后续若继续增加，需要警惕顶层 contract 膨胀。

## 下一步

继续评估是补更窄的 failure 快捷字段，还是把收敛重点切回其他 agent-facing command surface 缺口。
