# Round 168 - requiredBy / nextAction.category alignment

## 目标

补齐 capability `requiredBy` workflow lane 与 `nextAction.category` 恢复分类的一致性门禁，减少“lane 语义正确但恢复分类偏移”的风险。

## 变更

1. 新增测试 `SchemaFactSourceTests.capabilityRequiredByLanesStayAlignedWithNextActionCategories`。
2. 在 capability 三态（connected/disconnected/server-unreachable）上新增约束：

### `webview-check` lane

- 任一 capability 只要 `requiredBy` 包含 `webview-check`，`nextAction.category` 必须属于 `observe` 或 `verify`。

### `xcode/project` lane

- 任一 capability 只要 `requiredBy` 包含 `xcode` 或 `project`，`nextAction.category` 必须属于 `project` 或 `archive`。

### `smoke-*` capability lane

- `smoke-ios` / `smoke-harmony`（且 `requiredBy` 含 `smoke`）必须保持 `nextAction.category == smoke`。

### `route` lane

- 任一 capability 只要 `requiredBy` 包含 `route` 或 `group == route`，`nextAction.category` 必须属于 `observe` 或 `verify`。

3. 本轮仅新增测试门禁，不改 runtime 行为与 schema 事实源。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/capabilityRequiredByLanesStayAlignedWithNextActionCategories`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
