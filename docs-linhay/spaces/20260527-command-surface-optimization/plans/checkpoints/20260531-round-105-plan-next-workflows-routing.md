# Round 105 - plan next workflows routing

## 背景

Round 104 已经让 `doctor` 直接暴露 `nextWorkflows[]` 与 `checks[].workflowCategories[]`，agent 可以知道当前哪条 workflow 被阻塞。但 `plan` 还只暴露 `mode/goal/nextStep/steps[]`，agent 若想把 `doctor` 的阻塞 lane 与 `plan` 的推荐 lane 对齐，仍要从 `goal` 或 step 命令词做额外推断。

## 本轮动作

1. 为 `TKWorkflowPlanResponse` 增加顶层 `nextWorkflows: [String]`。
2. shared model 保持 backward-compatible decode：
   - 旧 JSON 缺少 `nextWorkflows` 时，根据 `goal + nextStep` 回填默认 workflow lane。
3. `plan.next-steps` output contract 显式声明 `nextWorkflows`。
4. `renderWorkflowPlan(...)` / `renderWorkflowPlanZH(...)` 补充文本输出，避免 text mode 丢失该字段。
5. 更新 shared tests：
   - `workflowPlanShape`
   - `workflowPlanInfersModeForOlderPayloads`
6. 更新 `SchemaFactSourceTests`：
   - `agentBootstrapSchemasExposeRecoveryCommandsAndOutputContracts` 断言 `plan.next-steps` 暴露 `nextWorkflows`
   - `taskWorkflowPlansExposeExecutableCommandSequences` 断言 `ios-smoke` / `open-url` / `webview-check` 的 `nextWorkflows`
   - 新增 `workflowPlanNextWorkflowsStayWithinTheWorkflowTaxonomy`
7. 同步更新 dev 文档与 public skills，把 `plan.nextWorkflows` 定义为与 `doctor.nextWorkflows`、`capabilities[].requiredBy` 同口径的 planning lane 字段。

## 结果

1. `plan` 顶层现在也能直接告诉 agent：“当前推荐的是哪条 workflow lane”，而不只是“下一步 step id 是什么”。
2. `doctor` 与 `plan` 的职责边界更容易衔接：
   - `doctor.nextWorkflows[]`：当前阻塞或受影响的 workflow
   - `plan.nextWorkflows[]`：当前推荐进入的 workflow
3. agent 可以先按 workflow lane 做恢复/执行决策，再按 `nextStep` 和 `steps[].argv` 进入具体命令执行。

## 验证

1. `swift test --filter TKCLITransportModelsTests/workflowPlanShape`
2. `swift test --filter TKCLITransportModelsTests/workflowPlanInfersModeForOlderPayloads`
3. `swift test --package-path CLI --filter SchemaFactSourceTests/taskWorkflowPlansExposeExecutableCommandSequences`
4. `swift test --package-path CLI --filter SchemaFactSourceTests/workflowPlanNextWorkflowsStayWithinTheWorkflowTaxonomy`
5. `swift test --filter TKCLITransportModelsTests`
6. `swift test --package-path CLI --filter SchemaFactSourceTests`

## 备注

本轮聚焦测试时误并行启动了多个 SwiftPM 命令，触发 `.build` 锁等待；最终测试均通过，但后续继续遵守 SwiftPM 串行执行，避免把锁竞争噪音混进验证回路。

## 下一步

1. 继续检查 `plan` 顶层是否还缺少与 `doctor` 同口径的 routing 事实，而不是让 agent 继续从 step 细节猜测。
2. 若继续推进方案 C，可考虑下一刀评估 task plan step 是否需要显式 workflow lane，还是保持顶层 `nextWorkflows` + step `category` 双层模型。
