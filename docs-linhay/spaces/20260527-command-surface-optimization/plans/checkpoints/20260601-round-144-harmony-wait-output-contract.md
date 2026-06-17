# Round 144: harmony wait output contract

## 目标

补齐 `wait --platform harmony` 的 host-side schema output contract，避免 agent 只按 embedded `wait.result` 解析 Harmony host wait 输出。

## 变更

1. 新增 `host.harmony-wait` output contract：
   - model: `HostHarmonyWaitOutput`
   - kind: `host-action`
   - 覆盖 `condition/query/matched/timedOut/elapsedMs/pollCount/match/sourceCommands`
2. `wait` schema 的 `outputContracts` 从仅 `wait.result` 扩展为：
   - `wait.result`
   - `host.harmony-wait`
3. 新增失败测试并转绿：
   - `SchemaFactSourceTests.executionAndEvidenceSchemasExposeRecoveryCommandsAndOutputContracts`
   - 新断言要求 `wait` 同时暴露 `host.harmony-wait`。
4. 同步更新 agent-facing 文档与 public skills，明确 Harmony host wait 不可套用 embedded `wait.result` parser。

## 验收

1. `triton schema --command wait --json` 同时暴露 `wait.result` 与 `host.harmony-wait`。
2. `host.harmony-wait` 字段覆盖 `HostHarmonyWaitOutput` 的 machine-readable 输出。
3. 现有 schema kind/selector/field taxonomy 测试保持通过。

## 验证

已通过：

```text
swift test --package-path CLI --filter SchemaFactSourceTests/executionAndEvidenceSchemasExposeRecoveryCommandsAndOutputContracts
swift test --package-path CLI --filter SchemaFactSourceTests
git diff --check
docs-linhay/scripts/check-docs.sh
docs-linhay/scripts/check-docs.sh
历史检索 "Round 144 harmony wait output contract"
```

## 风险

本轮只补 schema contract 和文档，不改 Harmony host wait runtime 行为。

## 下一步

继续审计 `smoke harmony` / `app open-url --device harmony` 是否还存在 host multi-envelope 分支未在 schema output contracts 中显式声明。

