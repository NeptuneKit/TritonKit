# Round 137 - plan primary workflow category

## 本切片目标

继续减少 `plan` 顶层事实源的数组扫描，为 `TKWorkflowPlanResponse` 增加单值 `primaryWorkflowCategory`，避免 agent 需要从 `nextWorkflows[]` 或 `steps[].workflowCategories[]` 自己决定“先按哪条 workflow lane 理解这张计划”。

## 完成结果

1. `TKWorkflowPlanResponse` 新增 `primaryWorkflowCategory: String?`。
2. shared model 默认回填逻辑已补齐：
   - 优先使用显式传入值；
   - 否则从 `nextStep` 对应 step 的 `workflowCategories[]` 里按固定 canonical 优先级挑出单值 lane；
   - 若回退到 `first-step` 或 `error.nextAction`，也沿同一路径匹配 step 后回填；
   - 若走 `default-next-step` 兼容回填，则从 `nextWorkflows[]` 沿同一规则选出单值 lane。
3. 当前固定场景：
   - bootstrap `start-server` 回填 `app`；
   - `ios-smoke` 和 `open-url` 回填 `app`；
   - `webview-check` 回填 `observe`。

## 变更文件

- `Sources/TritonKitShared/TKCLITransportModels.swift`
- `Sources/TritonKitCLI/CLISchemaContracts.swift`
- `Tests/TritonKitSharedTests/TKCLITransportModelsTests.swift`
- `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- `docs-linhay/memory/2026-05-31.md`

## 验证

- `swift test --filter TKCLITransportModelsTests`
- `swift test --package-path CLI --filter SchemaFactSourceTests`

## 剩余风险

1. `plan.primaryWorkflowCategory` 当前解决的是“首条 lane”，不是完整多 lane 解释；复杂任务仍需要读取 `nextWorkflows[]` 与 step 级 `workflowCategories[]`。
2. canonical 优先级仍是 agent-facing 经验规则；如果后续出现新的多 lane 竞争案例，需要用真实回归计划校准，而不是继续堆更多镜像字段。

## 下一步

优先评估 `plan` 是否还缺少顶层首选 artifact / evidence taxonomy；如果没有，再回看 bootstrap 事实源之外的 replay / evidence / target 面是否还存在 agent 需要二次聚合的一跳事实。
