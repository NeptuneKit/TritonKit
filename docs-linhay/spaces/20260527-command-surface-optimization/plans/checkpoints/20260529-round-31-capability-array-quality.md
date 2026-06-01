# Round 31: Capability Array Quality

## 目标

继续收紧 capabilities matrix，让 `requiredBy` 与 `evidence` 可以作为 agent 的稳定分类和证据索引。

## 改动

- 新增 `SchemaFactSourceTests.capabilityPlanningArraysExposeNonemptyUniqueValues`。
- 校验 connected 状态下所有 capability：
  - `requiredBy` 不能包含空字符串。
  - `requiredBy` 不能在同一 capability 内重复。
  - `evidence` 不能包含空字符串。
  - `evidence` 不能在同一 capability 内重复。
- 当前 capabilities matrix 直接通过。
- 更新 agent-facing CLI 信息架构文档、AI CLI 可读控制文档和 public skills。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/capabilityPlanningArraysExposeNonemptyUniqueValues` 通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests` 通过，27 个 Swift Testing 用例。
- `swift test --package-path CLI` 通过，98 个 Swift Testing 用例。

## 风险

- 本轮只检查数组值质量，不检查 `requiredBy` 的枚举集合是否应该收敛到固定 taxonomy。

## 后续

Round 32 建议检查 `capabilities[].group` 是否落在固定允许集合，避免新增能力时产生拼写漂移。
