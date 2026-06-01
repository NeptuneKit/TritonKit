# Round 45: subcommand output selector coverage

## 目标

为 agent-facing schema 增加子命令输出模型的一致性约束：`subcommands[].outputSelectors[]` 必须能被父命令的 `outputContracts[].selector` 覆盖。

## 完成结果

- 新增 `SchemaFactSourceTests.subcommandOutputSelectorsStayCoveredByParentOutputContracts`。
- 测试遍历所有 command schema：
  - 读取父命令 `outputContracts[].selector` 集合；
  - 检查每个子命令 `outputSelectors[]` 是否都能在父命令 output contract 中找到。
- 当前 schema 直接满足该不变量，没有发现缺失 selector。
- 同步更新：
  - `docs-linhay/dev/agent-facing-cli-information-architecture.md`
  - `docs-linhay/dev/ai-cli-readable-control.md`
  - `.agents/tritonkit-skills/public/tritonkit-dev-feedback/SKILL.md`
  - `.agents/tritonkit-skills/public/tritonkit-emulator-cli-takeover/SKILL.md`
  - `.agents/tritonkit-skills/public/tritonkit-real-project-regression/SKILL.md`

## 验证

```bash
swift test --package-path CLI --filter SchemaFactSourceTests/subcommandOutputSelectorsStayCoveredByParentOutputContracts
swift test --package-path CLI --filter SchemaFactSourceTests
swift test --package-path CLI
```

结果：通过。Schema fact source 当前为 37 个 Swift Testing 用例通过；CLI 全量当前为 108 个 Swift Testing 用例通过。

## 风险与后续

- 这是 schema 契约测试与文档/skill 同步，不改变 CLI runtime 行为。
- 下一轮建议进入 Round 46：继续补齐 subcommand `nextCommands[]` 与 schema-backed command 校验，或治理 command string 收集 helper。

## 提交状态

未提交。用户未授权 commit / push / tag / release。
