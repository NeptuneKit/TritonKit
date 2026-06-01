# Round 32: capability group taxonomy

## 目标

把 `triton capabilities --json` 的 `capabilities[].group` 固定为 agent 可规划的分类集合，避免新增能力时产生临时分组、近义分组或低信号 `misc`。

## 完成结果

- 新增 `SchemaFactSourceTests.capabilityGroupsStayWithinTheAgentTaxonomy`。
- 允许的 capability group 固定为：`action`、`assert`、`bootstrap`、`evidence`、`host`、`observe`、`replay`、`route`、`runtime`、`smoke`、`target`、`webview`、`xcode`。
- 聚焦测试、schema fact source 全量测试和 CLI 全量测试已通过。
- 同步更新 agent-facing 信息架构、AI CLI 控制文档和 public skills。

## 验证

```bash
swift test --package-path CLI --filter SchemaFactSourceTests/capabilityGroupsStayWithinTheAgentTaxonomy
swift test --package-path CLI --filter SchemaFactSourceTests
swift test --package-path CLI
```

结果：通过。CLI 全量当前为 99 个 Swift Testing 用例通过。

## 风险与后续

- 新增 capability group 时必须同步 taxonomy、文档、skills 与测试，不能只改运行时输出。
- 下一轮建议进入 Round 33：检查 `capabilities[].requiredBy` 是否也落在固定 workflow taxonomy，继续收紧 agent 的 workflow 分类入口。

## 提交状态

未提交。用户未授权 commit / push / tag / release。
