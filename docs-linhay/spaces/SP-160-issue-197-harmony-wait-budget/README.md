# SP-160：GitHub #197 Harmony wait layout budget

## 边界

- Issue：GitHub #197 `Harmony wait can start dumpLayout with near-zero remaining timeout`。
- 影响层：CLI host Harmony wait；共享 `waitForHarmonyText` 与 `dumpHarmonyLayout` 的 timeout 合同。
- 目标：在外层 wait deadline 临近时，不再启动几乎没有执行机会的 `hdc shell uitest dumpLayout`；保留标准 `timedOut=true` wait envelope 和已有 transient diagnostics。
- 非目标：不改变 Harmony 真机/仿真器发现、HDC 命令语义、wait condition 语义，不把真实项目或私有 App smoke 宣称为本地证据。

## BDD 验收

### 场景 1：剩余预算不足时停止轮询

- Given Harmony wait 的剩余总预算低于 layout capture 最小命令预算。
- When 下一轮即将开始。
- Then 不调用 `dumpLayout`/`recv` capture，不传入近零 timeout。
- And 返回 `timedOut=true`、`matched=false`，保留此前已采集的诊断。

### 场景 2：正常预算仍共享 deadline

- Given 剩余预算至少达到最小 capture 预算。
- When 执行一次 layout capture。
- Then dump/recv 继续共享同一绝对截止时间，capture timeout 不超过 `min(5s, remaining)`。

## 验收边界

- focused：`HarmonyWaitRuntimeTests` 覆盖 near-zero budget guard 与既有 transient retry/deadline 合同。
- full：CLI focused/full tests、`docs-linhay/scripts/verify.sh --local`、主线 CI。
- 环境风险：本轮没有可用于重新执行的 Harmony target；真实 HDC/ArkUI dumpLayout 仍需后续设备回归。

## 状态

- 当前：已合入主线 `e77c72b7`，分支提交为 `0ff8089e`；`HarmonyWaitRuntimeTests` 5/5、分支/主线全量门禁和 CI `31301092517` 均通过，GitHub #197 已评论并关闭。
- 远端边界：真实 Harmony HDC/ArkUI dumpLayout smoke 仍未执行；0.4 秒预算是 host command contract，不代表真实 target readiness。
