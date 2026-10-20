# SP-215 — Simulator 显示器安全主控

## 边界与状态

2026-10-20 新批次主控，仅负责 [SP-214](../SP-214-simulator-display-safety/README.md)，等待独立主控会话分派。旧 SP-206/211/213 已交付，不扩张其历史范围。

branch `feat/SP-215-simulator-display-integration`；worktree `../TritonKit-worktrees/SP-215-simulator-display-integration/`；产品基线 `main@f82872e2fa457431ee7cbc7df2bafecea7ca6f1c`。模型必须显式 `gpt-6.1-sol`，不可用则保存真实失败、不回退。

## 主控验收

- Requested：仅确证主屏安全或拒绝未知/非主屏，不新增 Duo 控制产品。
- Observed/Evidence：复核 SP-214 冻结候选实际 diff、生产门禁接线、parser 完整性、红绿和真实 CLI envelope 证据；报告不得只引用执行会话完成声明。
- Gaps：非主屏/unknown 路径必须证明 native action、文件和流副作用计数 0；合法单屏及 Resize 现有语义应保留，deadline 有界，重复操作事实新鲜。
- Fixes made：验收不足继续修复；需要改执行文件先冻结交接，不能双方同时写。
- Remaining risk：真实 Xcode/Simulator 验收仍未授权，不以离线绿色宣称设备效果；禁止安装依赖、上游代码执行、设备/签名/DDI、push/tag/release。

允许与本批次 SP-214 执行会话协调、处理冲突、跑独立联合门禁，必要本地提交并合入本地 main。共享副作用串行，不 stash、不混其他 WIP；合并前核对实际 main 与所有 worktree。同步 SP-214/SP-215、索引、正式契约、memory 和 SP-207 采用登记；记录实际 SHA/命令/数量及通过、失败、未执行阶段。

只有真实创建成功才登记 thread ID；部分失败仅补缺角色，不重复建 space/worktree。不向外部发消息。后续确需新建本项目执行/主控会话也必须显式 `model="gpt-6.1-sol"`，并沿用以上边界。

## 2026-10-20 分派结果

必要创建请求显式 `model="gpt-6.1-sol"` 后被桌面接口以 `could not validate model` 拒绝，无真实 thread ID；未开发、未验证、未合并。保留独立工作区供后续仅补缺角色，记录见 [分派证据](../SP-207-reference-adoption-pipeline/plans/20261020-dispatch.json)。
