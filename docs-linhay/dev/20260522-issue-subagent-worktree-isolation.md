# Issue Subagent Worktree Isolation

## 背景

用户要求“开 subagent 处理 issue，不要串工作”。本轮并行处理 GitHub issue #20 与 #21，主仓同时存在独立 WebView / transport 未提交改动，因此必须把 issue 实现、验证、文档与 memory 写回隔离在各自 worktree 中。

## BDD 场景

### 场景一：每个 issue 使用独立执行上下文

- Given 主仓可能存在未提交改动或另一条开发线
- When 用户要求多个 issue 并行处理
- Then 每个 issue 必须创建独立 `space`、branch 和 `../TritonKit-worktrees/<space-key>/`
- And subagent 只在自己分配的 worktree 内修改代码与文档
- And 主控 agent 不把多个 issue 的改动合并到同一个 commit

### 场景二：主控 agent 负责完整验收而不是只等代码

- Given subagent 已完成某个 issue 的实现
- When 主控 agent 收尾
- Then 必须逐 worktree 检查 clean status、最近 commit、测试结果、docs/memory 写回和 文档门禁
- And 未完成验证前不能宣称 issue 完成
- And push、PR、merge、删除 worktree 必须等待用户明确指令

### 场景三：主仓已有并行改动时只读隔离

- Given 主仓已有非本 issue 的未提交改动
- When issue worktree 收尾或补文档
- Then 只能只读核对主仓状态
- And 不 stage、不重置、不格式化、不顺手修这些未提交改动
- And 最终说明中明确这些改动未被混入 issue 分支

## 本轮实例

- Issue #20 使用 `docs-linhay/spaces/20260522-issue-20-tap-activation/`、branch `feat/20260522-issue-20-tap-activation`、worktree `../TritonKit-worktrees/20260522-issue-20-tap-activation/`，提交为 `e72d398 fix: activate tappable ancestors for text matches`。
- Issue #21 使用 `docs-linhay/spaces/20260522-issue-21-server-log-noise/`、branch `feat/20260522-issue-21-server-log-noise`、worktree `../TritonKit-worktrees/20260522-issue-21-server-log-noise/`，提交为 `ed42ca5 fix: avoid runtime websocket noise when server is down`。
- 两个 worktree 分别通过对应 Swift 测试、文档检查、`git diff --check` 和 文档门禁；#20 额外通过 iOS Simulator `xcodebuild test` 与 CLI build。
- 主仓存在并行 WebView / transport 改动，本轮未把这些文件混入 #20 / #21 分支。

## 复用入口

- `.agents/skills/tritonkit-subagent-supervision/SKILL.md`
- `.agents/skills/tritonkit-ops-governance/SKILL.md`
- `docs-linhay/scripts/check-docs.sh`
- `docs-linhay/scripts/check-docs.sh`

## 不纳入

- 不把 subagent 的具体名字、一次性构建临时目录或某次 XcodeBuildMCP 配置缺口写成长期规则。
- 不要求所有小修都必须开 worktree；一次性短改仍可在当前分支完成。
- 不自动 push、开 PR、merge 或关闭 issue；这些动作需要用户明确指令。
