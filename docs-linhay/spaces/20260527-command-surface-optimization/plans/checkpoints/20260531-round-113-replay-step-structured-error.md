# Round 113 - replay step structured error

## 本切片目标

为 replay 失败步骤补齐结构化 `error` 载荷，让 agent 在读取 `failureCode` 之后，可以直接消费 `TKCLIErrorDetail` 的 `message`、`hint`、`endpoint`、`nextAction` 等诊断信息。

## 完成结果

- `TKReplayStepResult` 新增 `error: TKCLIErrorDetail?`。
- step 初始化与 decode 现在优先使用 `error.code` 作为 `failureCode`，再回落到显式 `failureCode` 或旧的形状推断。
- replay 外层 catch 构造失败 step 时，直接把 `replayFailureDetail(...)` 结果放进 `steps[].error`。
- replay schema output contract 与 `successShape` 已补 `steps[].error`。
- replay text 输出在存在 failed step `error` 时会打印 `failureError: <code> <message>`。

## 影响文件

- `Sources/TritonKitShared/TKReplayPlanModels.swift`
- `Sources/TritonKitCLI/CLIEvidenceRuntime.swift`
- `Sources/TritonKitCLI/CLISchemaContracts.swift`
- `Sources/TritonKitCLI/CLISchemaObservationCommands.swift`
- `Sources/TritonKitCLI/CLIEvidenceCommands.swift`
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

## 剩余风险

- 当前只有 replay catch 路径会稳定补 `steps[].error`；形状化失败的 `input/wait/evidence` 步骤还没有统一把完整 error detail 显式挂到 step 上。
- 顶层 `TKReplayResult` 仍只暴露 `failureCode`，没有独立 `error`；agent 需要先通过 `failedStepIndex` 关联到 step 级 `error`。

## 下一步

继续统一 replay 各类“非抛错但失败”的步骤，把 runtime/action/assert/evidence 失败尽可能收敛到同一套 step 级结构化 `error` 事实源。
