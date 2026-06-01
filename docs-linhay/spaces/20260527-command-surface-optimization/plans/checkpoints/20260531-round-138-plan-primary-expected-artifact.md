# Round 138 - plan primary expected artifact

## 本切片目标

继续减少 `plan` 顶层事实源的数组扫描，为 `TKWorkflowPlanResponse` 增加单值 `primaryExpectedArtifact`，避免 agent 需要从 `nextStep` 对应 step 的 `expectedArtifacts[]` 自己决定“首看哪类计划产物 taxonomy”。

## 完成结果

1. `TKWorkflowPlanResponse` 新增 `primaryExpectedArtifact: String?`。
2. shared model 默认回填逻辑已补齐：
   - 优先使用显式传入值；
   - 否则直接取 `nextStep` 对应 step 的首个 `expectedArtifacts[]`；
   - 若回退到 `first-step` 或 `error.nextAction`，也会先匹配 step 再回填；
   - 若走 `default-next-step` 兼容回填，则根据默认 next action 派生对应 step 级默认 artifact taxonomy。
3. 该字段只表达首选 artifact taxonomy，不表达真实文件路径，也不替代真实 evidence bundle 里的 `primaryArtifacts[]`。
4. 当前固定场景：
   - bootstrap `start-server` 回填 `stdout-json`；
   - `ios-smoke` / `open-url` / `webview-check` 也都回填 `stdout-json`。

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

1. `primaryExpectedArtifact` 当前反映的是 step 级默认 artifact 顺序，仍不表达更高信号的具体文件对象；真实文件级优先级仍由 evidence / replay 结果里的 `primaryArtifacts[]` 负责。
2. 当前大多数 plan step 的首个 artifact 都是 `stdout-json`，所以这个字段更像把“至少先读 JSON”显式化；后续若更多 step 开始以领域产物优先，需要再重新检验排序是否合理。

## 下一步

转去 replay 或 target 面，继续寻找 agent 仍需从数组或多字段二次聚合的一跳事实；优先检查 replay 是否还缺单值首选 lane / artifact / command 之外的诊断入口。
