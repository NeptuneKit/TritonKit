# SP-206 — iCTRL 安全改动主控验证与合并

## 授权与状态

- 用户要求：2026-10-16“添加主控会话，负责验证，合并”。
- 状态：主控会话已创建并启动，集成结果待后续验收。
- 范围：接管 SP-203 / SP-204 / SP-205，复核实际候选、整合、修复集成冲突、联合验证，合并到本地 main。授权完成必要的本地候选提交和合并；不自动 push/tag/release。
- 影响层：CLI / HTTP / embedded SDK / 随包 Runner；保持 Web/Wails 只读边界、Debug/Release 隔离和上游监控只读权限。
- 评估依据：[SP-202](../SP-202-ictrl-security-assessment/plans/20261016-assessment.md)。
- 独立集成分支 `feat/SP-206-ictrl-security-integration`，同级 worktree `../TritonKit-worktrees/SP-206-ictrl-security-integration/`；启动时重新核对 main，登记时为 `dd613a994abe45aa14e072c381662a0e3d868f03`。

## 接管执行会话

| 切片 | 会话 | 工作目录 |
| --- | --- | --- |
| [SP-203](../SP-203-ictrl-discovery-hardening/README.md) | `01a14284-df87-7d13-8373-a4d3a56fd470` | `../TritonKit-worktrees/SP-203-ictrl-discovery-hardening/` |
| [SP-204](../SP-204-ictrl-log-privacy/README.md) | `01a14285-3be0-7213-9433-374c139189bd` | `../TritonKit-worktrees/SP-204-ictrl-log-privacy/` |
| [SP-205](../SP-205-ios-runner-auth-hardening/README.md) | `01a14285-3edd-7722-9c46-538e6f6066f4` | `../TritonKit-worktrees/SP-205-ios-runner-auth-hardening/` |

独立会话完成声明仅为线索；主控读取交付文档、候选文件清单/摘要、真实 diff 和验证日志，确认执行会话停止写入后才冻结集成。执行会话为门禁复制的其他 space、索引和文档不算候选文件，不整体覆盖主仓。

## BDD 与验收

- Given 三个切片各自交付，When 主控接收，Then 每个源 worktree、文件面、候选摘要、测试与未测边界都可追溯，未完成项继续处理，不凭总结判完成。
- Given 存在 SP-201 与其他主仓 WIP，When 集成，Then 逐文件合并仅纳入本期候选，保留无关改动，不使用 stash、不重置、不整目录覆盖。
- Given 合并候选，When 联合验证，Then CLI/root/SDK Debug与Release/Runner实际协议与鉴权负例、包资源和本地总门禁按适用范围通过；明确设备运行与发布未验收。
- Given 差异和验证已冻结，When 合入本地 main，Then 串行提交/合并并复核实际 main 候选，不自动推送或发布；同步三个 space、索引与每日 memory。

## 主控边界

主控拥有集成 worktree、三切片的集成修复与共享治理资料收口；执行会话有新写入时重新冻结，不与其并发改同一源码。源码、文档、门禁上下文逐项分类，不把复制的 SP-201 或其他任务 WIP 混进提交。merge 所需本地提交由主控按文件选择，禁止 git add -A。

未发现新的通用经验前不新增 skill/AGENTS 规则；交付前按经验索引复核并更新原权威资料。监控任务、设备/签名/DDI、第三方运行和依赖安装不因设置主控而自动获得授权。

## 主控会话

会话名称：SP-206 安全改动主控验证与合并；thread ID `01a142ac-b6e1-7db1-87ad-e0e10935ae69`，host `local`。已发送完整接管任务，授权协调 SP-203～205 并完成本地验证/提交/合并，不代表目前已合并。

## 联合候选与补证

- 源候选冻结见 [逐文件SHA](plans/20261016-source-freeze.json)，三个源会话确认停止全部写入。
- SP-203 配置矩阵补充：true/false/1/0、大小写、显式flag覆盖环境以及互斥flag组合。
- SP-205 补充真实socket握手/回包共享deadline，以及合法AEAD中错误session/request关联拒绝。
- 验证隔离：使用本worktree scratch；本机自建临时端口，不安装启动设备。无签名通用iOS SDK编译在资源副本中执行，防Xcode写回随包资源。
- SP-201完整文档仅是主仓既有未提交上下文；用户于2026-10-16另行授权仅提交最小登记README，使本期文档编号门禁独立通过。完整实现/设计/截图/验收内容不纳入本期提交。主仓CLAUDE、10-15 memory与SP-201内容不修改。

审查见[联合审查](plans/20261016-review.md)，实测命令/结果/风险见[验证报告](plans/20261016-validation.md)，[机器摘要](plans/20261016-validation-summary.json)。

## 本地集成结果

- 实现与补证提交 `6bfeba80`，候选治理文档 `6d41729a`；main按文件blob登记文档检查点 `2cbd69c8`，避免覆盖共享WIP，再以 `0a246d00` 合并实现分支。
- 合并时主仓新增SP-207授权/索引/memory/ops资料。按用户追加消息保留这些内容，未将其携入本期提交；共享文件逐hunk合并，产品范围仍仅SP-203～205。
- SP-201完整README、设计/验收等WIP保持原字节；仅最小登记进入提交。主仓其余无关WIP逐文件SHA复核保持；未使用stash、reset或目录覆盖。
- 合并后产品文件SHA与联合验证候选一致；main完整CLI和适用门禁复核在`.build/sp206-main-validation/`，全部通过，详见验证报告的“本地main合并后复核”。

经验沉淀已写回原Runner产品协议、iCTRL参考档案及本space；补齐历史候选不足的SDK/Runner/日志隔离反证。无新增AGENTS或skill规则。本地实现/整合完成；发布、安装接替与真实设备/用户验收未执行。

## 2026-10-16 工作区收口

本期产品与收口历史均已合入本地 main，主仓本地总门禁通过；原 worktree 与本地分支已清理，原始证据及历史副本已校验归档。发布、运行接替和用户验收边界不变。详见[本地 worktree 与分支收口](../../dev/20261016-worktree-closeout.md)。
