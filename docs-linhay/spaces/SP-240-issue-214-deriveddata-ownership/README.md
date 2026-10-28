# SP-240 · #214 DerivedData 处理结论

当前状态：调查与删除记录已通过 [PR #234](https://github.com/NeptuneKit/TritonKit/pull/234) 合入 main（`d52d62fd47d07f96940ddf59825b71e05d061bd6`，2026-10-28 13:08 +08:00），合并后复查 #214 仍为 OPEN。已完成只读调查，并按用户后续明确授权人工删除两处现存 `.triton/DerivedData`（删除前约1.95 GiB分配块）。原报告的大目录及原始调用仍未查明，#214 保持 OPEN；通用自动删除仍已取消。详见[调查记录](plans/20261028-cache-investigation.md)与[授权删除记录](plans/20261028-authorized-cache-deletion.md)。

最新调查：历史溯源文档已通过 [PR #235](https://github.com/NeptuneKit/TritonKit/pull/235) 合入 main（`5d0bba7b94f4fb127b7e7d7c599997b7311ce0ab`，2026-10-28 15:30:31 +08:00），合并后 #214 复查为 OPEN。已找到两组历史候选及实际构建目的地记录，但尚无原 12.13 GB / 6.53 GB 的路径映射；不能将候选等同原现场。H2 原始日志证明显式选择不同 derived-data 路径也会形成两处缓存，需与 cwd 变化分别核对。详见[历史调用溯源](plans/20261028-history-trace.md)。取证阶段只读；用户随后授权提交推送、创建 PR 和同步脱敏结论，#214 保持 OPEN。

## 范围

本 space 跟踪 [GitHub #214](https://github.com/NeptuneKit/TritonKit/issues/214) 的有效裁决及原始缓存来源、实际占用与重复情况。2026-10-28 用户先要求只读调查，随后明确授权提交推送、同步 issue 与删除缓存。范围限定为已调查的 A/B 两处目录，影响层为 CLI 只读观察、一次性人工缓存回收和文档；不启动构建、不改配置、不实现产品清理。旧 not planned 草稿仅作历史记录。

[SP-179](../SP-179-issue-214-derived-data-cleanup/README.md) 于 2026-10-24 取消通用自动删除，继续维护 inspect / dry-run 与 confirm fail-closed；[SP-191](../SP-191-default-xcode-deriveddata/README.md) 已在 v0.2.26 将默认路径交回 Xcode 用户级 DerivedData。这两项不证明原报告两处缓存重复或泄漏，也不证明实现了竞态安全删除。

## BDD / 验收

- Given 远端旧评论仍称待实现排他协议，When 对照后续取消裁决，Then 说明该目标退出当前队列，而不是恢复删除承诺。
- Given 当前源码，Then inspect/preview 为只读，confirm 在活动/未知构建状态返回 xcode_not_idle，空闲仍返回 derived_data_cleanup_unavailable，无删除路径。
- Given 原报告的大目录，Then 保留产生版本/调用未知，logical bytes 与目录 mtime 不能证明可回收量/最后使用时间。
- Given 现场候选目录，When 只读检查元数据、磁盘分配块与内容摘要，Then 分开报告逻辑大小、allocated blocks 与相同内容，不将其推断为可回收空间。
- Given 原路径已脱敏，When 候选目录与原报告不匹配，Then 明确未定位原现场，并保留来源与重复性未知；不拿其它缓存替代验收。

- Given 用户后续明确授权人工回收，When 目标身份/内容与构建活动复核通过，Then 仅删除已调查的 A/B 两处，保留父目录与其它缓存；结果不等于通用删除安全验收。

## 证据

- [原18.66 GB历史调用溯源](plans/20261028-history-trace.md)及[脱敏证据索引](plans/20261028-history-trace-evidence.json)

- [授权删除与验收](plans/20261028-authorized-cache-deletion.md)及[机器可读结果](plans/20261028-authorized-cache-deletion.json)
- [只读现场调查](plans/20261028-cache-investigation.md)与[脱敏统计](plans/20261028-cache-inventory.json)
- [历史范围审计](plans/20261028-audit.md)
- [历史回复草稿](plans/20261028-issue-reply-draft.md)（未采用的 not planned 方案，不代表当前处置）

初始审计 branch：feat/SP-240-issue-214-deriveddata-ownership；worktree：../TritonKit-worktrees/SP-240-issue-214-deriveddata-ownership。

本轮调查/删除记录位于 ../TritonKit-worktrees/SP-241-open-issues-validation，branch 为 codex/issue-214-cache-investigation；基线 32a85a9d。

历史溯源切片沿用同一集成 worktree，branch 为 codex/issue-214-history-trace，基线 eefac94f；只读外部资料；本切片已通过 PR #235 合并交付脱敏调查文档，不关闭 #214。
