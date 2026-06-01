# Round 134 - doctor primary capability

## 本切片目标

继续收紧 bootstrap 事实源顶层入口，给 `doctor` 增加单值 `primaryCapability`，避免 agent 为了知道当前 recovery check 首先对应哪项 capability，再扫描 `checks[].relatedCapabilities[]`。

## 完成结果

1. `TKDoctorResponse` 新增 `primaryCapability: String?`。
2. shared model 默认回填逻辑已补齐：
   - 优先使用显式传入值；
   - 否则取 `nextStep` 对应 check 的首个 `relatedCapabilities[]`；
   - 若落入首条 `fail/warn` fallback，也取该 check 的首个 `relatedCapabilities[]`；
   - 若只剩 `error.nextAction`，则尝试按 action 匹配 check 后回填 capability。
3. `doctor` output contract 已同步声明 `primaryCapability`。
4. 测试已固定两个 bootstrap 关键场景：
   - server 不可达时 `primaryCapability == "status"`；
   - 已连接但 action surface 受限时 `primaryCapability == "press"`。

## 变更文件

- `Sources/TritonKitShared/TKCLITransportModels.swift`
- `Sources/TritonKitCLI/CLISchemaContracts.swift`
- `Tests/TritonKitSharedTests/TKCLITransportModelsTests.swift`
- `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- `docs-linhay/memory/2026-05-31.md`

## 验证

- `swift test --filter TKCLITransportModelsTests`
- `swift test --package-path CLI --filter SchemaFactSourceTests`

## 剩余风险

1. `primaryCapability` 当前依赖 `relatedCapabilities[]` 的顺序稳定性；若未来单个 check 需要表达多个并列首选 capability，需要再显式建模，而不是继续靠数组首项约定。
2. `doctor` 目前只提升 capability，不提升 workflow lane；若后续发现 agent 仍频繁回扫 `checks[].workflowCategories[]`，可以再评估是否需要 `doctor.primaryWorkflowCategory`。

## 下一步

优先考虑 `doctor.primaryWorkflowCategory` 是否真的有必要；如果没有，再转去 `capabilities` 的 evidence 首选面，避免过早设计多余顶层字段。
