# Round 152 - Harmony host action nextAction batch guard

## 目标

把 Harmony host action capability 的 server-independent nextAction 约束从单点修复升级为批量回归门禁。

## 变更

新增 `SchemaFactSourceTests.harmonyHostActionCapabilitiesKeepServerIndependentNextActions`：

1. 在 `server-unreachable` fixture 下验证以下能力：
   - `harmony-tap-text`
   - `harmony-wait-text`
   - `harmony-swipe`
   - `harmony-type-text`
   - `harmony-paste-text`
   - `harmony-clear-text`
   - `harmony-press-key`
2. 每个能力都必须：
   - 保持 schema 对齐的 nextAction command/args；
   - `requiresLongRunningProcess != true`；
   - 不回退到 `serve`。

## 价值

- 防止后续调整 `runtimeCapabilityRequiresServer` 或能力分类时，把 host-side Harmony action 的恢复建议误导回 server bootstrap。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/harmonyHostActionCapabilitiesKeepServerIndependentNextActions`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
