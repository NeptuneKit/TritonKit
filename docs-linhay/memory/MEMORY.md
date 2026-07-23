# TritonKit Project Memory

## Canonical Indexes

- Spaces 的固定入口分为 [编号索引](../spaces/INDEX.md) 与 [路线总览](../spaces/README.md)：前者登记 SP 规范名、兼容目录与迁移进度，后者登记状态和队列。
- 新建 space、状态变化、worktree 集成或 space 收口时，必须同步更新两个入口。
- 新 space 采用 `SP-<三位序号>-<topic>`；单个需求的详细边界、BDD、计划和证据仍以对应 `docs-linhay/spaces/<space-id>-<topic>/README.md` 为事实源。

## Memory Rules

- 长期稳定的项目入口和跨会话约定记录在本文件。
- 每日实施记录继续写入 `docs-linhay/memory/YYYY-MM-DD.md`。
- repo-wide 执行规则仍以根目录 `AGENTS.md` 为准。
