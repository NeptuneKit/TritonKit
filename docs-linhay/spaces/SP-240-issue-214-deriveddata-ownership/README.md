# SP-240 · #214 DerivedData 处理结论

当前状态：范围审计已随PR #233合入远端main（`40850dde`）；#214保持OPEN，仅保留原始来源/占用的只读调查，通用自动删除仍已取消。[后续计划](https://github.com/NeptuneKit/TritonKit/issues/214#issuecomment-6460629137)。 本批次未发布；[合并归档报告](../SP-241-open-issues-validation/plans/20261028-merge-closeout.md)为当前事实源。
## 范围

本 space 只核对 [GitHub #214](https://github.com/NeptuneKit/TritonKit/issues/214) 的后续有效裁决和当前 CLI，并准备 not planned 收口说明。影响层为文档，无新增生产代码。

[SP-179](../SP-179-issue-214-derived-data-cleanup/README.md) 于 2026-10-24 取消通用自动删除，继续维护 inspect / dry-run 与 confirm fail-closed；[SP-191](../SP-191-default-xcode-deriveddata/README.md) 已在 v0.2.26 将默认路径交回 Xcode 用户级 DerivedData。这两项不证明原报告两处缓存重复或泄漏，也不证明实现了竞态安全删除。

## BDD / 验收

- Given 远端旧评论仍称待实现排他协议，When 对照后续取消裁决，Then 说明该目标退出当前队列，而不是恢复删除承诺。
- Given 当前源码，Then inspect/preview 为只读，confirm 在活动/未知构建状态返回 xcode_not_idle，空闲仍返回 derived_data_cleanup_unavailable，无删除路径。
- Given 原报告的大目录，Then 保留产生版本/调用未知，logical bytes 与目录 mtime 不能证明可回收量/最后使用时间。
- Given 回复草稿，Then 明确当前边界和 not planned 理由；只在用户明确授权的远端收口步骤发布，不能使用已实现安全删除的措辞。

## 证据

- [审计与验证](plans/20261028-audit.md)
- [可审阅回复草稿](plans/20261028-issue-reply-draft.md)

branch：feat/SP-240-issue-214-deriveddata-ownership；worktree：../TritonKit-worktrees/SP-240-issue-214-deriveddata-ownership。
