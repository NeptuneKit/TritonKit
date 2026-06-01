# Round 132 - bootstrap primary next action

## 本切片目标

把 bootstrap / capability / plan 三个事实源里的“首选下一条 Triton 命令”从隐式数组首元素提升成顶层结构化字段，减少 agent 为了决定第一步要执行什么而去扫 `checks[]`、`capabilities[]` 或 `steps[]`。

## 完成结果

- `Sources/TritonKitShared/TKCLITransportModels.swift`
  - `TKCLINextAction` 新增 `fromTritonArgv(_:)` helper，用于从 `plan.steps[].argv` 回填结构化 next action。
  - `TKCapabilitiesResponse` 新增：
    - `primaryCapability: String?`
    - `primaryNextAction: TKCLINextAction?`
  - `TKDoctorResponse` 新增：
    - `primaryNextAction: TKCLINextAction?`
  - `TKWorkflowPlanResponse` 新增：
    - `primaryNextAction: TKCLINextAction?`
  - shared init / decode 回填规则：
    - `capabilities`：优先 `error.nextAction`，否则首个 unsupported capability 的 nextAction，再回落到 `plan` capability 或首个可执行 capability。
    - `doctor`：优先 `nextStep` 对应 check 的 nextAction，再回落到首个 fail/warn check 或 `error.nextAction`。
    - `plan`：优先 `nextStep` 对应 step 的 `argv`，再回落到首个 step；旧 payload 缺 step 时，按 `nextStep` 做保守兼容推断。
- `Sources/TritonKitCLI/CLISchemaContracts.swift`
  - `capabilities` output contract 新增：
    - `primaryCapability`
    - `primaryNextAction`
  - `doctor` output contract 新增：
    - `primaryNextAction`
  - `plan.next-steps` output contract 新增：
    - `primaryNextAction`
  - 上述字段都复用通用 `TKCLINextAction?` schema 展开。
- `Tests/TritonKitSharedTests/TKCLITransportModelsTests.swift`
  - 补齐 shared roundtrip / old-payload decode 断言，覆盖 capabilities / doctor / plan 的 primary next action。
- `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`
  - bootstrap schema contract 断言补齐 `primaryCapability` / `primaryNextAction.*`
  - task / bootstrap fixture 补齐 primary next action 断言

## 影响边界

- 这是 bootstrap 事实源的 machine-readable 收口，不改 CLI 执行语义。
- 直接提升了 agent 的首步执行确定性，尤其是：
  - `doctor` 不再需要先找第一条 fail/warn check
  - `capabilities` 不再需要自己决定先看哪个 capability
  - `plan` 不再需要 `nextStep -> steps[]` 再反查 argv

## 验证

- `swift test --filter TKCLITransportModelsTests`
  - 通过，21 个 Swift Testing 用例通过
- `swift test --package-path CLI --filter SchemaFactSourceTests`
  - 通过，85 个 Swift Testing 用例通过

## 后续队列

- 继续看是否要给 `doctor` / `capabilities` 再补 top-level 首选 workflow lane 或首选 provenance，进一步减少 agent 对 `relatedCapabilities`、`requiredBy` 与数组排序的依赖。
