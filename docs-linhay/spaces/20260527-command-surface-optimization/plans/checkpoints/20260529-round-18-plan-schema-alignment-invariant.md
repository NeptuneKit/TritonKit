# Round 18 Plan Schema Alignment Invariant

## 目标

强化方案 C 的 plan fact source：`triton plan` 返回的命令序列必须能被 `triton schema --json` 解释，避免 agent 拿到 README 或实现里才存在的隐式参数。

## 完成结果

- 新增 `SchemaFactSourceTests.taskWorkflowPlanCommandsStayAlignedWithCommandSchemas`。
- 测试覆盖 `ios-smoke`、`open-url`、`webview-check` 三个任务型 plan。
- 对每个 `steps[].command` 验证：
  - 命令必须以 `triton` 开头。
  - 根命令必须存在于 `commandSchemas()`。
  - 如果根命令声明了 `subcommands[]`，命令中的第一个非 flag 子命令必须存在。
  - 所有 `--flag` 必须存在于根 schema 或 subcommand schema 的参数声明中。
- 红灯暴露了 `target --host/--port`、`smoke --assert-text` 和 `smoke --json` 未进入 schema 的问题。
- 修正 `target` schema，引入 host/port 参数声明。
- 修正 `smoke` schema，补齐 `--assert-text`、`--evidence-name`、`--evidence-note`、`--host`、`--port`、`--interval`、`--format` 和 `--json`。

## 改动文件

- `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`
- `Sources/TritonKitCLI/CLISchemaTargetCommands.swift`
- `Sources/TritonKitCLI/CLISchemaObservationCommands.swift`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `.agents/tritonkit-skills/public/tritonkit-emulator-cli-takeover/SKILL.md`
- `.agents/tritonkit-skills/public/tritonkit-dev-feedback/SKILL.md`
- `.agents/tritonkit-skills/public/tritonkit-real-project-regression/SKILL.md`

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/taskWorkflowPlanCommandsStayAlignedWithCommandSchemas` 通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests` 通过，15 个 Swift Testing 用例通过。
- `swift test --package-path CLI` 通过，86 个 Swift Testing 用例通过。

## 下一步

Round 19 建议把 `capabilities[].nextAction` 也纳入 schema 参数形态校验，确保 capabilities 推荐命令不会偏离 schema。
