# Round 107 - replay step workflow taxonomy

## 背景

Round 106 已经让 task `plan.steps[]` 暴露 `workflowCategories[]`，但 replay 侧的 `plan inspect` summary 和 `replay --dry-run/real replay` result 还只有 `category/requires/expectedArtifacts/stopConditions`。agent 若想比较 task plan、offline inspect 和 dry-run 是否在同一条 workflow lane 上，仍要自己重建 replay step 的 workflow taxonomy。

## 本轮动作

1. 为 `TKReplayPlanStepSummary` 增加 `workflowCategories: [String]`。
2. 为 `TKReplayStepResult` 增加 `workflowCategories: [String]`。
3. 为 `TKReplayStepExecutionDescriptor` 与 `TKReplayStepExecutionMetadata` 增加 `workflowCategories`，让 inspect summary 与 replay result 共用同一套默认派生逻辑。
4. 在 `TKReplayStepExecution.metadata(...)` 中新增 replay step workflow taxonomy 派生：
   - `tap/paste/type/clear/input` -> `action/assert/evidence`
   - `wait` -> `observe/assert/evidence`
   - `screenshot` -> `observe/evidence`
   - `evidence/capture` -> `evidence/replay`
   - 其他 replay fallback -> `replay`
5. shared decoder 对旧 JSON 保持兼容：
   - 缺少 `workflowCategories` 时，按 `argv + action` 回填默认 workflow taxonomy。
6. 更新 output contracts：
   - `plan.inspect.steps[].workflowCategories`
   - `replay.result.steps[].workflowCategories`
7. 更新 shared tests 与 `SchemaFactSourceTests`，固定 replay inspect / dry-run 的 workflow taxonomy。
8. 同步更新 dev 文档与 public skills，把 replay workflow lane 正式纳入与 `doctor / plan / capabilities` 同口径的 routing 事实。

## 结果

1. `doctor`、task `plan`、`plan inspect`、`replay --dry-run` 现在都能直接暴露 workflow lane，不再只有一部分 surface 具备这层事实。
2. agent 可以比较：
   - `doctor.nextWorkflows[]`
   - `plan.nextWorkflows[]`
   - `plan.steps[].workflowCategories[]`
   - `plan inspect steps[].workflowCategories[]`
   - `replay result steps[].workflowCategories[]`
   而不需要自己发明一套 replay-special taxonomy。
3. inspect 与 replay result 通过同一个 `TKReplayStepExecution.metadata(...)` 派生 workflow taxonomy，避免 offline plan 和 dry-run 执行在同一 step 上出现不一致。

## 验证

1. `swift test --filter TKReplayPlanModelsTests/planInspectSummaryExposesStepExecutionMetadata`
2. `swift test --filter TKReplayPlanModelsTests/replayStepResultDerivesExecutionMetadata`
3. `swift test --package-path CLI --filter SchemaFactSourceTests/planInspectStepsExposeWorkflowTaxonomy`
4. `swift test --package-path CLI --filter SchemaFactSourceTests/replayStepResultsExposeWorkflowTaxonomy`
5. `swift test --filter TKReplayPlanModelsTests`
6. `swift test --package-path CLI --filter SchemaFactSourceTests`

## 备注

本轮聚焦测试时再次触发了 SwiftPM `.build` 锁等待，但所有测试最终通过；后续继续按串行编译执行，避免把锁竞争当成产品噪音。

## 下一步

1. 继续检查 replay / evidence / failure envelope 之间是否还有 agent 必须手工 join 的 routing 事实。
2. 若继续推进方案 C，可评估 evidence manifest / replay failure summary 是否也应该暴露 workflow taxonomy 或 recovery lane。
