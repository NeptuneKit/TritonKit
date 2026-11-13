# 2026-11-13 采用与证据保管核验

固定 main：`366ae99b4be84b44e8e0718b39f278315d7c4c96`。本轮仅核验本地事实；未执行上游代码、联网、设备、共享测试、Git 或聊天修改。仓内与旧归档未改。

## 核验结果

- 11/12 主 manifest：1001 / 1001 文件 size 与 SHA256 匹配，共 61,738,259 bytes；无缺失、错配或重复路径。
- 11/12 closeout manifest：5 / 5 文件匹配，共 262,834 bytes；无缺失、错配或重复路径。
- 21 / 21 采用登记的合并 SHA 均为固定 main 祖先，登记仍为 local_merged。祖先关系不代表每项现行语义或真实运行场景重新验收。
- 两项 assessment_pending 仍需修订评估；本轮没有新实施分派，也不推进任何上游完整审阅检查点。

## Baguette：原始数据职责改变了后置条件边界

native semantic setText 仍以 clear、重新定位 responder、insert 返回提交成功，没有最终同对象精确回读。这本身不是已证明的错误成功；已有独立 verify、WebView 回读和 Harmony 可选验证，需先证明新后置条件的具体需要。

SP286 与最新 AGENTS 已替代旧评估里的“secure 拒绝”和默认隐藏业务值建议。不得凭字段名、内容或业务敏感性拒绝输入；原始可读值默认保留。系统屏蔽或不可读只意味着 verification unavailable，不能据此禁止技术上有效的提交。显式 --secure/redact 才改变输出副本。仍须验证 runtime、目标、对象、lease 与 observation 一致；过期、失败、unknown 或不匹配不自动重放。保持 revise_first；不得把未读值当空串或声称 exact match。

## Mirroir：仍待反例和窄化契约

CLIWebRuntime.swift 与 0ec972e6 完全相同（SHA256 `0b61d035a76323dd4767a27a8058e753d6b86bc68b80707005d53784340d985b`），同步 resolver/connect 尚无统一 deadline。此前 3 次本机 loopback 尝试未复现挂起，本轮未重跑。旧 52 提交的语义审阅缺口继续保留；不能由源码缺少 deadline 直接宣称已复现故障。若采用，先定义统一预算、取消与 unknown/error，不把超时等同可用端口，并覆盖旧 Boolean 消费入口。SP286 不取消技术预算边界。

## 真正未完成：SP281 P2

SP281 已明确撤回整体 P0–P2 完成表述。SimTap/SimSwipe 生产入口、普通 host 非零/超时失败收口、共享 owner/admission/cancellation，以及 act/app/WebView/manage/workspace/replay 的统一迁移仍不完整；helper、operation 字符串和绿色局部测试不构成生产路由证明。全局 Stop/resume 与原子 lease-check-to-provider 也未闭环。

父主控可核对既有 SP281 负责人后，按 main 串行规则冻结具体 BDD/失败测试切片继续推进。此项不在 21 条已合并采用中，不能用“21/21”把它误报完工，也不应重开历史已交付聊天。

## 聊天与附件

adoption-state 保留 13 个已归档聊天的历史成功记录，本轮未逐个重读或再次归档。当前审计调用方 list_artifacts 返回空，不证明其他聊天的附件已清理。SP255 的最后权威证据仍记录旧 SP254 附件受另一任务 owner 与恢复 checkout 为 primary 阻塞；本轮没有新的解除证据。保留历史 blocker，不重开已归档聊天、不执行破坏性清理，不伪报跨任务附件清理成功。长期主控保持开放。

## 证据与经验

对应 JSON 含逐条祖先结果、manifest 摘要、固定 main 来源 hash、阶段与剩余范围。11/12 文件完整不等于此前 11/02 丢失证据已恢复；本轮未重审那批文件。沿用原始数据、生产入口反证、持久证据保管三类既有经验，无需新增规则或改写冻结的历史报告。
