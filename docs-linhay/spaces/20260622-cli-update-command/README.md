# triton update command

## 背景

TritonKit 已通过 GitHub Release 发布 macOS arm64 / x86_64 CLI tarball、`tritonkit_checksums.txt`、Homebrew formula 和 public skills bundle。外部用户目前依赖 `tritonkit-update` skill 手动执行更新步骤，CLI 本身还没有统一的机器可读自更新入口。

## 目标

新增 `triton update`，让 agent 和用户可以从 CLI 检查、计划并执行 TritonKit CLI 更新，同时保持 release 资产、Homebrew 与 public skills 的版本边界清晰。

## 范围

- 覆盖 macOS `triton` CLI 自更新。
- Homebrew 安装来源只通过 `brew update` / `brew upgrade neptunekit/tap/triton` 更新，不直接覆盖 Homebrew 管理的 binary。
- 手动 tarball 安装来源可从 GitHub Release 下载当前架构资产，校验 `tritonkit_checksums.txt` 后原子替换当前 binary。
- 支持 `--check` / `--dry-run` / `--yes` / `--version vX.Y.Z` / `--include-skills`。
- 输出必须支持 JSON，包含当前版本、目标版本、安装来源、计划动作、是否需要确认、是否更新成功和错误。

## 非目标

- 不自动修改业务 App 的 SwiftPM / CocoaPods 依赖。
- 不移动已发布 tag，不改变 release 发布流程。
- 不新增 Web/Wails 更新入口。

## BDD 场景

### 场景 1：只检查更新

Given 当前 CLI 版本为 `0.1.0`
When 用户运行 `triton update --check --version v0.1.1 --json`
Then CLI 输出 `ok=true` 的 JSON
And `updateAvailable=true`
And `actions` 描述更新计划
And 不修改本机文件。

### 场景 2：Homebrew 安装

Given 当前 `triton` binary 位于 Homebrew Cellar
When 用户运行 `triton update --yes --json`
Then CLI 执行 `brew update` 和 `brew upgrade neptunekit/tap/triton`
And 不直接写入 Cellar binary。

### 场景 3：手动 tarball 安装

Given 当前 `triton` binary 是手动安装文件
When 用户运行 `triton update --yes --version v0.1.1 --json`
Then CLI 下载当前架构 tarball 和 checksum manifest
And 校验 tarball SHA-256
And 解压并原子替换当前 binary。

### 场景 4：同步 public skills

Given 用户提供 `--include-skills --skills-dir <dir>`
When 更新计划执行成功
Then CLI 下载同版本 `tritonkit-skills.tar.gz`
And 替换 `<dir>/TritonKit.skills`
And JSON 中报告 skills bundle 更新结果。

## 验收

- `triton update --help` 可见。
- `triton schema --command update --json` 暴露机器可读契约。
- focused CLI tests 覆盖安装来源检测、asset/checksum 解析、dry-run 计划和 schema contract。
- 文档和 memory 记录命令边界。
