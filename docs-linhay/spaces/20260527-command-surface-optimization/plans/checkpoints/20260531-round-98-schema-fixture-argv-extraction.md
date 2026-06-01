# Round 98: schema fixture argv extraction

## 目标

继续推进 `argv-first` 测试基座：把 `schema nextCommands[]` 和 `schema examples[]` 的 schema-backed 校验从直接吃字符串，收敛到“先抽出单个 Triton 调用 argv，再走统一 helper”。

## 完成内容

1. `CommandStringFixture` 新增 `argv` 字段，保存从原始字符串里抽出的单个 Triton 调用 token。
2. 新增 `extractSingleTritonInvocationArgv(from:)`：
   - 从字符串中定位第一个 `triton`；
   - 按 token 向后收集；
   - 遇到 `|`、`&&`、`||`、`;`、重定向或 shell substitution token 即停止；
   - 返回单个 Triton 调用的 argv。
3. `schemaNextCommandFixtures(...)` 与 `schemaExampleCommandFixtures()` 现在都预先抽出 `argv`。
4. `schema next commands ...` / `subcommand next commands ...` / `schema examples and output formats remain agent usable` 三条测试改为直接调用 `validateSchemaBackedArgv(...)`。
5. `schema and plan placeholders are complete argv tokens` 对 schema nextCommands / examples 也改为检查抽出的 `argv`，避免 pipeline 前置 shell 片段干扰 placeholder 质量判断。
6. `workflowPlanCommandFixtures(...)` 也同步补齐 `argv` 字段，保持 fixture 结构一致。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaNextCommandsExposeSchemaBackedArgv`：通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests/subcommandNextCommandsExposeSchemaBackedArgv`：通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaExamplesAndOutputFormatsRemainAgentUsable`：通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaAndPlanPlaceholdersAreCompleteArgvTokens`：通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests`：通过，79 个 Swift Testing 用例通过。

## 风险

1. 这轮仍是轻量 token 级提取，不解析复杂 shell quoting 或嵌套 substitution。
2. 当前 helper 只抽“第一个” Triton 调用；多调用示例仍靠 `schema examples contain one Triton invocation for agent reuse` 保证不进入可复用样本集合。

## 下一步

1. 可继续评估把 `capability.nextAction`、`defaultProviders[]` / `inheritsDefaultsFrom[]` 等字符串入口也逐步统一到同一类 argv 提取/校验模型。
2. 若后续出现需要支持更复杂 shell example 的场景，再单独决定是否引入更强的 argv 提取策略。
