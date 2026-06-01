# Round 99: string entrypoint argv unification

## 目标

继续收敛测试基座里残余的 string 入口，让 `capability.nextAction`、`defaultProviders[]`、`inheritsDefaultsFrom[]` 这些地方也尽量复用统一的 argv-first 校验路径。

## 完成内容

1. 新增 `validateSchemaBackedCommandExpression(...)`：
   - 接收一个 string command expression；
   - 通过 `extractSingleTritonInvocationArgv(from:)` 抽出单个 Triton 调用；
   - 再走 `validateSchemaBackedArgv(...)`。
2. `schema default provider references stay schema backed` 现在不再直接做字符串拆词，而是统一走 `validateSchemaBackedCommandExpression(...)`。
3. 新增 `validateSchemaBackedNextAction(...)`，把 `{ command, args }` 重新组装成 `["triton", command] + args` 后，统一交给 `validateSchemaBackedArgv(...)`。
4. `capability next actions stay aligned with command schemas` 现在也不再直接调用底层 `validateSchemaBackedCommand(...)`。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaDefaultProviderReferencesStaySchemaBacked`：通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests/capabilityNextActionsStayAlignedWithCommandSchemas`：通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests`：通过，79 个 Swift Testing 用例通过。

## 风险

1. `nextAction` 仍然是结构化 `{ command, args }`，本轮只是让测试消费路径也对齐 argv-first，不改 wire model。
2. `validateSchemaBackedCommandString(...)` 仍保留，主要服务 unknown-command 诊断等直接 string 场景；本轮没有强制删除旧 helper。

## 下一步

1. 若继续清理测试基座，可以评估哪些旧 string helper 已经完全无外部调用，是否值得进一步删除或收口。
2. 也可以转回更高层的契约治理，例如进一步减少 schema 中对 `command` shell string 的依赖描述。
