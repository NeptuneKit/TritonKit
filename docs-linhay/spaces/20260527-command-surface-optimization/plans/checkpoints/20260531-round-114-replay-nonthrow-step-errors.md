# Round 114 - replay non-throw step errors

## 本切片目标

把 replay 中“没有抛错但返回 `ok=false`”的步骤也接入 step 级结构化 `error`，优先覆盖最常见的 `input`、`wait`、`evidence`。

## 完成结果

- `executeReplayStep(...)` 在 `tap/paste/type/clear` 返回 `input.ok=false` 时，会补 `steps[].error.code=action_failed`。
- `executeReplayStep(...)` 在 `wait.ok=false` 时，会补 `steps[].error`；timeout 分支使用 `code=timeout`。
- `executeReplayStep(...)` 在 `evidence.ok=false` 时，会补 `steps[].error.code=request_failed`。
- 新增 `replayStepError(...)` helper，把非抛错失败步骤的 error detail 生成逻辑集中到一个事实源。

## 影响文件

- `Sources/TritonKitCLI/CLIEvidenceRuntime.swift`
- `CLI/Tests/TritonKitCLITests/ReplayCommandTests.swift`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- `TritonKit.skills/tritonkit-dev-feedback/SKILL.md`
- `TritonKit.skills/tritonkit-real-project-regression/SKILL.md`
- `TritonKit.skills/tritonkit-emulator-cli-takeover/SKILL.md`
- `docs-linhay/memory/2026-05-31.md`

## 验证

- `swift test --package-path CLI --filter ReplayCommandTests`

## 剩余风险

- `input` 失败当前统一映射为 `action_failed`，还没有细分成更具体的 runtime/semantic error code。
- 顶层 `TKReplayResult` 仍不直接带 `error`，agent 需要用 `failedStepIndex` 关联到 `steps[].error`。

## 下一步

继续检查是否需要把 `steps[].error` 的嵌套字段显式列进 output contract，或把顶层 `failureError` 也提升为直接可读字段。
