# Homebrew Binary Release

## 设计

TritonKit 的 Homebrew 能力建立在 GitHub Release 二进制资产上：

1. CI 在 macOS arm64 与 x86_64 runner 上分别构建 release `triton`。
2. 每个架构产出一个压缩包：
   - `triton-macos-arm64.tar.gz`
   - `triton-macos-arm64.zip`
   - `triton-macos-x86_64.tar.gz`
   - `triton-macos-x86_64.zip`
3. CI 从触发上下文解析版本号：
   - `v*` tag：去掉前缀 `v` 后作为正式版本。
   - 非 tag：使用 `0.1.0-dev+<short-sha>`。
4. CLI 构建前写入 `Sources/TritonKitCLI/main.swift` 中的 `TritonKitBuildInfo.cliVersion`。
5. skill 打包前写入 `SKILL.md` front matter 的 `metadata.version` 字段。
6. 汇总 job 生成 `tritonkit_checksums.txt`，并继续上传 `tritonkit-dev-feedback` 与 `tritonkit-real-project-regression` skill 包。
7. `v*` tag 发布时上传所有资产到 GitHub Release。
8. tag 发布完成后调用 tap 更新 workflow，将 `.github/homebrew/triton.rb.template` 渲染到 `NeptuneKit/homebrew-tap` 的 `Formula/triton.rb`。

## Formula 契约

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

公式按架构分流：

- Apple Silicon 下载 `triton-macos-arm64.tar.gz`
- Intel Mac 下载 `triton-macos-x86_64.tar.gz`

安装后只提供 `triton` CLI。iOS runtime 的 SwiftPM / CocoaPods 接入方式不变。

## Secrets

自动更新 tap 需要在 `NeptuneKit/TritonKit` 配置：

- `TAP_GITHUB_TOKEN`：具备推送 `NeptuneKit/homebrew-tap` 权限的 token。

手动触发 `.github/workflows/update-homebrew-tap.yml` 时可以覆盖：

- `version`：例如 `v0.1.0`
- `tap_repository`：默认 `NeptuneKit/homebrew-tap`

## 本地校验

```bash
docs-linhay/scripts/verify-homebrew-formula.sh
docs-linhay/scripts/verify-version-stamping.sh
```

第一个脚本使用 fixture checksum 渲染 formula，并用 `ruby -c` 做语法检查。第二个脚本验证版本解析、CLI Swift 版本常量写入和 skill `metadata.version` 写入。

## 风险

- GitHub hosted macOS runner 的具体镜像会变化；workflow 用 runner label 明确区分 arm64 与 Intel，避免用 `uname -m` 的偶然结果定义发布契约。
- tap 自动更新依赖外部仓库权限；如果 secret 缺失，release assets 仍可用，维护者可以用同一个 workflow 手动重跑。
