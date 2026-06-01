# Round 136 - capabilities primary evidence

## 本切片目标

继续减少 bootstrap 事实源的数组扫描，为 `capabilities` 增加单值 `primaryEvidence`，避免 agent 需要先拿到 `primaryCapability`，再回扫对应 capability 的 `evidence[]` 才能知道先看哪类 artifact taxonomy。

## 完成结果

1. `TKCapabilitiesResponse` 新增 `primaryEvidence: String?`。
2. shared model 默认回填逻辑已补齐：
   - 优先使用显式传入值；
   - 否则直接取当前 `primaryCapability` 对应 capability 的首个 `evidence[]`；
   - `error` / unsupported capability / plan capability / first actionable capability 几条既有 primary 选择路径都会沿同一规则自动回填。
3. 该字段只表达首选 artifact taxonomy，不表达真实文件路径，也不试图替代 evidence bundle 内的 `primaryArtifacts[]`。
4. 当前固定场景：
   - `tap` 能力回填 `input.result`；
   - runtime disconnected 时 `runtime-manifest` 能力回填 `runtime-manifest`。

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

1. `primaryEvidence` 目前依赖 capability 级 `evidence[]` 的顺序稳定性；如果未来某个 capability 同时有多个并列高信号 artifact 类型，需要再显式建模，而不是继续靠数组首项。
2. 该字段解决的是“首看哪类 artifact taxonomy”，不是“首看哪个具体文件”；真实 evidence bundle 里的文件级优先级仍由 `primaryArtifacts[]` 负责。

## 下一步

回到 `plan` 与 bootstrap 事实源，继续检查是否还存在需要 agent 手工聚合的一跳事实；优先看 `plan` 是否还缺少单值首选 lane / artifact / failure hint。
