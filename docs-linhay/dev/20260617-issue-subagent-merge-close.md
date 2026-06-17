# Issue Subagent Merge And Close Flow

## 背景

本轮用户要求用 subagent 处理线上全部 issue，随后由主控 agent 处理合并、worktree 清理、推送并关闭对应 issue。第一轮实际处理范围为 GitHub issue #57 到 #61；处理期间远端新增 #62、#63，第一轮只关闭已实现和验证的 #57 到 #61。第二轮继续处理 #62、#63，并在验证后推送关闭，最终 open issue 为空。

## BDD 场景

### 场景一：多个 issue 并行实现但主控统一收口

- Given 每个 issue 已在独立 `space`、branch 和 `../TritonKit-worktrees/<space-key>/` 中完成实现
- When 用户要求合并和清理 worktree
- Then 主控 agent 必须逐 worktree 复查 clean status、提交和验证结果
- And 在主仓执行无副作用合并预检
- And 只在主仓完成最终 merge、integration fix 和门禁验证

### 场景二：合并后暴露交叉测试问题

- Given 单个 issue 分支各自测试通过
- When 多个 issue 合并到 `main`
- Then 必须跑合并后的 focused tests、必要 build、`git diff --check` 和 `docs-linhay/scripts/check-docs.sh`
- And 若出现跨 issue 契约错位或测试隔离问题，使用独立 integration fix commit 修复
- And 修复后重新跑失败面和最终 focused tests

### 场景三：推送后只关闭已验证 issue

- Given `main` 已推送到 `origin/main`
- When 用户要求关闭对应 issue
- Then 只关闭本轮实现并验证的 issue
- And 不关闭新出现、未实现或未验证的 open issue
- And issue 评论写明对应实现提交、合并提交、integration fix 和验证范围

### 场景四：多 issue 分支追加同一天 memory

- Given 多个 issue 分支都更新 `docs-linhay/memory/YYYY-MM-DD.md`
- When 第一个分支已合入 `main`，第二个分支的 merge 预检提示 memory content conflict
- Then 主控 agent 只解决 memory 冲突
- And 保留每个 issue 的独立段落
- And 不把两个 issue 的实现、测试或剩余风险揉成单段记录

### 场景五：已合入本地但未推送时清理分支

- Given issue 分支已经合入本地 `HEAD`
- And `git branch -d <branch>` 因该分支尚未合入 `origin/main` 而拒绝删除
- When 主控 agent 已完成本地门禁
- Then 先推送 `main` 并 `git fetch origin main`
- And 再重试非强制 `git branch -d`
- And 不直接使用 `git branch -D`

## 第一轮实例

- #57：`34c9b63 fix: surface xcode stale derived data diagnostics`，合并提交 `75baeae`。
- #58：`20efdc1 feat: expose webview provider capabilities`，合并提交 `4cb65c5`。
- #59：`ee02d4c fix: propagate capture target and tap buttons`，合并提交 `d93cb4d`。
- #60：`2b05f90 test: cover ancestor table row taps`，合并提交 `fe2fad6`。
- #61：`e311c1c fix: expose android device platform surface`，合并提交 `f0584f3`。
- 合并后补充 `189e512 test: stabilize merged issue verification`，修复 `EvidenceBundleTests` 的 URLSession 注入隔离，以及 `DeviceCrossPlatformTests` 对 command schema usage form 的断言口径。
- 推送范围为 `05f674b..189e512 main -> main`。

## 第二轮实例

- #62：`8afc286 fix: bound discovery command timeouts`，合并提交 `867fb12`。该分支为 Harmony discovery HDC 命令设置 3 秒默认 timeout，并把 discovery timeout 映射为 `harmony_discovery_timeout`。
- #63：`0ea4218 feat: expose harmony route webview warnings`，合并提交 `7d0190d`。该分支为 Harmony WebView host-layout response 增加 `warnings[]`，并保留 route-loop / evidence artifact contract。
- #63 合并前 `git merge-tree --write-tree HEAD feat/20260617-issue-63-harmony-route-webview-evidence` 预检提示唯一冲突在 `docs-linhay/memory/2026-06-17.md`；实际 merge 时保留 #62 与 #63 两个独立 memory 段落后完成 merge commit。
- 两个 worktree 删除后，本地 `git branch -d` 因 `origin/main` 尚未包含新 merge commit 而拒绝删除分支；主控 agent 先推送 `main`，再 `git fetch origin main` 并用非强制 `git branch -d` 清理成功。
- 推送范围为 `26e2c94..7d0190d main -> main`，随后 #62、#63 使用 `docs-linhay/scripts/gh-issue-comment-file.sh` 评论并关闭。

## 验证

- `swift build --package-path CLI --scratch-path .build/cli-merged --product triton`
- `swift test --package-path CLI --scratch-path .build/cli-merged --filter 'XcodeDiagnosticsTests|EvidenceBundleTests|DeviceCrossPlatformTests|WebCommandTests'`
- `swift test --filter 'TKObservationModelsTests|TKRuntimeWebViewSnapshotTests|TKAXUIKitTextTests|TKRuntimeInputActionsTests'`
- `swift test --package-path CLI --scratch-path .build/cli-issues-62-63 --filter 'DiscoveryTimeoutTests|WebViewRouteTests'`
- `swift test --filter TKEvidenceModelsTests`
- `git diff --check`
- `docs-linhay/scripts/check-docs.sh`

## 可复用流程

1. 用 `gh issue list --state open --json number,title,url` 获取本轮候选 issue，并在主控侧明确处理范围。
2. 为每个 issue 创建独立 `space`、branch 和 worktree，交给 subagent 实现；主控 agent 不在主仓混写 issue 实现。
3. subagent 完成后逐 worktree 检查 clean status、提交、测试、docs 和 memory。
4. 合并前用 `git merge-tree --write-tree main <branch>` 做冲突预检。
5. 在主仓按 issue 分支逐个 `git merge --no-ff`，保留 issue 分支边界；若只有 memory 追加冲突，保留各 issue 独立段落后完成 merge commit。
6. 跑合并后门禁；必要时只做 integration fix，不回写到已清理的 issue worktree。
7. 门禁通过后执行 `git worktree remove <path>`。若 `git branch -d <branch>` 因尚未合入 `origin/main` 拒绝删除，先推送 `main` 并 fetch，再重试非强制删除。
8. 推送 `main` 后关闭对应 issue；评论中引用提交和验证命令。若评论含复杂 Markdown，必须使用 `--body-file`。
9. 最后复查 `git status --short --branch`、`git worktree list --porcelain` 和 open issue 列表。

## 不纳入

- 不把具体 subagent 名称、临时 scratch path 或单次 GitHub CLI 网络耗时写成长期规则。
- 不要求所有 issue 合并都必须直接推 `main`；是否 push、开 PR、关闭 issue 仍以用户明确指令为准。
- 不把 #63 的真实 Harmony route stack / WebView initURL extractor 误写成本轮已完成；第二轮只完成 warning 与 evidence artifact contract。

## 复用入口

- `.agents/skills/tritonkit-subagent-supervision/SKILL.md`
- `.agents/skills/tritonkit-ops-governance/SKILL.md`
- `docs-linhay/dev/20260522-issue-subagent-worktree-isolation.md`
