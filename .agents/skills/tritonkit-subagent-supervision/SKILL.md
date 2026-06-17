---
name: tritonkit-subagent-supervision
description: TritonKit 监督交付模式：用户要求 subagent 实做且主控 agent 监督闭环时触发。
---

# TritonKit Subagent Supervision

当用户明确要求“用 subagent 做、主控 agent 负责监督到完成”时，默认进入本模式。

## 目标

1. subagent 负责边界清晰的实现任务。
2. 主控 agent 负责需求边界、任务拆分、集成、验证、文档、memory 和最终完成判断。
3. 当用户授权主控 agent 作为 leader 自主管理 subagents 时，主控 agent 应主动创建、调度、改派、停止或续跑 subagent，目标是快速推进完整闭环，而不是等待用户逐步指挥。

## 执行顺序

1. 先确认需求文档、范围和验收标准。
2. 按写入面拆分 subagent 任务，避免冲突。
3. 主控 agent 持续集成 subagent 结果，不等到最后统一收口。
4. 跑完整个需求闭环后才停止：
   - 代码集成
   - 自动化验证
   - HTTP 接口或端到端验收
   - docs / memory 写回
   - 文档结构检查
5. 如果仍有未完成项，继续推进；如果卡住，明确写出 blocker 和剩余工作。

## Leader 自主管理

用户明确授权后，同一需求后续执行默认不再逐项请求用户介入。主控 agent 可以自行：

1. 按 `space`、计划和 `.codex/agents/` 配置选择 subagent。
2. 分批启动互不冲突的 subagent。
3. 根据结果改派、停止、续跑或补开验证 agent。
4. 合并结果并跑门禁。
5. 只在需求边界变化、破坏性操作、权限/环境 blocker 或必须用户取舍时打断用户。

主控 agent 仍必须保留最终完成判断；subagent 的“完成”只能作为输入，不能替代 DoD。

## GitHub Issue 并行处理

当用户要求用 subagent 处理多个 issue，且强调“不要串工作”时，默认按 issue 隔离执行：

1. 一个 GitHub issue 对应一个 `space`、一个 branch、一个同 key worktree。
2. worktree 路径使用 `../TritonKit-worktrees/<space-key>/`，不要放进主仓目录或 `/tmp`。
3. branch 默认使用 `feat/<space-key>`；`space-key` 推荐 `<YYYYMMDD>-issue-<number>-<topic>`。
4. 每个 subagent 只负责自己的 issue worktree，不跨 worktree 读取或修改同一批实现文件。
5. 主控 agent 在主仓或独立只读上下文里监督，不把多个 issue 的代码、文档、memory 提交混在同一个 commit。
6. 若主仓已有未提交改动，先记录为并行上下文，只读核对；除非用户明确要求，不 stage、不重置、不顺手修。
7. issue 分支收尾时分别检查 `git status --short --branch`、最近 commit、测试结果、docs/memory 状态，再汇总给用户。
8. 只有用户明确要求时才 push、开 PR、合并或删除 worktree。

## GitHub Issue 全链路收口

当用户在 issue 并行处理后明确要求“合并、清理、推送、关闭 issue”时，主控 agent 负责收口，不再让 subagent 各自操作远端：

1. 合并前在主仓确认 `git status --short --branch` 干净，并用 `git worktree list --porcelain` 枚举仍注册的 issue worktree。
2. 对每个 issue 分支核对 worktree clean status、最近提交和对应 issue 编号；主仓若已落后 `origin/main`，先更新或重新评估冲突风险。
3. 合并前优先用无副作用预检确认冲突风险，例如 `git merge-tree --write-tree main <branch>`；预检通过后再在主仓按分支逐个 `git merge --no-ff`。
4. 合并完成后跑与本轮改动匹配的 focused tests、必要 build、`git diff --check` 和 `docs-linhay/scripts/check-docs.sh`；若合并后才暴露测试不稳定或契约错位，允许在主仓补一个 integration fix commit。
5. 只有门禁通过后才清理 worktree；清理顺序为 `git worktree remove <path>`，再用 `git branch -d <branch>` 删除已合并本地分支，不使用强制删除，除非用户明确授权并已确认无未合入提交。
6. 推送前复查 `git status --short --branch` 和最近提交；推送成功后才关闭 GitHub issue。
7. 关闭 issue 时只关闭本轮已处理的 issue，不顺手关闭新出现或未验证的 open issue；评论写明合并提交、关键验证命令和剩余风险。
8. GitHub issue 评论包含命令片段、反引号或复杂 Markdown 时，使用 `docs-linhay/scripts/gh-issue-comment-file.sh` 或 `gh issue comment/close --body-file`，避免 shell 解释评论内容。

## 停止条件

只有以下情况可以停止：

1. 需求已经完整闭环。
2. 用户明确暂停。
3. 当前环境存在无法自行解决的具体 blocker。

“代码已改完”不是停止条件。
