# SP-133 Imported iOS Simulator Proof

> 状态：已完成（P1 imported plan 的真实 iOS Simulator evidence/provenance 纵切已通过）
>
> Branch：`feat/SP-133-imported-ios-simulator-proof`
>
> Worktree：`../TritonKit-worktrees/SP-133-imported-ios-simulator-proof/`
>
> 基线：`feat/SP-132-testrec-import-seam@b065b3f0`

## 目标

完成 SP-126 Hybrid 路线的最小 P1 证明：从一个可审计、已编译的 `.tritontestcase` 导入 `.tritontest.yaml`，再仅通过既有 `triton test run` 在**专用 iOS Simulator + Debug embedded runtime** 上执行，并读取产生的 evidence，证明 imported provenance 一直保留到 `normalized-plan.json` 与最终 verdict。

## 硬边界

- 只用 SP-131 已验证的仓内 `TritonKitTestFixture`、dedicated Simulator、显式 bundle ID 与独立临时 output/evidence 目录；先保存 `triton doctor/list/schema/plan --json` 事实，设备操作一律 Triton-first。
- 不读取、修改、合并或清理 #164 dirty evidence WIP；不抢占已有 server/Simulator/scratch，不改变 main；不 push、PR、merge、tag、release、关闭 issue 或删除 worktree/branch。
- 不改 testrec executor、不实现 `testrec local-device`、不扩 Android、Harmony、Web/Wails、真机、workspace 编排或可靠性矩阵。SP-132 只表示 AX text tap，不能复刻 SP-131 的 runtime-point 坐标字段；本 P1 只验收同一 `Fixture Login -> Go Home -> Fixture Home` 的可观察语义。若 source contract 本身无法无损映射，停止并记录 blocker，而不是手改 imported YAML。
- 暂不把包含 sensitive artifacts 的 evidence 纳入 Git；当前 `evidence redact` 也不能安全外发 imported-test evidence（normalized plan/run events/AX 仍可能含路径、bundle、selector 或 visible text）。所有公开日志/文档只写脱敏摘要与 machine-readable 结论。

## 预期 BDD

1. Given 一个只含 SP-132 支持 action、无 quality finding 的 fixture `.tritontestcase`，When 显式 import 到临时 plan，Then `test validate` 成功，且 provenance 是 `triton.testrec.compiled-contract` / package-relative FNV ref。
2. Given 对应 dedicated Simulator 上已运行的 Debug fixture runtime，When 用 imported plan 执行 `test run`，Then 真正经 target resolve、launch、exact-AX-text action/assertion、observation 生成 `passed` verdict，不能使用 `local-simulated` 或 fake executor。
3. Given 产出的 evidence，When 直接读取 `normalized-plan.json`、再用 `test report`、`evidence inspect/summary` 交叉检查，Then `normalized-plan.json` 保留同一 typed provenance，`run.planRef` 链接它，且断言/截图/hierarchy 等必要事实可读；report/summary 本身不被误当作 provenance 投影。
4. Given server、fixture 或 target 无法满足此前 preflight，When 执行，Then 停在机器可读 failure，清理本轮临时 server/专用 Simulator，不把环境不确定性写成产品通过。

## 审计与停止条件

- 先只读确认 SP-132 importer 能生成与 `TritonKitTestFixture` 真实 AX 流程相容的 source contract；再确认 dedicated target/server 空闲，才能启动一次串行真实 run。
- 若 preflight 或 import 本身失败，不做产品代码“为跑通而改”；仅保存脱敏 evidence / blocker，并将本 space 记为受环境阻断。
- 成功后必须关闭本轮 loopback server、恢复专用 Simulator 到 shutdown（若本轮启动）、记录 test/evidence 摘要，并跑匹配的 focused 回归与 docs gate；是否需要产品代码另立后续 space。

## 当前审计结果（2026-07-27）

- 已用独立临时根和隔离的 `TRITONKIT_TESTREC_SESSION_DIR` 通过真实 CLI 生成 source：5 个 action（screenshot、AX assert `Fixture Login`、AX tap `Go Home`、screenshot、AX assert `Fixture Home`）与 2 个 route event。`testrec compile` 返回 `compiled`、deterministic-offline、无 LLM/VLM、无 quality finding；没有调用 replay 或 `local-simulated`。
- `test import` 与独立 `test validate --emit-normalized-plan` 均通过，得到 `launch + 5` 步，provenance 为 importer v1 / `triton.testrec.compiled-contract` / source `ios` / package-relative `compiled-contract.json` FNV ref。source、plan 与 evidence 均只在本机临时根产生；proof 后该根已移入本机废纸篓以便可恢复处置，未纳入 Git。
- 本 space 独立 scratch 已成功构建 CLI；`TestImportTests` 11/11、`TestValidationTests` 13/13、`TestRunExecutionTests` 9/9 通过。
- 授权后的新鲜 Triton-first preflight 确认 `127.0.0.1:19421` 不可达、Xcode lane 空闲、专用 iOS Simulator 处于 Shutdown；本轮才启动该 Simulator、启动自己管理的 loopback server，并先验证 server 的 `targetCount=0`，没有复用或停止外部 runtime。
- `triton xcode run` 在专用 Simulator 上构建、安装、启动 Debug fixture；随后 `triton list` 只返回一个同时匹配预期 bundle 与 Simulator identity 的 embedded runtime target。导入后的 `test run` 真实通过：6 steps、2 次 AX assertion、4 次 observation、43 events、0 failures；其中 exact-AX-text `Go Home` tap 将界面从 `Fixture Login` 改为 `Fixture Home`，没有使用 `local-simulated` 或 fake executor。
- `test report` 与直接读取 `run/run.json` 确认 passed verdict 和 `run.planRef -> normalized-plan.json`；`evidence inspect` 与 `evidence summary --profile ios-private` 则交叉确认 manifest、runtime target、PNG、AX 与 hierarchy artifacts。直接读取 evidence 的 normalized plan 也确认它与 import/validate 的 typed provenance 完全一致；report/summary 仍只作为交叉证据，不能替代 provenance 本体。
- proof 后已停止本轮 loopback server、确认 19421 不再可达，并通过 `triton sim shutdown` 将本轮启动的专用 Simulator 恢复 Shutdown；Xcode lane 无遗留进程。sensitive evidence 已随本轮临时根移入本机废纸篓，未执行不足以安全外发的 redaction，也未纳入 Git。

## 后续

P1 已回答“imported plan 能否真实复用现有 runner”。可靠性样本、workspace 编排和第二平台仍须各自新建有限 space 与 BDD；本次 fixture proof 不构成通用 replay、跨平台或对外项目验证承诺。
