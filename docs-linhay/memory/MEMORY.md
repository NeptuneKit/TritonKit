# TritonKit Project Memory

- 2026-10-29：[v0.2.36发布验收](../spaces/SP-243-release-v0-2-36/plans/20261029-release.md)完成，candidate527b2368；main/tag CI、双架构Release、checksum/skills/Runner/Homebrew通过，包外只读Web及默认页面console检查通过，流黑图内容未验证。#224/#214 OPEN；主目录17个WIP未变，CocoaPods仅lint。

- 2026-10-28后续：[#224显式主屏截图](../spaces/SP-235-issue-224-simulator-resize-query/plans/20261028-primary-framebuffer.md)承接能力拒绝调查。Xcode27.1 iPad单LCD opt-in截图已实测成功，unsupported仍unknown；默认截图/输入仍拒绝，#224 OPEN，PR #236已合main（27c7a875），#224保持OPEN。原诊断completed仅历史记录，完整门禁结果见验收报告。

- 2026-10-28：[v0.2.35发布验收](../spaces/SP-242-release-v0-2-35/plans/20261028-release.md)完成：candidate190c161f，main/tag CI与Release全绿，双架构/checksum/skills/Runner/Homebrew验证通过。包外只读HTTP通过；默认实时流因本机resize unknown返回409，工作台布局零console error，不能声称默认流通过。#214 OPEN；原主目录HEAD/status/17个WIP哈希未变，CocoaPods仅lint。

- 2026-10-28：[SP-241全部开放issue本地联合验收](../spaces/SP-241-open-issues-validation/README.md)覆盖#214、#221～232，10项缺陷、1项文档及2项范围/历史审计；实现`51d505bb`，完整CLI/root/local与UIKit/Runner模拟器fixture通过，Android旧版黑盒反证明确。随后已按追加授权合并[PR #233](https://github.com/NeptuneKit/TritonKit/pull/233)为40850dde，#221～232共12项completed关闭；#214保留原始来源/占用只读调查，通用删除仍取消。[归档及后续计划](../spaces/SP-241-open-issues-validation/plans/20261028-merge-closeout.md)；本批已随v0.2.35发布，主目录WIP保留。

- 2026-10-26继续：[SP-207补查](../spaces/SP-207-reference-adoption-pipeline/plans/20261026-partial-recovery.md)恢复两仓文本完整性，当前24完整/9 partial（2仓重查、31沿用日检）。宿主退出后继承pipe超预算经自有原函数probe复现，SP-223执行/SP-224有限主控均gpt-6.1-sol；已验收合本地main9fbda1d5，独立及合后完整CLI/local通过，源worktree/branch已清理。

- 2026-10-26：[参考日检](../spaces/SP-207-reference-adoption-pipeline/plans/20261026-reference-update-report.md)22完整/11 partial、simslim/Revyl两仓HEAD变化。新增[SP-221](../spaces/SP-221-simulator-resource-read-retry/README.md)只读资源暂态有限重试及[SP-222](../spaces/SP-222-simulator-resource-retry-integration/README.md)有限主控，两个真实create_thread显式gpt-6.1-sol成功；候选eb9539f4经主控及合后门禁合本地main a0eebff0，未发布，旧模型失败不作为本批阻塞。

- 2026-10-25：[参考日检](../spaces/SP-207-reference-adoption-pipeline/plans/20261025-reference-update-report.md)22完整/11 partial、3仓HEAD变化；新增Revyl v0.1.188/Mobile MCP 1.0.13，无新本地采用。云优先级、托管Web说明、MCP依赖/描述无对应本地路径；既有13条采用均在main，不重排。

- 2026-10-24：[参考日检](../spaces/SP-207-reference-adoption-pipeline/plans/20261024-reference-update-report.md)22完整/11 partial、5仓HEAD变化，无新采用；按`main@24e7d0f2`及v0.2.33核对，采用登记补齐SP-214显示修复与SP-218/219真实验收，Resize AX/HID仍unsupported。本监控不重跑设备或发布。

- 2026-10-24：v0.2.33已发布，tag `e2b1d959`；SP-218真实显示查询兼容修复及本轮CLI契约收口已交付，双架构公开资产、Homebrew和仓库外只读Web验收通过。原工作区其他WIP未混入发布；CocoaPods仅lint、未推送trunk。详见[发布证据](../spaces/SP-218-issue-222-device-hub-input/plans/20261024-v0.2.33-release.md)。

- 2026-10-24：按用户裁决归档SP-126/134/177/179/183，SP-181/182维持研究设计归档；SP-193/207监控继续。真实可靠性专项仅由项目采用/公开可靠性承诺触发，自动DerivedData删除取消。当前裁决与验证见[本轮记录](2026-10-24.md)。

- 2026-10-23：[参考日检](../spaces/SP-207-reference-adoption-pipeline/plans/20261023-reference-update-report.md)22完整/11 partial、3仓变化，无新增采用。13仓首次连接故障经一次安全重试恢复，旧许可/源码缺口不推进；既有13条采用均已合main。

- 2026-10-22：[参考日检](../spaces/SP-207-reference-adoption-pipeline/plans/20261022-reference-update-report.md)22完整/11 partial、4仓变化，无新采用；SP-219许可按固定全文更正Apache-2.0，取证过滤规则写回[正式流程](../dev/reference-project-adoption-workflow.md)。现有采用均已交付，不重排旧任务。

## Canonical Indexes

- Spaces 的固定入口分为 [编号索引](../spaces/INDEX.md) 与 [路线总览](../spaces/README.md)：前者登记 SP 规范名、兼容目录与迁移进度，后者登记状态和队列。
- 新建 space、状态变化、worktree 集成或 space 收口时，必须同步更新两个入口。
- 新 space 采用 `SP-<三位序号>-<topic>`；单个需求的详细边界、BDD、计划和证据仍以对应 `docs-linhay/spaces/<space-id>-<topic>/README.md` 为事实源。

- 开工与交付的按主题入口：[经验索引](EXPERIENCE.md)；每个任务/交付切片默认自动沉淀，有复用价值的纠正/缺陷/失败触发原文更新，无需用户提醒。详细动作以 [治理流程](../dev/20260619-agent-workflow-skill-governance.md) 为准。无需全量预读每日历史，原文后续证据可替代旧结论。

## Memory Rules

- [OpenMinis/iCTRL](https://github.com/OpenMinis/iCTRL) 是长期参考项目：正式档案见 [iCTRL 参考与追踪](../dev/ictrl-reference-tracking.md)，持续追踪见 [SP-193](../spaces/SP-193-ictrl-reference-tracking/README.md)，已有借鉴实现见 SP-192。自动化 `ictrl` 每天北京时间 10:00 检查上游，有价值变化通知；后续已按SP-207扩展为评估可纳入项直接独立开发、验证与本地合并，设备/远端写入仍依明确授权。
- [mobile-next/mobile-mcp](https://github.com/mobile-next/mobile-mcp) 已列为参考项目：正式档案与能力差距见 [Mobile MCP 参考](../dev/mobile-mcp-reference.md) / [SP-199](../spaces/SP-199-mobile-mcp-reference/README.md)。固定源码与外部 mobilecli backend 分开核对；计入现有 iOS Runner。原登记研究阶段已结束，现由SP-207统一周期追踪与采用；SP-212契约切片已完成离线验收并合入本地main。
- 参考项目清单和2026-10-14上游更新统一入口：[参考项目更新报告](../dev/20261014-reference-project-updates.md) / [SP-194](../spaces/SP-194-reference-project-updates/README.md)，覆盖主要仓库与专题候选；后续比较优先使用其中固定SHA/Release证据，区分默认分支与已发布能力。

- 长期稳定的项目入口和跨会话约定记录在本文件。
- 每日实施记录继续写入 `docs-linhay/memory/YYYY-MM-DD.md`。
- repo-wide 执行规则仍以根目录 `AGENTS.md` 为准。


## 已实现的可选视图高亮

- [SP-197](../spaces/SP-197-view-annotation/README.md)已在本地main提供独立`highlight capabilities/apply/status/clear`；P0支持自愿启用Debug runtime的UIKit可写节点，普通截图不强制SDK。public skill的[高亮流程](../../TritonKit.skills/tritonkit-emulator-cli-takeover/references/view-highlight.md)为调用入口。恢复使用App-owned session、原始平台属性与整组值保护；业务冲突须报告，TTL不承诺挂起/卡死期间实时恢复。跨端及自动截图组合仍属后续。


## 上游优化交付入口

- 参考更新的已实现采用项与验证边界见[SP-196验收报告](../spaces/SP-196-upstream-optimization-delivery/plans/20261014-validation-report.md)及[工程说明](../dev/20261014-upstream-optimization-delivery.md)。已于2026-10-15完成主线集成及v0.2.28发布，详见[发布验收](../spaces/SP-196-upstream-optimization-delivery/plans/20261014-release.md)；跨OS私有行为仍需专项证明，当前工具链的Resize录制证据见SP-219。后续复用按报告的模块/真实/跳过口径判断，不继承上游性能估计。

- SP-200 Mobile 设备能力补齐：除云设备预订/释放与标准 MCP 接入外，已实现本机三平台环境、录屏、诊断、归档安装、动作、终端镜像及统一 HTTP command；真实证据和平台边界见 [SP-200](../spaces/SP-200-mobile-device-parity/README.md) / [实现说明](../dev/20261015-mobile-device-parity.md)。

- iCTRL安全采用在[SP-206](../spaces/SP-206-ictrl-security-integration/README.md)联合验收：默认发现/广播显式开启、响应日志元数据白名单、Runner CryptoKit会话持密证明与加密通道；未宣称embedded服务认证、物理身份、防透明转发或设备运行验收。

- 内置SDK悬浮圆点与用户选控件的需求入口：[SP-201](../spaces/SP-201-sdk-floating-picker/README.md) / [设计](../dev/20261015-sdk-floating-picker.md)。2026-10-16 已实现并验证直接拖选/长按移位、稳定方向罗盘、父子记忆和局部放大镜；UIKit85项、真实拖选0次→CLI guarded tap 1次通过。功能提交2711565f已按用户授权整合本地main，联合UIKit/启动回归107项通过，已随v0.2.30发布，用户体验另验；与SP-197属性高亮独立。

- 2026-10-16：[worktree与分支收口](../dev/20261016-worktree-closeout.md)完成9个源工作区和本地分支回收，仅保留main；未提交历史副本有可恢复snapshot/bundle，SP-208已整合并随v0.2.30发布。

- [SP-209 SDK hub 与选择器运行时开关](../spaces/SP-209-picker-runtime-toggle/README.md)：圆球单击进入系统 pageSheet 的首页连接摘要与连接/选择器/SDK功能/应用/入口五路由；iOS 15+ medium/large detents，旧系统 pageSheet 降级。选择辅助二级配置，能力为宿主配置只读，隐藏仅入口页确认。宿主自行通过独立API唤回，不重连；modal 期间圆球/选择提示暂隐藏且系统遮罩整窗拦截，关闭/下拉恢复有效上下文；内部使用系统导航与分组列表。已随v0.2.30发布，最终回归范围见space。

- v0.2.30已发布：CLI双架构/Homebrew/skills/Web/podspec统一；更新误报修复、原生SDK hub与安全整合已交付。[发布证据](../spaces/SP-208-update-version-alignment/plans/20261016-release.md)。

## 参考采用补充（2026-10-19）

- 新会话模型锁定（2026-10-16）：本项目由agent创建的新会话（含执行和主控）在 `create_thread` 中显式指定 `model: "gpt-6.1-sol"`；不依赖默认值或自动回退。后续主控分派遵守同一约束，既有会话与推理强度保持原设置。
- 全部参考项目采用授权（2026-10-16）：用户明确从iCTRL扩至所有参考；[SP-207](../spaces/SP-207-reference-adoption-pipeline/README.md) / [正式流程](../dev/reference-project-adoption-workflow.md)为当前事实源。评估可纳入项直接独立开发会话/worktree，由主控验证、必要本地提交与main合并，不逐项重问。原 `ictrl` 自动任务扩大范围并复用每日10:00计划；当前33仓（24参考+9研究候选），新正式登记项目后续加入，按机制/本地需求去重。push/发版、设备等按各自授权。
- 2026-10-17参考采用批次：[日报](../spaces/SP-207-reference-adoption-pipeline/plans/20261017-reference-update-report.md)；当时SP-210/SP-211已立项但桌面模型校验失败；该历史阻塞已由10月19日本聊天交付接替，当前均已验收合main。主目录HEAD不等于真实main，恢复集成按SP-211精确文件清单，不回灌旧产品或覆盖用户WIP。
- 2026-10-18参考日检：[SP-207第二轮日报](../spaces/SP-207-reference-adoption-pipeline/plans/20261018-reference-update-report.md)固定了19个完整、14个partial的结果；GitHub API 403不能伪装无变化，SKProcessRunner无许可证状态纠正为待复核，iCTRL仍由SP-193独立维护。SP-210/SP-211显式`gpt-6.1-sol`会话重试仍失败且无thread，不回退模型。

- 2026-10-19：本聊天已启动指定模型的SP-210与SP-212执行subagent，主控承担SP-211/SP-213；历史桌面会话创建失败保留，当前推进状态以采用登记为准。

- 2026-10-19：[SP-210～213联合验收](../spaces/SP-211-reference-adoption-integration/plans/20261019-validation.md)已完成离线AX可信几何、Android前台身份与legacy输入转义，经7a8e9f56合本地main；资料b1d20af9先行整合，未推送/发布。历史模型分派阻塞已由本聊天subagent交付接替。

- 2026-10-19追加清理：SP-209～213五个已合并worktree及本地分支普通删除；309份原始证据复制并SHA校验，仅保留实际main和原用户WIP。见[清理记录](../spaces/SP-211-reference-adoption-integration/plans/20261019-cleanup.md)。未推送，复用现有治理规则无新增经验。

- 原主目录WIP完整收口：49份文件快照1131b183，补回遗漏历史并修正共享入口及采用状态，保留已验收产品；按用户新授权合入main。见[WIP合并记录](../spaces/SP-211-reference-adoption-integration/plans/20261019-wip-closeout.md)。此前“保留未提交WIP”为清理时快照，已被本次完整集成接替。

- 2026-10-20：[参考日检](../spaces/SP-207-reference-adoption-pipeline/plans/20261020-reference-update-report.md)24完整/9 partial；新增SP-214主屏安全与SP-216 HDC清理归属、主控SP-215/SP-217。工作区与BDD就绪，桌面显式gpt-6.1-sol必要创建仍拒绝；仅新批次待分派，SP-210/SP-212旧交付保持完成。iCTRL HEAD874f528，Release仍v1.98.12。

- 2026-10-21：[参考日检](../spaces/SP-207-reference-adoption-pipeline/plans/20261021-reference-update-report.md)23完整/10 partial；扫描后SP-219候选`51cd20dd`经SP-220主控审查合入本地main `f9399e5e`，focused 5/5、合并后CLI 1509/1509通过。sim-use `42aa9a2` 的Resizable display录制路由已纳入，该历史切片未验真实Simulator；后续录制证据见SP-219，Resize AX/HID仍不支持；显式gpt-6.1-sol create_thread仍模型校验失败，thread ID保持null。

- 2026-10-21 主目录收口：旧 WIP `3ebb29fd` 已经 `d642e80c` 正式合入 main，原 TritonKit 目录切回 main；旧分支与 main-integrated 临时 worktree 清理，ignored 证据整体归档。见[收口记录](../spaces/SP-211-reference-adoption-integration/plans/20261021-main-checkout-closeout.md)。

- 2026-10-28 #214 只读调查：现存两处 `.triton/DerivedData` 候选约1.95 GiB分配块，跨根相同内容164.808 MiB，属于不同项目；原大目录仍待定位。分配块/摘要重复均不是可回收独占空间；用户后续明确授权后已人工删除这两处现存缓存，父目录保留，原大目录调查仍未完成。详见[SP-240现场调查](../spaces/SP-240-issue-214-deriveddata-ownership/plans/20261028-cache-investigation.md)。

- 2026-10-28 PR #234 已合并（`d52d62fd`），#214 复查保持 OPEN；原大目录/创建调用/实际可回收空间仍待证据，详见 [SP-240](../spaces/SP-240-issue-214-deriveddata-ownership/README.md)。

- 2026-10-28 #214 历史溯源新增H1/H2候选：有双层目录历史索引及实际不同derived-data目的地调用；仍缺原12.13/6.53 GB路径映射，不能认定原现场。#214保持OPEN。见[溯源记录](../spaces/SP-240-issue-214-deriveddata-ownership/plans/20261028-history-trace.md)。

- 2026-10-28 PR #235 已合并（`5d0bba7b`），历史溯源已归档，#214复查OPEN；H1/H2与原18.66 GB的关联仍未证实，未查明项全部保留。见[SP-240](../spaces/SP-240-issue-214-deriveddata-ownership/README.md)。

- 2026-10-30：[SP248 / #238](../spaces/SP-248-issue-238-arkweb-transport/plans/20261030-merged-validation.md) 与 [SP249 / #237](../spaces/SP-249-issue-237-webview-snapshot/plans/20261030-merged-validation.md) 已经 PR #239 / #240 合入远端 main；精确候选 CI 通过，组合 root 404 项 / 64 suites、CLI Release 和标准 CocoaPods lint 通过。未发布，真实 ArkWeb / iOS 原 App 验收待续，两个 issue 保持 OPEN。主目录其他提交与 WIP 保留，自动任务持续执行开发到 CI 通过后合并 main，不重复等待授权。
