# Round 145: harmony artifact output contract

## 目标

修正 Harmony host artifact 输出契约，让 `ax/screenshot --platform harmony` 不再错误声明为 `host.artifact`（device-level contract）。

## 变更

1. 新增 `host.harmony-artifact` output contract：
   - model: `HostHarmonyArtifactOutput`
   - kind: `host-artifact`
   - 覆盖 `ok/action/platform/target/artifact/sourceCommands/note`
2. `ax` schema output contracts 从：
   - `ax.current` + `host.artifact`
   改为：
   - `ax.current` + `host.harmony-artifact`
3. `screenshot` schema output contracts 从：
   - `screenshot.metadata` + `host.artifact`
   改为：
   - `screenshot.metadata` + `host.harmony-artifact`
4. 更新 schema 测试断言：
   - `SchemaFactSourceTests` 中 screenshot contract 选择器改为 `host.harmony-artifact`。

## 验收

1. `triton schema --command ax --json` 暴露 `host.harmony-artifact`。
2. `triton schema --command screenshot --json` 暴露 `host.harmony-artifact`。
3. `host.harmony-artifact` 字段与 `HostHarmonyArtifactOutput` 一致。

## 验证

已通过：

```text
swift test --package-path CLI --filter SchemaFactSourceTests/observationAndRuntimeSchemasExposeDiagnosticContracts
swift test --package-path CLI --filter SchemaFactSourceTests
git diff --check
docs-linhay/scripts/check-docs.sh
docs-linhay/scripts/qmd-sync.sh
qmd query "Round 145 harmony artifact output contract"
```

## 风险

本轮只改 schema contract 与测试断言，不改 Harmony host artifact runtime 行为。

## 下一步

继续审计 remaining host/embedded mixed commands（如 `press`、`clear`、`input`）是否还存在 schema 选择器语义不稳定或 parser 歧义。

