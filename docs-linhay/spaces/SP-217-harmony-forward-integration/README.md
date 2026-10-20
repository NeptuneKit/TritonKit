# SP-217 — Harmony 转发安全主控

2026-10-20 独立主控，仅负责 [SP-216](../SP-216-harmony-forward-cleanup/README.md)。branch `feat/SP-217-harmony-forward-integration`；worktree `../TritonKit-worktrees/SP-217-harmony-forward-integration/`；基线 main `f82872e2`。本 space 已完成离线主控验收，候选随 SP-216 一并合入本地 `main`。

用户已授权协调本批次执行会话、复核冻结候选真实 diff、修复冲突、联合验证、必要本地提交及本地 main 合并。不得把执行声明替代验收；Requested/Observed/Evidence/Gaps/Fixes made/Remaining risk 按监督 skill 记录。核对当前 main 与所有 worktree，禁止 stash 和混入其他 WIP，所有 Git/build 共享副作用串行。

## 主控验收（2026-10-21 完成）

验收覆盖当前唯一归属才 rm、foreign/Reverse/changed/ambiguous/failed listing 的 rm 计数为 0、主错误与 cleanup uncertainty 同时保留、进程内 allocation/cleanup 互斥且 deadline 有界、CLI 单一失败 envelope 与脱敏。候选 `5d5647b5` 的 `HarmonyArkWebBridgeCallTests` 37 tests 通过；清理前重新列出当前 forward 表，未知归属 fail closed，主错误不会被 cleanup 错误覆盖。

独立进程竞态仍是边界，真实 HDC 未验；本结果只证明 fake-HDC/离线契约和 host 接线，不声称彻底消除 TOCTOU。

主控拥有本 space、集成修复与共享索引/memory/契约收口；与执行文件交接前先冻结，不同时编辑。当前追踪 root 负责本日 SP-207 资料，整合时先核对较新资料，禁止整分支回灌旧产品或覆盖追踪 WIP。

不运行第三方源码、不安装/升级依赖、不操作设备/签名/DDI、不 push/tag/release。只离线 fixture/fake-HDC/进程验收；真实 HDC 和跨进程竞态留待后续真实环境回归。

## 2026-10-20 分派结果（历史）

指定模型 `gpt-6.1-sol` 的同接口创建失败，真实 thread ID 为空；该失败保留为分派历史，后续由本地执行流程完成实现与验收，未伪造会话 ID。
