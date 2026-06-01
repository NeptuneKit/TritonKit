# Round 121 - replay recovery family conflict

## 本切片目标

把 replay 顶层 `failureRecoveryCategories[]` 的冲突策略显式化：当 `failureError.nextAction` 和 `failureCode` family 同时存在时，明确哪些阶段应提前展示，哪些只作为后备 family 余项保留。

## 完成结果

- `TKReplayResult` 现在对 `failureRecoveryCategories[]` 采用更明确的排序策略：
  - 没有 `nextAction` 时，继续保持 `failureCode` family 的原始语义和顺序
  - 有 `nextAction` 时，先放 `nextAction.category`
  - 再放当前 `recoveryCommands[]` 真正覆盖到的 category
  - 最后才附加尚未被覆盖的 failure family 余项
- `replayFailureRecoveryCategories(...)` 同步采用同一策略，保证 CLI runtime 当场产物和 shared model 离线构造/解码结果一致。
- 新增 shared / CLI tests，覆盖：
  - `target_unavailable + nextAction=serve + input failure` 时，顶层 category 顺序为 `diagnose -> observe -> archive -> prepare-target`
  - `wait timeout` 这类没有 `nextAction` 的 replay failure 仍保持 `verify` family-first，不被 follow-up 命令稀释

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

- replay failure surface 的排序规则已经比之前清晰，但 artifact 优先级和 workflow lane 仍是独立维度，后续如果 agent 需要单次失败的更强诊断摘要，可能还要继续统一 `failurePrimaryArtifacts[]` 与 `failureWorkflowCategories[]` 的优先级口径。
- `qmd` 的 embedding 过程仍偶发输出 Metal 编译日志；当前不影响检索闭环，但若未来再次出现 chunk failure，需要单独治理。

## 下一步

继续检查 replay failure surface 是否需要把 `failureWorkflowCategories[]` 和 `failureRecoveryCategories[]` 之间的关系显式化，例如让 agent 更容易区分“失败发生在哪条 lane”与“现在优先去哪个恢复阶段”。
