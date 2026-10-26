# SP-221 — Simulator资源状态只读重试

## 当前状态与范围

2026-10-26：已完成离线实现、独立验收、main合后门禁和证据归档；本地main合并 `a0eebff0`，执行候选 `eb9539f4`。原执行worktree与分支已正常清理，未push/tag/release。最终结果见[SP-222主线验收与清理](../SP-222-simulator-resource-retry-integration/plans/20261026-main-merge.md)。本切片没有开发或整合待办；真实运行未验证边界继续保留。

来源为[simslim 2c68da93](https://github.com/MobAI-App/simslim/commit/2c68da93700aa1a1c45ce31a7ea9f7cac2174ddc)，MIT许可全文hash `8b65667572b02a584c03c2977372eeb5fe8de0e228211b6f83033c458cc10b4e`。独立实现，未复制或运行Go源码；产品基线 `24e7d0f2`。仅影响CLI host资源状态reader，HTTP/shared/Web/schema无新增契约，不扩大SP-177资源管理范围。

## 已实现的契约与BDD验收

| 场景 | 最终行为 |
| --- | --- |
| 同一有效精确UDID出现明确launchd启动/teardown暂态 | 仅重试同一 `xcrun simctl spawn <UDID> launchctl print-disabled system`，最多3次；30秒配置执行预算覆盖命令耗时及0.1/0.2秒退避，各次timeout不超过剩余预算 |
| 返回非零result或生产形式的typed nonZeroExit | 两路径均覆盖；typed error.command完整匹配当次issued command（含timeout、环境等），失败及成功结果均绑定sourceCommand |
| 截断、权限/永久/未知错误、timeout、取消、任意其他throw | 立即保留失败；非零暂态须空白stdout、有效UTF-8、完整诊断白名单，未知/复合上下文不重试 |
| 成功读取 | 严格解析payload，畸形/重复label不得变成成功map；合法非空stderr不单独判失败 |
| 持续暂态或预算耗尽 | 有界失败，保留返回失败的commandFailed或typed nonZeroExit语义 |
| apply/restore读失败或mutation失败 | enable/disable/boot等mutation不自动重放，保留原三方恢复语义 |

唯一生产文件为 `Sources/TritonKitCLI/CLISimulatorResourceState.swift`；State测试补22项、保留原7项，Mutation测试仅一行来源fixture对齐，不削弱原断言。完整诊断白名单：exit124的 `Failed to start launchd_sim: could not bind to session, launchd_sim may have crashed or quit responding`，或非零的 `Domain is tearing down`；可带唯一、同exitCode的NSPOSIXErrorDomain前导行。

## 验收与证据

- [首轮红证据](plans/20261026-red-evidence.md)与[精确红测试快照](plans/20261026-red-tests.swift.txt)：旧实现10项/3失败，exit1；exit130中止不计。
- [执行阶段交接快照](plans/20261026-candidate-handoff.md)：最终focused37/37，完整文件和日志hash。
- [独立候选验收](../SP-222-simulator-resource-retry-integration/plans/20261026-validation-report.md)与[证据清单](../SP-222-simulator-resource-retry-integration/plans/20261026-evidence-manifest.json)：联合4249bd26/tree3a1e130e、报告95a1dc8f；完整CLI XCTest91、SwiftTesting1515/153 suites，明确3项skip，不累加focused。
- [历史审查与修正](../SP-222-simulator-resource-retry-integration/plans/20261026-audit-history.md)：诊断误识别、来源绑定、fixture修正、索引及冻结patch不一致均已关闭。
- main合后根包、local/docs门禁和40份日志归档，以主线验收与清理记录为准。

## 真实运行未验证边界

诊断样本来自上游文本和离线fixture；typed throw证明reader处理生产错误类型，未在本机实际launchd故障中复现，不证明Simulator恢复概率、跨进程稳定或跨Xcode兼容。未知诊断形状保持fail-closed，扩展需实际捕获和负例。

30秒为runner配置执行预算，terminate/kill/drain清理可额外耗时，非硬墙钟上限。同步在途Process不由本层Task取消立即结束；取消只保证返回后不再重试。未执行真实Simulator/设备恢复、签名/DDI或依赖升级；本地Release构建不代表发布或安装接替。

## 经验入口

重试和诊断的可复用检查已进入[host simulator skill](../../../.agents/skills/tritonkit-host-simulator-takeover/SKILL.md)；候选冻结与当前/历史文档的分工见[ops治理](../../../.agents/skills/tritonkit-ops-governance/SKILL.md)。具体触发、修正及证据保留在历史审查与主线记录，不重复建立待办。
