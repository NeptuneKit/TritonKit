# Round 147: ax artifact contract test coverage

## 目标

补齐 `ax` 的 Harmony host artifact contract 测试覆盖，避免只校验 screenshot 而漏掉 `ax --platform harmony` 的 selector 回归。

## 变更

1. 在 `SchemaFactSourceTests.observationAndRuntimeSchemasExposeDiagnosticContracts` 中新增 `ax` 断言：
   - `ax` failure codes 覆盖 `server_unavailable`、`host_command_failed`
   - `ax` output contract 必须暴露 `host.harmony-artifact`
2. contract 字段断言覆盖：
   - `ok/action/platform/target/artifact/sourceCommands/note`

## 验收

1. `triton schema --command ax --json` 的 Harmony host artifact selector 有回归测试保护。
2. `SchemaFactSourceTests` 全量通过。

## 验证

已通过：

```text
swift test --package-path CLI --filter SchemaFactSourceTests/observationAndRuntimeSchemasExposeDiagnosticContracts
swift test --package-path CLI --filter SchemaFactSourceTests
git diff --check
docs-linhay/scripts/check-docs.sh
docs-linhay/scripts/check-docs.sh
历史检索 "Round 147 ax artifact contract test coverage"
```

## 风险

本轮是测试覆盖增强，不改变 runtime 行为或 schema contract 实现。

## 下一步

继续审计 host/embedded dual-path 命令的 output selector 命名与字段稳定性，优先覆盖 `clear`、`input`、`route` 的组合路径。

