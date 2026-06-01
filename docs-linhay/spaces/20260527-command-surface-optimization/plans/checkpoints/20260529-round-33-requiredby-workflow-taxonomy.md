# Round 33: capability requiredBy workflow taxonomy

## 目标

把 `triton capabilities --json` 的 `capabilities[].requiredBy` 固定为 agent 可规划的 workflow 分类集合，避免新增能力时产生临时 workflow 名称，导致 agent 无法稳定反查能力与任务的关系。

## 完成结果

- 新增 `SchemaFactSourceTests.capabilityRequiredByValuesStayWithinTheWorkflowTaxonomy`。
- 允许的 workflow taxonomy 固定为：`action`、`app`、`assert`、`evidence`、`observe`、`project`、`replay`、`route`、`runtime`、`smoke`、`target`、`webview-check`、`xcode`。
- 聚焦测试、schema fact source 全量测试和 CLI 全量测试已通过。
- 同步更新 agent-facing 信息架构、AI CLI 控制文档和 public skills。

## 验证

```bash
swift test --package-path CLI --filter SchemaFactSourceTests/capabilityRequiredByValuesStayWithinTheWorkflowTaxonomy
swift test --package-path CLI --filter SchemaFactSourceTests
swift test --package-path CLI
```

结果：通过。Schema fact source 当前为 29 个 Swift Testing 用例通过；CLI 全量当前为 100 个 Swift Testing 用例通过。

## 风险与后续

- 新增 workflow 分类必须说明它对 agent 规划的实际意义，并同步 taxonomy、文档、skills 与测试。
- 下一轮建议进入 Round 34：检查 `capabilities[].evidence` 是否落在固定 artifact taxonomy，继续收紧 agent 的证据选择入口。

## 提交状态

未提交。用户未授权 commit / push / tag / release。
