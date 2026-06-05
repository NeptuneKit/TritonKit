# Round 117 - replay nextAction recovery alignment

## 本切片目标

让 replay 的 `failureError.nextAction` 和 `suggestedCommands[]` / `recoveryCommands[]` 保持一致，避免错误详情和恢复建议出现两条彼此脱节的恢复路径。

## 完成结果

- 新增测试：当失败 step 的 `error.nextAction` 存在时，`replaySuggestedCommands(...)` 会把对应 `triton <command> ...` 放在恢复建议前部。
- `replayRecoveryCommands(...)` 通过复用 `replaySuggestedCommands(...)`，现在也会包含这条 nextAction 路径，并保留正确的 `category`。
- docs / skills / memory 已同步收紧口径：`failureError.nextAction` 若存在，replay 恢复建议必须可见同一路径。

## 影响文件

- `CLI/Tests/TritonKitCLITests/ReplayCommandTests.swift`
- `Sources/TritonKitCLI/CLIEvidenceRuntime.swift`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- `TritonKit.skills/tritonkit-dev-feedback/SKILL.md`
- `TritonKit.skills/tritonkit-real-project-regression/SKILL.md`
- `TritonKit.skills/tritonkit-emulator-cli-takeover/SKILL.md`
- `docs-linhay/memory/2026-05-31.md`

## 验证

- `swift test --package-path CLI --filter ReplayCommandTests`

## 剩余风险

- 当前一致性只保证“nextAction 路径会出现在 recovery commands 里”，还没有要求它必须排在第一优先级或与 `failureRecoveryCategories[]` 完全一一对应。
- 一些 replay failure helper 仍未主动生成 `nextAction`，因此这条一致性只在已有 nextAction 的分支生效。

## 下一步

继续考虑是否要把 `failureError.nextAction.category` 与 `failureRecoveryCategories[]` / `recoveryCommands[].category` 建成更严格的不变量。
