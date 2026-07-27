# SP-134 Reliability Gate Decision v01

## Decision

- **Adopt：先建设可靠性采样与离线判定，再做 workspace 接入。**

## Why

- SP-133 已证明一条 imported AX flow 真实通过，但其 README 明确不等于可靠性矩阵或 workspace 证明。
- 项目路线要求 iOS canonical 先冻结三条 flow，各采样 20 次，并以 ECR ≥ 95%、FER ≥ 90%、ORR ≥ 90% 决定是否扩张；ORR < 70% 必须停止扩张。
- `test run` 已是唯一真实 executor，并会写 normalized plan、target、events、observation 与 manifest；现有 app-map suite 只能累计 pass/fail，不能计算 ECR/FER/ORR。
- `workspace export-flow` 当前没有 imported provenance、可能静默丢弃 unsupported action、建议 run 缺显式 target，且 `workspace ios+simulator` 与 importer 的 `ios-simulator` 不是可隐式互换的语义。因此现在接入会掩盖可靠性/兼容问题。

## Execution Plan

1. 定义 private sample manifest：每条 sample 必须声明 `flowID`、evidence 位置、`initialStateID`、`resetEvidenceID`、target token；报告不得回显任何 private 输入，flow 仅输出每报告匿名编号。
2. 新增只读 `triton test reliability`：从 existing evidence 解析 status、step status、artifact/failure taxonomy、plan digest，以及带 iOS platform / Simulator UDID / canonical ID / connected=true 的 runtime-target、manifest target、plan bundle 的私下绑定；manifest 必须声明 matching plan / runtime-target sidecar，按 flow 汇总 ECR / FER / ORR。
3. 以稳定 taxonomy 输出 completeness、duplicate identity、failure recovery、initial-state/target/ORR drift；partial/skipped evidence、缺 count / recovery/ref、空 step coverage、未知或不匹配的 normalized-plan step 语义，或重复 evidence/run/reset 身份均不完整。所有 event、observation 与 terminal failure artifact ref 必须以 canonical path 绑定 manifest inventory，且 `artifact.created.kind` 必须匹配声明；bundle 内孤立文件不能充当证据。当前版本化 mapping 明确覆盖 runner 的 screenshot baseline missing、text-not-found 与 VLM policy failure，未知新 type 仍 fail closed。FER 分母覆盖所有已识别 non-passed run，只有与终态失败 step 的 command-to-finish 区间绑定的完整 failure record 才进入分子；缺失、partial 或未知 failure 仍留在分母。没有已识别 failure sample 时才为 not_evaluable。event log 中重启、暂停或中途终止也一律不完整。
4. 让 gate 以 3 flow × 20、95/90/90 阈值 fail closed；ORR<70 输出 stop-expansion。
5. 后续另立受控 harness slice：显式 reset/launch、fresh evidence、专用 Simulator、自管 loopback server、私有处置原始 evidence；不能在普通 Swift 测试或 docs gate 中隐式运行。

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

## Executor

- 主控实现离线 report 与 docs。
- 只读 subagent 审计过 workspace seam、可靠性门槛与 Web/Wails 边界；无 subagent 进行设备/服务写操作。
