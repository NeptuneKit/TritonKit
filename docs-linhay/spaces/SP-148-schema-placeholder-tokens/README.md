# SP-148 Schema Placeholder Tokens

> 状态：已完成（本地，待主控整合）
>
> 父基线：`SP-147@98110f60`（其根基线为 `main@d2578089`）
>
> 分支：`feat/SP-148-schema-placeholder-tokens`
>
> 工作树：`../TritonKit-worktrees/SP-148-schema-placeholder-tokens/`

## 目标与边界

将 `test reliability-sample` 的 machine-readable schema 模板中的 canonical runtime target 表示为完整、可替换的单个 argv token。仅修改 schema/help 模板、契约测试和文档：不修改 ArgumentParser、reliability runner、receipt、HTTP/server、Simulator、设备、testrec 或 workspace，也不执行真实采样。

本 space 从 SP-147 的本地 checkpoint 建立，未 cherry-pick、merge 或 rebase SP-143～146；那些未整合 reliability checkpoints 同时修改 `CLISchemaTestCommands.swift`，未来整合前必须按实际目标基线复核冲突。

## BDD 验收场景

1. **给定** reliability-sample 要求一个精确 canonical runtime target，**当** agent 读取 schema usage form 和 example，**那么** `--target` 后必须是完整的 `<canonical>` argv placeholder，不能把 `<udid>` 与 `<bundle>` 嵌进同一 token。
2. **给定** schema/plan placeholder contract，**当** 全部 schema usage/example 经过检查，**那么** 不得存在非完整 placeholder token。
3. **给定** 仅修正帮助/contract 模板，**当** focused tests 通过，**那么** runner、server、设备与 evidence 的行为保持未触及。

## 实施结果

- 将 reliability-sample usage form 和 example 的 `--target triton:ios-simulator:<udid>/app:<bundle>` 改为既有 schema 术语 `--target <canonical>`。
- 保持 canonical target 仍是一个真实 parser value；没有将它拆成多个 argv，也没有放宽 `isCompletePlaceholderToken` 或引入白名单。
- 新增 focused test，同时锁住 usage form 与 example 的 token 形状和 placeholder 完整性。

## 验证证据

- 红灯：`swift test --package-path CLI --scratch-path CLI/.build/sp148-schema-placeholder-tokens --filter 'SchemaFactSourceTests.schemaAndPlanPlaceholdersAreCompleteArgvTokens'` 在实现前失败，唯一项为 `test/example:triton:ios-simulator:<udid>/app:<bundle>`。
- 绿灯：`swift test --package-path CLI --scratch-path CLI/.build/sp148-schema-placeholder-tokens --filter 'SchemaFactSourceTests.schemaAndPlanPlaceholdersAreCompleteArgvTokens|SchemaFactSourceTests.reliabilitySampleTemplatesRetainCanonicalTargetAsOneArgvPlaceholder'` 通过 2/2。
- 扩展回归：`--filter 'SchemaFactSourceTests|FailureDiagnosticsTests'` 通过 136/136；这也验证 SP-147 继承的 schema/capability/failure 契约没有回退。
- 机器可读验收：隔离产物的 `triton schema --command test --json` 经 `jq -e` 验证所有 reliability-sample usage/example 都含 `--target <canonical>`，且不再含嵌入式 `triton:ios-simulator:<udid>/app:<bundle>` token。

## 已知边界与后续

- SP-143～146 的未整合 reliability 链对同一 schema 文件存在相邻变更。这个 checkpoint 可以保留为可审查的最小补丁，但将来进入包含那条链的目标基线前需做同文件面审查；本轮不重写分支历史。
- 当前登记册没有 SP-142～146 的真实目录。按不伪造历史 space 的约束，本轮只登记 SP-148；连续编号 docs gate 将保持失败，直到真实 spaces 进入主线。

详细计划见 [20260728-placeholder-token-contract-v01.md](./plans/20260728-placeholder-token-contract-v01.md)。
