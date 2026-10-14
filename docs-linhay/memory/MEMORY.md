# TritonKit Project Memory

## Canonical Indexes

- Spaces 的固定入口分为 [编号索引](../spaces/INDEX.md) 与 [路线总览](../spaces/README.md)：前者登记 SP 规范名、兼容目录与迁移进度，后者登记状态和队列。
- 新建 space、状态变化、worktree 集成或 space 收口时，必须同步更新两个入口。
- 新 space 采用 `SP-<三位序号>-<topic>`；单个需求的详细边界、BDD、计划和证据仍以对应 `docs-linhay/spaces/<space-id>-<topic>/README.md` 为事实源。

## Memory Rules

- [OpenMinis/iCTRL](https://github.com/OpenMinis/iCTRL) 是长期参考项目：正式档案见 [iCTRL 参考与追踪](../dev/ictrl-reference-tracking.md)，持续追踪见 [SP-193](../spaces/SP-193-ictrl-reference-tracking/README.md)，已有借鉴实现见 SP-192。自动化 `ictrl` 每天北京时间 10:00 检查上游，有价值变化通知；不自动采用、提交或操作设备。
- 参考项目清单和2026-10-14上游更新统一入口：[参考项目更新报告](../dev/20261014-reference-project-updates.md) / [SP-194](../spaces/SP-194-reference-project-updates/README.md)，覆盖主要仓库与专题候选；后续比较优先使用其中固定SHA/Release证据，区分默认分支与已发布能力。

- 长期稳定的项目入口和跨会话约定记录在本文件。
- 每日实施记录继续写入 `docs-linhay/memory/YYYY-MM-DD.md`。
- repo-wide 执行规则仍以根目录 `AGENTS.md` 为准。

## 已实现的可选视图高亮

- [SP-197](../spaces/SP-197-view-annotation/README.md)已在本地main提供独立`highlight capabilities/apply/status/clear`；P0支持自愿启用Debug runtime的UIKit可写节点，普通截图不强制SDK。public skill的[高亮流程](../../TritonKit.skills/tritonkit-emulator-cli-takeover/references/view-highlight.md)为调用入口。恢复使用App-owned session、原始平台属性与整组值保护；业务冲突须报告，TTL不承诺挂起/卡死期间实时恢复。跨端及自动截图组合仍属后续。
