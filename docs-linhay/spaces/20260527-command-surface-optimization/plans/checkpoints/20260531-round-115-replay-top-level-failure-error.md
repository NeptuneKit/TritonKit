# Round 115 - replay top-level failureError

## 本切片目标

为 `TKReplayResult` 增加顶层 `failureError`，让 replay 失败的结构化 `TKCLIErrorDetail` 成为顶层可直接读取的事实，而不是必须先关联 `failedStepIndex` 再取 `steps[].error`。

## 完成结果

- `TKReplayResult` 新增 `failureError: TKCLIErrorDetail?`。
- shared init / decode 都会优先从失败 step 的 `error` 自动回填 `failureError`。
- replay runtime 新增 `replayFailureError(...)` helper，并在结果构造时显式填充顶层 `failureError`。
- replay schema output contract 与 `successShape` 已补 `failureError`。
- replay text 输出优先直接打印 `result.failureError`。

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

- 当前 `failureError` 仍然只是失败 step `error` 的镜像，不是独立事实源；如果某些失败 step 还没补 `error`，顶层仍会为空。
- output contract 目前只声明 `failureError` 字段本身，还没有把其嵌套字段单独列成细化 contract。

## 下一步

继续检查是否需要把 `failureError.code/message/hint/nextAction/endpoint` 展开进 output contract，或者把 replay 顶层恢复建议进一步绑定到 `failureError.nextAction`。
