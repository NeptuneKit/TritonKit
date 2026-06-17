# Round 146: harmony press selector alignment

## 目标

统一 Harmony host press 的 schema selector，避免仍使用跨平台泛化名 `host.key-action`。

## 变更

1. `press` command host output contract selector 从：
   - `host.key-action`
   改为：
   - `host.harmony-key-action`
2. 新增 red-first 测试断言：
   - `SchemaFactSourceTests.executionAndEvidenceSchemasExposeRecoveryCommandsAndOutputContracts` 要求 `press` 暴露 `host.harmony-key-action`，字段与 `HostActionOutput` 对齐。
3. 同步更新 dev 文档与三个 public skills，统一 Harmony press 解析入口。

## 验收

1. `triton schema --command press --json` 暴露 `host.harmony-key-action`。
2. `host.harmony-key-action` 字段完整覆盖 `HostActionOutput`。
3. `SchemaFactSourceTests` 全量通过。

## 验证

已通过：

```text
swift test --package-path CLI --filter SchemaFactSourceTests/executionAndEvidenceSchemasExposeRecoveryCommandsAndOutputContracts
swift test --package-path CLI --filter SchemaFactSourceTests
git diff --check
docs-linhay/scripts/check-docs.sh
docs-linhay/scripts/check-docs.sh
历史检索 "Round 146 harmony press selector alignment"
```

## 风险

本轮只做 schema selector 命名收敛，不改变 `press --platform harmony` runtime payload。

## 下一步

继续审计 host/embedded dual-path command 的 selector 命名一致性与 parser 稳定性，优先检查 `clear`/`input`/`route` 的 recovery 与 output contract 组合。

