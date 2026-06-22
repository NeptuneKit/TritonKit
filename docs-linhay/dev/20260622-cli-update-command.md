# triton update command

## 决策

`triton update` 是 CLI 自更新入口，面向 agent 和人类用户提供同一套机器可读计划。它不改变 release 发布流程，也不自动修改业务 App 的 SwiftPM / CocoaPods 依赖。

## 命令契约

- `triton update --check --json`：只检查并输出计划，不修改本机。
- `triton update --dry-run --json`：输出计划，不执行任何 destructive action。
- `triton update --version vX.Y.Z --yes --json`：更新到指定 release。
- `triton update --include-skills --skills-dir <dir> --yes --json`：在 CLI 更新后同步 public `TritonKit.skills/` bundle。

JSON 输出模型为 `CLIUpdateResponse`，关键字段包括：

- `currentVersion` / `targetVersion` / `releaseTag`
- `installSource`：`homebrew`、`manual`、`sourceCheckout` 或 `unknown`
- `actions[]`：有序更新计划，标记每步是否 destructive
- `requiresConfirmation`：需要 `--yes` 时为 true
- `updated` / `skillsUpdated`
- `error.code`：失败时的稳定错误码

## 安装来源边界

Homebrew 来源只执行：

```sh
brew update
brew upgrade neptunekit/tap/triton
```

不得直接覆盖 Homebrew Cellar 管理的 binary。

手动 tarball 来源执行：

1. 下载当前架构 release asset：`triton-macos-arm64.tar.gz` 或 `triton-macos-x86_64.tar.gz`。
2. 下载同 release 的 `tritonkit_checksums.txt`。
3. 校验 SHA-256。
4. 解压并替换当前 `triton` binary。

源码 checkout build 来源返回 `source_checkout_update_unsupported`，提示使用本地 SwiftPM release build。

## 验证

- `swift test --package-path CLI --scratch-path .build/cli --filter UpdateCommandTests`
- `.build/cli/arm64-apple-macosx/debug/triton update --check --version v0.1.1 --current-executable /usr/local/bin/triton --json`
- `.build/cli/arm64-apple-macosx/debug/triton schema --command update --json`
