# Round 23: Output Contract Field Quality

## 目标

把方案 C 的 output contract 从“命令声明了输出模型”推进到“agent 能稳定解析输出字段”。本轮不改命令行为，只补 schema 质量不变量。

## 改动

- 新增 `SchemaFactSourceTests.schemaOutputContractsExposeNonemptyFields`。
- 校验所有 command schema 的 `outputContracts[]`：
  - `selector` 非空。
  - `model` 非空。
  - `fields[]` 非空。
  - 同一 contract 内字段名不重复。
  - 每个 field 的 `name`、`type`、`description` 非空。
- 现有 schema 已满足该约束；测试修正了 `model` 可选字段的检查方式后直接通过。
- 同步更新 agent-facing CLI 信息架构文档、AI CLI 可读控制文档和对外 public skills。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaOutputContractsExposeNonemptyFields` 通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests` 通过，19 个 Swift Testing 用例。
- `swift test --package-path CLI` 通过，90 个 Swift Testing 用例。

## 风险

- 本轮只覆盖 contract 字段完整性，不验证字段名是否真实覆盖运行时所有 JSON shape。
- 下一轮应继续检查 failure contract：有失败退出或 failure shape 的 agent-facing command 是否都暴露稳定 `failureCodes[]`。

## 后续

Round 24 建议建立 failure code 覆盖不变量，避免命令已经可能失败但 schema 没有给 agent 可恢复的稳定错误码集合。
