# Round 38: schema and plan placeholder tokens

## 目标

把 Round 37 的 placeholder token 约束扩展到 `schema.nextCommands[]`、`schema.examples[]` 与 `plan.steps[].command`，确保 agent 不需要解析半截字符串、shell 重定向或拼接占位符。

## 红灯

新增 `SchemaFactSourceTests.schemaAndPlanPlaceholdersAreCompleteArgvTokens` 后，聚焦测试暴露两个问题：

- `sim:nextCommand:sim:<udid>`：schema next command 把 `<udid>` 混进 `sim:` target-id 字符串。
- `general:input:<`：通用 plan 的 `input` step 使用了 shell 重定向 `< gestures.ndjson`。

## 完成结果

- 将 `triton device use sim:<udid> --json` 改为 `triton device use <sim-target-id> --json`。
- 将通用 plan 的 `input` step 从 `triton input ... < gestures.ndjson` 改为纯 Triton argv：`triton input --host ... --format json --summary --strict`。
- 将 stdin NDJSON 要求移动到该 step 的 `expected` 文本中。
- 聚焦测试、schema fact source 全量测试和 CLI 全量测试已通过。
- 同步更新 agent-facing 信息架构、AI CLI 控制文档和 public skills。

## 验证

```bash
swift test --package-path CLI --filter SchemaFactSourceTests/schemaAndPlanPlaceholdersAreCompleteArgvTokens
swift test --package-path CLI --filter SchemaFactSourceTests
swift test --package-path CLI
```

结果：通过。Schema fact source 当前为 34 个 Swift Testing 用例通过；CLI 全量当前为 105 个 Swift Testing 用例通过。

## 风险与后续

- 本轮没有改 CLI 参数解析，只改 agent-facing schema/plan 建议。
- 下一轮建议进入 Round 39：检查 plan step `command` 不包含 shell control operators，确保 plan 始终输出单条 Triton argv。

## 提交状态

未提交。用户未授权 commit / push / tag / release。
