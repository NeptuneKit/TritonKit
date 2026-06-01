# Round 25: Subcommand Failure Code Coverage

## 目标

继续收紧方案 C 的 failure contract：子命令 `failureCodes[]` 必须被父命令 `failureCodes[]` 覆盖。

## 改动

- 新增 `SchemaFactSourceTests.subcommandFailureCodesStayCoveredByParentSchemas`。
- 测试遍历所有 command schema 的 `subcommands[]`，检查每个子命令 failure code 是否存在于父命令 failure code 集合中。
- 当前 schema 直接通过，说明现有子命令错误码没有逃逸父命令恢复码全集。
- 更新 agent-facing CLI 信息架构文档、AI CLI 可读控制文档和 public skills。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/subcommandFailureCodesStayCoveredByParentSchemas` 通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests` 通过，21 个 Swift Testing 用例。
- `swift test --package-path CLI` 通过，92 个 Swift Testing 用例。

## 风险

- 本轮只检查子命令 codes 是否被父命令覆盖，不检查 failure shape 文本中的显式 code 是否完整映射到 failureCodes。

## 后续

Round 26 建议检查 schema 参数自身质量：所有 option / argument / subcommand 名称、类型、描述和重复项，防止 agent 读取低质量参数契约。
