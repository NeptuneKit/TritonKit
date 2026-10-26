# SP-221/SP-222 历史审查与修正

本文保存2026-10-26开发、审查及交接时的历史事实，不构成当前待办。当前完成状态以[主线验收与清理](20261026-main-merge.md)为准。整理前原README全文可从 `8fcd856f` 的Git对象及本机40份证据归档中复查；不修改这些快照、原日志、红测试或其hash。

## 基线与工作区交接

产品基线 `24e7d0f21017c8ca7104b6f8e3912fc2c44be892`：readOverrides仅查询一次，runner非零退出抛HostCommandRunError.nonZeroExit，返回值循环会漏掉生产错误路径。初始reader仅拒绝stdout截断，stderr截断覆盖缺失。

执行thread `01a175fc-c9c4-7053-b91e-74c209d3f0ca`、主控thread `01a175fd-5c91-7b52-bc7c-683468efff9f` 均显式gpt-6.1-sol创建成功；旧模型校验失败未延续为本批阻塞。App托管worktree正常迁移到同级SP-221/SP-222，保护原WIP；执行与主控分离文件面、串行使用Swift时段，禁止stash。最初setup阶段focused构建中止exit130，不计为红测试。

## 审查发现与关闭证据

| 历史发现 | 原因与修正 | 关闭证据 |
| --- | --- | --- |
| 基线只读暂态失败；stderr截断未拒绝 | 新测试先对精确旧生产blob运行，出现真实断言失败，再实现局部重试 | [红证据](../../SP-221-simulator-resource-read-retry/plans/20261026-red-evidence.md)：10项、3失败（1unexpected）、exit1；不是编译失败或exit130 |
| 暂态substring误识别 | `Unrecognized command: Domain is tearing down`、unsupported复合文本可被旧候选接受；改为完整诊断行白名单、header code一致性，并补返回/typed throw反例 | 最终state文件SHA256 `b7d7bd138da022866d999f7c1e3514a07ae03fdeb63b9ffe54a7b2e249133414` |
| 成功结果未绑定来源 | exit0合法payload也须检查sourceCommand；错误typed command完整匹配issued command，包含timeout/环境 | 错来源成功被拒绝；合法非空stderr仍可成功；[冻结清单](20261026-evidence-manifest.json) |
| 收紧来源后4个旧Mutation用例失败 | fixture固定sourceCommand为fixture；获单文件单行授权后改为hostSourceCommand(command)，不放宽guard或原断言 | 执行focused最终37/37，后续独立及main完整CLI通过 |
| 执行/主控初期docs索引缺项 | 各自基线未含共享登记；不越权修改索引或降低门禁 | 主控合入main@19fed414文档基线，aba285e7保留README双方边界，docs三门禁通过 |
| 66adfbde实际tracked patch与handoff不一致 | 原patch第21/400/491行及EOF空白使候选检查失败；不能相信交接文字代替实际tree | docs-only eb9539f4移除tracked原patch，保留ignored implementation.patch.log，产品3文件hash不变，相对产品基线diff检查通过 |

首次未冻结观察hash：state `82011a3077d9ca9bc242aa83ca241a6281209778a1264f4c8242aa26550014db`；state tests `253b2386913f6919f15e8c1dea95b39f3057c96be402e53c97a4c94609caab3e`。这些仅标识当时读取，不是最终冻结凭证。最终测试hash、二进制和日志hash见冻结清单，不累加早先28/33项与最终37项。

## 证据链与后续阶段

审查提交86744ec3 → 文档整合aba285e7 → 记录7fdc244b/4e562527 → 文档基线合入2748c537 → 联合候选4249bd26 → 独立验收报告95a1dc8f。执行冻结eb9539f4，真实main合并a0eebff0；精确吸收f3d06523后，history-only合并6271d24e与f3d06523 tree相同，仅保留历史可达性；最终清理记录8fcd856f。

开发时的“待候选、待完整CLI、待合main、待清理”均已由最终门禁和正常清理接替。原阶段报告保留其当时测试范围；真实设备恢复、跨进程竞态、跨Xcode兼容仍未验证，不能由离线绿色接替这些边界。
