# Round 35: capability evidence nonempty

## 目标

要求 `triton capabilities --json` 中每个 capability 都至少暴露一个 `evidence` source，让 agent 能知道该能力可以由哪个机器可读输出、artifact 或诊断证据证明。

## 红灯

新增 `SchemaFactSourceTests.capabilitiesExposeAtLeastOneEvidenceSource` 后，聚焦测试暴露以下 capability 缺少 evidence：

- `attrs`
- `export-archive`
- `export-json`
- `geometry`
- `hierarchy`
- `hit`
- `inspect`
- `list`
- `nodes`
- `object`

## 完成结果

- 为 `list` 增加 `status-json`、`runtime-manifest` evidence。
- 为 `inspect`、`hierarchy`、`nodes` 增加 `surface-tree`、`runtime-ax` evidence。
- 为 `attrs`、`object` 增加 `hierarchy-node`、`surface-tree` evidence。
- 为 `export-json` 增加 `surface-tree`、`host-artifact` evidence。
- 为 `export-archive` 增加 `host-artifact`、`screenshot-metadata` evidence。
- 为 `geometry` 增加 `snapshot-json` evidence。
- 为 `hit` 增加 `target.resolution`、`surface-tree` evidence。
- 同步更新 agent-facing 信息架构、AI CLI 控制文档和 public skills。

## 验证

```bash
swift test --package-path CLI --filter SchemaFactSourceTests/capabilitiesExposeAtLeastOneEvidenceSource
swift test --package-path CLI --filter SchemaFactSourceTests
swift test --package-path CLI
```

结果：通过。Schema fact source 当前为 31 个 Swift Testing 用例通过；CLI 全量当前为 102 个 Swift Testing 用例通过。

## 风险与后续

- evidence 名称已经受 Round 34 artifact taxonomy 约束；后续新增 evidence 需要先确认是否属于真实可审计输出。
- 下一轮建议进入 Round 36：把 capabilities 的 `nextAction.requiresLongRunningProcess` 语义收紧，只允许 serve/xcode run 等确实可能长驻或长耗时的恢复动作使用。

## 提交状态

未提交。用户未授权 commit / push / tag / release。
