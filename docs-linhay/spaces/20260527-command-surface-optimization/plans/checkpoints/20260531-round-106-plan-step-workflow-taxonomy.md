# Round 106 - plan step workflow taxonomy

## 背景

Round 105 已让 `plan` 顶层暴露 `nextWorkflows[]`，agent 能直接知道当前推荐 planning lane。但进入具体 `steps[]` 后，agent 仍需要从 root command 或顶层 lane 反推单步属于哪个 workflow，这和 `doctor.checks[].workflowCategories[]` 已经具备的“单条记录自带 workflow lane”仍不对称。

## 本轮动作

1. 为 `TKWorkflowPlanStep` 增加 `workflowCategories: [String]`。
2. shared model 保持 backward-compatible decode：
   - 旧 JSON 缺少 `workflowCategories` 时，按 step `command` 自动派生默认 workflow taxonomy。
3. 在 shared model 中新增 step-level workflow taxonomy 派生规则：
   - `target`、`app`、`runtime`、`webview`、`route`、`smoke`、`evidence`、`assert`、`observe`、`xcode`、`serve`、`schema/doctor/status/capabilities/plan` 等 root command 都映射到固定 workflow taxonomy。
4. 更新 `plan.next-steps` output contract，显式声明 `steps[].workflowCategories`。
5. 更新 shared tests：
   - `workflowPlanShape`
6. 更新 `SchemaFactSourceTests`：
   - `agentBootstrapSchemasExposeRecoveryCommandsAndOutputContracts` 断言 `plan.next-steps` 暴露 `steps[].workflowCategories`
   - `taskWorkflowPlansExposeExecutableCommandSequences` 断言关键 task step 的 workflow taxonomy
   - 新增 `workflowPlanStepsExposeWorkflowTaxonomy`
7. 同步更新 dev 文档与 public skills，把 step-level workflow taxonomy 明确定义为与 `doctor` / `capabilities` 同口径的 routing 事实。

## 结果

1. `plan.steps[]` 现在和 `doctor.checks[]` 一样，单条记录就能直接说明自己属于哪些 workflow lane。
2. agent 可以按两层信息规划：
   - 顶层 `plan.nextWorkflows[]`：当前推荐 lane
   - 单步 `steps[].workflowCategories[]`：具体 step 所属 lane
3. 这样 agent 进入具体 step 时，不需要再从 root command、顶层 goal 或前一步上下文重建 workflow taxonomy。

## 验证

1. `swift test --filter TKCLITransportModelsTests/workflowPlanShape`
2. `swift test --package-path CLI --filter SchemaFactSourceTests/taskWorkflowPlansExposeExecutableCommandSequences`
3. `swift test --package-path CLI --filter SchemaFactSourceTests/workflowPlanStepsExposeWorkflowTaxonomy`
4. `swift test --filter TKCLITransportModelsTests`
5. `swift test --package-path CLI --filter SchemaFactSourceTests`

## 下一步

1. 继续检查 `plan` 顶层与 step-level contract 是否还缺少能让 agent 少做 join 的 routing 事实。
2. 若继续推进方案 C，可评估 replay inspect / replay dry-run 的 step 结果是否也应补同口径 workflow taxonomy，形成 plan / replay / doctor 的完全对齐。
