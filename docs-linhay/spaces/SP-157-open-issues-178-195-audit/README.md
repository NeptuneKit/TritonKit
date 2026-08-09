# SP-157：GitHub 未关闭 issue 全量验证

## 边界

- 目标：验证 2026-08-09 初始快照中的全部未关闭 issue（#178–#195，共 18 条），逐条形成可审计结论。
- 影响层：CLI / HTTP contract、iOS embedded runtime、iOS Simulator host adapter、Xcode workflow、Harmony host adapter 与 DevEco emulator。
- 初始队列事实源：`gh issue list --repo NeptuneKit/TritonKit --state open --limit 100 --json number,title,url,labels,updatedAt,author,assignees,body`。
- 主控工作区：`main` 只读监督；本 space 使用独立 worktree，不读取或修改 #164 的既有 dirty worktree。
- 远端边界：用户已授权本轮提交、合并、push 与按验证结果关闭 issue；评论/关闭仍只针对已合入且证据明确的条目。

## BDD / 验收

### Scenario 1：初始队列可追踪

- Given GitHub 当前存在未关闭 issue
- When 固定 open 列表并读取每条正文与评论
- Then 每条 issue 都有编号、标题、平台、影响层、验收标准和验证状态

### Scenario 2：可本地验证的问题有失败测试或现有证据

- Given issue 能通过源码、fixture、schema 或本机无副作用命令核查
- When 执行 focused test / contract check / Triton-first 只读事实采集
- Then 结论区分仍存在、已覆盖、已修复但未发布、未复现和环境阻塞，不把静态覆盖冒充真实设备成功

### Scenario 3：需要修复的问题保持 issue 隔离

- Given issue 的缺口由证据确认且用户授权实现
- When 建立该 issue 专属 space / branch / worktree
- Then 失败测试、最小修复、focused/full 门禁、文档/memory 与 issue 证据单独收口，不混入其他 issue

### Scenario 4：队列收口重新以线上状态为准

- Given 一轮验证或修复完成
- When 重新执行 open issue 查询
- Then 新出现的 issue 进入新队列，不按初始快照误判清零；未获关闭授权的 issue 保持 open

## 初始队列

| Issue | 主题 | 初始验证状态 |
| --- | --- | --- |
| #178–#186 | iOS Simulator / embedded runtime / host proxy | 待审计 |
| #187–#194 | Harmony host / DevEco emulator | 待审计 |
| #195 | iOS real-device Xcode readiness / DDI | 待审计 |

详细逐条记录写入 `plans/`，真实私有项目、设备标识、凭据、绝对路径和未脱敏日志不进入公开 issue 或 space。

## 验证收口

- 逐条矩阵：[plans/verification-matrix.md](./plans/verification-matrix.md)
- 12 条已在本 worktree 完成本地窄修复：#179、#181、#182、#185、#187–#194。
- 3 条完成安全收口但仍保留能力边界：#178、#183、#186。
- 2 条已有静态覆盖但受 live 环境限制：#180、#184。
- #195 的可执行 DDI recovery 已拆到 SP-159；没有物理 iOS 设备时仍不宣称真实 readiness 已完成。
- 中途线上复查发现 #196，随后在 push/CI 期间新增 #197；两者分别由 SP-158 与 SP-160 建立独立边界并纳入同一轮串行收口，不按初始快照误关。
- 独立 worktree 已获授权进入串行提交、冲突预检、main 集成、push 和 issue 收口流程。

## 最终收口

- SP-157 的 #178–#194 修复/安全边界、SP-159 的 #195 DDI recovery、SP-158 的 #196 archive/export 和 SP-160 的 #197 Harmony wait budget 均已进入主线 `e77c72b7`。
- 主线本地 `docs-linhay/scripts/verify.sh --local` 全量通过；根包 239/239、Release CLI、Harmony/iOS smoke、iOS Simulator build、docs 160/160 和 whitespace gate 均通过。
- 主线 CI [31301092517](https://github.com/NeptuneKit/TritonKit/actions/runs/31301092517) 全绿；GitHub API 最终 open issue 查询返回空数组，#178–#197 共 20 条均已发布脱敏验证评论并关闭。
- 真实物理 iOS DDI/tunnel、私有 Xcode 签名/IPA 安装、真实 Harmony HDC/ArkUI smoke 仍是明确风险；#164 dirty worktree 未读取、未修改。

## 停止条件

- 每条初始 issue 有结论、证据、下一步和剩余风险。
- 可运行的本地 focused/full 验证已完成，不能运行的命令有具体环境 blocker。
- 若产生实现变更，每条 issue 独立 worktree，且主控复核 diff、测试、docs/memory 后再决定是否进入集成。
- 远端 issue 关闭前必须确认对应实现已进入 main、主线门禁通过且 push 成功；真实设备或签名依赖仍只记录为风险，不伪装为实机成功。
