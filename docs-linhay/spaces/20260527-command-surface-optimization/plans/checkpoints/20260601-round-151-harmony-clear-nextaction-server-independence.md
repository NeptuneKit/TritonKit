# Round 151 - Harmony clear nextAction server independence

## 目标

修复 `harmony-clear-text` 在 server 不可达状态下的恢复建议误导，确保该能力始终表达 host-side unsupported 边界。

## 变更

1. 在 `runtimeCapabilityRequiresServer` 中移除 `harmony-clear-text`。
2. 保持 `harmony-clear-text` 的 nextAction 在所有状态下固定为：
   - `triton clear --platform harmony --json`
3. 新增测试断言：
   - `unavailableServer["harmony-clear-text"]` nextAction 仍为 `clear --platform harmony --json`；
   - `requiresLongRunningProcess` 不是 `true`。

## 原因

`clear --platform harmony` 目前实现为 host-side unsupported envelope，不依赖 runtime 连接，因此不应引导 agent 先 `serve`。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/capabilitiesMatrixExposesGroupsDependenciesRecoveryAndEvidence`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
