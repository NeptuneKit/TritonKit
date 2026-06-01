# Round 37: nextAction placeholder tokens

## 目标

收紧 `capabilities[].nextAction.args` 中占位符的形态，确保 agent 可以把 `<...>` 作为完整 argv 槽位替换，而不需要解析半截字符串。

## 完成结果

- 新增 `SchemaFactSourceTests.capabilityNextActionPlaceholdersAreCompleteArgvTokens`。
- 测试覆盖 server 不可达、server 可达但 runtime 未连接、server 与 runtime 均可用三种 capabilities 状态。
- 凡是 `nextAction.args` 中包含 `<` 或 `>` 的参数，都必须是完整 token：以 `<` 开头、以 `>` 结尾，并且内部不能再包含尖括号。
- 聚焦测试、schema fact source 全量测试和 CLI 全量测试已通过。
- 同步更新 agent-facing 信息架构、AI CLI 控制文档和 public skills。

## 验证

```bash
swift test --package-path CLI --filter SchemaFactSourceTests/capabilityNextActionPlaceholdersAreCompleteArgvTokens
swift test --package-path CLI --filter SchemaFactSourceTests
swift test --package-path CLI
```

结果：通过。Schema fact source 当前为 33 个 Swift Testing 用例通过；CLI 全量当前为 104 个 Swift Testing 用例通过。

## 风险与后续

- 本轮只约束 capabilities `nextAction.args`。`schema.nextCommands[]` 与 `plan.steps[].command` 的占位符形态后续可继续收紧，最好复用同一个 placeholder helper。
- 下一轮建议进入 Round 38：把 placeholder token 校验扩展到 `schema.nextCommands[]` 和 `plan.steps[].command`。

## 提交状态

未提交。用户未授权 commit / push / tag / release。
