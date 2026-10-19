# 2026-10-19 原主目录 WIP 完整合并

## 边界与 BDD

用户明确要求将 `codex/wip-main-before-sp209` 推进完成并合入实际 `main-integrated` 中的 main。影响层为文档、内部 skill、采用登记及已有 CLAUDE 文件，无新增 CLI/HTTP/SDK/Web 行为。

- Given 原目录存在独有提交和49份未提交文件，When 集成，Then 原样保存为可追溯提交，不丢用户内容。
- Given main 已有较新实现及部分文档，When 冲突裁决，Then 保留较新已验收产品，补齐独有历史并修正过期状态，不回灌旧代码。
- Given 合并验收结束，Then WIP tip 为main祖先，两工作区干净，原目录同步已验收主线；不推送或发布。

## 候选与逐文件裁决

main基线 `6eb961dc`；原WIP独有提交 `0a0aec02`，49份未提交文件原样快照为 `1131b183`。本地 `.build/wip-main-closeout/source-manifest.json` 保存原文件SHA。源提交保留全部历史内容，冲突不使用整树覆盖。

独立只读审计：48份文档中36份与main字节相同；12份为共享状态或已被较新主线替代。`0a0aec02`的39文件中28份已完整吸收（含16张截图）；11份差异逐项审查。补回发布契约“2026-10-16 更新检查误报审计”和10月16日采用授权、模型策略、版本审计及修复阶段历史；保留main后续SDK演进和发布证据。

修正MEMORY顶部旧采用限制、SP-207最小登记、SP-199未追踪、已发布行仍写未发布，以及三个已合并任务的controller_state；SP-212历史路径恢复实际Codex worktree，并分别登记SP-213预留主控和SP-211联合验证目录。历史研究partial及用户原机/旧iOS/设备验收边界继续保留，不扩为本轮新需求。

CLAUDE.md是原有932字节macOS bookmark二进制，用户改动24字节；原样纳入，SHA-256为 `a688dcac041fc2e8c969f6476491c79b9bfb0a8e00473596897ed35f781a4b21`，未擅改格式，也不将其算作可读Markdown规则验收。

## 验收与经验

检查最终差异只涉及docs/skill/CLAUDE，Sources、CLI、Tests、Examples、Web、public skills、manifest、发布脚本和workflow均与已验收main基线相同。无产品改动，不重复跑Swift/设备测试；既有产品验收见[联合验收](20261019-validation.md)。本轮执行 `verify.sh --ci-docs`、`check-docs.sh`、`git diff --check`、采用状态和历史路径断言、来源SHA及祖先检查，日志位于实际main的 `.build/wip-main-closeout/`。

上一轮“文档已整合”遗漏旧独有提交的历史章节，并只追加新状态而保留共享入口旧断言；本轮已修正原文。经验沉淀到ops governance“参考更新采用与跨会话交付”及EXPERIENCE对应行：逐文件证明吸收，收口同时核对当前入口与机器登记字段，文档结构门禁不替代语义审查。

合并候选验收结果：独立逐文件审查、docs gate、check-docs、diff check、产品路径无差异、CLAUDE原始SHA及采用登记一致性断言全部通过。
