# SP-217 — Harmony 转发安全主控

2026-10-20 独立主控，仅负责 [SP-216](../SP-216-harmony-forward-cleanup/README.md)。branch `feat/SP-217-harmony-forward-integration`；worktree `../TritonKit-worktrees/SP-217-harmony-forward-integration/`；基线 main `f82872e2`。状态为待分派；指定模型 `gpt-6.1-sol` 的同接口创建刚刚失败，未额外重复探测，真实 thread ID 为空。

用户已授权协调本批次执行会话、复核冻结候选真实 diff、修复冲突、联合验证、必要本地提交及本地 main 合并。不得把执行声明替代验收；Requested/Observed/Evidence/Gaps/Fixes made/Remaining risk 按监督 skill 记录。核对当前 main 与所有 worktree，禁止 stash 和混入其他 WIP，所有 Git/build 共享副作用串行。

验收需覆盖当前唯一归属才 rm、foreign/Reverse/changed/ambiguous/failed listing 的 rm 计数为 0、主错误与 cleanup uncertainty 同时保留、进程内 allocation/cleanup 互斥且 deadline 有界、实际 CLI 单一失败 envelope 与脱敏。清楚记录独立进程竞态和真实 HDC 未验边界，不能声称彻底消除 TOCTOU。

主控拥有本 space、集成修复与共享索引/memory/契约收口；与执行文件交接前先冻结，不同时编辑。当前追踪 root 负责本日 SP-207 资料，整合时先核对较新资料，禁止整分支回灌旧产品或覆盖追踪 WIP。

不运行第三方源码、不安装/升级依赖、不操作设备/签名/DDI、不 push/tag/release。只离线 fixture/fake-HDC/进程验收；所有后续本项目新执行/主控会话显式 `model="gpt-6.1-sol"`，不可用则记录失败/待重试，不能回退或伪造 ID。
