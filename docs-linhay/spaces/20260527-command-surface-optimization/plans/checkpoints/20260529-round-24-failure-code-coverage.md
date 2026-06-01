# Round 24: Failure Code Coverage

## 目标

把失败恢复契约纳入方案 C 的 schema 全局不变量：agent-facing command 只要声明失败面，就必须暴露稳定 `failureCodes[]`。

## 红灯

新增 `SchemaFactSourceTests.schemaFailureSurfacesExposeStableFailureCodes` 后，聚焦测试失败，缺口为：

- `ax`
- `serve`
- `version`

原因：

- `version` 是无失败面的 bootstrap 命令，但继承了默认 `failureShape`。
- `serve` 是长运行进程，可能启动失败，但缺少稳定错误码集合。
- `ax` 同时覆盖 embedded runtime 与 Harmony host layout，已经有输出 contract，但缺失败码集合。

## 修复

- `version` 显式设置 `failureShape=nil`，避免默认失败 envelope 误导 agent。
- `serve` 增加 `failureShape` 和 `failureCodes=["validation_failed","server_start_failed"]`。
- `ax` 增加 embedded / host 统一失败 shape，并补齐 `server_unavailable`、`target_unavailable`、`target_not_found`、`ambiguous_target`、`runtime_unavailable`、`request_failed`、`host_command_failed`、`artifact_write_failed`、`validation_failed`。
- 更新 agent-facing CLI 信息架构文档、AI CLI 可读控制文档和 public skills。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaFailureSurfacesExposeStableFailureCodes` 通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests` 通过，20 个 Swift Testing 用例。
- `swift test --package-path CLI` 通过，91 个 Swift Testing 用例。

## 风险

- 本轮只要求失败码集合存在，不验证运行时实际错误码一定属于 schema 集合。
- 下一轮可以继续检查 `failureShape` 文本中出现的显式 code 是否被 `failureCodes[]` 覆盖，或检查 subcommand failure codes 是否回落到父命令集合。

## 后续

Round 25 建议检查 subcommand failure code 与父命令 failure code 的包含关系，避免 agent 读取子命令契约时拿到父命令未声明的恢复码。
