# Round 75: Runtime Transport Diagnose Recovery

## 目标

继续按单一 failure family 收紧命令级恢复覆盖：server / runtime transport 失败必须能导向 `diagnose` category。

## 初始红灯

新增 `SchemaFactSourceTests.runtimeTransportFailureCodesExposeDiagnoseRecoveryCategories` 后，红灯集中在 runtime、observe、action、assert、wait、evidence 等命令。它们包含 `server_unavailable`、`request_failed`、`request_timeout`、`runtime_unavailable` 或 `runtime_not_connected`，但恢复建议多为 observe、archive、verify 或 action。

## 本轮改动

- runtime state / snapshot / semantic action 命令补充 `triton status --json`。
- observe / webview / route / hierarchy / node / attrs / object / export / evidence / capture / assert / find / wait / ax / geometry / hit / screenshot 补充 `triton status --json`。
- action `tap` 与 batch `input` 补充 `triton status --json`。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/runtimeTransportFailureCodesExposeDiagnoseRecoveryCategories`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：全部通过，完整 CLI package 当前 136 个 Swift Testing 用例通过。

## 后续

Round 76 可继续按 target failure family 收紧：`target_not_found`、`target_unavailable`、`ambiguous_target`、`target_offline`、`device_not_ready` 应导向 `prepare-target`。
