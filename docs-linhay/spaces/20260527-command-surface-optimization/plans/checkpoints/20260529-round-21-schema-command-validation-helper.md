# Round 21 Schema Command Validation Helper

## 目标

降低 Round 18-20 新增不变量的维护成本：plan、capabilities nextAction 和 schema nextCommands 都在验证 schema-backed command，不应各自维护重复解析逻辑。

## 完成结果

- 抽取 `SchemaBackedCommandIssues`。
- 抽取 `validateSchemaBackedCommandString(...)`，用于验证 `triton ...` 命令字符串。
- 抽取 `validateSchemaBackedCommand(...)`，用于验证结构化 `{ command, args }`。
- 保留原有三个不变量：
  - `taskWorkflowPlanCommandsStayAlignedWithCommandSchemas`
  - `capabilityNextActionsStayAlignedWithCommandSchemas`
  - `schemaNextCommandsStayAlignedWithCommandSchemas`
- 行为不变，只减少重复测试代码。

## 改动文件

- `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests` 通过，17 个 Swift Testing 用例通过。
- `swift test --package-path CLI` 通过，88 个 Swift Testing 用例通过。

## 下一步

Round 22 建议检查 `outputContracts[]` 与 schema success/failure shape 的最低字段覆盖是否能形成全局不变量，优先避免新增命令缺少机器可读输出契约。
