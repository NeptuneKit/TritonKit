# Round 90: replay step execution helper

## 目标

减少 `.tritonplan` inspect summary、replay dry-run 和真实 replay result 的重复映射：把 replay step 的 argv、command string、category、requires、expectedArtifacts 与 stopConditions 派生收敛到一个共享事实源。

## 完成内容

1. 新增 `TKReplayStepExecution` 共享 helper：
   - `inspectDescriptor(for:planName:index:)`：供 `TKReplayPlanStepSummary` 离线生成变量保留的 summary。
   - `argv(for:planName:index:variables:)`：供 replay dry-run / execution 生成变量替换后的 argv。
   - `metadata(argv:action:)`：供 replay result 按首选 argv 派生执行元数据。
   - `artifactName(planName:step:index:)` 与 `commandString(_:)`：统一 artifact fallback 与人读 command string。
2. 新增 `TKReplayStepExecutionDescriptor` 与 `TKReplayStepExecutionMetadata`，让 summary 与 result 消费同一套结构化输出。
3. 新增 `TKReplayStepExecutionError`，保持 replay argv 构建错误仍为可读描述。
4. `TKReplayPlanStepSummary` 改为由 `TKReplayStepExecution.inspectDescriptor` 填充 `command/argv/category/requires/expectedArtifacts/stopConditions`。
5. `TKReplayStepResult` 改为由 `TKReplayStepExecution.metadata` 派生默认 metadata。
6. CLI `replayCommand` 改为调用 `TKReplayStepExecution.argv`，不再维护一份独立 argv builder。

## 验收

- inspect summary 的 `steps[].argv` 继续保留 `${variable}` 占位。
- replay dry-run 的 `steps[].argv` 继续输出变量替换后的 argv。
- secure replay step 继续只输出 `<redacted:length>`。
- replay result metadata 与 inspect summary 使用同一 helper 派生。
- CLI dry-run 输出结构与 Round 89 保持一致。

## 验证

- 先补测试并确认红灯：`swift test --filter TKReplayPlanModelsTests/replayExecutionHelperAlignsInspectAndResultMetadata` 首次失败，原因是 `TKReplayStepExecution` 未实现。
- `swift test --filter TKReplayPlanModelsTests/replayExecutionHelperAlignsInspectAndResultMetadata`：实现后通过。
- `swift test --filter TKReplayPlanModelsTests`：7 个 Swift Testing 用例通过。
- `swift test --package-path CLI`：147 个 Swift Testing 用例通过。
- `swift run --package-path CLI triton replay /tmp/round87-plan-inspect.tritonplan --dry-run --var username=alice --var password=secret --json`：通过，输出保持 `steps[].argv`、`steps[].command` 与 metadata。
- `swift test`：129 个 Swift Testing 用例通过。

## 风险

1. 本轮只收敛 replay step argv / metadata；实际执行请求构建如 `replayTapRequest`、`replayTextInputRequest`、`replayWaitRequest` 仍在 CLI runtime 中维护。
2. `command` 历史上仍是 argv token 数组，后续如果改为纯日志字符串，需要单独定义 wire schema version 或迁移策略。

## 下一步

1. 为 `TKReplayStepExecution` 补充 invalid plan step 的单元测试，确保 dry-run 阶段能提前暴露缺失 selector / text / wait condition。
2. 继续整理 replay / record 的 usageForms、argumentForms 与 output selectors。
