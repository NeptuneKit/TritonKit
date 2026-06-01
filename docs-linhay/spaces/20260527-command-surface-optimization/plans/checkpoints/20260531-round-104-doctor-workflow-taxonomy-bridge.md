# Round 104 - doctor workflow taxonomy bridge

## 背景

Round 103 已经让 `status`、`doctor`、`capabilities`、`plan` 能在 JSON 顶层自报 `surface`，但 `doctor` 仍只暴露 `relatedCapabilities[]`。agent 若想知道某条诊断实际阻塞了哪些 workflow，仍要再把 `doctor` 与 `capabilities[].requiredBy` 做一次 join，这不符合方案 C 里“诊断入口本身可规划”的目标。

## 本轮动作

1. 为 `TKDoctorCheck` 增加 `workflowCategories: [String]`。
2. 为 `TKDoctorResponse` 增加 `nextWorkflows: [String]`，指向第一条 `fail/warn` check 影响的 workflow taxonomy。
3. 在 `buildDoctorResponse(...)` 中新增 capability -> workflow 派生逻辑：
   - 每条 check 通过 `relatedCapabilities[]` 对应到 capability matrix；
   - 从匹配 capability 的 `requiredBy[]` 汇总去重后得到 `workflowCategories[]`；
   - 顶层 `nextWorkflows[]` 直接复用第一条 actionable check 的 `workflowCategories[]`。
4. shared decoder 对旧 JSON 保持兼容：
   - 缺少 `nextWorkflows` 时回填 `[]`；
   - 旧 payload 不需要同步补写即可继续 decode。
5. 更新 `doctor` output contract，显式声明：
   - `nextWorkflows`
   - `checks[].workflowCategories`
6. 更新 shared tests 与 `SchemaFactSourceTests`，固定 doctor recovery 输出和 bootstrap schema 契约。
7. 同步更新 dev 文档与 3 个 public skills，把这层 bridge 定义为“doctor 直接暴露 workflow taxonomy”，而不是让 agent 继续自行关联 capabilities。

## 结果

1. `doctor` 现在不仅能告诉 agent “下一条诊断项是什么”，还能直接告诉 agent “它阻塞了哪些 workflow 分类”。
2. `doctor` 与 `capabilities` 的职责边界更清晰：
   - `doctor`：排序后的恢复入口，直接给出恢复优先级和 workflow lane；
   - `capabilities`：完整能力矩阵，给出每项能力的 group、requiredBy、nextAction 和 evidence。
3. agent 先读 `doctor` 就能决定当前该走 `app`、`observe`、`action`、`assert`、`evidence`、`smoke`、`project/xcode` 哪条恢复链路，再按需下钻 `capabilities` 取更细粒度信息。

## 验证

1. `swift test --filter TKCLITransportModelsTests/doctorResponseShape`
2. `swift test --package-path CLI --filter SchemaFactSourceTests/doctorResponseExposesOrderedRecoveryChecks`
3. `swift test --package-path CLI --filter SchemaFactSourceTests/agentBootstrapSchemasExposeRecoveryCommandsAndOutputContracts`
4. `swift test --filter TKCLITransportModelsTests`
5. `swift test --package-path CLI --filter SchemaFactSourceTests`

## 下一步

1. 继续检查 `doctor / capabilities / plan` 三者之间是否还有需要 agent 手工 join 的 planning taxonomy。
2. 若继续推进方案 C，下一刀可考虑把 `plan` step 与 `doctor` check 的 workflow lane 再统一到更直接的 cross-surface routing 规则。
