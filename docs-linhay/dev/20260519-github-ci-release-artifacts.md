# GitHub CI Release Artifacts

## 背景

TritonKit 需要把云端验证和发布产物固定下来：使用者不仅要拿到 `triton` CLI，也要拿到项目级 skill 包，尤其是开发阶段反馈工作流 `tritonkit-dev-feedback`。

## Workflow

新增 `.github/workflows/ci.yml`：

1. `push` 到 `main`、`pull_request` 到 `main`、手动 `workflow_dispatch` 时运行。
2. tag `v*` 推送时，在同一 workflow 内创建或复用 GitHub Release，并上传产物。
3. 执行 `swift test`。
4. 执行 `swift build -c release --product triton`。
5. 按架构打包 CLI：
   - `triton-macos-arm64.tar.gz`
   - `triton-macos-arm64.zip`
   - `triton-macos-x86_64.tar.gz`
   - `triton-macos-x86_64.zip`
6. CI 写入版本号：
   - CLI：更新 `Sources/TritonKitCLI/main.swift` 中的 `TritonKitBuildInfo.cliVersion`，`triton version --json` 输出该版本。
   - skill：打包前向 `SKILL.md` front matter 写入 `metadata.version`。
   - tag `v1.2.3` 解析为 `1.2.3`；非 tag 构建解析为 `0.1.0-dev+<short-sha>`。
7. 生成 checksum manifest：
   - `tritonkit_checksums.txt`
8. 打包 skill：
   - `tritonkit-dev-feedback.tar.gz`
   - `tritonkit-dev-feedback.zip`
   - `tritonkit-real-project-regression.tar.gz`
   - `tritonkit-real-project-regression.zip`
9. 所有包先作为 workflow artifact 上传；tag 发布时再作为 GitHub Release asset 上传。
10. tag 发布完成后触发 Homebrew tap 更新 workflow。

## 产物契约

发布产物必须至少包含：

1. `triton` CLI 可执行文件包，必须同时覆盖 macOS arm64 与 x86_64。
2. 面向外部使用者的项目级 skill 包，当前至少包括 `.agents/skills/tritonkit-dev-feedback` 与 `.agents/skills/tritonkit-real-project-regression`。
3. `tritonkit_checksums.txt`，用于 Homebrew formula 渲染和用户校验。
4. CLI 与 skill 包必须携带同一个 CI 解析出的版本号；skill 使用 `metadata.version`，保持 skill front matter 兼容。

后续新增面向使用者的项目级 skill 时，应同步纳入 CI/release packaging。

## Homebrew

新增 Homebrew 二进制安装链路：

1. `.github/homebrew/triton.rb.template` 定义 `triton` formula 模板。
2. `docs-linhay/scripts/render-homebrew-formula.sh` 从 release checksum manifest 渲染 formula。
3. `.github/workflows/update-homebrew-tap.yml` 支持 workflow call 与手动触发，默认更新 `NeptuneKit/homebrew-tap`。
4. `v*` tag 发布后，CI 自动调用 tap 更新 job；需要配置 `TAP_GITHUB_TOKEN`。

用户安装：

```bash
brew install NeptuneKit/tap/triton
```

用户更新：

```bash
brew update
brew upgrade triton
```

## 验证

- 本地运行 `swift test` 通过。
- 本地运行 `swift build -c release --product triton` 通过。
- 使用临时目录复现 CI 打包命令，生成 CLI 与 skill 的 `.tar.gz` / `.zip` 产物。
- 运行 `docs-linhay/scripts/verify-homebrew-formula.sh`，验证 formula 模板可用。
- 运行 `docs-linhay/scripts/verify-version-stamping.sh`，验证 CI 版本解析、Swift 版本常量写入和 skill front matter `metadata.version` 写入。
- 用 Python YAML parser 校验 `.github/workflows/ci.yml` 语法可解析。
