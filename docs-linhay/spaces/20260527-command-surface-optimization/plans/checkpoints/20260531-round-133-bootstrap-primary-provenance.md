# Round 133 - bootstrap primary provenance

## 本切片目标

继续收紧 bootstrap 三个事实源的顶层首选入口，让 agent 不只知道“下一条先跑什么”，还知道“为什么是它”。

## 完成结果

- `Sources/TritonKitShared/TKCLITransportModels.swift`
  - `TKCapabilitiesResponse` 新增：
    - `primaryWorkflowCategory: String?`
    - `primaryNextActionSource: String?`
  - `TKDoctorResponse` 新增：
    - `primaryNextActionSource: String?`
  - `TKWorkflowPlanResponse` 新增：
    - `primaryNextActionSource: String?`
  - shared 回填规则现在同时返回 next action 与 source：
    - `capabilities`
      - `explicit`
      - `error`
      - `unsupported-capability`
      - `plan-capability`
      - `actionable-capability`
    - `doctor`
      - `explicit`
      - `next-step-check`
      - `actionable-check`
      - `error`
    - `plan`
      - `explicit`
      - `next-step-step`
      - `first-step`
      - `default-next-step`
      - `error`
  - `capabilities.primaryWorkflowCategory` 直接回填 `primaryCapability` 对应 capability 的首个 `requiredBy` 值。
- `Sources/TritonKitCLI/CLISchemaContracts.swift`
  - `capabilities` output contract 新增：
    - `primaryWorkflowCategory`
    - `primaryNextActionSource`
  - `doctor` output contract 新增：
    - `primaryNextActionSource`
  - `plan.next-steps` output contract 新增：
    - `primaryNextActionSource`
- 测试
  - `Tests/TritonKitSharedTests/TKCLITransportModelsTests.swift`
    - 覆盖 provenance/source 与 `primaryWorkflowCategory` roundtrip / old-payload fallback
  - `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`
    - bootstrap schema contract 断言补齐
    - task/bootstrap fixture 断言补齐

## 影响边界

- 继续强化 bootstrap machine-readable facts，不改 CLI 执行语义。
- 现在 agent 能区分：
  - 当前首选命令是否来自正常 next step
  - 是否来自 unsupported capability fallback
  - 是否只是旧 payload 的默认 nextStep 兼容回填

## 验证

- `swift test --filter TKCLITransportModelsTests`
  - 通过，21 个 Swift Testing 用例通过
- `swift test --package-path CLI --filter SchemaFactSourceTests`
  - 通过，85 个 Swift Testing 用例通过

## 后续队列

- 继续看是否要把 `doctor` 的首选 capability 名称也提到顶层，或者为 `capabilities` 增加首选 evidence artifact，进一步减少 agent 对 `checks[].relatedCapabilities[]` / `capabilities[].evidence[]` 的数组扫描。
