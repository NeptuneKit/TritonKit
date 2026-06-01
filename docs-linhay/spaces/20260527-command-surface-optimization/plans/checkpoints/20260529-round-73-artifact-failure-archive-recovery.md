# Round 73: Artifact Failure Archive Recovery

## 目标

在 Round 72 的 failure code family 分类基础上，先选择语义最明确的一类做命令级恢复覆盖：artifact / output 失败必须能导向 `archive` category。

## 初始红灯

第一版“高优先级 failure code 必须匹配命令级 recovery category”的范围过大，会牵动 server、target、runtime、observe、action、assert 等大量命令恢复建议。

本轮收窄为 artifact / output 失败族后，红灯集中在两处：

- `sim:artifact_output_rejected` 只有 `prepare-target|smoke` 恢复类别。
- `record:file_write_failed` 只有 `diagnose|plan|replay` 恢复类别。

## 本轮改动

- 新增 `SchemaFactSourceTests.artifactFailureCodesExposeArchiveRecoveryCategories`。
- `sim.nextCommands[]` 增加 `triton evidence --output <dir.tritonevidence> --json`。
- `record.nextCommands[]` 增加 `triton evidence --output <dir.tritonevidence> --json`。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/artifactFailureCodesExposeArchiveRecoveryCategories`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：全部通过，完整 CLI package 当前 134 个 Swift Testing 用例通过。

## 后续

继续以单一 failure family 为单位收紧命令级恢复覆盖，避免再次扩大成全 schema `nextCommands[]` 重排。
