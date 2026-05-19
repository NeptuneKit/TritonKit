# Homebrew Binary Install

## 背景

真实项目接入 TritonKit 时，AI agent 和开发者不应该每次从源码构建 `triton` CLI。TritonKit 需要提供可通过 Homebrew 安装与更新的二进制发布链路，并继续保留 GitHub Release 产物。

## 验收场景

### 场景 1：tag release 产出 Homebrew 可消费的二进制包

- Given 维护者推送 `v*` tag
- When GitHub Actions 发布 release assets
- Then release assets 包含 `triton-macos-arm64.tar.gz` 与 `triton-macos-x86_64.tar.gz`
- And release assets 包含 `tritonkit_checksums.txt`
- And checksum manifest 可用于渲染 Homebrew formula

### 场景 2：Homebrew formula 支持安装与更新

- Given Homebrew tap 仓库配置了 `Formula/triton.rb`
- When 用户执行 `brew install neptunekit/tap/triton`
- Then Homebrew 按当前 Mac 架构下载对应 GitHub Release 二进制包
- And 安装后 `triton version --json` 返回机器可读版本信息
- When 后续推送新 `v*` tag
- Then tap 更新 workflow 用新 release checksum 更新 formula，实现 `brew update && brew upgrade triton`

### 场景 3：非 tag CI 也能验证发布契约

- Given PR 或 `main` push
- When CI 运行
- Then Homebrew formula 渲染脚本通过 fixture 校验
- And CLI 包、skill 包和 checksum manifest 仍作为 workflow artifact 上传

## 边界

- Homebrew 安装只覆盖 macOS `triton` CLI，不安装 iOS embedded runtime；iOS runtime 仍通过 SwiftPM / CocoaPods 接入。
- tap 仓库默认按 `NeptuneKit/homebrew-tap` 处理，可在 workflow dispatch 时通过输入覆盖。
- 若未配置 `TAP_GITHUB_TOKEN`，tag release 仍发布 GitHub assets，但 tap 更新 job 会失败；这是发布配置问题，不影响源码测试。
