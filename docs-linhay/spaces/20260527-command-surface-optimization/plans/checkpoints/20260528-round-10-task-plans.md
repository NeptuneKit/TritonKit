# Round 10: Task Workflow Plans

## 目标

将 `triton plan` 从通用下一步建议扩展为有限任务型 planning 入口，让 agent 可以先询问 Triton 如何执行高频工作流，再逐条执行返回的命令。

## 完成结果

- `TKWorkflowPlanResponse` 新增可选 `goal` 字段，用于标明当前规划目标。
- `triton plan` 新增任务型目标：
  - `ios-smoke`
  - `open-url`
  - `webview-check`
- `plan` 新增任务参数：`--device`、`--bundle-id`、`--url`、`--text`、`--expected-url`、`--evidence`。
- `ios-smoke` 计划输出 target list / resolve / use / wait-ready、`triton smoke ios ... --json` 和 evidence summary 步骤。
- `open-url` 计划输出 target resolve、`triton app open-url ... --wait-ready --snapshot --json`、wait、assert 和 evidence 步骤。
- `webview-check` 计划输出 WebView current、route assert-current-url、WebView wait 和 evidence 步骤。
- server 不可达时，任务型 plan 仍保留 `goal`，并优先返回 `start-server` 恢复步骤，不假装已经能规划运行态命令。
- 更新 schema、README、dev 文档和 public skills，明确 task plan 只输出建议，不执行动作。

## 验收场景

1. agent 执行 `triton plan ios-smoke ... --json` 时，输出带 `goal=ios-smoke` 的机器可读 plan。
2. server 不可达时，任务型 plan 返回 `nextStep=start-server` 和 `error.nextAction.command=serve`。
3. 单元测试能直接构造 connected capabilities，并验证 `ios-smoke/open-url/webview-check` 的有序 steps。
4. schema 暴露 `ios-smoke/open-url/webview-check` 和任务参数，agent 不需要读 README 才能发现入口。

## 已运行验证

- `swift test --package-path CLI --filter SchemaFactSourceTests` 通过，10 个 Swift Testing 用例通过。
- `swift test --package-path CLI` 通过，81 个 Swift Testing 用例通过。
- `swift test` 通过，125 个 Swift Testing 用例通过。
- `swift run --package-path CLI triton plan ios-smoke --device iphone15 --bundle-id com.example.app --url myapp://smoke --text Home --evidence /tmp/smoke.tritonevidence --json` 通过，server 不可达环境下返回合法 JSON、`goal=ios-smoke` 和 `nextStep=start-server`。

## 后续队列

- Round 11：升级 `doctor` 恢复路径，基于 capabilities group/nextAction 输出更明确的诊断检查。
- 后续继续把 plan response 中的 requires、commands、expectedArtifacts、stopConditions 结构化，而不是扩大成完整 workflow DSL。
