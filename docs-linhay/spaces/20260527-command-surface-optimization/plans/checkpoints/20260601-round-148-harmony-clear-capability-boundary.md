# Round 148 - Harmony clear capability boundary

## 目标

在 agent-facing capabilities matrix 中显式表达 Harmony clear 目前不支持，避免 agent 将通用 `clear` 动作误规划到 Harmony host 路径。

## 变更

1. `runtimeCapabilities` 新增 `harmony-clear-text`：
   - `supported=false`
   - `reason=Host-side Harmony clear is not available in the current adapter`
2. `harmony-clear-text` 补齐 planning metadata：
   - `group=action`
   - `requiredBy=["action","assert","evidence"]`
   - `nextAction=triton clear --platform harmony --json`
   - `evidence=["unsupported-envelope","command-schema"]`
3. `clear` command schema 的 `providedCapabilities` 增加 `harmony-clear-text`，保证 schema 与 capabilities matrix 同步。
4. `doctor` action-surface 诊断显式忽略 `harmony-clear-text`，避免把既有 `press` warning 升级为 fail。

## 测试

- `SchemaFactSourceTests.capabilitiesMatrixExposesGroupsDependenciesRecoveryAndEvidence`
  - 验证 `harmony-clear-text` 存在且元数据稳定。
- `SchemaFactSourceTests.executionAndEvidenceSchemasExposeRecoveryCommandsAndOutputContracts`
  - 验证 `clear` schema 暴露 `harmony-clear-text`，并保持 `outputContracts=["input.result"]`。
- 全量回归：
  - `swift test --package-path CLI --filter SchemaFactSourceTests`

## 结果

- `harmony-clear-text` 已成为可发现能力边界；
- agent 可以通过 capabilities + schema 在规划阶段判断 Harmony clear 不可用并走替代路径；
- doctor 的 existing unsupported 动作告警语义保持稳定。
