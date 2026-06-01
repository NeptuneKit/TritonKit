# Round 83: Doctor NextAction Category Contract

## 目标

让 `triton doctor --json` 的有序诊断检查也显式暴露 nextAction 的恢复阶段。doctor、capabilities 和 plan 三个入口应共享同一套 category vocabulary，agent 不需要在不同入口之间切换解析规则。

## 变更

- `SchemaFactSourceTests.agentBootstrapSchemasExposeRecoveryCommandsAndOutputContracts` 新增 `checks[].nextAction.category` contract 断言。
- `SchemaFactSourceTests.doctorResponseExposesOrderedRecoveryChecks` 增加 server bootstrap check 的 `nextAction.category == diagnose` 断言。
- `doctor` output contract 新增 `checks[].nextAction.category` 字段说明。
- 同步更新 agent-facing CLI 文档、AI CLI 当前契约文档、三份 public skill 和 memory。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/agentBootstrapSchemasExposeRecoveryCommandsAndOutputContracts`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：

- 聚焦 doctor output contract 测试先红灯，补字段后通过。
- `SchemaFactSourceTests` 72 项通过。
- CLI 全量 143 项通过。

## 后续

- 检查 `TKCLIErrorDetail.nextAction` 是否也需要在错误 output contract / failure shape 中显式说明 category。
- 或继续按剩余高优先级 failure family 收紧命令级 recovery category 覆盖。

## 提交状态

未提交，未 push，未 tag，未 release。
