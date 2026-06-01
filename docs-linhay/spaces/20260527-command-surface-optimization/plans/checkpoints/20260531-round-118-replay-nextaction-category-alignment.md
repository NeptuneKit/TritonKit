# Round 118 - replay nextAction category alignment

## 本切片目标

把 `failureError.nextAction` 的恢复阶段也显式并入 `failureRecoveryCategories[]`，避免 replay 失败结果在“具体命令”与“恢复阶段”两个层面出现不一致。

## 完成结果

- 新增测试：当 `failureCode` 自带恢复阶段较窄时，只要 `failureError.nextAction.category` 存在，就必须被并入 `failureRecoveryCategories[]`。
- `replayFailureRecoveryCategories(...)` 现在会在 `failureCode` 默认映射之外，追加 `failureError.nextAction.category` 并去重。
- docs / memory / checkpoint 已同步更新：`failureError.nextAction` 的命令路径和阶段路径都必须在 replay 顶层 failure surface 可见。

## 影响文件

- `CLI/Tests/TritonKitCLITests/ReplayCommandTests.swift`
- `Sources/TritonKitCLI/CLIEvidenceRuntime.swift`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- `docs-linhay/memory/2026-05-31.md`

## 验证

- `swift test --package-path CLI --filter ReplayCommandTests`

## 剩余风险

- 当前只保证 category 至少出现，不保证 `failureError.nextAction.category` 一定排在 `failureRecoveryCategories[]` 的最前面。
- `TKCommandRecoveryCommand.recoveryCategories(forFailureCode:)` 仍然比 schema test 使用的更宽 failure-family 分类表保守，未来若要统一 taxonomy，还需要单独切片治理。

## 下一步

继续考虑是否要把 `failureError.nextAction.category` 与 `recoveryCommands[].category` 建成顺序级优先级不变量，而不只是集合包含关系。
