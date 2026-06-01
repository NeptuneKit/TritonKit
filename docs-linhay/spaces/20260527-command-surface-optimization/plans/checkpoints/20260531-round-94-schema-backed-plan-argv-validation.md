# Round 94: schema-backed plan argv validation

## 目标

把 task workflow plan 的 schema-backed 校验从 `steps[].command` shell 字符串迁到 `steps[].argv`，让 `argv` 真正成为 agent 首选执行事实源，而不是只有“非空 + `triton` 前缀”的弱校验。

## 完成内容

1. 在 `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift` 新增 `validateSchemaBackedArgv(...)` helper。
2. helper 直接读取 `argv[1]` 作为 root command，并复用现有 schema map / flag 校验逻辑，不再依赖 `command` 字符串拆词。
3. `task workflow plan ... aligned with command schemas` 测试改为直接校验 `step.argv`。
4. `workflow plan steps expose executable metadata` 中的 schema-backed command 校验改为读取 `step.argv`。
5. `workflow plan steps expose executable argv` 从“非空 + `triton` 前缀”增强为：
   - 非空；
   - 首 token 为 `triton`；
   - token 不为空；
   - `argv` 本身可通过 schema-backed helper 校验。
6. `workflow plan steps expose stable recovery categories` 改为从 `step.argv` 推导 root command，再与 `step.category` 对齐。
7. 保留 `step.command` 的人读/复制用途，本轮不改变其 wire contract。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/taskWorkflowPlanArgvStayAlignedWithCommandSchemas`：通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests/workflowPlanStepsExposeExecutableArgv`：通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests/workflowPlanStepsExposeStableRecoveryCategories`：通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests`：通过，77 个 Swift Testing 用例通过。

## 风险

1. 本轮只把 task workflow plan 测试事实源迁到 `argv`；`schema.examples[]`、`nextCommands[]`、capability `nextAction` 仍各自沿用既有 helper / string fixture 路径。
2. replay dry-run / `plan inspect` 的 `steps[].argv` 已经存在，但还没有单独补“schema-backed argv helper”覆盖；这是后续可继续推进的补强项。

## 下一步

1. 继续把 replay / `plan inspect` 的 `steps[].argv` 也纳入同一套 schema-backed 校验，彻底减少对 `command` 字符串的依赖。
2. 若后续把 `step.command` 进一步收敛为纯日志字段，需要同步评估 schema contract 与测试命名，避免再次回退到 shell string 校验。
