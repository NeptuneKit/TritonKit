# 参考项目追踪与自动采用流程

当前授权：2026-10-16 用户要求后续评估可纳入项直接进入开发，随后将范围从 iCTRL 扩大到所有参考项目。流程事实源为 [SP-207](../spaces/SP-207-reference-adoption-pipeline/README.md)，覆盖当前已登记24个参考仓库与9个研究候选，以及后续正式登记项目；具体仓库、别名与历史基线见 [参考登记](../spaces/SP-207-reference-adoption-pipeline/plans/reference-state.json)。候选不等于已采用。

## 默认执行

官方上游增量读取 → 当前main源码/测试/已交付差距评估 → 保存采用理由、BDD和文件面 → 独立space/worktree与执行会话开发验证 → 主控审查、修复冲突与联合验证 → 必要本地提交、本地main合并。可纳入且属于现有产品范围的变更无需逐项再次确认。现有明确授权持续有效，历史报告“不自动采用”只代表当时权限，不再作为当前阻断条件。

## 自动推进、验收、合并与清理闭环

当一个采用切片进入开发后，自动流程按以下阶段推进，并分别记录状态：读取、评估、分派、实现、验证、合并、清理。子会话完成只产生候选证据，不直接改变 `main` 状态。

1. **隔离开发**：为每个 issue/机制使用独立 `SP-<三位序号>-<topic>`、branch 和 worktree；明确执行会话与主控会话的文件面，冻结后再交接。共享副作用串行执行，禁止 `git stash`，不得把其他 WIP 混入候选。
2. **候选验收**：主控必须核对实际 diff、候选 SHA、BDD 场景、focused 测试、受影响层完整测试和错误/unknown 语义；真实设备、签名、DDI、跨进程竞态或发布验收若未执行，单独记录为边界，不用离线绿色替代。
3. **合并前检查**：在实际 `main` worktree 中确认干净状态，使用 `git merge-tree --write-tree main <candidate>` 预检。多个候选按顺序合并；同一文档发生 add/add 冲突时保留已验证实现，并把最新验收事实合并到主线索引/space README，不能整分支回灌历史 WIP。
4. **合并后门禁**：合并后重跑受影响的完整测试、根包测试（适用时）、`docs-linhay/scripts/verify.sh --ci-docs`、`docs-linhay/scripts/check-docs.sh`、`git diff --check` 和适用的 local/release/smoke 门禁。只有门禁与主控验收都通过，采用登记才可标记 `local_merged`。
5. **资料回写**：同步 space README、`spaces/INDEX.md`、`spaces/README.md`、SP-207 `adoption-state.json`、正式技术文档和当日 memory；写明实现 SHA、合并 SHA、测试数量、跳过项、未执行边界和远端操作状态。
6. **清理**：门禁通过后先把需要保留的 ignored build 日志、未跟踪证据和继承文档复制到带 manifest/hash 的本地归档，再正常移除已合并 worktree，最后用 `git branch -d` 删除已合并分支。原工作区有用户 WIP 时保持原样，不能用清理动作覆盖或重置。 收尾还须核对原项目目录的分支：用户要求回归主线且目录干净时，先整合源分支独有提交并确认祖先关系，再解除临时 worktree 对 main 的占用，将原目录切回 main。归档 ignored 证据后正常移除临时 worktree，删除已合并分支；不能只因 main-integrated 已同步就宣称原目录收口完成。

自动流程只做本地合并和本地清理；push、tag、release、依赖安装、第三方代码、设备动作、签名和 DDI 仍需单独明确授权。状态通知必须区分“实现完成”“验收通过”“已合并”“已清理”，不能把其中一个阶段冒充全部完成。

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

## 当前交付状态（2026-10-21）

SP-203～205、[SP-210](../spaces/SP-210-simulator-ax-geometry/README.md)、[SP-212](../spaces/SP-212-mobile-mcp-android-contracts/README.md) 与 SP-214～SP-219 均已完成本地合并；SP-211/SP-213 与 [SP-220](../spaces/SP-220-simulator-resizable-integration/README.md) 主控验收均有独立证据。这些已交付项无需重试。历史交付记录以当时 `f82872e2fa457431ee7cbc7df2bafecea7ca6f1c` 为基线；当前 main 已随 `v0.2.32` 推送并发布，SP-219 的真实 Simulator/Xcode 和 AX/HID transport 仍未执行。

10月17～19日桌面 `create_thread` 拒绝显式模型参数的记录是历史事实；其后指定 `gpt-6.1-sol` 的执行 subagent 已实际交付，当前聊天完成主控验收和本地合并。桌面 thread ID 仍为 null，不能用 agent 名替造 thread ID，也不能把旧失败继续列为旧开发 blocker。

2026-10-20 新批次：[SP-214](../spaces/SP-214-simulator-display-safety/README.md) 主屏路由安全与 [SP-216](../spaces/SP-216-harmony-forward-cleanup/README.md) HDC 清理归属已完成本地交付。2026-10-21 的 SP-219/SP-220 也已完成；桌面 `create_thread` 对显式 `gpt-6.1-sol` 仍返回模型校验失败，thread ID 保持 null，由当前主控在已授权范围内完成候选审查与本地合并，未使用回退模型。具体证据见 [2026-10-21 主控验证](../spaces/SP-220-simulator-resizable-integration/plans/validation-20261021.md)。

## 2026-10-18 完整性纠正

第二轮全量检查发现，上一轮若把许可证 404、Release API 403 或固定二进制来源未闭合的结果标成“完整”，会让检查点看似成功但无法支持复核。本轮统一将这些结果记为 partial，保留旧 SHA/tag，不推进检查点；只有官方 HEAD、非 draft Release 分页、许可证全文和相关增量证据闭合后才可推进。SKProcessRunner 的历史标签已在 [20261018 日报](../spaces/SP-207-reference-adoption-pipeline/plans/20261018-reference-update-report.md) 中纠正。


## 2026-10-21 参考采用更新

- [全量日检](../spaces/SP-207-reference-adoption-pipeline/plans/20261021-reference-update-report.md)完成33仓官方只读查询：23完整、10 partial；Baguette、sim-use、device-hub-ios、Revyl CLI相对昨日有变化。iCTRL仍由SP-193独立维护且无变化。
- sim-use `42aa9a2` 将Xcode 27 Resize Mode的`Resizable` display身份、前台应用路由和动作边界写实；SP-214提供未知拓扑拒绝底座，SP-219补齐已确认 display identity 的录制路由，候选 `51cd20dd` 已由 SP-220 审查并合入 `f9399e5e`。AX/HID/真实 Simulator transport 仍保持边界。
- 会话创建仍必须显式`gpt-6.1-sol`；SP-219/SP-220 的桌面接口校验失败保留为事实，未记录虚假thread，当前主控按授权完成了离线验证与本地合并。
