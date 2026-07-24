# SP-129 Serve Loopback Default

## 状态

- 状态：执行（有限 CLI 契约切片）。
- Branch：`feat/SP-129-serve-loopback-default`。
- Worktree：`../TritonKit-worktrees/SP-129-serve-loopback-default/`。
- 基线：`feat/SP-126-testrec-convergence@5f6c2f6f`（2026-07-24）。
- 影响层：CLI `serve` parser/runtime bind、CLI help、bootstrap schema、纯内存 recovery/action contract。

## 目标与 BDD

1. **默认 loopback**：给定执行 `triton serve` 且未传 `--host`，解析出的 host 为 `127.0.0.1`，port 仍为 `19421`；serve runtime 使用该解析值绑定。
2. **显式 host 兼容**：给定 `--host 0.0.0.0` 或其它明确 host，解析和 recovery/action 仍保留调用方指定值；本切片不把显式非 loopback 行为收窄。
3. **契约一致**：中文 help、`schema --command serve --json` 的 host defaultValue、server-unavailable 的默认 recovery/action 均表达 `127.0.0.1:19421`。
4. **无副作用验证**：parser、schema、help 和 recovery 测试不调用 `Serve.run()`，不启动真实 server、不占用固定端口、不操作设备。

## 范围

包含：

- `Sources/TritonKitCLI/CLIServeCommand.swift` 的 Serve host 默认值。
- `Sources/TritonKitCLI/CLICoreModels.swift` 的中文 serve help 默认文案。
- `Sources/TritonKitCLI/CLISchemaBootstrapCommands.swift` 的 serve schema host defaultValue。
- `ServeCommandTests` 的 parser、显式覆盖、中文 help、schema 和 recovery/action focused tests。

不包含：

- `CLIWebRuntime`、Web 前端、Web POST routes 或 managed Web serve host。
- evidence、testrec、Android、#164/#166/#167/#168、设备动作和真实 server smoke。
- recovery/action 生成器的显式 host 语义改造；它们继续回显调用方传入的 host。

## Bonjour 剩余风险

`Serve.run()` 在创建 server 后仍调用 `publishTritonBonjourService(port:)`，发布 `_tritonkit-server._tcp.local`。本切片只收敛无 `--host` 时的 bind 默认值，不改变 Bonjour publish/discovery 语义；因此不能宣称“默认 serve 无 LAN 广播”。若后续需要收敛广播或 discovery，另建独立 space 和契约，不能在本切片顺手改变。

## TDD 与验收

- 先以 `ServeCommandTests` 锁定 parser 默认、显式 `0.0.0.0` 覆盖、中文 help、schema default 和 recovery/action host 传递。
- focused test 使用本 worktree 独立 scratch：`.build/sp129-serve-loopback-default`。
- 代码门禁：`swift test --package-path CLI --scratch-path .build/sp129-serve-loopback-default --filter ServeCommandTests`；必要时补跑 CLI 全量测试与本地总门禁。
- 文档门禁：`git diff --check`、`docs-linhay/scripts/check-docs.sh`，按变更范围运行 `docs-linhay/scripts/verify.sh --ci-docs` 或 `--local`。

本次验证记录：`ServeCommandTests` 6/6 通过；`ReplayCommandTests/replayRecoveryCommandsIncludeFailureErrorNextAction` 1/1 通过；release `triton` 已用独立 scratch 编译通过，并以只读 `schema --command serve --json` 验证 host default 为 `127.0.0.1`。既有 `SchemaFactSourceTests` 的 12 个失败均为 `network-proxy/device proxy`、`sim app-console` 和设备 selector/output contract 基线不一致，不涉及 serve host；完整 `ReplayCommandTests` 另有 2 个测试假定可从 `CLI/.build` 查找产物，与本 slice 强制独立 scratch 的测试环境约束冲突。

`git diff --check` 已通过。`check-docs.sh` 和 `verify.sh --ci-docs` 在结构检查处因当前基线只有 SP-001…SP-126，而本 slice 按并发裁决登记 SP-129、不得写入 SP-127/SP-128，触发连续编号规则而停止；不修改治理脚本或伪造占位 space，待主控集成并发 space 后重跑。

## 完成定义与停止条件

完成定义：BDD 四项满足；focused command/schema/recovery tests 通过；显式非 loopback 行为有回归证据；space、路线索引和当天 memory 已同步；只创建本地 checkpoint commit。

出现以下任一情况即停止并回报主控：需要修改 Web/evidence/其它并发切片；显式 host 兼容行为必须改变；测试显示默认 bind 之外还有需要本切片处理的监听面；需要启动 server、Bonjour、设备或远端操作才能证明本契约。

本切片禁止 push、PR、merge、tag、release、关闭 issue，以及删除或清理其它 worktree/branch。
