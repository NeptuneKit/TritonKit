# TritonKit Project Memory

## Canonical Indexes

- Spaces 的固定入口分为 [编号索引](../spaces/INDEX.md) 与 [路线总览](../spaces/README.md)：前者登记 SP 规范名、兼容目录与迁移进度，后者登记状态和队列。
- 新建 space、状态变化、worktree 集成或 space 收口时，必须同步更新两个入口。
- 新 space 采用 `SP-<三位序号>-<topic>`；单个需求的详细边界、BDD、计划和证据仍以对应 `docs-linhay/spaces/<space-id>-<topic>/README.md` 为事实源。

- 开工与交付的按主题入口：[经验索引](EXPERIENCE.md)；每个任务/交付切片默认自动沉淀，有复用价值的纠正/缺陷/失败触发原文更新，无需用户提醒。详细动作以 [治理流程](../dev/20260619-agent-workflow-skill-governance.md) 为准。无需全量预读每日历史，原文后续证据可替代旧结论。

## Memory Rules

- [OpenMinis/iCTRL](https://github.com/OpenMinis/iCTRL) 是长期参考项目：正式档案见 [iCTRL 参考与追踪](../dev/ictrl-reference-tracking.md)，持续追踪见 [SP-193](../spaces/SP-193-ictrl-reference-tracking/README.md)，已有借鉴实现见 SP-192。自动化 `ictrl` 每天北京时间 10:00 检查上游，有价值变化通知；不自动采用、提交或操作设备。
- [mobile-next/mobile-mcp](https://github.com/mobile-next/mobile-mcp) 已列为参考项目：正式档案与能力差距见 [Mobile MCP 参考](../dev/mobile-mcp-reference.md) / [SP-199](../spaces/SP-199-mobile-mcp-reference/README.md)。固定源码与外部 mobilecli backend 分开核对；计入现有 iOS Runner。仅登记研究，未启用周期追踪或采用功能。
- 参考项目清单和2026-10-14上游更新统一入口：[参考项目更新报告](../dev/20261014-reference-project-updates.md) / [SP-194](../spaces/SP-194-reference-project-updates/README.md)，覆盖主要仓库与专题候选；后续比较优先使用其中固定SHA/Release证据，区分默认分支与已发布能力。

- 长期稳定的项目入口和跨会话约定记录在本文件。
- 每日实施记录继续写入 `docs-linhay/memory/YYYY-MM-DD.md`。
- repo-wide 执行规则仍以根目录 `AGENTS.md` 为准。


## 已实现的可选视图高亮

- [SP-197](../spaces/SP-197-view-annotation/README.md)已在本地main提供独立`highlight capabilities/apply/status/clear`；P0支持自愿启用Debug runtime的UIKit可写节点，普通截图不强制SDK。public skill的[高亮流程](../../TritonKit.skills/tritonkit-emulator-cli-takeover/references/view-highlight.md)为调用入口。恢复使用App-owned session、原始平台属性与整组值保护；业务冲突须报告，TTL不承诺挂起/卡死期间实时恢复。跨端及自动截图组合仍属后续。


## 上游优化交付入口

- 参考更新的已实现采用项与验证边界见[SP-196验收报告](../spaces/SP-196-upstream-optimization-delivery/plans/20261014-validation-report.md)及[工程说明](../dev/20261014-upstream-optimization-delivery.md)。已于2026-10-15完成主线集成及v0.2.28发布，详见[发布验收](../spaces/SP-196-upstream-optimization-delivery/plans/20261014-release.md)；active Resize与跨OS私有行为仍需专项证明。后续复用按报告的模块/真实/跳过口径判断，不继承上游性能估计。
