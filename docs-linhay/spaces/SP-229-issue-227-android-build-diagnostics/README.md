# SP-229 · Android build diagnostics

当前状态：本地实现/联合验收完成；汇入 `feat/SP-241-open-issues-validation`，未合main、未发布、远端仍开放。[联合验收与风险](../SP-241-open-issues-validation/plans/20261028-validation.md)为当前事实源；独立分支冻结记录保留为历史。
## 边界

对应 [GitHub #227](https://github.com/NeptuneKit/TritonKit/issues/227)，影响 CLI Android 构建诊断和 timeout 摘要；不改变 Gradle 构建任务、进程超时策略或 Harmony/Xcode 诊断。

## BDD 与验收

- Given Gradle task 名含 Errors、Kotlin w: 消息含 error，When 汇总日志，Then task 不记错误、w: 只记 warning。
- Given Kotlin e:、Java 文件位置 error/warning 和 Gradle FAILURE block，When 汇总日志，Then 按显式 severity 计数；FAILURE block 不因 What went wrong/BUILD FAILED 重复计数。
- Given fake Gradle 输出上述 warning 后超时，When 生成 failure summary，Then ok=false、无安装产物、errorCount=0、warningCount=1，durationMs 为实际流逝时间。
- 实际 Android 项目/设备未运行；fixtures 证明解析与计时契约，不解释原私有工程构建慢的原因。

## 证据

[验收记录](plans/20261028-validation.md)；实现涉及 CLIBuildRuntime/CLIBuildModels，测试为 BuildRunnerTests。

## 工作区

branch：feat/SP-229-issue-227-android-build-diagnostics；worktree：../TritonKit-worktrees/SP-229-issue-227-android-build-diagnostics。

## 实现与沉淀

Android severity 按 Kotlin e:/w:、独立 error:/warning: 或 Java source-location marker 分类；Gradle FAILURE banner 为一条构建错误，任务名/What went wrong heading/BUILD FAILED footer 不额外计数。warning 中包含 error 不会双计。失败摘要即使重新解析工具失败，也使用原请求的 platform 选择 Android 分类器。超时耗时由 monotonic uptime 记录，包含进程收尾耗时，与原 timeout 上限分开。

经验沉淀写入本 space：构建结果状态与诊断计数是两类事实；timeout 可有零个 source error，有限日志计数不证明构建成功。保持原采样预算（最多 2000 行），不把它解释为完整 compiler 总数。本切片无跨 space 重复新规则，不扩充 AGENTS/skill。
