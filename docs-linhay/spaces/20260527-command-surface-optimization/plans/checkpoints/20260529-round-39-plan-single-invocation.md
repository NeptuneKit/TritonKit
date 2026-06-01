# Round 39: plan single invocation commands

## 目标

确保 `plan.steps[].command` 始终是单条 `triton ...` invocation，不把 shell 管道、重定向、命令替换或脚本片段塞进任务计划。

## 完成结果

- 新增 `SchemaFactSourceTests.workflowPlanCommandsStaySingleTritonInvocations`。
- 测试覆盖通用 plan 的 server 不可达、target/runtime 缺失、connected 三种状态，以及 `ios-smoke`、`open-url`、`webview-check` 三种任务 plan。
- 测试要求每个 step command 以 `triton` 开头，且不包含 `|`、`&&`、`||`、`;`、`<`、`>`、`>>`、`2>`、`2>>`、命令替换或反引号。
- 聚焦测试、schema fact source 全量测试和 CLI 全量测试已通过。
- 同步更新 agent-facing 信息架构、AI CLI 控制文档和 public skills。

## 验证

```bash
swift test --package-path CLI --filter SchemaFactSourceTests/workflowPlanCommandsStaySingleTritonInvocations
swift test --package-path CLI --filter SchemaFactSourceTests
swift test --package-path CLI
```

结果：通过。Schema fact source 当前为 35 个 Swift Testing 用例通过；CLI 全量当前为 106 个 Swift Testing 用例通过。

## 风险与后续

- 本轮只约束 plan step command，不约束 schema examples 中的人读 shell pipeline；后续如果要让 examples 也完全 argv-only，需要先评估现有 pipeline 示例的教学价值。
- 下一轮建议进入 Round 40：抽取 workflow plan fixture builder，减少 Round 18/28/29/37/38/39 对同一批 plan 状态的重复构造。

## 提交状态

未提交。用户未授权 commit / push / tag / release。
