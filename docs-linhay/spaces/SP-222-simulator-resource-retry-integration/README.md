# SP-222 — Simulator资源只读重试验收与整合

## 当前状态

2026-10-26：SP-221离线候选验收及实际main合后门禁通过，证据已归档，SP-221/SP-222工作区与分支已正常清理。执行候选 `eb9539f4`，独立联合候选 `4249bd26`，报告 `95a1dc8f`，产品合并 `a0eebff0`，最终清理记录 `8fcd856f`。未push/tag/release。

本批只审查[SP-221](../SP-221-simulator-resource-read-retry/README.md)同目标只读暂态重试，不修改mutation策略，不承接其他采用批次。执行、验收、main整合与清理均已完成；真实恢复未验证属于保留的验收边界，不列作本批开发待办。

## 验收分层与证据入口

| 阶段 | 结果与范围 | 权威记录 |
| --- | --- | --- |
| 执行先红后绿 | 基线10项/3失败；最终focused37/37；非零typed throw与返回result均覆盖 | [执行交接快照](../SP-221-simulator-resource-read-retry/plans/20261026-candidate-handoff.md) |
| 独立联合候选 | focused37/37；完整CLI XCTest91零失败、SwiftTesting报告1515项/153 suites通过，3项真实环境skip；exit0 | [候选验收报告](plans/20261026-validation-report.md)、[tree/文件/日志hash清单](plans/20261026-evidence-manifest.json) |
| 实际main合后 | 完整CLI同数量通过；根包XCTest5及SwiftTesting108/20 suites、293/41 suites通过；适用local和docs门禁exit0 | [主线验收与清理](plans/20261026-main-merge.md) |
| 证据归档与清理 | 40份文件的大小/SHA256匹配；该批清理完成时只剩干净主工作区；history-only合并无tree变化 | 同上，含归档路径及历史提交 |

focused与完整CLI重叠，不累加；日志中重复suite汇总不累加。3项CLI skip为owned Simulator JPEG和两个真实NetService用例，根包真实Bonjour也有skip。`TRITON_VERIFY_XCODE=0`跳过真实Simulator构建，fake smoke只证明对应离线契约；本地Release CLI构建不等于发布。

## 审查结果与经验

[历史审查与修正](plans/20261026-audit-history.md)集中保留首次风险、过渡失败、旧hash及关闭证据。已关闭项包括substring暂态误识别、成功来源未绑定、固定fixture来源、共享索引基线缺项，以及tracked patch与冻结说明不一致。原阶段文档及归档原日志继续保留；README不再复制其全文或延续已完成的待交接/待合并状态。

复用检查：分别覆盖typed nonZeroExit与返回结果；对完整诊断及命令身份做正负例；契约收紧时修fixture，不放宽产品guard；冻结时核对实际tree、tracked文件和日志hash；报告区分配置预算、进程清理、fixture与真实恢复。领域规则见[host skill](../../../.agents/skills/tritonkit-host-simulator-takeover/SKILL.md)，文档收口规则见[ops治理](../../../.agents/skills/tritonkit-ops-governance/SKILL.md)。

## 真实运行与发布边界

暂态样本为上游文本和离线fixture，未复现本机launchd故障；真实Simulator恢复概率、跨进程竞态及跨Xcode兼容未验证。30秒配置预算不含runner额外终止/drain清理；取消不保证同步在途Process立即终止，未知诊断继续fail-closed。无设备、签名/DDI、依赖升级、第三方参考代码运行或远端写入。

## 历史身份与职责

执行thread `01a175fc-c9c4-7053-b91e-74c209d3f0ca`，主控thread `01a175fd-5c91-7b52-bc7c-683468efff9f`，均显式gpt-6.1-sol创建成功。历史分支为 `feat/SP-221-simulator-resource-read-retry`、`feat/SP-222-simulator-resource-retry-integration`，对应同级worktree已删除。执行拥有一生产文件、两测试文件及SP-221资料；主控拥有SP-222审查资料，root完成实际main合并、合后门禁和正常清理。旧setup/模型失败不是当前阻塞。
