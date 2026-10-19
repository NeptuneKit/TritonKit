# 参考项目追踪与自动采用流程

当前授权：2026-10-16 用户要求后续评估可纳入项直接进入开发，随后将范围从 iCTRL 扩大到所有参考项目。流程事实源为 [SP-207](../spaces/SP-207-reference-adoption-pipeline/README.md)，覆盖当前已登记24个参考仓库与9个研究候选，以及后续正式登记项目；具体仓库、别名与历史基线见 [参考登记](../spaces/SP-207-reference-adoption-pipeline/plans/reference-state.json)。候选不等于已采用。

## 默认执行

官方上游增量读取 → 当前main源码/测试/已交付差距评估 → 保存采用理由、BDD和文件面 → 独立space/worktree与执行会话开发验证 → 主控审查、修复冲突与联合验证 → 必要本地提交、本地main合并。可纳入且属于现有产品范围的变更无需逐项再次确认。现有明确授权持续有效，历史报告“不自动采用”只代表当时权限，不再作为当前阻断条件。

每日任务复用id `ictrl`，名称“参考项目更新与采用推进”，保持当前聊天、ACTIVE与北京时间10:00；不新增重叠任务。现有iCTRL检查点仍由SP-193管理，其他仓库从SP-194/SP-199历史快照开始，首次完整读取后才建立对应成功点。本轮配置未重新查询全体仓库。

## 新会话模型

2026-10-16用户指定：今后本项目由agent创建的新会话（执行和主控）锁定为 `gpt-6.1-sol`。调用 `create_thread` 必须显式传入 `model: "gpt-6.1-sol"`，后续主控分派同样遵守；不省略后依赖默认模型，不使用latest别名，不自动回退其他模型。模型不可用则记录创建失败/待重试并报告，不冒充创建成功。本次不切换既有会话，也不改变推理强度。

## 证据与去重

- [上游登记与检查点](../spaces/SP-207-reference-adoption-pipeline/plans/reference-state.json)逐仓库独立更新；完整读取和摘要保存成功后原子推进。截断/失败不推进，不能伪装无变化；无旧SHA先建基线。
- [采用登记](../spaces/SP-207-reference-adoption-pipeline/plans/adoption-state.json)与读取状态分开，按仓库+机制以及跨仓库本地需求去重；先核对SP-192/196/200及各space当前实现，不能把旧差距重复排期。
- 开始对照前同时核对 `git branch --show-current`、`git rev-parse main` 与 `git worktree list --porcelain`。主目录HEAD不一定是实际main；用实际main固定blob核对产品差距，较新的授权/追踪文档可能仍在另一分支，不因main占号页而丢弃。集成只按批准文件清单提取，索引/历史人工合并，不整分支回灌旧产品。
- 会话创建成功才记录真实ID，部分失败先补缺项；建立实现/主控空间时串行登记编号。执行会话停止写入后冻结候选，不整目录复制其门禁上下文；测试绑定联合候选，主控复核后才能合并。
- 通知去重另存 `last_notified_observation`（HEAD/tag/许可hash/覆盖状态指纹），不推进未完成仓库的成功点。相同未完成增量或模型校验故障不重复通知；覆盖恢复或故障变化再报告。采用登记的 `last_dispatch_failure_notice` 同样不代表会话创建成功。
- 新批次创建或复用范围适合的主控。现有SP-206负责SP-203～205，不因此无限扩张；后续若复用需明确更新其有限范围。允许主控协调本批次执行会话，但不授权外部消息。

## 边界与通知

该授权包括本项目评估、分派、开发验证、必要本地提交与本地合并；push/tag/release、依赖安装/升级、第三方代码执行、设备/签名/DDI、扩大远端/云等产品面需对应明确授权。许可与代码复用条件在采用评估中核实，不能将一个仓库许可证套用到其外部分发依赖。保留CLI/HTTP契约优先与Web只读边界。

有价值更新、新采用批次、重要交付/阻塞、读取故障变化或恢复时简短中文通知并附原始链接；未变化且无待推进采用任务则静默。上游性能、测试数量与成功率如未在本地证明，明确标注未经验证。未来正式登记的参考进入清单，偶然链接或clone目录不自动纳入。

## 历史关系

- [SP-194参考报告](../spaces/SP-194-reference-project-updates/README.md)及[2026-10-14快照](20261014-reference-project-updates.md)：保留当时23+9数量和证据；后新增Mobile MCP使当前登记为33仓。
- [SP-193 iCTRL专项](../spaces/SP-193-ictrl-reference-tracking/README.md)：保留原成功检查点、报告与更严格的完整性规则，采用入口统一到本流程。
- [SP-206主控](../spaces/SP-206-ictrl-security-integration/README.md)：当前首批三个切片的验证与本地合并，不代表这次扩大流程已经执行所有参考更新或产生新产品交付。

## 当前批次（2026-10-17）

[首轮33仓日报](../spaces/SP-207-reference-adoption-pipeline/plans/20261017-reference-update-report.md)记录32仓完整的有界机制观察、1仓partial；9仓变化。旧SP-203～205本地合并已核验，新的[SP-210](../spaces/SP-210-simulator-ax-geometry/README.md)/[SP-211](../spaces/SP-211-reference-adoption-integration/README.md)已规划并建立独立worktree。桌面create_thread无法校验显式gpt-6.1-sol，两角色均未创建；采用登记保留待重试，不能宣称开发/主控已启动。具体证据和重试去重以SP-207登记为准。

## 2026-10-18 完整性纠正

第二轮全量检查发现，上一轮若把许可证 404、Release API 403 或固定二进制来源未闭合的结果标成“完整”，会让检查点看似成功但无法支持复核。本轮统一将这些结果记为 partial，保留旧 SHA/tag，不推进检查点；只有官方 HEAD、非 draft Release 分页、许可证全文和相关增量证据闭合后才可推进。SKProcessRunner 的历史标签已在 [20261018 日报](../spaces/SP-207-reference-adoption-pipeline/plans/20261018-reference-update-report.md) 中纠正。
