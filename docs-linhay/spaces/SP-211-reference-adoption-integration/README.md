# SP-211 — 2026-10-17参考采用主控

## 边界与状态

本期只负责 [SP-210](../SP-210-simulator-ax-geometry/README.md) 和本次SP-207追踪资料的有限集成，状态：模型校验失败，待重试分派；不复用已收口SP-206，不无限追加后续参考批次。用户授权主控协调本批执行、审查真实候选、修复冲突、联合门禁、必要本地提交及本地main合并；不推送/tag/release，不运行上游代码/安装/签名/DDI/设备动作。

branch：`feat/SP-211-reference-adoption-integration`；worktree：`../TritonKit-worktrees/SP-211-reference-adoption-integration/`；基线 `main@d51403a69afbafd9426bd5ed6bfe3eb81a0ff0ec`。实际main在 `../TritonKit-worktrees/main-integrated/`，主目录另在 `codex/wip-main-before-sp209@0a0aec02` 且存在用户CLAUDE.md变更，禁止切换/重置/全分支合并或混入该WIP。

## 集成合同

1. 新建会话必须显式 `model="gpt-6.1-sol"`，后续分派同样遵守；不自动回退。收到执行thread ID后允许仅与该执行会话及当前追踪会话协调本期事项。
2. 核对SP-210失败测试、实现diff、冻结SHA、失败输出合法envelope、非finite/缺失几何、预算与合法路径回归。子会话“完成”不代替主控证据。
3. 主目录已有SP-207完整流程与授权资料尚未进入真实main（main只保留最小占号页），且主目录HEAD不是main。追踪会话会提供本期文档提交/精确manifest；以该提交逐文件提取批准的流程/追踪文件，不能整分支merge或覆盖main的SP-209/发布历史。共享索引/memory/治理文件按实际main人工合并，只追加本期内容。
4. 在独立候选worktree串行集成、冻结并独立跑受影响focused/full CLI、根包与适用local门禁；docs-only门禁不能代替产品验证。受限制的设备/签名步骤明确未执行。禁止同scratch并发、禁止stash。
5. 完成后检查真实main worktree状态与是否有其他写入者，串行将验证候选合入本地main，复核合后产品blob/受影响检查，写回SP-210/211、SP-207 adoption-state、索引/memory。遇main共享占用则等待协调，不强行覆盖，不伪称合并。

## BDD与验收

- Given实际main与主目录分支不同，When集成，Then采用实际main产品基线并保留双方最新授权、SP-209与发布记录，不把较新流程文档丢失解释成授权撤销。
- Given执行候选已冻结，When主控完成验证，Then证据绑定真实联合候选SHA，区分实现、验证、本地合并、发布和运行验收。
- Given任一门禁失败或候选变化，When继续，Then修复并重跑受影响检查，不能凭旧日志或子会话总结合并。

验收与失败证据写本space `plans/`。本期采用登记见 [adoption-state.json](../SP-207-reference-adoption-pipeline/plans/adoption-state.json)；根追踪报告在SP-207。无远端写入。

## 2026-10-17 分派结果

独立branch/worktree创建成功；`create_thread` 显式指定 `model="gpt-6.1-sol"` 后返回 `could not validate model`，未产生thread ID。保留待重试，不省略模型、不回退、不冒称开发或主控已启动。下一次先核对登记并补缺会话，不重复建space/worktree。
