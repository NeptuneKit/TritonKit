# GitHub CI Release Artifacts

## 背景

TritonKit 需要把云端验证和发布产物固定下来：使用者不仅要拿到 `triton` CLI，也要拿到项目级 skill 包，尤其是开发阶段反馈工作流 `tritonkit-dev-feedback`。

## Workflow

新增 `.github/workflows/ci.yml`：

1. `push` 到 `main`、`pull_request` 到 `main`、手动 `workflow_dispatch` 时运行 validate。
2. 普通 `main` push / PR 只阻塞 validate，不等待双架构 CLI artifact 与 release asset 打包。
3. `v*` tag 或手动 `workflow_dispatch` 才运行双架构 CLI build 和 release asset packaging。
4. tag `v*` 推送时，在同一 workflow 内创建或复用 GitHub Release，并上传产物。
5. validate 先调用 `docs-linhay/scripts/ci-validate-mode.sh` 分类变更范围：
   - docs/skill-only：运行 `docs-linhay/scripts/verify.sh --ci-docs`，覆盖文档结构、diff whitespace、版本脚本和 release/skill packaging 契约。
   - full：运行 `docs-linhay/scripts/verify.sh --ci-validate`，覆盖 Swift 测试、CocoaPods spec、Homebrew formula template、版本脚本和 release automation 契约。
6. CLI build 执行 `swift build -c release --product triton`。
7. 按架构打包 CLI：
   - `triton-macos-arm64.tar.gz`
   - `triton-macos-x86_64.tar.gz`
8. CI 写入版本号：
   - CLI：更新 `Sources/TritonKitCLI/main.swift` 中的 `TritonKitBuildInfo.cliVersion`，`triton version --json` 输出该版本。
   - skill：打包前向 `SKILL.md` front matter 写入 `metadata.version`。
   - tag `v1.2.3` 解析为 `1.2.3`；非 tag 构建解析为 `0.1.0-dev+<short-sha>`。
9. 生成 checksum manifest：
   - `tritonkit_checksums.txt`
10. 打包 skill：
   - `tritonkit-skills.tar.gz`，包含 `tritonkit-dev-feedback`、`tritonkit-emulator-cli-takeover` 与 `tritonkit-real-project-regression`
11. 所有包先作为 workflow artifact 上传；tag 发布时再作为 GitHub Release asset 上传。
12. tag 发布完成后触发 Homebrew tap 更新 workflow。

Skill 源码分层约束：release packaging 只能读取 `.agents/tritonkit-skills/public/`。`.agents/tritonkit-skills/internal/` 只存放 repo 维护、治理、实现和监督用 skill，不进入 `tritonkit-skills.tar.gz`；`.agents/skills/` 只作为本地 agent discovery symlink，不作为打包源。

补充约束：`workflow_dispatch` 的非 tag 构建只验证 release asset 集合并上传 workflow artifact，不渲染 Homebrew formula。原因是非 tag 版本形如 `0.1.0-dev+<short-sha>`，不是可发布的 Homebrew release tag；只有真实 `v*` tag 构建才使用 `GITHUB_REF_NAME` 渲染 formula 并做 Ruby 语法检查。

GitHub Actions 的 `actions/checkout` 固定使用 Node 24 兼容版本，避免 Node.js 20 deprecation annotation 干扰失败判断。

## 产物契约

发布产物必须至少包含：

1. `triton` CLI 可执行文件包，必须同时覆盖 macOS arm64 与 x86_64。
2. 面向外部使用者的项目级 skill 合并包 `tritonkit-skills.tar.gz`，当前至少包括 `.agents/tritonkit-skills/public/tritonkit-dev-feedback`、`.agents/tritonkit-skills/public/tritonkit-real-project-regression` 与 `.agents/tritonkit-skills/public/tritonkit-emulator-cli-takeover`。
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
- 本地运行 `docs-linhay/scripts/verify.sh --local` 覆盖项目级默认门禁。
- CI docs/skill-only fast path 使用 `docs-linhay/scripts/verify.sh --ci-docs`；只允许 README、AGENTS、docs/memory/references/screenshots 与 `.agents/tritonkit-skills/` / `.agents/skills/` 进入 fast path，`Sources/`、`Tests/`、podspec、workflow、`docs-linhay/scripts/` 和 fixtures 默认触发 full validate。
- 本地运行 `docs-linhay/scripts/verify-ci-validate-mode.sh` 验证 fast/full 分类边界。
- 使用临时目录复现 CI 打包命令，生成 CLI 与 skill 的 `.tar.gz` 产物。
- 运行 `docs-linhay/scripts/verify-homebrew-formula.sh`，验证 formula 模板可用。
- 运行 `docs-linhay/scripts/verify-version-stamping.sh`，验证 CI 版本解析、Swift 版本常量写入和 skill front matter `metadata.version` 写入。
- 用 Python YAML parser 校验 `.github/workflows/ci.yml` 语法可解析。

## 交付辅助脚本

- `docs-linhay/scripts/gh-run-summary.sh --watch <run-id>`：低噪音观察 GitHub Actions run，只输出 job 状态和 URL；失败后再进入详细日志。
- `docs-linhay/scripts/gh-issue-comment-file.sh <issue> <markdown-file>`：通过 `gh issue comment --body-file` 发送 Markdown，避免正文里的反引号命令被 shell 执行。
- `docs-linhay/scripts/qmd-sync.sh`：固定 TritonKit 的 qmd 同步入口。当前 qmd CLI 不支持 `update/embed` 按 collection 过滤，所以脚本仍会执行全量 `qmd update` 与 `qmd embed`。
