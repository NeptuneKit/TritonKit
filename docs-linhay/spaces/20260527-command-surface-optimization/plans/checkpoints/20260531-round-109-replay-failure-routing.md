# Round 109 - replay failure routing

## 本轮目标

把 replay result 从“只告诉 agent 第几步失败了”推进到“直接告诉 agent 失败后先看哪个 lane、哪个 artifact、跑哪几个命令”。

## 完成结果

- `TKReplayResult` 新增：
  - `failureWorkflowCategories[]`
  - `failurePrimaryArtifacts[]`
  - `suggestedCommands[]`
- shared decoder 对老 payload 自动回填：
  - `failureWorkflowCategories[]` 由 failed step 的 `workflowCategories[]` 派生；
  - `failurePrimaryArtifacts[]` 从最近 replay step 中的 evidence/file artifact 回填；
  - `suggestedCommands[]` 缺省为空数组。
- CLI replay runtime 现在会按失败上下文生成 follow-up：
  - wait 失败优先给 `find` / `snapshot`
  - input 失败优先给 `snapshot` / `screenshot`
  - 最近存在 evidence bundle 时优先给 `evidence summary` / `inspect`
  - 当前失败 step 自己已产出 evidence 时再给 `redact`
- replay schema contract 与 text output 同步补齐 failure routing 字段。

## 改动文件

- `Sources/TritonKitShared/TKReplayPlanModels.swift`
- `Sources/TritonKitCLI/CLIEvidenceRuntime.swift`
- `Sources/TritonKitCLI/CLIEvidenceCommands.swift`
- `Sources/TritonKitCLI/CLISchemaContracts.swift`
- `Sources/TritonKitCLI/CLISchemaObservationCommands.swift`
- `Tests/TritonKitSharedTests/TKReplayPlanModelsTests.swift`
- `CLI/Tests/TritonKitCLITests/ReplayCommandTests.swift`
- `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- `.agents/tritonkit-skills/public/tritonkit-dev-feedback/SKILL.md`
- `.agents/tritonkit-skills/public/tritonkit-real-project-regression/SKILL.md`
- `.agents/tritonkit-skills/public/tritonkit-emulator-cli-takeover/SKILL.md`
- `docs-linhay/memory/2026-05-31.md`

## 验证

- `swift test --filter TKReplayPlanModelsTests`
- `swift test --package-path CLI --filter ReplayCommandTests`
- `swift test --package-path CLI --filter SchemaFactSourceTests`

## 剩余风险 / 下一步

- 当前 `suggestedCommands[]` 还是启发式命令组，不含 step 级参数化恢复 DSL。
- 下一刀可以继续补 `doctor` / `plan` / `replay` 之间的失败 taxonomy 闭环，尤其是让 failure codes 与 replay 顶层 routing 做更直接的映射。
