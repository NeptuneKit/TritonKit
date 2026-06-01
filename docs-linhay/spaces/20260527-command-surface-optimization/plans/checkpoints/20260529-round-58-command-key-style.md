# Round 58: Command Key Style

## 目标

收紧 CLI schema 中可安全锁定的命令 key 命名：root command、subcommand 以及纯长 flag / alias 组必须适合作为 agent 路由 key。

## 红灯发现

首次测试把所有 `options[].name` 都当作纯 option key，立即暴露历史混用：大量 `options[].name` 实际是 usage / synopsis，例如 `inspect <path>`、`device:alias set <name> ...`、`sim:runtime list|verify|...`。

该发现说明 `options[].name` 当前还承担“参数说明”和“命令形态说明”两种职责，后续应拆成独立 `usageForms` / `argumentForms` 或等价字段。

## 改动

- 新增 `SchemaFactSourceTests.schemaCommandSubcommandAndFlagNamesUseStableCLIKeys`。
- 要求 root command name 使用 lower-kebab。
- 要求 subcommand name 使用 lower-kebab。
- 要求以 `--` 开头的纯长 flag 或 slash alias 组使用 lower-kebab，例如 `--language/--lang`。
- 新增 `isLongOptionKeyExpression(_:)` helper。
- 文档和 public skills 同步记录：usage / synopsis 混在 `options[].name` 是后续治理点，不应让 agent 把它误当纯 option key。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaCommandSubcommandAndFlagNamesUseStableCLIKeys`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：全部通过。CLI 全量测试当前为 119 个 Swift Testing 用例通过。

## 风险与后续

- 本轮不重构 schema 数据结构，只锁定不会破坏现有表达的 key 语法。
- 后续建议单独推进 `options[].name` 语义拆分：纯 flags、positional arguments、usage forms、subcommand synopsis 不再混在同一个字段。
