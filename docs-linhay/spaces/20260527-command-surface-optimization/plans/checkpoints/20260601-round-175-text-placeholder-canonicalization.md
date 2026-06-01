# Round 175 - text placeholder canonicalization

## 目标

新增 capability `nextAction` 文本参数占位符门禁，确保 wait/assert/smoke 等文本语义入口对 agent 保持一致可替换 token。

## 变更

1. 新增测试 `SchemaFactSourceTests.capabilityNextActionTextPlaceholdersStayCanonical`。
2. 新增约束（覆盖 connected/disconnected/server-unreachable 三态）：
   - `--text` 的值必须是 `<text>`。
   - `--wait-text` 的值必须是 `<text>`。
   - `assert text-exists` 的 operand 必须是 `<text>`。
3. 本轮仅新增测试门禁，不改 runtime 行为与 schema 事实源。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/capabilityNextActionTextPlaceholdersStayCanonical`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
