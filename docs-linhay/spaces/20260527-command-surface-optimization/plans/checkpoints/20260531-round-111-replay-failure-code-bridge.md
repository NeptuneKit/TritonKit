# Round 111 - replay failure code bridge

## 本轮目标

把 replay 顶层 failure routing 和 schema `failureCodes[]` 体系直接接起来，减少 agent 从 workflow lane 或 follow-up 命令反推失败码族。

## 完成结果

- `TKReplayStepResult` 新增 `failureCode`。
- `TKReplayResult` 新增：
  - `failureCode`
  - `failureRecoveryCategories[]`
- shared decoder 对老 payload 自动回填：
  - step 级 `failureCode` 由失败形状推导（例如 wait timeout -> `timeout`，input failure -> `action_failed`，其他默认 `step_failed`）；
  - result 顶层 `failureCode` 取 failed step 的 `failureCode`；
  - `failureRecoveryCategories[]` 由 `TKCommandRecoveryCommand.recoveryCategories(forFailureCode:)` 回填。
- replay schema contract 已同步暴露：
  - `failureCode`
  - `failureRecoveryCategories[]`
  - `steps[].failureCode`
- replay schema `failureCodes[]` 同步扩展到实际会出现的 replay-level failure code：
  - `action_failed`
  - `timeout`
  - `artifact_write_failed`

## 改动文件

- `Sources/TritonKitShared/TKCLITransportModels.swift`
- `Sources/TritonKitShared/TKReplayPlanModels.swift`
- `Sources/TritonKitCLI/CLIEvidenceRuntime.swift`
- `Sources/TritonKitCLI/CLIEvidenceCommands.swift`
- `Sources/TritonKitCLI/CLISchemaContracts.swift`
- `Sources/TritonKitCLI/CLISchemaObservationCommands.swift`
- `Tests/TritonKitSharedTests/TKReplayPlanModelsTests.swift`
- `CLI/Tests/TritonKitCLITests/ReplayCommandTests.swift`
- `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- `.agents/tritonkit-skills/public/tritonkit-dev-feedback/SKILL.md`
- `.agents/tritonkit-skills/public/tritonkit-real-project-regression/SKILL.md`
- `.agents/tritonkit-skills/public/tritonkit-emulator-cli-takeover/SKILL.md`
- `docs-linhay/memory/2026-05-31.md`

## 验证

- `swift test --filter TKReplayPlanModelsTests`
- `swift test --package-path CLI --filter ReplayCommandTests`
- `swift test --package-path CLI --filter SchemaFactSourceTests`

## 剩余风险 / 下一步

- 当前 replay step `failureCode` 仍是基于失败形状的保守推导，尚未贯通底层 runtime / host error envelope 的原始 code。
- 下一刀可以继续把 runtime / host 真实 error.code 贯通进 replay step 结果，减少 `step_failed` 这类保守兜底值。
