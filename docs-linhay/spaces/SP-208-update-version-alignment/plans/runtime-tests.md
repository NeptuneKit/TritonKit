# SP-208 更新运行时测试证据

日期：2026-10-16。候选工作区：`TritonKit-worktrees/SP-208-update-version-alignment`。以下是实现阶段的确定性测试，Homebrew、GitHub resolver 与 skills installer 使用注入 spy；未执行真实升级，不代表真实用户安装验收。

## 红灯：Homebrew latest 被跳过

先修改原 `UpdateCommandTests.homebrewCheckWithoutExplicitVersionResolvesGitHubLatest` 预期，保持运行时旧实现：

```sh
swift test --package-path CLI --no-parallel --filter UpdateCommandTests.homebrewCheckWithoutExplicitVersionResolvesGitHubLatest
```

退出码 1，1 test / 4 issues：`releaseTag/latestVersion/targetVersion` 实际均为 nil，`updateAvailable` 实际为 false；注入的 GitHub latest 返回 `v999.0.0`。原始本地日志：`/tmp/sp208-runtime-red.log`。

## 红灯：skills 版本身份

主控提供恒成功 stub 与正式回归用例后执行：

```sh
swift test --package-path CLI --no-parallel --filter PublicSkillReleaseValidationTests
```

退出码 1，2 tests / 7 issues；7 类不一致 bundle 均错误通过。原始本地日志：`/tmp/sp208-skills-red.log`。随后由主控替换正式 validator。

## 红灯：独立审查反例

增加非法 target、`version --json` 的 `ok:false` / 缺少 `ok` 反例后执行：

```sh
swift test --package-path CLI --no-parallel --filter 'UpdateVersionAlignmentTests.invalidTargetIsRejected|UpdateVersionAlignmentTests.successfulBrewMustStillVerifyInstalledBinary'
```

退出码 1，2 tests / 8 issues：4 个非法 target 错误成功；两类不成功版本 envelope 继续安装 skills（各触发预期失败及 skills 副作用断言）。本地日志：`/tmp/sp208-runtime-review-red.log`。

## 绿灯

```sh
swift test --package-path CLI --no-parallel --filter 'UpdateCommandTests|UpdateVersionAlignmentTests|PublicSkillReleaseValidationTests'
git diff --check
```

最终退出码均为 0，26 tests / 3 suites 全通过（参数化测试另包含多个反例）。本地日志：`/tmp/sp208-runtime-green.log`。

覆盖：Homebrew check/dry-run 解析 latest 且零 host 命令；网络与空解析失败；非法目标（含末尾换行）失败；未确认零 host 命令；brew update 后 formula 落后、领先或 JSON 损坏均不 upgrade；升级命令成功仍必须从新 formula prefix 下的 `bin/triton version --json` 验证 `ok:true` 与目标 exact 一致；旧 binary、领先 binary、损坏 JSON、执行失败、失败 envelope 均禁止 skills；当前目标相同可 skills-only 但必须验证实际 CLI；目标旧于当前拒绝；CLI 成功后 skills 失败保留 `updated:true`、`installedVersion` 与 `cliUpdateAttempted:true`；CLI 核验失败保留 attempted 而不虚报成功。

## 集成约定

- 新响应字段：`installedVersion` 可选；`cliUpdateAttempted` 默认 false。
- 新动作：`verifyHomebrewVersion`、`verifyInstalledVersion`。
- 新失败：`homebrew_version_mismatch`、`installed_version_mismatch`、`downgrade_unsupported`。
- 执行阶段抛 `CLIUpdateExecutionFailure(response:)`，命令层只输出一个保留执行上下文的 envelope；文本同时输出错误码/信息。
- 已将主控 `validatePublicSkillRelease` 接线到解包后安装前，以及安装后 destination 的 `TritonKit.skills`。
- host subprocess 复用现有 bounded concurrent drain，避免 brew stdout/stderr 填满 pipe；600 秒超时与输出超限都明确失败。
- 尚待主控：完整 CLI、真实进程 fake-brew、local gate、文档门禁；真实远端发布/用户验收尚未执行。
