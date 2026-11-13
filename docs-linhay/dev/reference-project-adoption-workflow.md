# 参考项目追踪与自动采用流程

当前授权：2026-10-16 用户要求后续评估可纳入项直接进入开发，随后将范围从 iCTRL 扩大到所有参考项目。流程事实源为 [SP-207](../spaces/SP-207-reference-adoption-pipeline/README.md)，覆盖当前已登记25个参考仓库与9个研究候选（SP279正式参考Pinky于11月11日补齐SP207漏登），以及后续正式登记项目；具体仓库、别名与历史基线见 [参考登记](../spaces/SP-207-reference-adoption-pipeline/plans/reference-state.json)。候选不等于已采用。

## 默认执行

2026-11-11 用户裁决：后续全部在当前 main 开发，不推荐或创建 branch/worktree；下方带日期的旧分支/合并记录仅保留历史事实。

官方上游增量读取 → 当前main源码/测试/已交付差距评估 → 保存采用理由、BDD和文件面 → 在当前main串行开发验证 → 主控复核、联合验证、必要本地提交。可纳入且属于现有产品范围的变更无需逐项再次确认。现有明确授权持续有效，历史报告“不自动采用”只代表当时权限，不再作为当前阻断条件。

2026-10-22用户再次明确“开发验证完成要合并到 main 分支”：开发验证通过后继续完成必要本地提交、合并与合并后门禁，不能停在候选分支或子会话完成状态；不逐项重问合并授权。仅有巡检报告或观察候选不算开发交付，未通过验收的候选继续修复，不提前合并。

2026-10-27用户明确由本主控负责自己开启的会话任务：实现、验证、测试、必要本地提交、合入本地main、清理及关闭会话。该责任持续适用于后续分派，不能把收尾留给用户逐个跟进；失败继续修复，具体阻塞如实记录。关闭指归档已验收且已合并的执行/批次主控聊天，保留当前长期追踪聊天；不等于关闭GitHub issue或新增远端授权。

## 自动推进、验收与 main 提交闭环

当一个采用切片进入开发后，自动流程按以下阶段推进，并分别记录状态：读取、评估、分派、实现、验证、main提交、收口。子会话完成只产生候选证据，不直接改变 `main` 状态。

1. **main 开发**：为每个 issue/机制建立或复用独立 Space，明确文件面、BDD 和验收边界；实现、测试和资料回写直接在当前 `main` 串行完成，不创建 branch/worktree，不混入其他 WIP。
2. **候选验收**：主控必须核对实际 diff、候选 SHA、BDD 场景、focused 测试、受影响层完整测试和错误/unknown 语义；真实设备、签名、DDI、跨进程竞态或发布验收若未执行，单独记录为边界，不用离线绿色替代。
3. **main 提交前检查**：在当前 `main` worktree 中确认目标文件面和 WIP 边界，核对实际 diff、BDD、测试证据和错误语义；不整分支回灌历史 WIP。同一文档的冲突通过当前文件逐段裁决。
4. **main 提交后门禁**：提交后重跑受影响的完整测试、根包测试（适用时）、`docs-linhay/scripts/verify.sh --ci-docs`、`docs-linhay/scripts/check-docs.sh`、`git diff --check` 和适用的 local/release/smoke 门禁。只有门禁与主控验收都通过，采用登记才可标记 `local_merged`。
5. **资料回写**：同步 space README、`spaces/INDEX.md`、`spaces/README.md`、SP-207 `adoption-state.json`、正式技术文档和当日 memory；写明实现 SHA、合并 SHA、测试数量、跳过项、未执行边界和远端操作状态。
6. **收口**：门禁通过后先把需要保留的 ignored build 日志、未跟踪证据和继承文档复制到带 manifest/hash 的本地归档；确认 `main` 工作区只包含本次文件面后提交。原工作区有用户 WIP 时保持原样，不能用清理动作覆盖或重置。

7. **会话关闭**：核对采用登记中的真实thread ID、最后执行状态、实际main祖先关系及验收/证据归档；确认任务没有剩余工作后，用会话归档工具关闭该批执行与主控聊天，记录工具成功结果。已归档可幂等核对，失败保留待关闭；不因聊天idle或子会话声称完成而提前关闭。当前长期追踪聊天保持可用。

自动流程只做 main 本地开发、提交、资料收口及已交付会话归档；push、tag、release、依赖安装、第三方代码、设备动作、签名和 DDI 仍需单独明确授权。状态通知必须区分“实现完成”“验收通过”“已提交”“已收口”，不能把其中一个阶段冒充全部完成。

每日任务复用id `ictrl`，名称“参考项目更新与采用推进”，保持ACTIVE与北京时间10:00。当前绑定接管聊天`01a19a4a-50e2-7731-b8fa-880efb954eb5`，2026-11-11重读配置确认；`01a18a91-f44e-7fd0-8e4b-c891b44377e0`为前任，不新建重叠任务。当前prompt已同步main串行开发、arm64-only和SwiftPM-only规则，旧批次branch/worktree步骤只保留历史。现有iCTRL检查点仍由SP-193管理，其他仓库从SP-194/SP-199历史快照开始，首次完整读取后才建立对应成功点。

2026-10-27闭环已执行：[33仓日检](../spaces/SP-207-reference-adoption-pipeline/plans/20261027-reference-update-report.md)24完整/9 partial，6仓更新；SP-225/226 Files Recents只读诊断完成开发、独立验收、main合并607cdf1c、合后完整CLI与docs、53份证据归档以及两个会话关闭。当前16条采用均已合main；首次既有夹具失败原因未知并保留证据，多点HID和软件键盘真实兼容前置继续观察。详见[收口](../spaces/SP-226-files-recents-integration/plans/20261027-main-closeout.md)。

2026-10-30用户要求新聊天接管：原`ictrl`已迁入`01a18a91-f44e-7fd0-8e4b-c891b44377e0`，原聊天`01a139bf-ab78-7783-b37a-ed336be2ef38`保留历史；每日北京时间10:00与完整任务prompt不变。配置已重读确认，见[接管记录](../spaces/SP-207-reference-adoption-pipeline/plans/20261030-controller-takeover.md)。

2026-10-31 [SP252/253](../spaces/SP-253-detached-log-integration/plans/20261031-main-closeout.md)按既有授权完成detached日志安全修复、独立验收、合main56ef7719、合后CLI162+1665与适用local及清理/执行聊天归档。当前17条采用均在main。首次静态审查发现测试flags/FIFO前置不足，补强后重跑旧逻辑red；真实复现是竞争者叶子被替换，不是链接目标写穿。

当前交付与读取：见[2026-11-11日报](../spaces/SP-207-reference-adoption-pipeline/plans/20261111-reference-update-report.md)。34仓21完整/13 partial，既有18条均可达main；SP283/284实现14574a7b与提交后验证分开登记。历史原始证据455份当前缺失，unknown原因，不能沿用旧available断言。

## 新会话模型

2026-10-16用户指定：今后本项目由agent创建的新会话（执行和主控）锁定为 `gpt-6.1-sol`。调用 `create_thread` 必须显式传入 `model: "gpt-6.1-sol"`，后续主控分派同样遵守；不省略后依赖默认模型，不使用latest别名，不自动回退其他模型。模型不可用则记录创建失败/待重试并报告，不冒充创建成功。本次不切换既有会话，也不改变推理强度。

## 证据与去重

- [上游登记与检查点](../spaces/SP-207-reference-adoption-pipeline/plans/reference-state.json)逐仓库独立更新；完整读取和摘要保存成功后原子推进。截断/失败不推进，不能伪装无变化；无旧SHA先建基线。
- [采用登记](../spaces/SP-207-reference-adoption-pipeline/plans/adoption-state.json)与读取状态分开，按仓库+机制以及跨仓库本地需求去重；先核对SP-192/196/200及各space当前实现，不能把旧差距重复排期。
- 开始对照前同时核对 `git branch --show-current`、`git rev-parse main` 和 `git status --short --branch`。当前产品评估固定绑定实际 `main` blob；资料、索引和历史按 main 裁决，不整分支回灌旧产品。
- 会话创建成功才记录真实ID，部分失败先补缺项；建立实现/主控空间时串行登记编号。执行会话停止写入后冻结候选，不整目录复制其门禁上下文；测试绑定联合候选，主控复核后才能合并。
- 长期原始证据不能仅保存在`.build`/scratch，也不能挂在会整体清理的worktree根下。当前使用仓外`TritonKit-archives/reference-monitor/YYYYMMDD/`，检查点提交前验证实际文件size/hash，并在正式plans登记manifest和复核时间。`TritonKit-worktrees/archives/`为历史位置，不再作为新归档目标。目录存在、metadata数量或历史hash通过都不等于当前可恢复；清理前核对实际载荷与恢复方式。历史读取成功和当前raw evidence可用性分别记录；缺失先记unknown原因，固定SHA重取标恢复副本，不伪造旧API响应或日志。见[11月11日保管复核](../spaces/SP-207-reference-adoption-pipeline/plans/20261111-evidence-custody.json)和[10月31日保管缺口](../spaces/SP-207-reference-adoption-pipeline/plans/20261031-evidence-custody.md)。
- 恢复旧partial时逐项核对本轮许可证/文本/来源证据，仅清除已闭合缺口；不能把`prior.complete`作为永远拒绝恢复的条件。复用日检脚本前排除硬编码历史版本、日期、待办数量与旧main断言，先保存候选摘要再提交检查点，实际通知与成功点分别记录。 汇总器必须强校验review的repository、base/head与actual main，不能以当前main作为缺字段默认值。跨SP193/SP207检查点分别原子写入前保存带before/after的持久publication记录；中断后仅接受精确before或after并先验manifest，再补写未完成项，不能为重跑回退成功点。
- 通知去重另存 `last_notified_observation`（HEAD/tag/许可hash/覆盖状态指纹），不推进未完成仓库的成功点。相同未完成增量或模型校验故障不重复通知；覆盖恢复或故障变化再报告。采用登记的 `last_dispatch_failure_notice` 同样不代表会话创建成功。
- 上游取证在请求 contents/blob 前检查路径用途和文本白名单；二进制、身份目录、密钥和证书只记录路径/来源缺口，不自动获取内容。仅靠扩展名黑名单会漏掉无扩展名二进制和身份材料。过滤失误须停止相应读取、移除意外内容、禁用原脚本并复核残留；不得因此把未审来源标为完整。许可证按固定 SHA 全文与 hash 核对，API NOASSERTION和人工识别分别保留，不沿用历史误记。
- 新批次创建或复用范围适合的主控。现有SP-206负责SP-203～205，不因此无限扩张；后续若复用需明确更新其有限范围。允许主控协调本批次执行会话，但不授权外部消息。

## 边界与通知

该授权包括本项目评估、分派、开发验证、必要本地提交与本地合并；push/tag/release、依赖安装/升级、第三方代码执行、设备/签名/DDI、扩大远端/云等产品面需对应明确授权。许可与代码复用条件在采用评估中核实，不能将一个仓库许可证套用到其外部分发依赖。保留CLI/HTTP契约优先与Web只读边界。

有价值更新、新采用批次、重要交付/阻塞、读取故障变化或恢复时简短中文通知并附原始链接；未变化且无待推进采用任务则静默。上游性能、测试数量与成功率如未在本地证明，明确标注未经验证。未来正式登记的参考进入清单，偶然链接或clone目录不自动纳入。

## 2026-10-28 检查记录（历史基线）

[日检](../spaces/SP-207-reference-adoption-pipeline/plans/20261028-reference-update-report.md)以main `a0d187ac`评估33仓：24完整/9 partial，Baguette、mirroir、Revyl三仓变化，无新采用切片。mirroir的compiled技能链、Revyl云端导入/认证与Baguette折叠3D不直接映射本机缺口。16条采用合并均可达main，已随独立SP-227的v0.2.34发布；历史v0.2.33不含SP-221/223/225的记录仅代表当时版本。累计许可/二进制来源缺口继续保留，已关闭会话不重开。

## 历史关系

- [SP-194参考报告](../spaces/SP-194-reference-project-updates/README.md)及[2026-10-14快照](20261014-reference-project-updates.md)：保留当时23+9数量和证据；后新增Mobile MCP使当前登记为33仓。
- [SP-193 iCTRL专项](../spaces/SP-193-ictrl-reference-tracking/README.md)：保留原成功检查点、报告与更严格的完整性规则，采用入口统一到本流程。
- [SP-206主控](../spaces/SP-206-ictrl-security-integration/README.md)：当前首批三个切片的验证与本地合并，不代表这次扩大流程已经执行所有参考更新或产生新产品交付。

## 历史交付状态（2026-10-26）

用户要求继续后，[补查](../spaces/SP-207-reference-adoption-pipeline/plans/20261026-partial-recovery.md)闭合sim-use/device-hub-ios两仓文本缺口，当前合并视图24完整/9 partial（仅2仓重查，31仓沿用日检）。原函数自有probe复现退出后继承pipe超预算等待；SP-223/SP-224已创建显式gpt-6.1-sol执行/主控会话，已验收合本地main9fbda1d5，独立/合后完整CLI与适用local通过，源worktree/branch已清理。既有14条采用记录不改。

2026-10-26 [日检](../spaces/SP-207-reference-adoption-pipeline/plans/20261026-reference-update-report.md)22完整/11 partial，simslim/Revyl CLI两仓HEAD变化，Release与许可不变。新SP-221仅为同目标print-disabled明确launchd暂态提供有界只读重试；SP-222有限主控审查真实nonZeroExit throw、次数/总预算、取消和拒绝语义，不重放mutation。执行/主控均已通过create_thread显式gpt-6.1-sol创建真实会话（见分派记录），不将历史模型失败当当前阻塞。旧13条采用保持已合main，新批验证与合并分别记录；SP-221候选eb9539f4经SP-222独立验收后合actualmain a0eebff0，合后CLI/root/local/docs通过，当前标local_merged。真实恢复未执行，未push/tag/release。为原main干净，当前聊天自身跟踪资料可作本批必要的独立本地归档提交，与产品候选分开；不包含远端写入。

2026-10-25 [日检](../spaces/SP-207-reference-adoption-pipeline/plans/20261025-reference-update-report.md)对照未变的 `main@24e7d0f2`：22完整/11 partial，Revyl CLI、Maestro、Mobile MCP共3仓HEAD变化，新增v0.1.188/1.0.13，无新增采用项。云上传优先级、托管Web说明、MCP依赖与工具描述不能推定本地缺口；Mobile MCP描述门控此前已实现，不把changelog提及当成本次代码新增。13条采用状态不变，已合入main；不重复分派旧完成项。

2026-10-24 [日检](../spaces/SP-207-reference-adoption-pipeline/plans/20261024-reference-update-report.md)以原目录 `main@24e7d0f2` 为基线：22完整/11 partial，5仓HEAD变化、Release/许可hash不变，无新采用项。录制预算、OCR/空帧、安装状态、UTF-8目录和托管fold schema分别对照实际入口，不把上游通用优化推成本地缺陷。当前网络读取正常，昨日故障不重复通知。

2026-10-23 [日检](../spaces/SP-207-reference-adoption-pipeline/plans/20261023-reference-update-report.md)以原目录 `main@409670ef` 为基线：22完整/11 partial，Maestro、MobileBuildMCP、Revyl CLI共3仓变化；实际锁/资源关闭、工具链与遥测路径对照后无新增本地缺口。13仓首次TLS/连接失败经一次安全重试恢复，原11个许可/源码缺口未恢复；不关闭TLS或将某组故障外推全部仓库。13条既有采用登记均已在main，跟踪资料保留未提交状态，不新建开发批次。

SP-203～205、[SP-210](../spaces/SP-210-simulator-ax-geometry/README.md)、[SP-212](../spaces/SP-212-mobile-mcp-android-contracts/README.md) 与 SP-214～SP-219 均已完成本地合并；SP-211/SP-213 与 [SP-220](../spaces/SP-220-simulator-resizable-integration/README.md) 主控验收均有独立证据。这些已交付项无需重试。历史交付记录以当时 `f82872e2fa457431ee7cbc7df2bafecea7ca6f1c` 为基线；当前 `main@24e7d0f2` 已纳入真实displays修复并完成 `v0.2.33` 独立发布。2026-10-24 [SP-218联合报告](../spaces/SP-218-issue-222-device-hub-input/plans/20261024-live-acceptance-closeout.md)与[SP-219录制报告](../spaces/SP-219-simulator-resizable-routing/plans/20261024-live-recording-validation.md)已证明本机Xcode27.1/iOS27.0专用Simulator的普通native HID/占用拒绝恢复及普通→Resize→普通录制；替代此前真实验收未执行的当前断言。Resize AX/HID仍unsupported，其他工具链、全面AX和用户项目不外推。本监控仅核对已有证据，未执行设备。

10月17～19日桌面 `create_thread` 拒绝显式模型参数的记录是历史事实；其后指定 `gpt-6.1-sol` 的执行 subagent 已实际交付，当前聊天完成主控验收和本地合并。桌面 thread ID 仍为 null，不能用 agent 名替造 thread ID，也不能把旧失败继续列为旧开发 blocker。

2026-10-22 [全量日检](../spaces/SP-207-reference-adoption-pipeline/plans/20261022-reference-update-report.md)以原目录 `main@409670ef` 为基线：22完整、11 partial，4仓有新变化，无新增采用缺口。sim-use v0.16.0 的 Homebrew 修复要求已公证产物，当前 Triton 无该签名前提，保留观察；SP-219许可证误记已按固定全文更正为 Apache-2.0。13条既有采用记录均有主线祖先证据，不重试旧分派、不扩大签名/设备范围。

2026-10-20 新批次：[SP-214](../spaces/SP-214-simulator-display-safety/README.md) 主屏路由安全与 [SP-216](../spaces/SP-216-harmony-forward-cleanup/README.md) HDC 清理归属已完成本地交付。2026-10-21 的 SP-219/SP-220 也已完成；桌面 `create_thread` 对显式 `gpt-6.1-sol` 仍返回模型校验失败，thread ID 保持 null，由当前主控在已授权范围内完成候选审查与本地合并，未使用回退模型。具体证据见 [2026-10-21 主控验证](../spaces/SP-220-simulator-resizable-integration/plans/validation-20261021.md)。

## 2026-10-18 完整性纠正

第二轮全量检查发现，上一轮若把许可证 404、Release API 403 或固定二进制来源未闭合的结果标成“完整”，会让检查点看似成功但无法支持复核。本轮统一将这些结果记为 partial，保留旧 SHA/tag，不推进检查点；只有官方 HEAD、非 draft Release 分页、许可证全文和相关增量证据闭合后才可推进。SKProcessRunner 的历史标签已在 [20261018 日报](../spaces/SP-207-reference-adoption-pipeline/plans/20261018-reference-update-report.md) 中纠正。


## 2026-10-21 参考采用更新

- [全量日检](../spaces/SP-207-reference-adoption-pipeline/plans/20261021-reference-update-report.md)完成33仓官方只读查询：23完整、10 partial；Baguette、sim-use、device-hub-ios、Revyl CLI相对昨日有变化。iCTRL仍由SP-193独立维护且无变化。
- sim-use `42aa9a2` 将Xcode 27 Resize Mode的`Resizable` display身份、前台应用路由和动作边界写实；SP-214提供未知拓扑拒绝底座，SP-219补齐已确认 display identity 的录制路由，候选 `51cd20dd` 已由 SP-220 审查并合入 `f9399e5e`。AX/HID/真实 Simulator transport 仍保持边界。
- 会话创建仍必须显式`gpt-6.1-sol`；SP-219/SP-220 的桌面接口校验失败保留为事实，未记录虚假thread，当前主控按授权完成了离线验证与本地合并。

## 2026-11-12 main串行采用核对

34仓日检中新增SP285：以mobile-mcp变化为线索，先追实际消费者和AOSP固定输出合同，再用失败测试证明本地有效尺寸选择缺陷；main c4c5f014仅提交精确文件/共享文档段落。提交后完整CLI与适用local通过，原SP281/SP279 WIP保留。读取完整性和采用状态分开，Baguette/Mirroir候选保持revise-first，不因已分派审查自动升级采用。见[当日日报](../spaces/SP-207-reference-adoption-pipeline/plans/20261112-reference-update-report.md)。

## 2026-11-13 原始数据职责复核

参考采用以SP286及当前AGENTS为准：不照搬上游按业务字段/内容判敏感、删原件或禁止输入的策略。Baguette昨日候选中的secure拒绝/默认不返回值仅作历史，当前改为输入提交与同对象读回独立；系统不可读报告verification unavailable，显式转换才改变表示，不编造成功、不重放。Mirroir音频转写只能作为派生产物候选，静音阈值不是“没有播放”的事实证明，模型下载与音频新产品范围另定。技术身份、访问权限、预算和自身协议凭据边界保持。
