# Round 47: command string test fixtures

## 目标

治理 `SchemaFactSourceTests` 中 schema / subcommand / plan command string 的收集逻辑，减少后续继续增加 agent-facing 命令不变量时的重复遍历。

## 完成结果

- 新增 `CommandStringFixture`。
- 新增 `schemaNextCommandFixtures(includeSubcommands:)`。
- 新增 `schemaExampleCommandFixtures()`。
- 新增 `workflowPlanCommandFixtures(includeTaskInputs:)`。
- 替换以下测试中的重复 command string 收集逻辑：
  - `schemaNextCommandsStayAlignedWithCommandSchemas`
  - `subcommandNextCommandsStayAlignedWithCommandSchemas`
  - `schemaExamplesAndOutputFormatsRemainAgentUsable`
  - `schemaAndPlanPlaceholdersAreCompleteArgvTokens`
  - `workflowPlanCommandsStaySingleTritonInvocations`

## 验证

```bash
swift test --package-path CLI --filter SchemaFactSourceTests
swift test --package-path CLI
```

结果：通过。Schema fact source 当前为 38 个 Swift Testing 用例通过；CLI 全量当前为 109 个 Swift Testing 用例通过。

## 风险与后续

- 这是测试侧重构，不改变 CLI schema、capabilities、plan 或 runtime 行为。
- 下一轮建议进入 Round 48：继续补一个新的 command string 层不变量，或将 schema / plan command 校验上下文进一步统一。

## 提交状态

未提交。用户未授权 commit / push / tag / release。
