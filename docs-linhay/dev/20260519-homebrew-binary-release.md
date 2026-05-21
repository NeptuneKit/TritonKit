# Homebrew Binary Release

## 设计

TritonKit 的 Homebrew 能力建立在 GitHub Release 二进制资产上：

1. CI 只在 `v*` tag 或手动 `workflow_dispatch` 时进入发布物链路；普通 `main` push / PR 只跑 validate。
2. 发布物链路在 macOS arm64 与 x86_64 runner 上分别构建 release `triton`，但 arm64 完成后即可发布 Release / Homebrew，x86_64 作为后补资产上传。
3. 每个架构产出一个压缩包：
   - `triton-macos-arm64.tar.gz`
   - `triton-macos-x86_64.tar.gz`
4. CI 从触发上下文解析版本号：
   - `v*` tag：去掉前缀 `v` 后作为正式版本。
   - 非 tag：使用 `0.1.0-dev+<short-sha>`。
5. CLI 构建前写入 `Sources/TritonKitCLI/main.swift` 中的 `TritonKitBuildInfo.cliVersion`。
6. skill 打包前写入 `SKILL.md` front matter 的 `metadata.version` 字段。
7. arm64 汇总 job 生成首版 `tritonkit_checksums.txt`，并上传合并后的 `tritonkit-skills.tar.gz` skill 包，包含 `tritonkit-dev-feedback`、`tritonkit-real-project-regression` 与 `tritonkit-emulator-cli-takeover`。
8. `v*` tag 发布时先上传 arm64 CLI、skill 包和首版 checksum 到 GitHub Release。
9. arm64 发布完成后调用 tap 更新 workflow，将 `.github/homebrew/triton.rb.template` 渲染到 `NeptuneKit/homebrew-tap` 的 `Formula/triton.rb`；x86_64 构建完成后补传 x86 包、合并 checksum，并再次更新 tap。

`workflow_dispatch` 只作为发布物集合的云端演练入口：它会生成双架构 CLI、合并 skill 包和 checksum，并上传 workflow artifact；但不会渲染 Homebrew formula。Homebrew formula 只允许在真实 `v*` tag 上用 `GITHUB_REF_NAME` 渲染，避免把 `0.1.0-dev+<short-sha>` 这种 dev 版本拼成无效 tag。

## Formula 契约

当前发布状态：

- `v0.1.0` 已发布到 `NeptuneKit/TritonKit` GitHub Releases。
- `NeptuneKit/homebrew-tap` 已创建，`brew install NeptuneKit/tap/triton` 可用。
- 本地 release CLI fallback 只用于验证未发布源码变更，或在外部网络/Release 资产不可用时应急。

## 本地 CLI 更新安全规则

当本地 fallback 或手动 release asset 需要更新 `~/.local/bin/triton`、`/usr/local/bin/triton` 等已在 `PATH` 上的 CLI 路径时，不能假设旧的 `triton serve` 已退出。若正在运行的 server 进程来自同一个二进制路径，直接 `cp` 覆盖该文件可能导致后续新进程被 macOS 杀掉，表现为无 stdout/stderr 的 exit 137。

安全做法有两种：

1. 先停止 `triton serve`，再覆盖 CLI 路径。
2. 在同一目录写入临时文件，再用 `mv` 原子替换目标路径。

推荐命令：

```bash
swift build --package-path CLI --scratch-path .build/cli -c release --product triton
cp .build/cli/release/triton ~/.local/bin/triton.new
mv ~/.local/bin/triton.new ~/.local/bin/triton
triton version --json
```

维护 README、项目级 skill 或真实项目回归文档时，凡是指导用户手动更新现有 `triton` 可执行文件，都必须使用上述模式，或明确要求先停止正在运行的 `triton serve`。

公式名：`triton`

安装命令：

```bash
brew tap NeptuneKit/tap
brew install triton
```

或：

```bash
brew install NeptuneKit/tap/triton
```

更新命令：

```bash
brew update
brew upgrade triton
```

公式按架构分流；刚发布且 x86_64 后补尚未完成时，formula 可以只有 arm64 分支，后补完成后会再次写入 Intel 分支：

- Apple Silicon 下载 `triton-macos-arm64.tar.gz`
- Intel Mac 下载 `triton-macos-x86_64.tar.gz`

Formula 的 `install` 逻辑必须同时兼容两种 Homebrew staging 布局：

- release archive 原始目录布局：`triton-macos-*/triton`
- Homebrew 解包后扁平布局：`triton`

`docs-linhay/scripts/verify-homebrew-formula.sh` 会检查这两个候选路径，避免回退到只识别原始目录布局导致 `triton binary not found in release archive`。

Formula 的 `test` 逻辑必须解析 `triton version --json`，不要用紧凑 JSON 字符串匹配。CLI 的 JSON 输出允许 pretty-print 空格和换行。

安装后只提供 `triton` CLI。iOS runtime 的 SwiftPM / CocoaPods 接入方式不变。

## Secrets

自动更新 tap 需要在 `NeptuneKit/TritonKit` 配置：

- `TAP_GITHUB_TOKEN`：具备推送 `NeptuneKit/homebrew-tap` 权限的 token。

当前仓库已配置 `TAP_GITHUB_TOKEN`，并通过手动重跑 `update-homebrew-tap.yml` 验证了 `v0.1.0` 的 tap 更新权限。

## 维护者发布入口

维护者默认使用脚本发布新版本：

```bash
docs-linhay/scripts/release.sh 0.1.1
```

脚本会执行：

1. 校验 worktree 干净、`main` 与 `origin/main` 同步、tag 不存在。
2. 校验 `NeptuneKit/TritonKit`、`NeptuneKit/homebrew-tap` 和 `TAP_GITHUB_TOKEN`。
3. 默认运行 `docs-linhay/scripts/verify.sh --local`。
4. 创建 annotated tag 并推送。
5. 观察 tag 触发的 GitHub Actions run，直到 arm64 Release 资产和 Homebrew tap 可用。
6. 下载 release checksum，重新渲染并语法检查 Homebrew formula。
7. 执行 `brew fetch --formula NeptuneKit/tap/triton` 验证 Homebrew 可获取；x86_64 后补 job 继续在 CI 中运行并刷新 Release / tap。

实现注意：发布脚本查找 tag 对应的 GitHub Actions run 时，必须从 `gh run list --json headBranch,url` 返回的 URL 字符串解析 run id。不要使用 `databaseId` 配合 `gh --template` 输出，因为 GitHub CLI 模板可能把大整数转成科学计数法，导致后续 `gh run view` 404。

只检查发布前置条件时使用：

```bash
docs-linhay/scripts/release.sh 0.1.1 --dry-run --skip-local-verify
```

手动触发 `.github/workflows/update-homebrew-tap.yml` 时可以覆盖：

- `version`：例如 `v0.1.0`
- `tap_repository`：默认 `NeptuneKit/homebrew-tap`

## 本地校验

```bash
docs-linhay/scripts/verify.sh --local
docs-linhay/scripts/verify-homebrew-formula.sh
docs-linhay/scripts/verify-version-stamping.sh
```

`verify.sh --local` 是本仓库默认交付门禁。`verify-homebrew-formula.sh` 使用 fixture checksum 渲染 formula，并用 `ruby -c` 做语法检查。`verify-version-stamping.sh` 验证版本解析、CLI Swift 版本常量写入和 skill `metadata.version` 写入。

## 风险

- GitHub hosted macOS runner 的具体镜像会变化；workflow 用 runner label 明确区分 arm64 与 Intel，避免用 `uname -m` 的偶然结果定义发布契约。
- tap 自动更新依赖外部仓库权限；如果 secret 缺失，release assets 仍可用，维护者可以用同一个 workflow 手动重跑。
