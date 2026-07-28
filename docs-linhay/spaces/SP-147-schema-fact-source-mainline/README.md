# SP-147 Schema Fact Source Mainline

> 状态：已完成（本地，待主控集成）
>
> 基线：`main@d2578089`
>
> 分支：`feat/SP-147-schema-fact-source-mainline`
>
> 工作树：`../TritonKit-worktrees/SP-147-schema-fact-source-mainline/`

## 目标与边界

将当前 `main` 中手写的 CLI machine-readable schema 与实际 ArgumentParser 层的已知事实重新对齐。本 schema 轨仅改 schema fact source、其契约测试及文档写回：不修改 parser、设备动作、HTTP/server、Web/Wails、Xcode、testrec 或 workspace。`CLIRuntimeTransport` 的 capability argv 对齐由并行、独立所有权的 contract 子轨处理。

本轮在隔离工作树从 `main@d2578089` 重做；未 cherry-pick、merge 或 rebase 任何历史 feature 分支。

## BDD 验收场景

1. **给定** `device` parser 已接受 polling interval 且 direct child 包含 alias、bridge、proxy、start、stop，**当** agent 查询 `triton schema --command device --json`，**那么** root option、可选 selector 语义、直接子命令和 host 输出合同都应可机器读取。
2. **给定** `device wait-ready` parser 通过 `--device` 接收 target，**当** schema 被生成，**那么** 不得把不存在的 positional `<selector>` 声明为 wait-ready 参数。
3. **给定** `sim app-console` 的失败恢复应既能采集 log，又能重新输出 artifact 与归档 evidence，**当** schema 暴露 recovery commands，**那么** `nextCommands`、派生 recovery command 与 category 必须保持同序一致。

## 实施结果

- `device` root schema 补齐 `--interval`、可选 `<selector>` 的正确归属、alias/bridge/proxy/start/stop direct child，并为 device doctor、screenshot、Harmony runtime URL 补齐具体 output contract。
- host artifact contract 改为可带 selector；新 doctor/runtime URL contract 显式列出实际 DTO 的主要字段，避免 schema 宣告泛化或缺失的输出模型。
- `wait-ready` 不再错误接受 positional selector；selector 描述收敛为 `device use` / `resolve` 的 host target 输入。
- `sim app-console` 用同一份 action sequence 生成 `nextCommands` 和 recovery commands，保留 `prepare-target` 与 `archive` 的诊断分类。
- 新增 focused contract tests，先在隔离 scratch 获得红灯，再以最小 schema 调整转绿。

## 验证证据

- 红灯：`swift test --package-path CLI --scratch-path CLI/.build/sp147-schema-fact-source-mainline --filter 'SchemaFactSourceTests.deviceSchemaMirrorsDirectParserGroupsAndFacts|SchemaFactSourceTests.simAppConsoleRecoveryMirrorsActionableNextCommands'` 在实现前以 2 个测试、8 个断言失败退出。
- 绿灯：同一 focused 命令在实现后通过；`FailureDiagnosticsTests` 通过。
- 机器可读验收：隔离产物的 `triton schema --command device --json` 和 `triton schema --command 'device bridge' --json` 均经 `jq -e` 校验 root option、direct child、output selector 与 command scope。
- 扩展命令 `--filter 'SchemaFactSourceTests|FailureDiagnosticsTests'` 共执行 135 项，只有 1 个既有无关失败：`SchemaFactSourcePlanTests.schemaAndPlanPlaceholdersAreCompleteArgvTokens`。它来自基线 `CLISchemaTestCommands.swift` 的 `triton:ios-simulator:<udid>/app:<bundle>` 内嵌 placeholder，未在本轮触及。

## 已知边界与后续

- 并行的 capability contract 子轨已将 `device wait-ready` 四个平台变体的 next action 对齐为 `--device <selector>`；本 space 仅把该真实 parser 事实纳入 schema 验收，不改变设备运行时行为。
- 当前 `TKCommandSubcommandSchema` 仅有一层 subcommand 表达，`device bridge` / `device proxy` 的更深层 child 不在本轮凭空建模；direct child 和 output selector 已与现有事实入口对齐。
- 当前 `main` 的登记册没有 `SP-142` 至 `SP-146` 目录。按不伪造历史 space 的要求，本轮只登记已分配的 SP-147；`check-docs.sh` 因连续编号规则在 SP-147 处预期失败，待这些真实 space 进入主线后统一恢复门禁。

详细计划见 [20260728-schema-fact-source-repair-v01.md](./plans/20260728-schema-fact-source-repair-v01.md)。
