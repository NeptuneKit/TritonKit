# SP-186 · xcode run 构建失败退出传播

- Issue：[#217](https://github.com/NeptuneKit/TritonKit/issues/217)
- 状态：修复与聚焦验证完成，待主控集成。
- 影响层：CLI 命令退出状态；保留 shared summary 与 JSON/JSONL 输出契约。
- 分支：`feat/SP-186-issue-217-xcode-run-exit`
- Worktree：`../TritonKit-worktrees/SP-186-issue-217-xcode-run-exit/`

## BDD 与验收

Given build phase 返回 `ok:false`、`exitCode:70`、`failureCode:xcodebuild_failed`；When 执行 `xcode run --json` 或 `--jsonl`；Then 仅输出一个 typed final summary，CLI 退出非零，不执行 settings/install/launch。JSONL 中先前 `ok:true` progress 不表示最终成功。

## 实现

`XcodeRun` 输出 final summary 后传播失败，并直接透传 `ExitCode`，避免二次错误包装。现有 build guard 保持 settings/install/launch 不执行。新增 helper/lifecycle 回归及真实 CLI 子进程 fake xcodebuild fixture，覆盖 JSON 与 JSONL。

## 验证

- `swift test --package-path CLI --filter XcodeCommandTests.xcodeRunFailedBuild --no-parallel`：通过 2 tests（子进程测试含 JSON/JSONL 两个 cases），1.554s；本次构建 binary 真实退出非零、final 单一且无 settings/install/launch。
- `git diff --check`：通过。
- `check-docs.sh`：当前仅因新增 space 未同步全局 index 阻塞；INDEX/路线/memory 由主控统一集成，避免多 issue 并行修改冲突。
- 不操作真实 Simulator；此 issue 仅修复 CLI 退出语义，不承担 Xcode destination 兼容验证。
- 根包、完整 CLI 与本地总门禁由主控集成后统一验证。
