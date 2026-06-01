# Round 60: Argument Forms

## 目标

继续拆分 schema 参数信息，把 positional argument 从 `options[]` 中移出，让 `options[]` 可以稳定表示纯 `--long-flag` 或 slash alias 组。

## 改动

- 新增 `TKCommandArgumentForm`，字段为 `name`、`type`、`required`、`description`。
- 在 `TKCommandSchema` 新增 `argumentForms: [TKCommandArgumentForm]` wire 字段。
- `TKCommandSchema` 初始化时自动把 `name` 形如 `<...>` 的历史 option 条目从 `options[]` 分离到 `argumentForms[]`。
- `renderSchema` 文本输出新增 argument forms 分组。
- 新增 `SchemaFactSourceTests.schemaArgumentFormsStaySeparateFromOptions`。
- 收紧 `SchemaFactSourceTests.schemaCommandSubcommandAndFlagNamesUseStableCLIKeys`：拆分后 `options[]` 全部都必须是 `--long-flag` 或 slash alias 组。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaArgumentFormsStaySeparateFromOptions`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：全部通过。CLI 全量测试当前为 121 个 Swift Testing 用例通过。

## 风险与后续

- 这是 schema wire 字段新增和输出形态调整；当前没有 legacy agent 兼容负担。
- 下一步可以继续治理 `requiredOptions[]` / `optionalOptions[]` / `oneOfRequiredOptions[]` 的 key 语法，确保这些数组只引用 `options[]` 或 `argumentForms[]` 中可发现的 key。
