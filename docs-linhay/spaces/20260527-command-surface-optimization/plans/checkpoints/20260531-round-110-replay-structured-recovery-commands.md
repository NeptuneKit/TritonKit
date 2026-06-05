# Round 110 - replay structured recovery commands

## 本轮目标

把 replay failure 顶层 follow-up 从字符串建议继续收敛成结构化恢复命令，和 schema / bootstrap 的 recovery taxonomy 对齐。

## 完成结果

- `TKReplayResult` 新增 `recoveryCommands[]: [TKCommandRecoveryCommand]`。
- shared decoder 对老 payload 自动回填：
  - 优先读取显式 `recoveryCommands[]`
  - 缺失时从 `suggestedCommands[]` 自动派生
- replay runtime 现在显式写入：
  - `suggestedCommands[]`
  - `recoveryCommands[]`
  两层并存；前者保留兼容字符串入口，后者给 agent 直接消费 `{command, category}`。
- replay schema contract 与 text 输出同步补齐 `recoveryCommands[]`。

## 改动文件

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
- `TritonKit.skills/tritonkit-dev-feedback/SKILL.md`
- `TritonKit.skills/tritonkit-real-project-regression/SKILL.md`
- `TritonKit.skills/tritonkit-emulator-cli-takeover/SKILL.md`
- `docs-linhay/memory/2026-05-31.md`

## 验证

- `swift test --filter TKReplayPlanModelsTests`
- `swift test --package-path CLI --filter ReplayCommandTests`
- `swift test --package-path CLI --filter SchemaFactSourceTests`

## 剩余风险 / 下一步

- 当前 replay `recoveryCommands[]` 仍从启发式 suggested commands 派生，尚未按 failure code family 做更细粒度建模。
- 下一刀可以继续把 replay 顶层 failure routing 与 `failureCodes[]` family 建立更直接的 machine-readable bridge，避免 agent 还要从 failure lane 反推失败码族。
