# Round 44: output contract selector uniqueness

## 目标

为 agent-facing schema 增加一个新的可执行不变量：同一 command 内的 `outputContracts[].selector` 必须唯一，避免 agent 通过 selector 查找输出模型时遇到歧义。

## 完成结果

- 新增 `SchemaFactSourceTests.schemaOutputContractSelectorsRemainUniqueForAgentLookup`。
- 测试遍历所有 command schema，检查每个命令内部的 output contract selector 是否重复。
- 当前 schema 直接满足该不变量，没有发现重复 selector。
- 同步更新：
  - `docs-linhay/dev/agent-facing-cli-information-architecture.md`
  - `docs-linhay/dev/ai-cli-readable-control.md`
  - `.agents/tritonkit-skills/public/tritonkit-dev-feedback/SKILL.md`
  - `.agents/tritonkit-skills/public/tritonkit-emulator-cli-takeover/SKILL.md`
  - `.agents/tritonkit-skills/public/tritonkit-real-project-regression/SKILL.md`

## 验证

```bash
swift test --package-path CLI --filter SchemaFactSourceTests/schemaOutputContractSelectorsRemainUniqueForAgentLookup
swift test --package-path CLI --filter SchemaFactSourceTests
swift test --package-path CLI
```

结果：通过。Schema fact source 当前为 36 个 Swift Testing 用例通过；CLI 全量当前为 107 个 Swift Testing 用例通过。

## 风险与后续

- 这是 schema 契约测试与文档/skill 同步，不改变 CLI runtime 行为。
- 下一轮建议进入 Round 45：继续补齐 output contract selector 与 capability evidence / artifacts 的交叉一致性，或治理 command string 收集 helper。

## 提交状态

未提交。用户未授权 commit / push / tag / release。
