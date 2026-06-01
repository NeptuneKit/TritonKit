# Round 63: Default Provider References

## 目标

把 `defaultProviders[]` 与 `inheritsDefaultsFrom[]` 纳入 schema-backed command 校验，确保 agent 看到默认值来源后能直接回到 `triton schema --json` 解释。

## 改动

- 新增 `SchemaFactSourceTests.schemaDefaultProviderReferencesStaySchemaBacked`。
- 测试覆盖 command 级 `inheritsDefaultsFrom[]`，以及 subcommand 级 `defaultProviders[]` / `inheritsDefaultsFrom[]`。
- 复用现有 `validateSchemaBackedCommandString(...)`，要求引用值是单条可被 schema 解释的 `triton ...` 命令。
- 当前 schema 直接满足该不变量；本轮不修改 runtime 行为或 schema 数据。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaDefaultProviderReferencesStaySchemaBacked`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：全部通过。CLI 全量测试当前为 124 个 Swift Testing 用例通过。

## 风险与后续

- 当前只校验引用命令是否存在、子命令是否可发现、flag 是否被声明；不验证 default provider 是否真的写入某个默认值文件。
- 下一步建议 Round 64 检查 `artifacts[]` / `subcommands[].artifacts[]` 是否落在固定 artifact taxonomy，避免 evidence 和 host artifact 名称继续自由增长。
