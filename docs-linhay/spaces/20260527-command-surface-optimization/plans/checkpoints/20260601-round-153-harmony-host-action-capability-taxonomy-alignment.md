# Round 153 - Harmony host action capability taxonomy alignment

## 目标

把 Harmony host action capability 的 capabilities taxonomy 与动作语义对齐，避免 agent 规划时将其误归类为 target/app 准备能力。

## 变更

1. `runtimeCapabilityGroup` 调整：
   - `harmony-tap-text`
   - `harmony-wait-text`
   - `harmony-swipe`
   - `harmony-type-text`
   - `harmony-paste-text`
   - `harmony-press-key`
   - 以上能力统一归类到 `action`。
2. `runtimeCapabilityRequiredBy` 调整：
   - 上述能力统一使用 `["action", "assert", "evidence"]`。
3. `runtimeCapabilityEvidence` 调整：
   - 上述能力统一映射为 `["host-command-json", "host-artifact"]`。
4. 测试加固：
   - `capabilitiesMatrixExposesGroupsDependenciesRecoveryAndEvidence` 新增 connected 状态断言；
   - `harmonyHostActionCapabilitiesKeepServerIndependentNextActions` 新增 `group/requiredBy` 断言。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/capabilitiesMatrixExposesGroupsDependenciesRecoveryAndEvidence`
- `swift test --package-path CLI --filter SchemaFactSourceTests/harmonyHostActionCapabilitiesKeepServerIndependentNextActions`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
