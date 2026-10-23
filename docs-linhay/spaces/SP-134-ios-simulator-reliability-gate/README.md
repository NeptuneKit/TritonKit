# SP-134 iOS Simulator Reliability Gate

> 状态：已归档（2026-10-24；离线 gate 及后继 receipt-backed 加固已交付；真实 3 flow × 20 + 1 negative 未采样）
>
> 历史 Branch：`feat/SP-134-ios-simulator-reliability-gate`
>
> 历史 Worktree：`../TritonKit-worktrees/SP-134-ios-simulator-reliability-gate/`（不作为恢复执行入口）
>
> 基线：`feat/SP-133-imported-ios-simulator-proof@19e2c35f`

## 决策

**本期离线 gate 完成归档；真实可靠性作为一项未来项目触发的专项，不继续挂起本 space。**

SP-133 只证明一条 imported iOS Simulator flow 能复用既有 `test run`，不能证明重复执行、失败可解释性或 workspace 编排。保留的[唯一后续事项](./plans/20260727-reliability-gate-decision-v01.md#future-reliability-acceptance)仅在有明确项目需要 recorder/workspace 自动回归，或准备对外承诺该执行路径可靠性时启动；触发前不占 active queue。相关 workspace / 平台测试扩张仍需该专项数据及独立裁决，独立 testrec 第二执行器继续不做。

本 space 已交付纯离线的 `triton test reliability` 报告：读取已有私有 `.tritonevidence`，输出不含路径、selector、可见文本或截图的诊断指标。原始 `--samples` 输入在 SP-143 后固定为 `legacy-diagnostic`，即使指标达标也 `gate=blocked` / `receipt_required`，不能通过 Stage 1。只有 SP-140/143～150 的 receipt-backed report 才能评估 Stage 1；后继加固已由 [SP-151 / PR #177](../SP-151-trusted-baseline-integration/README.md) 整合，不重新打开这些完成项。

后继 SP-136 已以 `triton test reliability-preflight --collection <private.json> --json` 定义 collection 的 imported-plan / canonical target / 20-slot / reset-recipe 合同；其 `ready_to_collect` 固定不是 sample、receipt、runtime verdict 或 gate 的通过。真实专项仍要求 dedicated Simulator、self-managed server、逐样本 reset、fresh private evidence 与串行采样；本次归档没有执行这些动作。

2026-10-24 文档核对：原离线 gate 已随 `d0f09d3c` 进入主线；receipt-backed 后继由 `66f975d9` 整合，两者均为候选 `409670ef` 的祖先。当前源码仍通过显式 CLI 调用报告器/sample harness；归档不删除命令、不降低阈值，也不把历史 focused tests 当作本轮真实执行证据。

## 范围与硬边界

- 只复用既有 `test import -> test validate -> test run -> .tritonevidence`；不新增 `testrec` executor、workspace executor、Web/Wails 写入口、HTTP route、Android/Harmony/真机能力。
- 每条真实样本必须由外部、受控 harness 在独立临时根创建：显式 dedicated Simulator UDID、已连接且 canonical 的 `triton:ios-simulator:<udid>/app:<bundle>` runtime target、与之相同的 manifest target / plan bundle、自管 `127.0.0.1:19421` server、新鲜 evidence 目录，且所有设备/服务动作串行。
- `test run` 的 `launch` 只解析已连接 runtime，**不会**重置 App 初态。因此报告只接受具有稳定 `initialStateID` / `resetEvidenceID` 的 sample；缺失、重复 reset/evidence/run 身份、partial evidence、目标绑定不一致或初态/目标漂移一律阻断 gate，不能把连续 run 当作可重复性数据。
- 原始 evidence（含 normalized plan、run events、AX/hierarchy、PNG）仍可能敏感；不得进入 Git、issue、PR 或公开日志。报告输出仅含 digest、枚举 taxonomy、计数和脱敏 flow ID。
- 历史实现阶段隔离了 #164 evidence WIP；本次仅收口文档，不读取或修改其它未提交代码、设备、服务或私有 evidence。

## BDD 验收

1. Given 一个含 `flowID`、私有 evidence 路径、`initialStateID`、`resetEvidenceID` 与 target token 的 sample manifest，When 运行 `triton test reliability --samples <private.json> --json`，Then 只读所有 evidence 并输出稳定 `triton.test.reliability-report`；输出不泄露绝对路径、bundle、selector、可见文本、run ID、原始 `flowID` 或截图字节。SP-143 后该入口固定为 legacy diagnostic，`eligibleForStage1Gate=false`、`gate=blocked` 且含 `receipt_required`；下列指标检查不能授予它 Stage 1 authority。
2. Given 一个样本缺少 manifest 声明的 `test.normalized-plan@normalized-plan.json` 或 `runtime.target@runtime-target.json`、带 iOS platform / Simulator UDID / canonical ID / connected=true 的 runtime target、event / observation count、终态 run event、逐 step 的 command/finish 覆盖、需要 runtime observation 的步骤所需 artifact、declared reset identity，或其 manifest 是 partial/skipped，When 汇总，Then ECR 将其标为不完整并以稳定 issue code 说明；所有 `artifact.created` 必须按 kind 与 canonical path 绑定 manifest artifact，observation 与终态 failure 的所有 artifact ref 也必须绑定 manifest 声明，不能仅因 bundle 内存在同名文件而计入 passed 或 ORR。
3. Given 已识别为 non-passed 的样本含稳定 failure type、artifact reference 与版本化 recovery category，When 汇总，Then 每个 non-passed 样本都进入 FER 分母；只有与终态失败步骤同 index、且位于其 `command.executed -> failure.recorded -> step.finished` 区间的完整记录才能进入分子。若任一字段缺失或借用其他步骤记录，该样本仍留在分母且不得被虚报为通过。没有已识别失败样本时，FER 为 `not_evaluable`，gate 不通过。
4. Given 同一私有 `flowID` 的重复样本，When 比较，Then ORR 只比较 verdict、step status、artifact taxonomy、failure taxonomy、initial state 与由 normalized plan / manifest target / runtime-target 私下绑定的目标身份；忽略 timestamp、run ID、evidence 路径和截图字节。任何 taxonomy/初态/目标漂移都必须暴露为 issue。
5. Given receipt-backed collection 的 3 个 supported flow 未各有 20 个完整样本、全部 61 个槽的 receipt/control integrity 不完整，或 ECR < 95%、FER < 90%、ORR < 90%，When 读取 Stage 1 gate，Then 状态为 `blocked`；若 supported ORR < 70%，明确输出 `stop_expansion`。Stage 1A 只统计 60 个 supported 槽的 ECR/ORR，Stage 1B 统计全部 61 槽的 integrity/FER（包含 exact negative control）；不能用 legacy 样本、少量 smoke 或 synthetic evidence 代替真实验收。
6. Given 同一 canonical evidence bundle、event run ID 或 reset identity 被重复登记，When 汇总，Then 全部关联样本均以稳定 duplicate issue 标为不完整；它们不能伪造 flow/run 阈值。

## 私有 sample manifest（legacy diagnostic 兼容输入）

样本清单仅保存在受控本地目录，不进 Git。最小形状如下；`evidence`、`resetEvidenceID`、`targetToken` 都是私有输入，报告不会回显它们。

```json
{
  "schemaVersion": 1,
  "kind": "triton.test.reliability-sample-set",
  "samples": [
    {
      "flowID": "fixture-login-home",
      "classification": "supported",
      "evidence": "/private/runs/login-home-01.tritonevidence",
      "initialStateID": "fixture-login-v1",
      "resetEvidenceID": "dedicated-reset-01",
      "targetToken": "dedicated-ios-simulator"
    }
  ]
}
```

`flowID` 是仅供本地分组的稳定 key（小写字母、数字、连字符），**不会**回显；报告中的 `flows[].flowID` 固定为本报告内按私有 key 排序得到的 `flow_001` 形式匿名编号。下划线也使其不可能与允许连字符但不允许下划线的输入 key 同名。`initialStateID` 在同一冻结 flow 的样本间必须一致；`resetEvidenceID` 是由受控 harness 记下的私有 reset 身份，gate 会验证非空和不复用，但不能把它误称为独立的 reset 执行证明。所有 evidence 路径必须指向已有、未复用的 `.tritonevidence` bundle；manifest 必须显式声明 canonical normalized plan / runtime target sidecar。runtime target 必须为已连接的 iOS Simulator target，ID 必须从其 UDID 与 bundle canonical 推导，且其 ID / bundle 要分别与 manifest target / normalized plan 在本地交叉绑定。

报告会回显自身使用的 `thresholds`；CLI 保留 canonical 默认值（3 flow × 20、95% / 90% / 90%），没有降低门槛的选项。上述 legacy manifest 仅用于诊断；真实 Stage 1 必须使用 `reliability-reserve` 生成的 immutable receipt、root 外保留的 SHA-256 anchor、61 个完整 slot 与 `test reliability --collection-receipt ... --expect-receipt-sha256 ...`，具体约束见 [SP-140](../SP-140-ios-simulator-reliability-live-harness/README.md) 与 [SP-151](../SP-151-trusted-baseline-integration/README.md)。

## 已交付文件面

- `Sources/TritonKitCLI/CLITestReliabilityRuntime.swift`：sample-manifest / privacy-safe report DTO、离线读取、bundle containment、duplicate identity、canonical Simulator target / manifest-sidecar binding、event/observation/failure artifact-to-manifest binding、事件/计划逐 step 覆盖与 terminal-failure 归因校验、ECR / FER / ORR 及 gate 判定。
- `Sources/TritonKitCLI/CLITestCommands.swift`、`CLISchemaTestCommands.swift`、`CLISchemaOutputContracts.swift`：CLI、schema 与机器可读输出契约。
- `CLI/Tests/TritonKitCLITests/TestReliabilityRuntimeTests.swift`：完整、缺 artifact/计数/恢复、partial/空 event、canonical target binding、terminal-failure 归因、真实 runner 的 `../` artifact ref、baseline/text failure recovery、重复样本伪造、plan tamper、taxonomy drift、匿名输出、忽略时间差异、阈值/样本数 gate 的 focused TDD。
- 本 README、[决策备忘录](./plans/20260727-reliability-gate-decision-v01.md)、spaces 索引与 daily memory。

## 验证与归档边界

- 原离线切片已完成合成 evidence 的 BDD/TDD 与 focused 验证；后续联合门禁和整合证据以 SP-151 为准。本次只改文档，不重跑 Swift 或真实设备检查。
- 真实 3 flow × 20 + 1 negative 不属于本次归档的已验收结果，也不是命令的自动副作用。仅按唯一后续事项的项目触发条件另立有限 space；环境不空闲、server owner 不明、target 不一致或 privacy 处置不足时停止并记录 blocker。
- 未来允许先做 1 supported + 1 negative 的真实接线 smoke，仅证明 harness 接线；完整 Stage 1 gate 仍为 blocked。只有完整专项的可复核数据才能支持可靠性 Go/No-Go 和后续 workspace handoff；不得把 workspace 的 `passed`、少量 smoke 或 dry fixture 当作该结论。
