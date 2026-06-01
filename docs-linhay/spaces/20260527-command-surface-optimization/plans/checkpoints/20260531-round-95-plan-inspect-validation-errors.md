# Round 95: plan inspect validation errors

## 目标

让 `triton plan inspect <file.tritonplan> --json` 在保持离线、非执行摘要语义的同时，为 invalid replay step 暴露机器可读的 step-level 静态诊断，避免 agent 只能等到 `replay --dry-run` 的全局 `error.message` 才知道 plan 哪一步不可执行。

## 完成内容

1. 新增 `TKReplayPlanStepValidationError`，字段为 `code/message/field/severity`。
2. `TKReplayPlanStepSummary` 新增 `validationErrors[]`，旧 JSON 缺少该字段时默认解码为 `[]`。
3. `TKReplayStepExecution.validationErrors(for:)` 复用 replay step 形状规则，离线报告：
   - `missing_tap_selector`
   - `ambiguous_tap_selector`
   - `missing_text`
   - `missing_wait_condition`
   - `ambiguous_wait_condition`
   - `incomplete_coordinate`
4. `plan inspect` 不求值 `${variable}`，合法变量模板继续输出空 `validationErrors[]`。
5. `plan.inspect` output contract 新增 `steps[].validationErrors`。
6. 修正 `replay.result.failedStepIndex` contract 描述为 1-based，并注明与 `steps[].index` 对齐。
7. 更新 agent-facing docs 与 public skills 的 `plan inspect` 字段清单。

## 验证

- `swift test --filter TKReplayPlanModelsTests/planInspectSummaryExposesStepValidationErrors`：通过。
- `swift test --filter TKReplayPlanModelsTests`：9 个 Swift Testing 用例通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests/agentBootstrapSchemasExposeRecoveryCommandsAndOutputContracts`：通过。
- `swift test --package-path CLI --filter ReplayCommandTests`：通过，确认 `replay --dry-run --json` invalid plan 仍保持单 error envelope。
- `swift run --package-path CLI triton plan inspect <invalid.tritonplan> --json`：通过，输出 `steps[0].validationErrors[0].code == "ambiguous_tap_selector"`，变量模板 step 输出空 `validationErrors[]`。

## 风险

1. 本轮只把 step 形状诊断挂到 `plan inspect` summary；`replay --dry-run` 的失败 envelope 仍保持 Round 92 的单 envelope 语义，未新增结构化 detail。
2. `validationErrors[]` 是 additive 字段；旧 consumer 若忽略未知字段不受影响，旧 JSON 解码也会默认空数组。

## 下一步

1. 可继续为 `replay --dry-run` 增加可选 detail wire model，但需要单独评估全局 `TKCLIErrorDetail` 的兼容面。
2. 后续新增 replay action 时，应同步更新 `TKReplayStepExecution.validationErrors(for:)` 与 argv helper，保持 inspect / dry-run 规则一致。
