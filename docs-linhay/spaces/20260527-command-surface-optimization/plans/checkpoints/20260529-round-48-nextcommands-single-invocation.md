# Round 48: nextCommands single invocation contract

## 目标

将单条 Triton invocation 约束从 `plan.steps[].command` 扩展到命令级与子命令级 `nextCommands[]`，避免恢复建议依赖 shell 管道、重定向、命令替换或多命令拼接。

## 完成结果

- 新增 `SchemaFactSourceTests.schemaNextCommandsStaySingleTritonInvocations`。
- 测试复用 Round 47 的 `schemaNextCommandFixtures(includeSubcommands: true)`，覆盖 command 与 subcommand 的 `nextCommands[]`。
- 当前 schema 直接满足该不变量，没有发现复合 shell command。
- 同步更新：
  - `docs-linhay/dev/agent-facing-cli-information-architecture.md`
  - `docs-linhay/dev/ai-cli-readable-control.md`
  - `TritonKit.skills/tritonkit-dev-feedback/SKILL.md`
  - `TritonKit.skills/tritonkit-emulator-cli-takeover/SKILL.md`
  - `TritonKit.skills/tritonkit-real-project-regression/SKILL.md`

## 验证

```bash
swift test --package-path CLI --filter SchemaFactSourceTests/schemaNextCommandsStaySingleTritonInvocations
swift test --package-path CLI --filter SchemaFactSourceTests
swift test --package-path CLI
```

结果：通过。Schema fact source 当前为 39 个 Swift Testing 用例通过；CLI 全量当前为 110 个 Swift Testing 用例通过。

## 风险与后续

- 这是 schema 契约测试与文档/skill 同步，不改变 CLI runtime 行为。
- 下一轮建议进入 Round 49：将 command string fixture helper 继续用于 examples 的 shell 边界，明确哪些 example 可以包含 pipeline，哪些恢复/plan 命令不能包含。

## 提交状态

未提交。用户未授权 commit / push / tag / release。
