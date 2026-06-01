# Round 91: replay step static validation

## 目标

补强 `TKReplayStepExecution` 的 dry-run 静态验证：在不连接 runtime 的情况下提前拒绝明显不可执行的 `.tritonplan` step，避免 agent 到真实 replay 执行阶段才发现 plan 本身有歧义或缺参。

## 完成内容

1. 新增 `TKReplayStepExecutionError.ambiguousTapSelector`。
2. 新增 `TKReplayStepExecutionError.ambiguousWaitCondition`。
3. `TKReplayStepExecution.argv(...)` 在 strict / dry-run 路径中提前校验：
   - `tap` 必须且只能声明一个 selector：`text`、`oid`、`x/y`、`axOID` 或 `axLabel`。
   - `wait` 必须且只能声明一个 condition：`text`、`gone`、`exists`、`idle`、`hierarchyChange` 或 `predicate`。
   - `paste/type` 必须提供 `value` 或 `text`。
   - `wait` 必须提供 condition。
4. 新增测试 `replayExecutionHelperRejectsAmbiguousDryRunSteps`，覆盖多 selector、多 wait condition、缺失 paste text 与缺失 wait condition。
5. 同步更新 dev 文档与 public skills，要求 agent 将 dry-run 接受静态 invalid step 视为 validation bug。

## 验收

- 静态 invalid `.tritonplan` 不应通过 replay dry-run argv 构建。
- 错误描述保持 agent 可读，并与既有 runtime validation 文案一致。
- 有效 replay dry-run 输出保持 Round 89 / Round 90 的 `steps[].argv` 与 metadata 形态。

## 验证

- 先补测试并确认红灯：`swift test --filter TKReplayPlanModelsTests/replayExecutionHelperRejectsAmbiguousDryRunSteps` 首次失败，原因是缺少 `ambiguousTapSelector` / `ambiguousWaitCondition`。
- `swift test --filter TKReplayPlanModelsTests/replayExecutionHelperRejectsAmbiguousDryRunSteps`：实现后通过。
- `swift test --filter TKReplayPlanModelsTests`：8 个 Swift Testing 用例通过。
- `swift test --package-path CLI`：147 个 Swift Testing 用例通过。
- `swift test`：130 个 Swift Testing 用例通过。
- `swift run --package-path CLI triton replay /tmp/round87-plan-inspect.tritonplan --dry-run --var username=alice --var password=secret --json`：通过，有效 plan 输出保持 `steps[].argv`、`steps[].command` 与 metadata。

## 风险

1. 本轮让 dry-run 比之前更早拒绝 ambiguous plan；这是符合 agent-facing 目标的破坏性收紧，但可能暴露已有手写 `.tritonplan` 中的歧义 step。
2. `plan inspect` 仍以离线审计为主，不抛错；严格可执行性以 `replay --dry-run` 为准。

## 下一步

1. 在 CLI 层补一个 invalid `.tritonplan` dry-run 的 JSON 错误 envelope 测试，确保静态 validation error 不被二次包装。
2. 继续整理 replay / record 的 usageForms、argumentForms 与 output selectors。
