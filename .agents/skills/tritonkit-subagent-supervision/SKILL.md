---
name: tritonkit-subagent-supervision
description: TritonKit 监督交付模式：用户要求 subagent 实做且主控 agent 监督闭环时触发。
---

# TritonKit Subagent Supervision

当用户明确要求“用 subagent 做、主控 agent 负责监督到完成”时，默认进入本模式。

## 目标

1. subagent 负责边界清晰的实现任务。
2. 主控 agent 负责需求边界、任务拆分、集成、验证、文档、memory 和最终完成判断。

## 执行顺序

1. 先确认需求文档、范围和验收标准。
2. 按写入面拆分 subagent 任务，避免冲突。
3. 主控 agent 持续集成 subagent 结果，不等到最后统一收口。
4. 跑完整个需求闭环后才停止：
   - 代码集成
   - 自动化验证
   - HTTP 接口或端到端验收
   - docs / memory 写回
   - `qmd update`
   - `qmd embed`
5. 如果仍有未完成项，继续推进；如果卡住，明确写出 blocker 和剩余工作。

## GitHub Issue 并行处理

当用户要求用 subagent 处理多个 issue，且强调“不要串工作”时，默认按 issue 隔离执行：

1. 一个 GitHub issue 对应一个 `space`、一个 branch、一个同 key worktree。
2. worktree 路径使用 `../TritonKit-worktrees/<space-key>/`，不要放进主仓目录或 `/tmp`。
3. branch 默认使用 `feat/<space-key>`；`space-key` 推荐 `<YYYYMMDD>-issue-<number>-<topic>`。
4. 每个 subagent 只负责自己的 issue worktree，不跨 worktree 读取或修改同一批实现文件。
5. 主控 agent 在主仓或独立只读上下文里监督，不把多个 issue 的代码、文档、memory 提交混在同一个 commit。
6. 若主仓已有未提交改动，先记录为并行上下文，只读核对；除非用户明确要求，不 stage、不重置、不顺手修。
7. issue 分支收尾时分别检查 `git status --short --branch`、最近 commit、测试结果、docs/memory/qmd 状态，再汇总给用户。
8. 只有用户明确要求时才 push、开 PR、合并或删除 worktree。

## 停止条件

只有以下情况可以停止：

1. 需求已经完整闭环。
2. 用户明确暂停。
3. 当前环境存在无法自行解决的具体 blocker。

“代码已改完”不是停止条件。
