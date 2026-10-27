# iCTRL 长期参考与更新追踪

- 最近检查：2026-10-26，[SP-193记录](../spaces/SP-193-ictrl-reference-tracking/plans/20261026-reference-review.md)。本轮官方身份、全部Release分页、固定许可全文/hash读取正常，HEAD `874f528`、Release `v1.98.12`、Apache-2.0/hash未变；无新故障或iCTRL采用。10月23日首次连接失败与有界恢复保留为历史记录，成功点仍只由SP-193维护。

- 上游：[OpenMinis/iCTRL](https://github.com/OpenMinis/iCTRL)。
- 决策：正式列为 TritonKit 长期参考项目，自 2026-10-14 起持续追踪。
- 追踪事实源：[SP-193](../spaces/SP-193-ictrl-reference-tracking/README.md)；检查点：[upstream-state.json](../spaces/SP-193-ictrl-reference-tracking/plans/upstream-state.json)。
- 已有借鉴工作：[SP-192](../spaces/SP-192-ictrl-adoption-feasibility/README.md) 与 [技术接入边界](./20261014-ictrl-agent-feedback-adoption.md)。

## 上游基线

2026-10-14 通过 GitHub 官方仓库页面及 API 核对：默认分支 `main`，HEAD [99dbfecdb39836ba26a0b2b0dcfde90f705a6835](https://github.com/OpenMinis/iCTRL/commit/99dbfecdb39836ba26a0b2b0dcfde90f705a6835)，最新稳定 Release [v1.97.1](https://github.com/OpenMinis/iCTRL/releases/tag/v1.97.1)，2026-10-13 发布；许可证 [Apache-2.0](https://github.com/OpenMinis/iCTRL/blob/main/LICENSE)，仓库未归档。

v1.97.1 修复 host app 的配对文件选择器不能选取 XML plist 的问题；Release notes 明确 Runner 无功能变化。本次与 SP-192 使用相同 SHA，尚无新增机制差异。

## 参考价值与边界

iCTRL 以长期运行的 XCUITest Runner 提供 agent 可发现的 HTTP JSON-RPC 自动化。重点持续比较：

| 上游方向 | TritonKit 关注点 |
| --- | --- |
| live ref、可见性、歧义提示 | SP-192 alias 新鲜度与实时身份校验 |
| 有界 UI snapshot | 跨平台节点、深度、子节点和 deadline 预算 |
| Vision OCR 与动作反馈 | candidateOnly、坐标来源、视觉稳定和业务验证边界 |
| 独立诊断、占用请求、熔断 | unknown 不重放、诊断不等待 UI |
| 自描述 skill/schema、错误 hint | CLI/HTTP 机器可读契约与下一步提示 |
| Runner/DDI、签名与配对安全 | 独立接管路线的兼容条件和安全变化 |

上游性能数字属于其自述，不代表 TritonKit 本地测量。参考登记不引入第三方运行时依赖；不复制私有 XCTest API 到 embedded SDK，不扩展默认远端控制面，不自动采用 Runner/DDI 或签名能力。

## 追踪流程

自动化 `ictrl` 绑定当前聊天，每天北京时间 10:00 查询 GitHub 默认分支、Release 和许可证，与最后成功检查点比较。增量摘要保存到 SP-193 `plans/`，包含旧/新 SHA 和 tag、原始链接、事实、与 SP-192 的关系及可借鉴价值；重大结论同步本档案和每日 memory。摘要成功保存后才更新检查点；读取失败不推进状态。无变化保持安静，有值得借鉴的更新、安全/兼容性变化或首次/变化故障及恢复时通知，重复变化和不变故障去重。2026-10-16 用户已授权评估通过项自动独立立项、创建执行/主控会话、开发验证及必要本地提交/本地 main 合并，无需逐项确认；采用登记与读取检查点分开，具体以 SP-193 当前授权为准。push/tag/release 等仍须另有授权。


## 2026-10-16：v1.98.12 增量与可复用检查

最新核对main@d88bbf0、非draft Release [v1.98.12](https://github.com/OpenMinis/iCTRL/releases/tag/v1.98.12)，较99dbfec/v1.97.1新增27提交、30文件；许可证仍Apache-2.0，仓库未归档。上游基线段保留首次历史记录；当前检查点及[本次报告](../spaces/SP-193-ictrl-reference-tracking/plans/20261016-v1-98-12-update.md)为后续增量依据。

本轮以LAN/AWDL发现、配对和管理为主；SP-192的alias、采集预算、视觉settle、OCR、UI健康五项无新核心算法升级。可复用检查：地址/发现ID不能充当已认证身份；密钥迁移先验证响应；配置先完整预检并区分“已安排重启”和真实就绪；正常只读轮询降噪仍保留失败与统计。后续SP-195已有独立Runner，不将本轮当Runner初次引入。

安全边界：新版本修复配对指纹缺失、设备ID跨源暴露、未认证header诱导配对及mDNS解析边界；仍有未加密屏幕流、公开端点经AWDL暴露、主机名泄露和发现可仿冒风险；源码另保留非nearby路径的开发一次性免审批入口，正常审批规则不代表所有配置均强制人工批准。不得据此自动启用LAN/AWDL、照搬nc权限回退或手写密码学。地址约4秒恢复是上游自述、未本地验证。后续采用独立立项，本次只读研究，无设备操作或产品修改。

## 2026-10-16：采用优先级复核

用户要求评估后，已在 [SP-202](../spaces/SP-202-ictrl-security-assessment/README.md) 对照 `main@dd613a99` 源码与既有测试完成[采用评估和验收规划](../spaces/SP-202-ictrl-security-assessment/plans/20261016-assessment.md)。先前“可复用检查”是上游原则，不等于本地全部缺失：workspace 配置已有完整预检/安全原子替换，Runner 已有 target/USB Serial/token/session/request 绑定，id=0 心跳已静默。

推荐先收敛已有 Bonjour 无条件广播与 SDK 首服务自动连接；该风险承接 SP-129，默认 loopback 不证明没有广播，公开 ID/单候选也不证明身份。后续再做响应日志脱敏/限长和 Runner 本机恶意端口占用强化；文件替换不等于运行态配置事务、回包关联不等于双向认证。AWDL、远端配对管理、权限回退和手写密码学不纳入本期。以上为静态源码评估，未复现攻击、实施修复或操作设备，长期追踪只读边界不变。

## 当前采用授权（2026-10-16 更新）

用户要求“后期评估可以纳入的改动可以直接按照这个流程直接进入开发”。因此后续可纳入项直接走：当前源码差距评估与BDD → 独立space/worktree及开发会话 → 主控复核/联合验证 → 必要本地提交与main合并。此条替代前述历史研究中的“不自动采用”权限说明，不把历史未实施状态改写成已交付。

[SP-193采用边界](../spaces/SP-193-ictrl-reference-tracking/README.md)为流程事实源，[统一采用登记](../spaces/SP-207-reference-adoption-pipeline/plans/adoption-state.json)对任务与会话去重，[流程授权记录](../spaces/SP-193-ictrl-reference-tracking/plans/20261016-adoption-workflow.md)记录本次变更。自动任务沿用原计划；新批次建立/复用主控，不把不相关批次强塞入已完成会话。推送/发布、依赖变更和设备等边界不因采用授权自动开放。

用户随后明确将上述流程从iCTRL扩大到所有参考项目；当前统一事实源见 [SP-207](../spaces/SP-207-reference-adoption-pipeline/README.md) 与 [正式说明](reference-project-adoption-workflow.md)。自动任务复用id `ictrl`并扩为“参考项目更新与采用推进”，iCTRL原检查点保留；历史只读权限记录由本条和当前统一授权接替。


## 2026-10-16：本地采用后的复核

SP-202 的静态建议已由 SP-203/204/205 实现，联合候选由 [SP-206](../spaces/SP-206-ictrl-security-integration/README.md) 审查验证。默认广播/自动发现策略、响应日志元数据白名单、Runner会话持密证明与加密通道分别解决其明确边界；不能继续把这些作为“尚未实施”待办，也不能将它们升级为embedded服务认证、物理设备身份或防透明转发。证据区分冻结候选、真实socket、UIKit spy、SDK编译与实际设备验收；SP-206未改动自动任务；后续监控授权由其独立会话的最新记录决定。


## 2026-10-18：全量流程日检与完整性纠正

SP-207 第二轮全量检查见 [日报](../spaces/SP-207-reference-adoption-pipeline/plans/20261018-reference-update-report.md)：iCTRL 仍无变化；serve-sim 与 Atlantis 保持观察；Baguette、agent/Revyl API 403 和 SKProcessRunner 许可证问题均未推进检查点。本轮特别将 SKProcessRunner 先前过强的“完整”标签纠正为待复核，避免无许可证据形成可复用成功点。

## 2026-10-19：检查恢复与无变化

[SP-193 检查摘要](../spaces/SP-193-ictrl-reference-tracking/plans/20261019-check-summary.json)确认 iCTRL `main@d88bbf0b3a5addead31b4298d605d7ac7a87d6e7`、`v1.98.12` 与 Apache-2.0 许可证 hash 均未变化。首次 `gh api` 因本机 TLS 证书校验失败，随后使用官方 GitHub API 的系统 curl 完整读取 repository、HEAD、Release 分页和固定 HEAD 许可证；失败与恢复分别留有原始证据。未发现新的安全、兼容或 SP-192 机制变化，不重复排期。


## 2026-10-20：认证入口、隐私与RemotePairing

[3提交/9文件增量](https://github.com/OpenMinis/iCTRL/compare/d88bbf0b3a5addead31b4298d605d7ac7a87d6e7...874f528759b1b977971a06cc4a3594d169eb77b9)完成有界全文审阅与blob校验，见[专项报告](../spaces/SP-193-ictrl-reference-tracking/plans/20261020-reference-review.md)。上游stop深链要求解锁确认、日志出口改脱敏、whoami删除name、配对文件预检改用实际RemotePairing parser。SP-204/205已覆盖Triton当前日志/Runner入口的对应原则；SP-192五项机制无新增算法变化，SP-196/200不因此扩展DDI或通知面。callback scheme过滤并非调用方身份认证，未知动作不得照搬失败后重放。

HEAD874f528源码称1.98.13，但GitHub最新非draft Release仍[v1.98.12](https://github.com/OpenMinis/iCTRL/releases/tag/v1.98.12)，不可报告新版本已发布。Apache-2.0全文hash未变。未运行上游或验证实际挂载兼容，本轮无新采用项。

## 2026-10-27：v1.98.16与新输入路径评估

[固定增量专项审阅](../spaces/SP-193-ictrl-reference-tracking/plans/20261027-reference-review.md)覆盖12提交/17文本文件，当前HEAD c1e4268859ba858d1579f7b846a56cb40641b7f6、Release v1.98.16，Apache-2.0全文hash不变。连续多点拖动、视频重复帧跳过/后台恢复、键盘可见性与输入失败处理分别对照现有产品；SP-192五机制和SP-203～205安全机制不重复立项。多点host HID接口缺口存在，但需要本机真实触点/拐角/取消验证，不把上游私有XCTest路径或离线fixture当兼容证明，暂观察。未运行设备、上游或性能验证。
