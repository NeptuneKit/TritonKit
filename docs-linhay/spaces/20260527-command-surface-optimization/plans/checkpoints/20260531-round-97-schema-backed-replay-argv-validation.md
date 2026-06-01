# Round 97: schema-backed replay argv validation

## 目标

把 Round 94 新增的 `validateSchemaBackedArgv(...)` 继续扩到 replay / `plan inspect`，避免只有 task workflow plan 使用 `argv` 作为 schema-backed 执行事实源。

## 完成内容

1. 在 `SchemaFactSourceTests` 新增 `plan inspect steps expose schema-backed argv templates`：
   - 构造 `.tritonplan` fixture；
   - 通过 `TKReplayPlanSummary` 生成 `steps[].argv`；
   - 用 `validateSchemaBackedArgv(...)` 校验每一步 template argv。
2. 新增 `replay step results expose schema-backed argv`：
   - 通过 `TKReplayStepExecution.argv(...)` 构造 dry-run/replay argv；
   - 生成 `TKReplayStepResult`；
   - 用同一 helper 校验 `result.argv` 的 root command / subcommand / flags。
3. 完成后，workflow plan、`plan inspect`、replay result 三条 agent-facing 执行链都能用同一套 helper 做 schema-backed argv 校验。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/planInspectStepsExposeSchemaBackedArgvTemplates`：通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests/replayStepResultsExposeSchemaBackedArgv`：通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests`：通过，79 个 Swift Testing 用例通过。

## 风险

1. 本轮仍是测试基建补强，不改变 replay / inspect / plan 的对外 JSON 结构。
2. `steps[].command` 仍保留在 replay 与 inspect 输出中；本轮只是进一步证明 `steps[].argv` 已经足以承担机器执行事实源。

## 下一步

1. 若继续沿这条线收敛，可以评估把更多 replay/inspect 分类判断直接切到 `argv` helper，而不是在不同层保留 root command string 推导。
2. 也可以继续治理 schema examples / nextCommands 中仍基于字符串的校验路径，逐步形成统一 argv-first 测试基座。
