# Round 89: replay step result argv

## 目标

继续收敛 `.tritonplan` / replay 的 agent-facing 执行契约：让 `triton replay --dry-run --json` 和真实 replay result 与 `triton plan inspect`、任务型 `triton plan` 一样，都能通过 `steps[].argv` 读取首选执行字段。

## 完成内容

1. `TKReplayStepResult` 新增 `argv: [String]` wire 字段。
2. `command` 保留为历史 argv token 数组；`argv` 是 agent 首选执行字段。
3. 初始化逻辑默认令 `argv = command`，调用方也可显式传入 `argv`。
4. 自定义 decoder 支持旧 JSON：
   - 有 `command` 无 `argv` 时，自动补齐 `argv = command`。
   - 有 `argv` 无 `command` 时，自动补齐 `command = argv`。
5. replay step metadata 派生改为读取 `argv`，避免未来 `command` 转向日志字段时影响分类与 artifact / stop condition 推导。
6. `replay.result` output contract 新增 `steps[].argv`，success shape 同步展示该字段。
7. 文档与 public skills 已同步要求：replay dry-run / execution step result 必须暴露 `steps[].argv`，并用它和 `plan inspect` 的 `steps[].argv` 做交叉检查。

## 验收

- `triton replay <file.tritonplan> --dry-run --json` 每个 step 返回 `argv`。
- `argv` 是变量替换后的 argv token 数组，secure 值仍只输出 `<redacted:length>`。
- `command` 继续存在，避免既有消费方断裂。
- 旧 replay result JSON 缺少 `argv` 时仍可解码。

## 验证

- `swift test --filter TKReplayPlanModelsTests/replayStepResultDerivesExecutionMetadata`：通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests/executionAndEvidenceSchemasExposeRecoveryCommandsAndOutputContracts`：通过。
- `swift test --filter TKReplayPlanModelsTests`：6 个 Swift Testing 用例通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests`：76 个 Swift Testing 用例通过。
- `swift test --package-path CLI`：147 个 Swift Testing 用例通过。
- `swift test`：128 个 Swift Testing 用例通过。
- `swift run --package-path CLI triton replay /tmp/round87-plan-inspect.tritonplan --dry-run --var username=alice --var password=secret --json`：通过，输出包含 `steps[].argv` 与 `steps[].command`。

## 风险

1. `TKReplayPlanStepSummary` 与 `TKReplayStepResult` 仍各自维护一部分 step metadata 派生逻辑，后续应抽取共享 helper。
2. `command` 目前仍是 argv token 数组，不是 task plan 中的人读 command string；本轮通过 `argv` 消除 agent 首选执行字段歧义，但历史字段语义仍需在后续 schema v2 或模型整理时收敛。

## 下一步

1. 抽取 replay step metadata / argv 派生 helper，统一 inspect summary 与 replay result。
2. 继续补强 replay / record 的 usageForms、argumentForms 与 output selectors。
