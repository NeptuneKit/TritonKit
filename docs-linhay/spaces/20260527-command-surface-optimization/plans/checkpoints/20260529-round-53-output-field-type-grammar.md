# Round 53 - output contract field type grammar

## 目标

锁定 `outputContracts[].fields[].type` 的机器可读类型语法，避免字段类型退化成自然语言说明。

## 完成结果

- 新增 `SchemaFactSourceTests.schemaOutputContractFieldTypesStayMachineReadable`。
- 首次红灯发现现有 schema 使用 `[String:String]` 字典类型，初版 helper 只支持数组。
- 修正 helper，支持标量/DTO 类型、optional `?`、数组 `[Type]`、字典 `[Key:Value]` 和 union `TypeA|TypeB`。
- 当前 schema 已满足该不变量。
- 同步更新 agent-facing CLI 信息架构文档、AI CLI 控制文档，以及三个 public skill 的字段类型契约说明。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaOutputContractFieldTypesStayMachineReadable`：先失败，随后修正 helper 后通过，1 个 Swift Testing 用例通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests`：通过，44 个 Swift Testing 用例通过。
- `swift test --package-path CLI`：通过，115 个 Swift Testing 用例通过。

## 风险与后续

- 当前约束是类型语法，不限制具体 DTO 名称集合；这样既保证可解析，又不让新增 DTO 每次都修改巨大白名单。
- 下一轮可整理 schema taxonomy helper，降低 `SchemaFactSourceTests` 内多个 taxonomy 集合的维护重复。

## 提交状态

未提交。
