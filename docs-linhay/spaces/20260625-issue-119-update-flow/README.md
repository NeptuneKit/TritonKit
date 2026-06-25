# Issue 119: triton update flow

## 背景

GitHub issue #119 反馈 `triton update` 有两个更新链路问题：

- Homebrew 管理的 CLI 执行 `triton update --yes --json` 时，把相对命令 `brew` 当成当前工作目录下的文件解析。
- `triton update --include-skills --skills-dir ... --dry-run --json` 在未显式传 `--version` 时无法解析 latest release。

## 范围

- 修复 CLI update runtime。
- 保持 Web、Wails、HTTP server、CocoaPods / SwiftPM package surfaces 不变。
- 不发布新 tag；本次只修 main 源码并关闭 issue。

## BDD 验收

### 场景 1：Homebrew action 执行走 PATH

Given `triton` 当前安装源为 Homebrew
When `triton update --yes --json` 执行 Homebrew action
Then `brew` 应通过 PATH 解析执行
And 不应尝试执行 `<cwd>/brew`。

### 场景 2：skills 更新可解析 latest release

Given 用户未传 `--version`
When 执行 `triton update --include-skills --skills-dir <dir> --dry-run --json`
Then CLI 应能从 GitHub latest release 入口解析 `v*` tag
And API fallback 失败时返回包含 HTTP status 或解析失败类型的机器可读错误。

## 验证

- 先补 `UpdateCommandTests` 得到红灯。
- focused `swift test --package-path CLI --filter UpdateCommandTests --disable-sandbox --disable-automatic-resolution` 通过。
- 收尾运行 `git diff --check` 与 `docs-linhay/scripts/check-docs.sh`。
