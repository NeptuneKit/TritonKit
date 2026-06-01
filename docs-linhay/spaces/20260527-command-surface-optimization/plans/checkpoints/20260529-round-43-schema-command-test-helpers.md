# Round 43: schema-backed command test helpers

## 目标

继续治理 `SchemaFactSourceTests` 的测试基础设施，把 schema-backed command 校验中的重复 schema map 构造与 issue 空断言收敛成 helper。

## 完成结果

- 新增 `commandSchemaMap()`，统一生成 command name 到 `TKCommandSchema` 的索引。
- 新增 `expectNoSchemaBackedCommandIssues()`，统一断言：
  - `unknownCommands` 为空；
  - `unknownSubcommands` 为空；
  - `unknownFlags` 为空。
- 替换 task workflow plan、workflow plan metadata、schema nextCommands、schema examples、capability nextAction 等测试里的重复校验代码。
- 顺手替换多个 schema contract 测试中的重复 schema map 构造，测试语义保持不变。

## 验证

```bash
swift test --package-path CLI --filter SchemaFactSourceTests
swift test --package-path CLI
```

结果：通过。Schema fact source 当前为 35 个 Swift Testing 用例通过；CLI 全量当前为 106 个 Swift Testing 用例通过。

## 风险与后续

- 这是测试侧重构，不改变 CLI schema、capabilities、plan 或 runtime 行为。
- 下一轮建议进入 Round 44：继续治理 placeholder / single invocation 的 command string 收集逻辑，或补一个新的 agent-facing schema 不变量。

## 提交状态

未提交。用户未授权 commit / push / tag / release。
