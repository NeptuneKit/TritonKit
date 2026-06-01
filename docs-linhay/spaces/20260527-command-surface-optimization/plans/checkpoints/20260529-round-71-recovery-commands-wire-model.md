# Round 71: Recovery Commands Wire Model

## 目标

把 Round 70 的 recovery category 从测试 helper 推进到 `triton schema --json` 的机器可读输出。agent 不需要再只解析 `nextCommands[]` 字符串并另行查表，而是可以直接读取结构化 `recoveryCommands[]`。

## 改动

- 新增 `TKCommandRecoveryCommand`，字段为：
  - `command`
  - `category`
- `TKCommandSchema` 新增 `recoveryCommands[]`。
- `TKCommandSubcommandSchema` 新增 `recoveryCommands[]`。
- `recoveryCommands[]` 默认由 `nextCommands[]` 自动派生，保持现有 schema 定义点不需要逐条手工改。
- 新增 `TKCommandRecoveryCommand.rootCommand(in:)`、`category(forRootCommand:)`、`rootCommandTaxonomy`、`categoryTaxonomy`。
- 新增 `SchemaFactSourceTests.schemaRecoveryCommandsMirrorNextCommandsAndExposeCategories`，要求 command 级和 subcommand 级 `recoveryCommands[].command` 完全镜像 `nextCommands[]`，且 category 与 root command taxonomy 对齐。
- 直接验证 `triton schema --command status --json` 已输出 `recoveryCommands[]`，示例包含 `diagnose` 与 `discover` category。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaRecoveryCommandsMirrorNextCommandsAndExposeCategories`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`
- `swift run --package-path CLI triton schema --command status --json`

结果：全部通过。`SchemaFactSourceTests` 当前为 61 个 Swift Testing 用例通过；CLI 全量测试当前为 132 个 Swift Testing 用例通过。

## 风险与后续

- `nextCommands[]` 仍保留为字符串入口；`recoveryCommands[]` 是结构化增强，不要求旧消费者立刻迁移。
- 下一步建议 Round 72：建立 failure code family 到 recovery category 的测试映射，让 agent 能从 `error.code` 自动选择优先恢复阶段。
