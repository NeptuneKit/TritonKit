# Round 46: subcommand nextCommands schema alignment

## 目标

为 agent-facing schema 增加子命令恢复建议的一致性约束：`subcommands[].nextCommands[]` 必须和全局 command schema 中的命令、子命令与参数声明对齐。

## 完成结果

- 新增 `SchemaFactSourceTests.subcommandNextCommandsStayAlignedWithCommandSchemas`。
- 测试遍历所有 command schema 与子命令：
  - 读取每个 `subcommands[].nextCommands[]`；
  - 使用现有 schema-backed command 校验 helper 检查 root command、subcommand 和 `--flag` 是否已声明。
- 当前 schema 直接满足该不变量，没有发现未声明命令、子命令或 flag。
- 同步更新：
  - `docs-linhay/dev/agent-facing-cli-information-architecture.md`
  - `docs-linhay/dev/ai-cli-readable-control.md`
  - `.agents/tritonkit-skills/public/tritonkit-dev-feedback/SKILL.md`
  - `.agents/tritonkit-skills/public/tritonkit-emulator-cli-takeover/SKILL.md`
  - `.agents/tritonkit-skills/public/tritonkit-real-project-regression/SKILL.md`

## 验证

```bash
swift test --package-path CLI --filter SchemaFactSourceTests/subcommandNextCommandsStayAlignedWithCommandSchemas
swift test --package-path CLI --filter SchemaFactSourceTests
swift test --package-path CLI
```

结果：通过。Schema fact source 当前为 38 个 Swift Testing 用例通过；CLI 全量当前为 109 个 Swift Testing 用例通过。

## 风险与后续

- 这是 schema 契约测试与文档/skill 同步，不改变 CLI runtime 行为。
- 下一轮建议进入 Round 47：治理 command string 收集 helper，避免 schema / subcommand / plan 三处命令抽取逻辑继续分散。

## 提交状态

未提交。用户未授权 commit / push / tag / release。
