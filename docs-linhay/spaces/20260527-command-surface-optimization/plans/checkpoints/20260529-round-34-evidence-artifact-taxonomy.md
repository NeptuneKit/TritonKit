# Round 34: capability evidence artifact taxonomy

## 目标

把 `triton capabilities --json` 的 `capabilities[].evidence` 固定为 agent 可审计的 artifact taxonomy，避免新增能力时把人读说明或临时标签写进 evidence 数组。

## 完成结果

- 新增 `SchemaFactSourceTests.capabilityEvidenceValuesStayWithinTheArtifactTaxonomy`。
- 允许的 evidence taxonomy 覆盖 stdout/schema/status、host target/artifact、runtime manifest/snapshot/AX/ledger、WebView provider/route/assertion、input/action result、evidence bundle、smoke summary、tritonplan、Xcode/xcresult/trace/coverage 和 unsupported envelope。
- 聚焦测试、schema fact source 全量测试和 CLI 全量测试已通过。
- 同步更新 agent-facing 信息架构、AI CLI 控制文档和 public skills。

## 验证

```bash
swift test --package-path CLI --filter SchemaFactSourceTests/capabilityEvidenceValuesStayWithinTheArtifactTaxonomy
swift test --package-path CLI --filter SchemaFactSourceTests
swift test --package-path CLI
```

结果：通过。Schema fact source 当前为 30 个 Swift Testing 用例通过；CLI 全量当前为 101 个 Swift Testing 用例通过。

## 风险与后续

- 当前 Round 34 只锁定已声明 evidence 的 taxonomy，不强制所有 capability 都必须有非空 evidence。
- 下一轮建议进入 Round 35：检查 `capabilities[].evidence` 是否应对所有 capability 非空，并补齐 inspect/hierarchy/attrs/export 等 observe 能力的证据面。

## 提交状态

未提交。用户未授权 commit / push / tag / release。
