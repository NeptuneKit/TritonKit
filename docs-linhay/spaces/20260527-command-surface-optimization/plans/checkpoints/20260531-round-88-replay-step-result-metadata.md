# Round 88: replay step result metadata

## 目标

继续收敛 `.tritonplan` / replay 的 agent-facing 执行契约：让 `triton replay --dry-run --json` 的 step result 与 Round 87 的 `plan inspect` summary 使用同一套执行诊断元数据。

## 完成内容

1. `TKReplayStepResult` 新增：
   - `category`
   - `requires`
   - `expectedArtifacts`
   - `stopConditions`
2. 新字段按 step `command` argv 自动派生：
   - `category` 复用 `TKCommandRecoveryCommand` recovery taxonomy。
   - `requires` 为 `cli.available/server.reachable/target.ready/runtime.connected`。
   - `expectedArtifacts` 按 root command 派生 `input-result`、`wait-result`、`screenshot` 或 `evidence-bundle`。
   - `stopConditions` 按 root command 派生 `timeout`、`artifact.write-failed` 或 `step.failed`。
3. `TKReplayStepResult` 增加自定义 decoder，旧 JSON 缺少这些字段时自动补齐默认值。
4. `replay.result` output contract 新增 `steps[].category/requires/expectedArtifacts/stopConditions` 及相关 step 字段。
5. 文档与 public skills 已同步要求：`plan inspect` 与 `replay --dry-run` 可交叉检查 step metadata。

## 验收

- `triton replay <file.tritonplan> --dry-run --json` 每个 step 返回执行诊断元数据。
- schema 可通过 `triton schema --command replay --json` 发现 replay result 的 step 字段契约。
- 旧 replay step result JSON 仍可解码，并自动派生 metadata。

## 验证

- `swift test --filter TKReplayPlanModelsTests/replayStepResultDerivesExecutionMetadata`：通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests/executionAndEvidenceSchemasExposeRecoveryCommandsAndOutputContracts`：通过。
- `swift run --package-path CLI triton replay /tmp/round87-plan-inspect.tritonplan --dry-run --var username=alice --var password=secret --json`：通过，输出包含 `steps[].category/requires/expectedArtifacts/stopConditions`。
- `swift test --filter TKReplayPlanModelsTests`：6 个 Swift Testing 用例通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests`：76 个 Swift Testing 用例通过。
- `swift test --package-path CLI`：147 个 Swift Testing 用例通过。
- `swift test`：128 个 Swift Testing 用例通过。

## 风险

1. `TKReplayStepResult.command` 历史上是 argv token 数组，字段名与 task plan 的 string `command` 不完全一致；文档已注明 dry-run 用它和 inspect `steps[].argv` 对照。
2. 本轮仍未把 plan inspect 与 replay result 的 metadata 派生逻辑完全抽成单一 helper，后续可继续去重。

## 下一步

1. 抽取 replay step metadata 派生逻辑，避免 inspect summary 与 replay result 各自维护 root command 到 artifact/stop condition 的映射。
2. 在 schema 层继续补强 replay/record 的 usageForms、argumentForms 与 output selectors。
