# Round 86: Plan Step Argv

## 目标

让 `triton plan --json` 的每个步骤直接提供可执行 argv，避免 agent 解析 shell 字符串。`command` 保留为人读日志和复制入口，机器执行首选 `argv[]`。

## 变更

- `TKWorkflowPlanStep` 新增 `argv` wire 字段。
- 初始化和 decoder 在缺少 `argv` 时，会从既有 `command` 做保守 tokenization，支持当前 `shellEscaped` 生成的单引号形式。
- `plan.next-steps` output contract 新增 `steps[].argv` 字段说明。
- 新增 `SchemaFactSourceTests.workflowPlanStepsExposeExecutableArgv`，要求所有 plan fixture step 都暴露非空 argv，且首 token 为 `triton`。
- 共享模型测试补充 plan JSON roundtrip 后 `argv` 的断言。
- 同步更新 agent-facing CLI 文档、AI CLI 当前契约文档、三份 public skill 和 memory。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/workflowPlanStepsExposeExecutableArgv`
- `swift test --package-path CLI --filter SchemaFactSourceTests/agentBootstrapSchemasExposeRecoveryCommandsAndOutputContracts`
- `swift test --filter TKCLITransportModelsTests/workflowPlanShape`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`
- `swift test`
- `swift run --package-path CLI triton plan --json`

结果：

- 新增 argv 测试先因缺字段红灯，补齐 wire model / contract 后通过。
- `SchemaFactSourceTests` 76 项通过。
- CLI 全量 147 项通过。
- 根包全量第一次在 `TKPlatformFallbackTests.missingLocalServerDoesNotSurfaceConnectionNoise` 触发 runtime observer 清理相关 NSException；该用例单跑通过，第二次根包全量 126 项通过。
- 实际 `triton plan --json` 输出已包含 `steps[].argv`。

## 后续

- 后续可以把 plan builder 改成先组装 argv，再派生 command，减少反向 tokenization。
- 继续检查 `.tritonplan` / `plan inspect` 是否也需要 argv 与 execution metadata 对齐。

## 提交状态

未提交，未 push，未 tag，未 release。
