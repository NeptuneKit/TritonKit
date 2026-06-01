# Round 119 - replay shared nextAction backfill

## 本切片目标

把 replay 恢复面的一致性从 CLI runtime 下沉到 shared `TKReplayResult`，避免离线解码旧 payload 或其他调用方手工构造结果时丢失 `failureError.nextAction` 对应的恢复命令和恢复阶段。

## 完成结果

- `TKReplayResult` 初始化与解码现在都会自动规范化 recovery surface：
  - `failureRecoveryCategories[]` 会补齐 `failureError.nextAction.category`
  - `suggestedCommands[]` 会在缺失时回填 `triton <nextAction.command> ...`
  - `recoveryCommands[]` 会基于规范化后的 `suggestedCommands[]` 自动生成
- 新增 shared tests，覆盖两类场景：
  - 手工构造 `TKReplayResult` 时自动补齐 nextAction 命令与 category
  - 解码缺少 recovery surface 的旧 JSON 时自动回填同样的信息
- docs / memory / checkpoint 已同步更新：replay failure surface 的一致性不再依赖 CLI runtime 执行路径，shared model 本身就提供兜底。

## 影响文件

- `Sources/TritonKitShared/TKReplayPlanModels.swift`
- `Tests/TritonKitSharedTests/TKReplayPlanModelsTests.swift`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- `docs-linhay/memory/2026-05-31.md`

## 验证

- `swift test --filter TKReplayPlanModelsTests`
- `swift test --package-path CLI --filter ReplayCommandTests`

## 剩余风险

- 当前只保证 nextAction 对应的 command/category 会出现并去重，不保证它在所有恢复数组里都严格占据第一优先级。
- CLI runtime 与 shared model 目前各自维护一份 replay failure surface 聚合逻辑；若后续继续扩展 recovery ordering，可能需要再抽一层共享 helper。

## 下一步

继续考虑是否把 `failureError.nextAction` 提升为 replay recovery surface 的显式首选路径，包括 category 排序和 `recoveryCommands[0]` 的优先级约束。
