# Round 30: Capability Name Uniqueness

## 目标

确保能力名可以作为 agent 的稳定索引 key 使用，避免 schema 或 capabilities matrix 出现重复能力名。

## 改动

- 新增 `SchemaFactSourceTests.capabilityNamesRemainUniqueForAgentIndexing`。
- 校验每个 command 的 `providedCapabilities[]` 内部不能重复。
- 校验 connected 状态下 `runtimeCapabilities(...)` 输出的 `capabilities[].name` 不能重复。
- 当前数据直接通过，未发现重复能力名。
- 更新 agent-facing CLI 信息架构文档、AI CLI 可读控制文档和 public skills。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/capabilityNamesRemainUniqueForAgentIndexing` 通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests` 通过，26 个 Swift Testing 用例。
- `swift test --package-path CLI` 通过，97 个 Swift Testing 用例。

## 风险

- 本轮只检查命名唯一性，不检查能力命名是否语义精确；语义仍由 group、requiredBy、nextAction、evidence 和 outputContracts 共同约束。

## 后续

Round 31 建议检查 `capabilities[].requiredBy`、`evidence` 是否去重且非空字符串，避免能力元数据数组出现重复或空值。
