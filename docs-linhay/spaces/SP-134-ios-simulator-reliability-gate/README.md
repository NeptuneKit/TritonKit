# SP-134 iOS Simulator Reliability Gate

> 状态：离线 gate 已完成本地验证；真实 3 flow × 20 采样只能在独占环境门禁通过后另立受控 harness 串行执行
>
> Branch：`feat/SP-134-ios-simulator-reliability-gate`
>
> Worktree：`../TritonKit-worktrees/SP-134-ios-simulator-reliability-gate/`
>
> 基线：`feat/SP-133-imported-ios-simulator-proof@19e2c35f`

## 决策

**Adopt：可靠性门槛先行，暂不接入 workspace。**

SP-133 只证明一条 imported iOS Simulator flow 能复用既有 `test run`，不能证明重复执行、失败可解释性或 workspace 编排。路线图要求先以三个冻结 flow 各 20 次的样本评估 ECR / FER / ORR；在这些门槛未通过前，workspace、Android 与第二执行器均不能扩张。

本 space 的第一个代码切片是纯离线的 `triton test reliability` 报告：读取已有私有 `.tritonevidence` 与显式 sample manifest，输出不含路径、selector、可见文本或截图的数据化可靠性结论。它不启动 server、App、Simulator 或 test executor。

后继 SP-136 已以 `triton test reliability-preflight --collection <private.json> --json` 冻结 future collection 的 imported-plan / canonical target / 20-slot / reset-recipe 合同；其 `ready_to_collect` 固定不是 sample、receipt、runtime verdict 或本 space gate 的通过。它不解除本 README 的 dedicated Simulator、self-managed server、fresh private evidence 与串行真实采样门槛。

## 范围与硬边界

- 只复用既有 `test import -> test validate -> test run -> .tritonevidence`；不新增 `testrec` executor、workspace executor、Web/Wails 写入口、HTTP route、Android/Harmony/真机能力。
- 每条真实样本必须由外部、受控 harness 在独立临时根创建：显式 dedicated Simulator UDID、已连接且 canonical 的 `triton:ios-simulator:<udid>/app:<bundle>` runtime target、与之相同的 manifest target / plan bundle、自管 `127.0.0.1:19421` server、新鲜 evidence 目录，且所有设备/服务动作串行。
- `test run` 的 `launch` 只解析已连接 runtime，**不会**重置 App 初态。因此报告只接受具有稳定 `initialStateID` / `resetEvidenceID` 的 sample；缺失、重复 reset/evidence/run 身份、partial evidence、目标绑定不一致或初态/目标漂移一律阻断 gate，不能把连续 run 当作可重复性数据。
- 原始 evidence（含 normalized plan、run events、AX/hierarchy、PNG）仍可能敏感；不得进入 Git、issue、PR 或公开日志。报告输出仅含 digest、枚举 taxonomy、计数和脱敏 flow ID。
- 不读取、修改、合并、清理 #164 dirty evidence WIP；不碰 main 的用户 WIP；不 push、PR、merge、tag、release、关闭 issue 或删除 worktree/branch。

## BDD 验收

1. Given 一个含 `flowID`、私有 evidence 路径、`initialStateID`、`resetEvidenceID` 与 target token 的 sample manifest，When 运行 `triton test reliability --samples <private.json> --json`，Then 只读所有 evidence 并输出稳定 `triton.test.reliability-report`；输出不泄露绝对路径、bundle、selector、可见文本、run ID、原始 `flowID` 或截图字节。
2. Given 一个样本缺少 manifest 声明的 `test.normalized-plan@normalized-plan.json` 或 `runtime.target@runtime-target.json`、带 iOS platform / Simulator UDID / canonical ID / connected=true 的 runtime target、event / observation count、终态 run event、逐 step 的 command/finish 覆盖、需要 runtime observation 的步骤所需 artifact、declared reset identity，或其 manifest 是 partial/skipped，When 汇总，Then ECR 将其标为不完整并以稳定 issue code 说明；所有 `artifact.created` 必须按 kind 与 canonical path 绑定 manifest artifact，observation 与终态 failure 的所有 artifact ref 也必须绑定 manifest 声明，不能仅因 bundle 内存在同名文件而计入 passed 或 ORR。
3. Given 已识别为 non-passed 的样本含稳定 failure type、artifact reference 与版本化 recovery category，When 汇总，Then 每个 non-passed 样本都进入 FER 分母；只有与终态失败步骤同 index、且位于其 `command.executed -> failure.recorded -> step.finished` 区间的完整记录才能进入分子。若任一字段缺失或借用其他步骤记录，该样本仍留在分母且不得被虚报为通过。没有已识别失败样本时，FER 为 `not_evaluable`，gate 不通过。
4. Given 同一私有 `flowID` 的重复样本，When 比较，Then ORR 只比较 verdict、step status、artifact taxonomy、failure taxonomy、initial state 与由 normalized plan / manifest target / runtime-target 私下绑定的目标身份；忽略 timestamp、run ID、evidence 路径和截图字节。任何 taxonomy/初态/目标漂移都必须暴露为 issue。
5. Given 不是至少 3 个 flow、每个至少 20 个完整样本，或 ECR < 95%、FER < 90%、ORR < 90%，When 读取 gate，Then 状态为 `blocked`；若 ORR < 70%，明确输出 `stop_expansion`，不进入 workspace、平台扩张或第二 runner。
6. Given 同一 canonical evidence bundle、event run ID 或 reset identity 被重复登记，When 汇总，Then 全部关联样本均以稳定 duplicate issue 标为不完整；它们不能伪造 flow/run 阈值。

## 私有 sample manifest

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

报告会回显自身使用的 `thresholds`，以便审计 ECR / FER / ORR 的 gate 结论；CLI 当前只接受仓内 canonical 默认值（3 flow × 20、95% / 90% / 90%），不会提供降低门槛的命令行选项。

## 计划内文件面

- `Sources/TritonKitCLI/CLITestReliabilityRuntime.swift`：sample-manifest / privacy-safe report DTO、离线读取、bundle containment、duplicate identity、canonical Simulator target / manifest-sidecar binding、event/observation/failure artifact-to-manifest binding、事件/计划逐 step 覆盖与 terminal-failure 归因校验、ECR / FER / ORR 及 gate 判定。
- `Sources/TritonKitCLI/CLITestCommands.swift`、`CLISchemaTestCommands.swift`、`CLISchemaOutputContracts.swift`：CLI、schema 与机器可读输出契约。
- `CLI/Tests/TritonKitCLITests/TestReliabilityRuntimeTests.swift`：完整、缺 artifact/计数/恢复、partial/空 event、canonical target binding、terminal-failure 归因、真实 runner 的 `../` artifact ref、baseline/text failure recovery、重复样本伪造、plan tamper、taxonomy drift、匿名输出、忽略时间差异、阈值/样本数 gate 的 focused TDD。
- 本 README、[决策备忘录](./plans/20260727-reliability-gate-decision-v01.md)、spaces 索引与 daily memory。

## 验证与停止条件

- 先写合成 evidence 的失败测试；实现后至少通过 `TestReliabilityRuntimeTests`、`TestRunExecutionTests`、`TestImportTests`、`TestValidationTests`、schema focused tests、`git diff --check`、`docs-linhay/scripts/check-docs.sh` 与匹配的本地门禁。
- 真实 60 次采样不是本命令的自动副作用。它需另有明确的 reset/preflight harness；环境不空闲、server owner 不明、target 不一致或 privacy 处置不足时停止并记录 blocker。
- workspace handoff 仅在可靠性 gate 有可复核数据且未触发 stop 条件后，另立独立 space；不得把 workspace 的 `passed` 或 dry fixture 当作 test verdict。
