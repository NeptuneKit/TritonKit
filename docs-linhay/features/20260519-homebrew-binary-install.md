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

### 场景 4：首个 release / tap 不存在时文档给出可执行 fallback

- Given `NeptuneKit/TritonKit` 还没有 GitHub Release
- And `NeptuneKit/homebrew-tap` 还不存在
- When 外部 AI agent 或开发者按 README / skill 接入 TritonKit
- Then 文档先提示使用 `swift build -c release --product triton` 构建本地 release CLI
- And Homebrew 被标记为首个 `v*` release 与 tap 可用后的安装路径

### 场景 5：运行中的 CLI 更新使用原子替换

- Given `triton serve --host 127.0.0.1 --port 19421` 可能正从 `~/.local/bin/triton` 运行
- When 开发者或 AI agent 将本地构建的 `.build/release/triton` 更新到该路径
- Then README 与项目级 skill 必须推荐先复制到临时文件，再用同目录 `mv` 原子替换
- And 文档必须说明也可以先停止 `triton serve`，再覆盖原路径
- And 禁止推荐直接 `cp .build/release/triton ~/.local/bin/triton` 覆盖正在使用的 CLI 路径

## 边界

- Homebrew 安装只覆盖 macOS `triton` CLI，不安装 iOS embedded runtime；iOS runtime 仍通过 SwiftPM / CocoaPods 接入。
- 首个 release / tap 未发布前，对外接入文档和 skill 必须把本地 release CLI fallback 放在 Homebrew 之前。
- 本地 fallback 或手动 release asset 更新现有 CLI 路径时，若 `triton serve` 可能仍在运行，必须使用临时文件加 `mv` 的原子替换方式，或先停止服务。
- tap 仓库默认按 `NeptuneKit/homebrew-tap` 处理，可在 workflow dispatch 时通过输入覆盖。
- 若未配置 `TAP_GITHUB_TOKEN`，tag release 仍发布 GitHub assets，但 tap 更新 job 会失败；这是发布配置问题，不影响源码测试。
