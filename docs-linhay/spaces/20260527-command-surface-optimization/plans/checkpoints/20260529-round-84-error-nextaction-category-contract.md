# Round 84: Error NextAction Category Contract

## 目标

让通用错误 envelope 也显式暴露 nextAction 的恢复阶段。`failureShape`、`TKCLIErrorDetail?` output contract、doctor、capabilities 和 plan 应共享同一套 category vocabulary，agent 不需要解析人读 hint 或 command root 才能判断恢复阶段。

## 变更

- 新增 `SchemaFactSourceTests.schemaFailureShapesDescribeNextActionCategory`，要求所有声明 `nextAction?` 的 command-level `failureShape` 同时说明 nextAction 的 category 结构。
- 新增 `SchemaFactSourceTests.errorOutputContractsExposeNextActionCategory`，要求所有声明 `error: TKCLIErrorDetail?` 的 output contract 同步暴露 `error.nextAction.category`。
- `TKCommandSchema` 默认 failure shape 更新为 `nextAction?{ command,args,category,requiresLongRunningProcess? }`。
- `TKCommandSchema` 初始化/解码时会标准化旧式 `nextAction?` failure shape，避免各命令定义重复维护错误 envelope 文案。
- `schemaContractFields` 对 `TKCLIErrorDetail?` 字段自动补充 `error.nextAction` 与 `error.nextAction.category`。
- 同步更新 agent-facing CLI 文档、AI CLI 当前契约文档、三份 public skill 和 memory。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaFailureShapesDescribeNextActionCategory`
- `swift test --package-path CLI --filter SchemaFactSourceTests/errorOutputContractsExposeNextActionCategory`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：

- 两条新增测试均先红灯，补齐 schema 标准化与 output contract 注入后通过。
- `SchemaFactSourceTests` 74 项通过。
- CLI 全量 145 项通过。

## 后续

- 继续检查剩余 error family 是否需要更细的 recovery category 覆盖。
- 或检查 `schema --command <name>` 的单命令输出是否需要额外暴露 error envelope field taxonomy，减少 agent 从 output contract 反查的步骤。

## 提交状态

未提交，未 push，未 tag，未 release。
