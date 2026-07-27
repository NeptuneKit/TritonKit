# SP-140 iOS Simulator Reliability Live Harness

## 状态

- 状态：已完成（本地；receipt、严格 target preflight、schema 合同与 focused Swift 验证已完成；真实采样仍未授权）。
- 负责人：Codex。
- Branch：`feat/SP-140-ios-simulator-reliability-live-harness`。
- Worktree：`../TritonKit-worktrees/SP-140-ios-simulator-reliability-live-harness/`。
- 基线：`main@0cb7e958`。

## 裁决

**Adopt：把真实 3 flow × 20 + 1 negative 的采样约束固化为 receipt-backed、fail-closed 的本地 harness；本 space 不自动操作任何运行时。**

SP-136 的 `reliability-preflight` 只能离线检查仍可变的 collection。SP-140 新增私有 `collection-receipt.json`，在 reserve 时冻结已校验的 normalized plan、plan digest、执行语义 identity、canonical target binding、slot、initial state、reset recipe 与 evidence 相对路径。之后 sample 只能从 receipt 读取；它不能重新读取 YAML、选择 booted/alias target、清空 slot 或隐式管理 server / Simulator / App。

## 边界

包括：

- `triton test reliability-reserve --collection <private.json> --json`：只在验证成功后原子创建未存在的私有 evidence root 与 immutable receipt；不触及 runtime。
- `triton test reliability-sample --collection-receipt <private.json> --flow flow_001 --slot 1 --reset-receipt <private.json> --target triton:ios-simulator:<UDID>/app:<bundle> --host 127.0.0.1 --port 19421 --confirm --json`：严格从 receipt 的匿名 alias 读取 frozen plan；只有确认、canonical（大写 UUID）target、loopback host/port、operator reset attestation，以及已运行 server 返回的 exact `{id, connected, platform, UDID, bundle}` 全部匹配才允许 claim slot 并进入 runner。
- sample 的 live preflight 直接读取 `GET /targets`，只接受**唯一且 exact id** 的 receipt target；不调用通用 selector resolver，也不接受同 UDID、缺 bundle、错误 platform 或 disconnected fallback。server 对完整 canonical iOS Simulator app target 的 exact-id miss 同样返回 not found，只有裸 UDID selector 保留历史兼容 fallback。
- receipt-backed `triton test reliability --collection-receipt <private.json> --json`：从 receipt 派生固定 61 个预期样本，并验证 receipt → binding sidecar → reset sidecar → frozen plan → runtime target → manifest 的完整链。
- 新增纯内部 normalized-plan runner bridge，使 harness 不需要重新读取可变 YAML；既有 `test run` 路径保持兼容。
- `schema --command test --json` 为 `reliability` 明确 `--samples` / `--collection-receipt` 二选一；为 reserve/sample 标注 side effect、sample 的 server/target/confirmation 要求与严格 option override。capability 的下一步保持只读 schema 引导，不会建议自动附带 `--confirm` 执行 sample。

不包括：

- 自动 boot / shutdown / select / reset / install / launch Simulator 或 App，启动、停止或接管任何 server 生命周期，或真实采样。
- `--force`、删除、覆盖、重置既有 root / receipt / slot / `run/` / manifest。
- Android、Harmony、真机、Web、Wails、testrec replay、#164 WIP 或公开 collection / evidence / receipt fixture。

## BDD 验收

1. Given 三条 imported、strict、retry=0 的 iOS Simulator plan 仅在 name、provenance、step id/index/kind 上不同，When reserve，Then execution identity 相同而 fail closed；真正不同的有序实际 step payload 才可同时冻结。
2. Given 未存在 root，When 两个 reserve 并发尝试，Then 至多一个原子创建 root/receipt 成功；失败方不触碰 runtime，成功 receipt bytes 不被改变。
3. Given reserve 后 source YAML 改动，When sample，Then 仍只使用 receipt frozen normalized plan；receipt / binding 受损在 executor 与任何 primitive 之前失败。
4. Given `local`、`booted`、alias、大小写不 canonical 的 UUID、错误 UDID/bundle、非 loopback host/port 或缺少 `--confirm`，When sample，Then 不创建 slot、不执行 primitive；确认后的 runtime preflight 也必须返回 receipt 的 exact id/connected/iOS/UDID/bundle，拒绝同 UDID fallback，并把该 target 固定给 live runner。
5. Given reset receipt 缺失、`verified=false`、collection/flow/slot/target/initial/reset 不匹配，When sample，Then fail closed；成功时 manifest 声明 binding/reset sidecar。
6. Given slot 的空目录、`run/` 或 manifest 已存在，When sample，Then 原子 slot claim 拒绝且不删除任何内容。
7. Given receipt-backed gate 的 sidecar 缺失、重复 reset receipt / slot、plan/target drift 或 negative control 意外 passed，When evaluate，Then report gate blocked 并记录稳定 invalidator。
8. Given 既有 `test run` 指向可复用 evidence directory，When harness 加入，Then 其原有目录准备与运行行为不改变；`--samples` v1 也继续作为 legacy input，不被描述成 receipt-backed。
9. Given 任何 receipt reserve/slot/runner 失败，When schema consumer 查询 recovery category，Then 只得到不覆盖、不清理、不重试 runtime 的 `diagnose`（写入或 runner bridge 失败可额外 `archive` 以保留已有私有事实）。
10. Given negative control 实际 nonpassed，When sample 命令结束，Then stdout 只含 `TKTestReliabilitySampleResponse` 且 exit 0；Given supported flow nonpassed 或 negative control 意外 passed，Then stdout 仍只含同一 typed result、`ok=false` 且 exit 1，不额外包 error envelope；Given receipt/target/reset 参数不完整，Then stdout 只含 `TKCLIErrorResponse` 且 exit 1。

## 验证与停止条件

- 已执行独立 scratch 的 focused Swift 验证，覆盖 receipt/slot 的 fail-closed、strict `/targets`、canonical UUID、server exact-only fallback、business result/exit 合同、parser/schema/recovery、shared schema model；未启动 server、Simulator、Xcode、test run runtime 或设备。
- 已通过：`TestReliabilityHarnessRuntimeTests` (3)、`TestReliabilityHarnessTests` (11)、`ServerTargetSelectionTests` (2)、`TestReliabilityCollectionRuntimeTests` (4)、`TestReliabilityRuntimeTests` (28)、`TestValidationTests` (16，使用 `CLI/.build/...` 以支撑 subprocess)、`FailureDiagnosticsTests` (13)、`SchemaFactSourceCapabilityTests` (22)、`TestCreateFromSessionTests` (2)、`PublicSkillCommandSchemaTests` (1) 与根 package `TKCLITransportModelsTests` (28)。同时将 public skill schema snapshot 补齐 `test import` 与 reliability 系列命令。`git diff --check` 通过。
- `SchemaFactSourceContractTests` 仍有 6 个已知无关基线失败，集中于既有 `device` 子命令参数/selector、`sim app-console` recovery 分类与 device capability 示例；该 suite 没有报告 reliability/receipt/target 相关 failure。本 space 不扩大到这些设备 schema 账务。
- 已 rebase 到 `main@0cb7e958`；主控随后同步 `spaces/README.md`、`INDEX.md`、项目级 CLI/skill 指南与当日日志。真实 3×20 仍需用户授予 dedicated Simulator、server ownership、reset recipe 与证据目录权限。

## 已知残余风险

- 正常本地文件系统上，root 与最终 slot 以 exclusive `mkdir` / `O_EXCL|O_NOFOLLOW` fail closed；但 hostile local filesystem 在父目录检查和后续目录操作之间仍可能制造 symlink TOCTOU。本期不把该模型误称为对抗性文件系统隔离；真实采样仅允许在 operator 拥有的私有可信目录中进行。
- sample 不负责 server、Simulator 或 App 生命周期，也不会根据 failure category 自动清理、重置、重试或扩容；任何真实轮次仍需先通过独立的 ownership/reset/evidence 授权。
