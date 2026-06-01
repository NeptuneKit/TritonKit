# Round 173 - target selector placeholder canonicalization

## 目标

新增 capability `nextAction` 目标选择类参数的占位符一致性门禁，确保 agent 在 target/simulator/bundle-id 维度拿到稳定可替换 token。

## 变更

1. 新增测试 `SchemaFactSourceTests.capabilityNextActionTargetSelectorPlaceholdersStayCanonical`。
2. 新增约束（覆盖 connected/disconnected/server-unreachable 三态）：
   - `--device`：
     - `smoke` 命令固定使用 `<device>`
     - 其余命令固定使用 `<selector>`
   - `--simulator` 固定使用 `<udid|booted>`
   - `--bundle-id` 固定使用 `<bundle-id>`
3. 本轮仅新增测试门禁，不改 runtime 行为与 schema 事实源。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/capabilityNextActionTargetSelectorPlaceholdersStayCanonical`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
