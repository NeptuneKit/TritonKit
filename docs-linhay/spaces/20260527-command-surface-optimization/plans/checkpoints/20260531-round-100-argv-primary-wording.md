# Round 100 - argv primary wording

## 背景

Round 94-99 已经把 schema-backed 校验主路径迁到 `argv`，但 schema contract、开发文档和 public skills 里仍有少量表述把 `command` 写得像主执行字段，容易让后续实现和外部 agent 继续把 shell-like string 当事实源。

## 本轮动作

1. 更新 `Sources/TritonKitCLI/CLISchemaContracts.swift`：
   - `plan.next-steps.steps[].argv` 改为 agent 主执行字段说明；
   - `plan.next-steps.steps[].command` 改为人读 / copy-paste 字段说明；
   - `plan.inspect.steps[].argv` 改为 replay step 的主执行模板说明；
   - `replay.steps[].command` 改为历史 argv alias / 日志一致性字段说明。
2. 更新开发文档：
   - `docs-linhay/dev/agent-facing-cli-information-architecture.md`
   - `docs-linhay/dev/ai-cli-readable-control.md`
   将 task plan、plan inspect、replay dry-run 的叙述统一为：
   - `argv[]` = agent 主执行事实源
   - `command` = human-readable/logging form
3. 更新 public skills：
   - `tritonkit-dev-feedback`
   - `tritonkit-emulator-cli-takeover`
   - `tritonkit-real-project-regression`
   把 placeholder / 执行契约的关注点从 `plan.steps[].command` 明确挪到 `plan.steps[].argv`，同时保留 `command` 的单条 Triton invocation 约束。
4. 同步把开发文档中的旧测试名 `taskWorkflowPlanCommandsStayAlignedWithCommandSchemas` 改为当前实际测试名 `taskWorkflowPlanArgvStayAlignedWithCommandSchemas`。

## 结果

1. schema contract、开发文档、public skills 三层现在都明确：
   - `argv` 是 agent 首选执行事实源；
   - `command` 是日志 / copy-paste / 人读字段；
   - `command` 仍必须保持单条 `triton ...` 调用，但不再承担主执行语义。
2. replay result 的 `steps[].command` 继续保留，以避免外部消费方立即破坏；但文案已收敛为历史 alias，而不是新的主执行入口。

## 验证

1. `swift test --package-path CLI --filter SchemaFactSourceTests`
2. `docs-linhay/scripts/check-docs.sh`
3. `git diff --check`

## 下一步

1. 继续检查是否还存在只剩边缘用途的 string-first helper，评估是否删除。
2. 从 wording 收敛进入下一轮真实信息架构推进，例如 `schema/capabilities/plan` 更明确的领域入口与任务入口边界。
