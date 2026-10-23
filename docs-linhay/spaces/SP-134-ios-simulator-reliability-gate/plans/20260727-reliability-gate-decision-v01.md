# SP-134 Reliability Gate Decision v01

> 状态：本期离线 gate 已完成归档（2026-10-24）。下方保留原设计依据；真实采样只登记为本文的一项条件触发专项，不构成 SP-126/SP-134 或 SP-140/143～151 的未完成实现。

## 当前裁决与后继证据

- SP-126 的 bounded importer / 单 flow 真实纵切、SP-134 的离线 gate 已交付；SP-140 提供 receipt-backed harness，SP-143～150 加固 authority、anchor、identity chain、cohort 和 failure/recovery，后由 [SP-151 / PR #177](../../SP-151-trusted-baseline-integration/README.md) 整合。这些完成项保持归档，不反复打开。
- 当前 `test reliability --samples` 是 legacy diagnostic，即使指标达标也固定 `gate=blocked` / `receipt_required`；只有 receipt-backed `reliability --collection-receipt ... --expect-receipt-sha256 ...` 能评估 Stage 1。原 sample manifest 设计保留为兼容史，不再具有通过门禁的 authority。
- 当前 sample 调用复用 `runTritonFrozenTest -> runTritonTest`；普通 `test run` 不依赖 report gate。源码入口见 [harness](../../../../Sources/TritonKitCLI/CLITestReliabilityHarnessRuntime.swift)、[runner bridge](../../../../Sources/TritonKitCLI/CLITestRunRuntime.swift) 与 [Stage 1 metrics](../../../../Sources/TritonKitCLI/CLITestReliabilityStageMetricsRuntime.swift)。2026-10-24 静态检索 workspace、Web、CI 和 scripts 未发现该 gate 的自动业务消费者；scripts 仅有 public skill schema 快照。归档保留现有 CLI/schema/public skill，不删实现、不降低阈值。

<a id="future-reliability-acceptance"></a>

## 唯一后续事项：真实可靠性专项

**状态：条件触发，当前不进入 active queue。** SP-126、SP-134 和其它引用只链接此事项，不重复登记多个采样或“继续加固”任务。

**进入条件：** 有一个明确、获准维护的项目即将采用 recorder 导入或 workspace 自动回归，或准备对外承诺当前 `test` 执行路径的可靠性；同时已经确定要依据结果作出的 Go/No-Go 决策。只有历史未勾选项、命令已经存在或希望清空队列，不构成触发条件。届时另建有限 space，固定候选代码/二进制、App/OS 版本、三个具有业务断言的受支持 flow、初态/reset recipe、专用 Simulator、自管 loopback server 与私有 evidence 生命周期；不预占编号。

**执行范围：** 先允许 1 supported + 1 exact negative 的真实接线 smoke，验证 sample/target/receipt/evidence 路径。仍使用现有三 flow/61 槽 receipt，抽取两槽后 report 必须保持 blocked；这只能关闭“真实接线”子项，不能降低完整门槛或宣称可靠性通过。若接线失败，先分类修复产品、环境或 fixture 问题，不自动重用槽或删除失败证据。需要完整 Go/No-Go 时，再在新鲜、冻结的 collection 中串行完成 3 flow × 20 + 1 negative；不增加新执行器、平台矩阵或 workspace 实现。

**完成条件：** 公开报告只记录可复核的安全聚合，原始 evidence 与其保存位置留在受控本机记录；Stage 1A 覆盖每 flow 完整 20 次的 60 个 supported 槽，ECR ≥ 95%、ORR ≥ 90%；Stage 1B 的 receipt/control integrity 为 61/61，FER ≥ 90%，覆盖 expected negative 及所有 supported nonpass。保留 root 外 anchor、逐槽 reset attestation、真实目标/初态与失败归因，不能用 synthetic evidence、simulated pass 或静默重试补齐。identity chain 只证明字节一致性，不能替代真实 reset/设备独占事实。

**退出条件：** 满足上述门槛才记“Stage 1 可靠性验收通过”；门槛未满足但评估和失败归因完整时，可以“评估完成，No-Go”关闭该专项，并明确产品限制。若未来项目不再需要该能力，则按“取消/不进入实施”关闭后续事项，不能记“可靠性已验证”。专项未触发不妨碍已交付实现 space 归档；其完成或取消都不重开 SP-140/143～151。

**价值与成本：** 能检验受控流程的证据完整性、重复一致性和负控解释，但不证明跨 App/跨系统普遍可靠性。完整 61 次需要真实 reset、设备/服务独占、不可覆盖的证据槽及失败分析，成本高于单次 smoke；优先由具体项目决策驱动，不为历史队列继续堆门禁。

## 原始 Decision（2026-07-27，保留设计历史）

- **Adopt：先建设可靠性采样与离线判定，再做 workspace 接入。**

## 原始 Why

- SP-133 已证明一条 imported AX flow 真实通过，但其 README 明确不等于可靠性矩阵或 workspace 证明。
- 项目路线要求 iOS canonical 先冻结三条 flow，各采样 20 次，并以 ECR ≥ 95%、FER ≥ 90%、ORR ≥ 90% 决定是否扩张；ORR < 70% 必须停止扩张。
- `test run` 已是唯一真实 executor，并会写 normalized plan、target、events、observation 与 manifest；现有 app-map suite 只能累计 pass/fail，不能计算 ECR/FER/ORR。
- `workspace export-flow` 当前没有 imported provenance、可能静默丢弃 unsupported action、建议 run 缺显式 target，且 `workspace ios+simulator` 与 importer 的 `ios-simulator` 不是可隐式互换的语义。因此现在接入会掩盖可靠性/兼容问题。

## 原始 Execution Plan（已交付及被后继替代）

1. 定义 private sample manifest：每条 sample 必须声明 `flowID`、evidence 位置、`initialStateID`、`resetEvidenceID`、target token；报告不得回显任何 private 输入，flow 仅输出每报告匿名编号。
2. 新增只读 `triton test reliability`：从 existing evidence 解析 status、step status、artifact/failure taxonomy、plan digest，以及带 iOS platform / Simulator UDID / canonical ID / connected=true 的 runtime-target、manifest target、plan bundle 的私下绑定；manifest 必须声明 matching plan / runtime-target sidecar，按 flow 汇总 ECR / FER / ORR。
3. 以稳定 taxonomy 输出 completeness、duplicate identity、failure recovery、initial-state/target/ORR drift；partial/skipped evidence、缺 count / recovery/ref、空 step coverage、未知或不匹配的 normalized-plan step 语义，或重复 evidence/run/reset 身份均不完整。所有 event、observation 与 terminal failure artifact ref 必须以 canonical path 绑定 manifest inventory，且 `artifact.created.kind` 必须匹配声明；bundle 内孤立文件不能充当证据。当前版本化 mapping 明确覆盖 runner 的 screenshot baseline missing、text-not-found 与 VLM policy failure，未知新 type 仍 fail closed。FER 分母覆盖所有已识别 non-passed run，只有与终态失败 step 的 command-to-finish 区间绑定的完整 failure record 才进入分子；缺失、partial 或未知 failure 仍留在分母。没有已识别 failure sample 时才为 not_evaluable。event log 中重启、暂停或中途终止也一律不完整。
4. 让 gate 以 3 flow × 20、95/90/90 阈值 fail closed；ORR<70 输出 stop-expansion。
5. 原计划的受控 harness 已由 SP-140 交付，后继已加固并整合；真实 reset/launch、fresh evidence、专用 Simulator、自管 loopback server 和原始 evidence 处置只在上方唯一专项中验收，不能在普通 Swift 测试或 docs gate 中隐式运行。

## Borrowed

- `test import` 的 typed provenance 与 fail-closed 约束。
- `test run` 的 normalized plan、run event、evidence manifest 与 target artifact。
- app-map suite 的串行 `runTritonTest` 组合模式，仅作未来 harness 参考。

## Rejected

- 直接做 live workspace orchestration：缺少 provenance/target/semantic fail-closed/reset 契约，风险大于当前可验证价值。
- 重复或扩展 `testrec local-device` / matrix executor：违反唯一真实 executor 规则。
- 立即跑 60 次或自动探测 booted target：会抢占共享设备/server，且没有 initial-state reset 证据时统计无效。

## Verification

- 合成 evidence focused tests 证明指标、阈值、隐私输出、duplicate 防伪、target binding、逐 step 覆盖与 drift 分类。
- 既有 import / validation / runner focused tests 不回归。
- CLI schema、docs structure、whitespace 与本地验证通过。

## 历史 Executor

- 主控实现离线 report 与 docs。
- 只读 subagent 审计过 workspace seam、可靠性门槛与 Web/Wails 边界；无 subagent 进行设备/服务写操作。
