# Round 59: Usage Forms

## 目标

把 schema 中“命令形态说明”和“option/flag”分开，让 agent 不再从 `options[]` 中猜哪些条目是可传 flag，哪些只是 `Subcommand` / `Task` synopsis。

## 改动

- 在 `TKCommandSchema` 新增 `usageForms: [TKCommandUsageForm]` wire 字段。
- 新增 `TKCommandUsageForm`，字段为 `form`、`kind`、`description`。
- `TKCommandSchema` 初始化时自动把 `TKCommandSchemaOption.type == "Subcommand"` 或 `"Task"` 的历史条目从 `options[]` 分离到 `usageForms[]`。
- `renderSchema` 文本输出新增 usage forms 分组。
- 新增 `SchemaFactSourceTests.schemaUsageFormsStaySeparateFromOptions`，要求 Subcommand / Task 不再出现在 `options[]`，且有 subcommands 的命令必须暴露 usage forms。
- 更新 `plan`、`device`、`sim`、`webview`、`xctrace`、`coverage`、`xcresult` 相关测试，从 `options[]` 改为读取 `usageForms[]`。
- 同步更新 agent-facing CLI 信息架构、AI CLI 可读控制文档，以及三个 public skills。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaUsageFormsStaySeparateFromOptions`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：全部通过。CLI 全量测试当前为 120 个 Swift Testing 用例通过。

## 风险与后续

- 这是 schema wire 字段新增和输出形态调整；当前项目不承担 legacy agent 兼容负担，符合“CLI 直接绑定 skills”的破坏性更新策略。
- 剩余 positional argument，例如 `<query>`、`<path>`、`<text>`，仍暂存在 `options[]`。下一步建议新增 `argumentForms[]` 或等价字段，把 positional argument 继续从 flags 中拆出来。
