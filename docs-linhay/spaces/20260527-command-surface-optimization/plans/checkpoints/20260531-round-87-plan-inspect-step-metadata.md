# Round 87: plan inspect step metadata

## 目标

继续方案 C 的 agent-facing CLI 信息架构收敛，把 `.tritonplan` 的离线检查入口与 `triton plan --json` 的执行元数据口径对齐。

本轮只增强 `triton plan inspect <file.tritonplan> --json` 的摘要输出，不修改 `.tritonplan` 文件 schema，不改变 replay 执行行为。

## 完成内容

1. `TKReplayPlanSummary` 新增 `steps: [TKReplayPlanStepSummary]`。
2. `TKReplayPlanStepSummary` 为每个 replay step 暴露：
   - `index`
   - `id`
   - `name`
   - `action`
   - `command`
   - `argv`
   - `category`
   - `requires`
   - `expectedArtifacts`
   - `stopConditions`
3. `argv` 保留 `${variable}` 占位；secure step 使用 `<redacted:length>`，避免 inspect 输出明文。
4. `category` 复用 `TKCommandRecoveryCommand` 的 recovery taxonomy。
5. `requires`、`expectedArtifacts`、`stopConditions` 使用与 task plan 相同的 agent 元数据词汇。
6. `plan` schema 新增 `plan.inspect` output contract，声明 `TKReplayPlanSummary.steps[]` 字段。
7. 文档与 public skills 已同步说明：agent 可先离线 inspect `.tritonplan`，再 dry-run 或真实 replay。

## 验收

- 新 agent 可通过 `triton schema --command plan --json` 发现 `plan.inspect` 输出契约。
- `triton plan inspect <file.tritonplan> --json` 返回每步的 `argv/category/requires/expectedArtifacts/stopConditions`。
- `.tritonplan` 文件仍保持 schema version 1 原有结构。
- `replay --dry-run` 与真实 `replay` 的执行路径不受本轮修改影响。

## 验证

- `swift test --filter TKReplayPlanModelsTests/planInspectSummaryExposesStepExecutionMetadata`：通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests/agentBootstrapSchemasExposeRecoveryCommandsAndOutputContracts`：通过。
- `swift test --filter TKReplayPlanModelsTests`：5 个 Swift Testing 用例通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests`：76 个 Swift Testing 用例通过。
- `swift run --package-path CLI triton record --output /tmp/round87-plan-inspect.tritonplan --json`：通过，生成 replay plan 模板。
- `swift run --package-path CLI triton plan inspect /tmp/round87-plan-inspect.tritonplan --json`：通过，输出包含 `steps[].argv/category/requires/expectedArtifacts/stopConditions`。
- `swift test --package-path CLI`：147 个 Swift Testing 用例通过。
- `swift test`：第一次在 `TKPlatformFallbackTests.stateObserverToken` 触发既有 observer 重复通知间歇失败；该用例单跑通过，第二次根包全量 127 个 Swift Testing 用例通过。

## 风险

1. `plan inspect` 的 per-step `argv` 是离线模板，变量仍以 `${name}` 保留；真实可执行命令仍应通过 `replay --dry-run --var ...` 校验。
2. `command` 字段仍主要用于日志与人读复制，agent 执行应优先使用 `argv[]`。
3. 根包 runtime observer 间歇问题不是本轮路径，但仍需后续单独治理。

## 下一步

1. 继续收敛 `record/replay` 与 task plan 的 output contract：让 `replay --dry-run` 的 `steps[].command` 与 inspect summary 元数据可交叉验证。
2. 后续可把 replay step 的 metadata taxonomy 抽成共享 helper，减少 `plan` 与 replay summary 的重复派生逻辑。
