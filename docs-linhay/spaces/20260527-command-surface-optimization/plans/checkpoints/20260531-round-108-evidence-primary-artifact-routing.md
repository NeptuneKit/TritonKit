# Round 108 - evidence primary artifact routing

## 本轮目标

把 evidence manifest / summary / redact 从“只给全量 artifact 列表”推进到“直接给 agent 第一阅读入口”，减少 agent 自己从 `artifacts[].kind` 重新推断该先看哪些证据。

## 完成结果

- `TKEvidenceManifest` 新增 `primaryArtifacts[]`，老 payload 缺字段时自动由 `artifacts[]` 回填。
- `TKEvidenceSummaryResponse` 新增 `primaryArtifacts[]`，并继续保留 `suggestedCommands[]` 作为离线 follow-up。
- `TKEvidenceRedactionResponse` 新增 `primaryArtifacts[]` 与 `suggestedCommands[]`，让 redacted bundle 也有直接的后续入口。
- evidence schema 新增：
  - `evidence.summary`
  - `evidence.redact`
  两个详细 output contracts。
- `evidence.manifest` contract 同步补 `primaryArtifacts` 字段。

## 事实源与排序规则

首期 `primaryArtifacts[]` 排序规则固定在 shared model：

1. `xcode.action-summary`
2. `screenshot`
3. `archive`
4. `geometry`
5. `ax`
6. `hierarchy`
7. `run.events`
8. `run.meta`
9. `status`
10. `list/version/host.*/xcode.*`

同优先级保持原始 artifact 顺序，默认截取前 5 个。

## 改动文件

- `Sources/TritonKitShared/TKEvidenceModels.swift`
- `Sources/TritonKitCLI/CLIEvidenceRuntime.swift`
- `Sources/TritonKitCLI/CLISchemaContracts.swift`
- `Sources/TritonKitCLI/CLISchemaObservationCommands.swift`
- `Tests/TritonKitSharedTests/TKEvidenceModelsTests.swift`
- `CLI/Tests/TritonKitCLITests/EvidenceBundleTests.swift`
- `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- `.agents/tritonkit-skills/public/tritonkit-dev-feedback/SKILL.md`
- `.agents/tritonkit-skills/public/tritonkit-real-project-regression/SKILL.md`
- `.agents/tritonkit-skills/public/tritonkit-emulator-cli-takeover/SKILL.md`
- `docs-linhay/memory/2026-05-31.md`

## 验证

- `swift test --filter TKEvidenceModelsTests`
- `swift test --package-path CLI --filter EvidenceBundleTests`
- `swift test --package-path CLI --filter SchemaFactSourceTests`

## 剩余风险 / 下一步

- 当前 `primaryArtifacts[]` 仍是静态优先级，不区分具体失败上下文。
- 下一刀可以继续看 replay failure/result 顶层是否需要直接给出 failure-focused artifact routing，避免 agent 还要从 `failedStepIndex + evidence path` 自己拼接诊断入口。
