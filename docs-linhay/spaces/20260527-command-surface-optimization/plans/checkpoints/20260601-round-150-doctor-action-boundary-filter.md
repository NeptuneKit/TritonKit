# Round 150 - Doctor action boundary filter

## 目标

避免 `doctor` 的 action-surface 检查依赖单个 capability 名称白名单，改为基于能力语义判断信息性 Harmony 边界。

## 变更

1. `doctorChecks` 中 `unsupportedActionNames` 的筛选逻辑改为：
   - 保留 `group=action && supported=false` 的基本条件；
   - 新增 `isInformationalHarmonyActionBoundary(...)` 过滤：
     - capability 名以 `harmony-` 开头；
     - reason 包含 `not available in the current adapter`。
2. 这样 `harmony-clear-text` 不会把 `action-surface` 从 warn 推到 fail，同时不再依赖 capability 名硬编码。

## 影响

- `press` unsupported 仍会触发 `action-surface` warning；
- 后续新增同类 Harmony 信息性边界能力时，不需要再逐项改 capability 名排除列表。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/doctorResponseExposesOrderedRecoveryChecks`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
