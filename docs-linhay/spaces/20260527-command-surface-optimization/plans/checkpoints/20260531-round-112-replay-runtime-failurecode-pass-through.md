# Round 112 - replay runtime failureCode pass-through

## 本切片目标

收紧 replay 真实执行阶段的 failure routing，让 step/top-level `failureCode` 尽量直接反映底层 runtime / target / transport / artifact 写盘失败，而不是在外层 catch 中统一退化成 `step_failed`。

## 完成结果

- `runReplayPlan(...)` 的外层 catch 改为通过 `replayFailureStepResult(...)` 构造失败 step。
- 新增 `replayFailureDetail(...)`，优先透传底层 `TKCLIErrorDetail.code`。
- `RuntimeRequestTimeoutError` 在 replay failure surface 中映射为 `timeout`。
- screenshot / evidence 的本地写盘 `CocoaError` 在 replay failure surface 中映射为 `artifact_write_failed`。
- 仍无法识别的异常继续安全回落到 `cliErrorDetail(...)` 或最终 `step_failed`。

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
- `swift test --filter TKReplayPlanModelsTests`

## 剩余风险

- 目前 replay step 仍只暴露 `failureCode`，没有把完整 `TKCLIErrorDetail` 放进 step wire model；agent 若需要 `hint/nextAction/endpoint`，还要依赖其他证据入口。
- 某些 replay action 的本地错误仍通过通用 `cliErrorDetail(...)` 兜底，后续可以继续按 action 细化失败 envelope。

## 下一步

继续检查 replay step 是否需要直接暴露结构化 `error`，让 agent 在失败后不只知道 `failureCode`，还知道可执行 hint / nextAction，而不是只靠 `message` 和 follow-up 命令。
