# SP-207 — 全部参考项目追踪与采用流程

## 当前授权与状态

- 用户于2026-10-16要求“后期评估可以纳入的改动可以直接按照这个流程直接进入开发”，随后明确“从 iCTRL 扩大到所有参考项目”。本页是当前流程事实源，替代各历史研究中逐项等待采用授权的说明。
- 范围：全部已登记参考仓库，及登记为研究线索的候选；候选身份不等于已经采用。当前登记由 SP-194 的23主要仓库+9候选及 SP-199 的 Mobile MCP 组成，合计33个去重仓库。
- 影响层：参考资料、自动任务、开发分派和治理规则；本次配置不修改CLI/HTTP/SDK产品代码。
- 状态：持续追踪与采用。既有 SP-203～205、SP-210、SP-212、SP-214～SP-219 已完成本地合并，SP-211/SP-213 与 SP-220 主控验收和清理均有独立证据；日检基线为 `24e7d0f2`；SP-221经主控验收后已合入本地main `a0eebff0`，后续SP-223合并为 `9fbda1d5`，本轮会话收口核对基线为 `71ff9ae4`。`v0.2.33` 已由独立授权会话发布，未包含SP-221。SP-218普通native HID/占用拒绝恢复、SP-219普通→Resize→普通录制已有Xcode27.1/iOS27.0专用Simulator真实验收；Resize AX/HID仍unsupported，其他工具链及用户项目不外推。
- 正式说明：[参考项目追踪与采用](../../dev/reference-project-adoption-workflow.md)。
- 仓库与读取状态：[reference-state.json](./plans/reference-state.json)；任务去重与授权：[adoption-state.json](./plans/adoption-state.json)。上游读取状态与采用交付状态分开。
- 最近检查：2026-10-26，22完整/11 partial，simslim/Revyl两仓HEAD变化，Release/许可不变；[日报](./plans/20261026-reference-update-report.md)。用户要求继续后，两仓文本缺口已闭合并独立推进，当前合并视图24完整/9 partial，见[补查记录](./plans/20261026-partial-recovery.md)；本次仅重新查询2仓，其他31仓沿用日检。新SP-223/224已验收合本地main9fbda1d5；独立与合后完整CLI XCTest91/SwiftTesting1527、fakeCLI4场景和适用local通过，源worktree/branch已归档清理。新[SP-221](../SP-221-simulator-resource-read-retry/README.md)经[SP-222](../SP-222-simulator-resource-retry-integration/README.md)验收，候选eb9539f4合本地main `a0eebff0`；focused37、独立与合后完整CLI、root、适用local/docs均通过。显式gpt-6.1-sol真实执行/主控会话创建成功。旧13条采用保持，11旧源码/许可缺口不推进；未push/tag/release或执行设备恢复验证。
- 2026-10-22用户重申：开发验证完成须继续合入本地main并通过合并后门禁，不停在执行会话或候选分支完成；当前15条采用登记的合并提交已核对为main祖先（含SP-221、SP-223；条目数不等于独立功能数）。

- 2026-10-27主控接管自己开启会话的完整交付与关闭责任：15条合并提交再次确认在main，9个真实执行/主控会话已归档；本长期追踪聊天保留，见[关闭记录](./plans/20261027-session-closeout.md)。

- 2026-10-27完成33仓检查，24完整/9 partial，6仓HEAD和Release变化。Files Recents诊断进入SP-225/226独立开发验收；多点HID/软件键盘需真实兼容证据，保持观察。见[当日报告](./plans/20261027-reference-update-report.md)。

## 执行流程

1. **追踪与完整性**：每天只读查询官方默认分支HEAD、最新非draft Release与许可证，比较各仓库自身检查点。完整读取变化、来源与摘要成功保存后才原子推进该仓库相应检查点；分页/文件上限/截断、网络/权限失败保留旧点和失败记录，不以失败判无变化。新仓库先建基线，不把全部历史当新增。
2. **当前工程评估**：对照实际main源码、测试、已集成/已发布space，保存来源revision、机制、实际缺口、收益、产品边界、许可条件、BDD与验收；分类为可纳入、已覆盖、观察或拒绝。上游性能与测试声明未经本地证明就明确标注。
3. **直接开发**：可纳入项无需再次逐项确认。建立独立space/branch/worktree与执行会话，必要时按互斥文件面拆分；CLI/HTTP机器可读契约优先，Web/Wails不新增写控制面。先失败测试再实现，独立验证并保留候选清单和SHA。
4. **主控验证与合并**：同步建立或复用范围合适的主控会话，允许其与本批次执行会话协调、审查真实diff/测试证据、处理冲突、跑联合门禁；完成必要本地提交并合入本地main。验证失败继续修复，不能凭执行会话完成声明直接合并。已有SP-206只接管当前SP-203～205，不默认无限接收新批次。
5. **去重与恢复**：以canonical仓库+机制/本地需求为任务键，记录来源revision、decision、space、执行/主控thread与状态；改名仓库合并别名，同类机制跨仓库按本地需求去重。新SHA/tag不自动新建同机制任务。创建会话成功才记录ID；部分创建/失败标pending或dispatch_partial，先补缺项。既有任务继续跟进，不能用读取成功标开发/合并完成。
6. **归档与通知**：摘要/失败/评估放本space的plans，具体开发证据归各实现space，重大结论写正式档案和每日memory。只在有价值更新、新采用批次、重要交付/阻塞或读取故障变化/恢复时简要通知；上游未变且无待推进任务时保持安静。

## 既有交付与执行入口

- [SP-194更新报告](../SP-194-reference-project-updates/README.md)、[SP-196已发布优化](../SP-196-upstream-optimization-delivery/README.md)、[SP-200 Mobile能力](../SP-200-mobile-device-parity/README.md)先核对，避免把旧差距重复实施。
- iCTRL来源追踪与独立检查点保留在[SP-193](../SP-193-ictrl-reference-tracking/README.md)，本流程不降低其完整性要求。
- 已交付批次：[SP-203](../SP-203-ictrl-discovery-hardening/README.md)、[SP-204](../SP-204-ictrl-log-privacy/README.md)、[SP-205](../SP-205-ios-runner-auth-hardening/README.md)及主控[SP-206](../SP-206-ictrl-security-integration/README.md)；后续 SP-210/SP-212 及 SP-211/SP-213 也已验收合入本地 main。以采用登记核对历史会话与交付，不重复创建。

## 自动任务与边界

### 新会话模型

2026-10-16用户指定：今后本项目由agent创建的新会话（执行和主控）锁定为 `gpt-6.1-sol`。调用 `create_thread` 必须显式传入 `model: "gpt-6.1-sol"`，后续主控分派同样遵守；不省略后依赖默认模型，不使用latest别名，不自动回退其他模型。模型不可用则记录创建失败/待重试并报告，不冒充创建成功。本次不切换既有会话，也不改变推理强度。

复用当前聊天自动任务id `ictrl`，名称扩为“参考项目更新与采用推进”，沿用ACTIVE、每天北京时间10:00和当前thread绑定，不新增重叠定时任务。2026-10-16 导入旧快照时仅代表已知基线；此后逐日完整检查结果与 partial 分别保存在 plans，当前成功点以 reference-state.json 与 SP-193 独立状态为准。

授权本工程内评估、分派开发、验证、必要本地提交及本地main合并；push/tag/release、自动安装升级依赖、运行第三方代码、签名、DDI、设备操作、扩大远端/设备云等产品边界不从本授权推导。有对应明确授权时按该授权执行，否则记录具体依赖，不以抽象风险反复打断用户。所有共享副作用串行，保留其他WIP，禁止stash和整目录混入。

## BDD与验收

- Given任一已登记参考有更新，When证据完整且当前源码评估为可纳入，Then自动登记独立实现与主控会话，开发验证并本地合并，不逐项重问。
- Given机制已有任务或已实现，When新tag或多个仓库出现相同思想，Then复用任务/已交付事实，不重复立项；读取与交付状态分开。
- Given读取/会话创建失败，When恢复，Then保留真实检查点、任务状态与失败信息，只补缺项，不伪造成功。
- Given历史研究写着“不自动采用”，When后续执行查阅，Then当前入口明确指出2026-10-16用户追加授权，保留历史事实但不继承过期禁令。
- Given仅流程文档/配置变化，When收口，Then仓库清单、JSON/链接/去重与授权边界可核对，docs-only门禁通过；自动任务保存后读取确认，不声称已跑全仓追踪或功能验证。

## 验证与经验沉淀

本轮仅配置和文档；Swift/设备/上游运行不适用。本次使用既有ops治理skill沉淀跨会话流程，强调用户最新授权优先、独立检查点、去重与主控复核，不新增重复skill或AGENTS规则。2026-10-16：`verify.sh --ci-docs`、独立 `check-docs.sh`、`git diff --check` 通过（207 spaces）。33仓唯一性、24参考/9候选分类、40位导入SHA、既有3任务去重及新增文档链接校验通过。已从保存的自动配置确认原id/heartbeat/ACTIVE/每日10:00/原thread均保留，名称与prompt扩围成功；没有在本轮执行33仓完整读取或新功能开发。

## 2026-10-17 首轮全量日检与采用跟进

[日报](./plans/20261017-reference-update-report.md)和[观察记录](./plans/20261017-observations.json)：33仓查询，32仓在明确的相关机制审阅范围内完整，Baguette的APK关联源码未证实，保留partial和旧点；9仓相对导入观察出现HEAD/Release变化。ai-phone/Revyl的比较分页、相关源码与生成记录缺口已补齐，范围排除/未运行限制见补审；导入不是完整历史审计，首次全文许可hash不倒推历史变化。iCTRL专项SHA/tag/许可无变，成功点仍只在SP-193更新。

SP-203～205按既有联合验证与main祖先证据刷新为local_merged，不重复立项。新增SP-210可信AX几何切片及SP-211有限主控，独立branch/worktree已建；两次create_thread显式gpt-6.1-sol均被桌面接口拒绝校验，无真实thread，登记dispatch_blocked_model。后续先补缺会话，不重新建space/worktree、不换模型。当前主目录HEAD不是实际main，产品评估已绑定main@d51403a6；流程资料和main集成按SP-211精确清单处理，保留用户WIP。

本期无产品实现/运行验证，文档门禁结果见日报收口段。经验回写正式流程、ops skill与经验索引；通知指纹与成功检查点分离，未完成项不因去重而前移成功点。

2026-10-17收口：docs-only、独立check-docs、diff whitespace与登记一致性通过（211 spaces）；实现/主控分派仍受桌面接口模型校验阻塞，不标完成。


## 2026-10-18 第二轮全量日检

[日报](./plans/20261018-reference-update-report.md)与[观察记录](./plans/20261018-observations.json)保存了 33 仓的独立结果：19 仓完整、14 仓 partial，观察到 5 个 HEAD/Release 变化。serve-sim 与 Atlantis 仅列观察；Baguette 保持 APK 来源 partial；ai-phone/revyl-cli 因 GitHub API 403 无法闭合 Release/增量阅读，旧点不推进；SKProcessRunner 的许可缺失纠正为 partial。iCTRL 由 SP-193 成功检查点更新，SHA/tag/许可未变。

本轮无新采用项。SP-210/SP-211 的显式 `gpt-6.1-sol` 会话重试仍被接口模型校验拒绝；没有 thread ID、没有回退模型。

## 2026-10-19 第三轮全量日检与 mobile-mcp 采用登记

[日报](./plans/20261019-reference-update-report.md)与[观察记录](./plans/20261019-observations.json)保存了 33 仓独立结果：28 仓完整、5 仓 partial，观察到 5 个相对记录点变化，其中 4 个完整仓、1 个 partial 仓。Baguette 的 APK provenance、SKProcessRunner 的许可证与 RevylAI 三仓 API rate limit 继续保留旧检查点；iCTRL 在首次 gh TLS 失败后由官方 curl 完整恢复，SP-193 无变化检查点已更新。

mobile-mcp `c659f8e`/`1.0.12` 的 Android focused activity 身份与 legacy ADB `#`/`~` 转义经实际 main 复核为可纳入项，建立 [SP-212](../SP-212-mobile-mcp-android-contracts/README.md) 与 [SP-213](../SP-213-mobile-mcp-contracts-integration/README.md)，执行/主控 worktree 已建。三次 `create_thread` 均显式使用 `gpt-6.1-sol`，其中执行省略 reasoning 重试仍失败；`list_threads` 未发现 SP-212/SP-213 thread，保留 `dispatch_blocked_model`，不回退、不伪称开发完成。

## 2026-10-19 执行接替（历史阶段，现已完成本地交付）

本聊天已按用户授权启动指定`gpt-6.1-sol`的`/root/implement_sp210`与`/root/implement_sp212`，对应采用任务为implementing；当前聊天主控承担SP-211/SP-213，状态integration_in_progress，不额外创建聊天。以上历史桌面接口失败保留但已由本次subagent执行接替，不再作为当前blocker；execution_thread_id仍为null，execution_agent单独记录。尚未宣称联合产品门禁或main合并完成。


## 2026-10-19 本地交付

用户要求全部已实现worktree合main、未实现完成验收后合main。本聊天以指定模型subagent实施SP-210/SP-212并统一承担SP-211/SP-213；参考资料b1d20af9、产品联合候选f9760a17均已通过适用验收，经7a8e9f56合入本地main。历史create_thread失败退出当前待办，采用状态以登记为准。main合后完整CLI与local门禁复验通过，未设备操作、推送或发布。


## 2026-10-20 第四轮检查与安全切片

[日报](./plans/20261020-reference-update-report.md)与[机器观察](./plans/20261020-observations.json)：24/33完整、9 partial，6仓相对昨日真实新变化。7仓相对成功/导入点变化包含Baguette历史partial，不能重复称今日新增。8仓缺许可与Baguette来源保留旧点；CogniSim读取完整恢复，另两Revyl API恢复后转为缺许可。修正昨日无许可仍完整和figma观察SHA笔误，不倒推为上游许可删除/新提交。

sim-use的可信主屏安全拒绝归SP-214/215，ai-phone的HDC forward清理归属归SP-216/217；两项均已对照实际main f82872e2及SP-192/196/200/210/212，保存固定来源、许可、BDD、文件面与独立工作区。SP-214执行和SP-215主控的两次必要create_thread均显式gpt-6.1-sol，实际仍返回模型校验失败；SP-216/217未重复探测，保留pending。没有新thread ID，没有产品开发/验证/合并；不重做已交付SP-210/SP-212。

经验检查复用既有完整性与去重规则，修订原流程当前批次和顶部陈旧断言；没有新增重复skill/AGENTS规则。验证结果见日报收口。

2026-10-20收口：docs-only、独立check-docs（217 spaces）、diff whitespace及JSON/链接/逐仓检查点/采用去重与真实祖先校验通过；仅规划和追踪完成，新批开发分派仍受阻。


## 2026-10-21 第五轮全量日检与 Resizable 路由采用

[日报](./plans/20261021-reference-update-report.md)与[观察记录](./plans/20261021-observations.json)：33仓官方只读查询完成，23完整、10 partial；Baguette、sim-use、device-hub-ios、Revyl CLI相对昨日有新变化。扫描时 sim-use 的 Xcode 27 Resize Mode 在主线仍只有截图 display 选择，随后 SP-219/SP-220 已补齐并合入录制 display identity 路由；AX/触摸/视频保持拒绝或未验证边界。Baguette/APK provenance、缺许可证和patch省略继续保留旧点；iCTRL由SP-193独立检查且无变化。

本轮不重复SP-214～SP-218；SP-219/SP-220 的实现、主控验收和本地合并已另存证据。未运行第三方代码、设备、依赖、签名/DDI、推送或发布；会话创建结果另记采用状态。
