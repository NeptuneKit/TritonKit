# Round 135 - doctor primary workflow category

## 本切片目标

继续收紧 bootstrap 顶层事实源，为 `doctor` 增加单值 `primaryWorkflowCategory`，避免 agent 为了判定“当前优先恢复的是哪条 workflow lane”继续扫描 `nextWorkflows[]` 或 `checks[].workflowCategories[]`。

## 完成结果

1. `TKDoctorResponse` 新增 `primaryWorkflowCategory: String?`。
2. shared model 已补兼容回填逻辑：
   - 优先使用显式传入值；
   - 否则从 `nextStep` 对应 check 的 `workflowCategories[]` 按固定 canonical 优先级挑选；
   - 若回退到首条 `fail/warn` check，也沿同一规则选择；
   - 若只剩 `error.nextAction`，则先匹配 check，再按同一规则回填。
3. 这次没有直接复用数组首项，而是用稳定优先级挑单值 lane，避免 capability 并集顺序把 server unavailable 一类场景误导成 `action`。
4. 当前固定场景：
   - server 不可达时 `primaryWorkflowCategory == "app"`；
   - 已连接但 action surface 受限时 `primaryWorkflowCategory == "action"`。

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

1. canonical 优先级是当前 agent-facing 经验规则，不是从产品需求直接推导出的全局真理；若后续出现新的 doctor lane 竞争场景，需要再用真实回归案例校准优先级。
2. `doctor` 现在已具备 `primaryCapability`、`primaryWorkflowCategory`、`primaryNextAction` 和 `primaryNextActionSource`；继续新增顶层字段前，应优先验证 agent 是否还在频繁回扫数组，而不是机械补更多镜像字段。

## 下一步

优先回到 `capabilities` 面，评估是否存在同等高价值的“单值首选 evidence / artifact”缺口；如果没有，再审视 `plan` 顶层是否仍有需要 agent 手工聚合的恢复语义。
