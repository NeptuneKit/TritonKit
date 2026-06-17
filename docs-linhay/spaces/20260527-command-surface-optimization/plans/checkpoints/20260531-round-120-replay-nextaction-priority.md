# Round 120 - replay nextAction priority

## 本切片目标

把 replay failure surface 对 `failureError.nextAction` 的要求从“必须出现”继续收紧到“必须成为首选恢复路径”，避免 agent 在顶层恢复面里还要自己重排 command/category 的优先级。

## 完成结果

- `TKReplayResult` 现在会统一规范化三层 recovery surface：
  - `failureRecoveryCategories[]` 会把 `failureError.nextAction.category` 移到首位
  - `suggestedCommands[]` 会把 `triton <nextAction.command> ...` 移到首位
  - `recoveryCommands[]` 会在显式传入旧顺序时同样把对应 recovery command 移到首位并去重
- `replayFailureRecoveryCategories(...)` 也同步采用相同优先级规则，保证 CLI runtime 当场产出的 replay JSON 与 shared model 离线构造/解码保持一致。
- 新增 shared / CLI tests，覆盖：
  - 旧 payload 或显式传入的 recovery surface 已经包含 nextAction，但顺序不对时，必须自动重排到第一位
  - `target_unavailable` 这类 failure code family 已有多阶段恢复时，`nextAction.category` 仍必须压到第一推荐阶段

## 影响文件

- `Sources/TritonKitShared/TKReplayPlanModels.swift`
- `Sources/TritonKitCLI/CLIEvidenceRuntime.swift`
- `Tests/TritonKitSharedTests/TKReplayPlanModelsTests.swift`
- `CLI/Tests/TritonKitCLITests/ReplayCommandTests.swift`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- `docs-linhay/memory/2026-05-31.md`

## 验证

- `swift test --filter TKReplayPlanModelsTests`
- `swift test --package-path CLI --filter ReplayCommandTests`

## 剩余风险

- 当前 replay failure surface 的顺序规则已经统一，但聚合逻辑仍分布在 shared model 和 CLI helper 两处；后续若继续扩展 failure ordering 或 artifact ordering，可能需要再下沉一层共享 helper。
- `历史检索嵌入` 仍然存在 chunk failed 的历史问题，虽然不影响本轮 checkpoint 可检索，但会影响长期索引质量，需要单独治理。

## 下一步

继续检查 replay failure surface 是否还需要把 `failureError.nextAction` 和 `failureCode` family 之间的冲突策略显式化，例如何时允许更广的 failure family 覆盖次级恢复阶段、何时只保留 nextAction 单一路径。
