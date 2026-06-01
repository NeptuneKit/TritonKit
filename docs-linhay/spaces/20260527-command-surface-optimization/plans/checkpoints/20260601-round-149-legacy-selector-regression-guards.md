# Round 149 - Legacy selector regression guards

## 目标

为 action/observe 的 host-harmony 输出 contract 增加负向断言，防止 selector 命名回退到泛化旧名。

## 变更

在 `SchemaFactSourceTests.executionAndEvidenceSchemasExposeRecoveryCommandsAndOutputContracts` 增加以下断言：

1. `wait` output contracts 不得出现 `host.wait`。
2. `tap` output contracts 不得出现 `host.tap`。
3. `swipe` output contracts 不得出现 `host.swipe`。
4. `type` 与 `paste` output contracts 不得出现 `host.text-input`。

## 范围说明

- 本轮仅测试加固，不调整 CLI runtime 行为。
- 目标是把已完成的 `host.harmony-*` selector 收敛固化为长期回归门禁。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/executionAndEvidenceSchemasExposeRecoveryCommandsAndOutputContracts`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
