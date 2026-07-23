# GitHub CI Release Artifacts

## 背景

TritonKit 需要把云端验证和发布产物固定下来：使用者不仅要拿到 `triton` CLI，也要拿到项目级 skill 包，尤其是开发阶段反馈工作流 `tritonkit-dev-feedback`。

## Workflow

新增 `.github/workflows/ci.yml` 与独立 `.github/workflows/release.yml`：

1. `push` 到 `main`、`pull_request` 到 `main`、手动 `workflow_dispatch` 时运行 validate。
2. 普通 `main` push / PR 只阻塞 validate，不等待双架构 CLI artifact 与 release asset 打包。
3. `v*` tag 触发独立 `Release` workflow 构建 CLI、skill bundle、checksum 和 release assets；`CI` workflow 中的 `v*` tag validate mode 固定为 `contracts`，只做发布脚本、Homebrew、版本 stamping、CI 分类和 release asset 契约快检，避免重复等待 main/PR 已覆盖的 Swift tests 与 CocoaPods lint。
4. tag `v*` 推送时，arm64 CLI 产物完成后先创建或复用 GitHub Release，并上传 arm64 CLI、skill 包与 checksum；x86_64 CLI 产物在 arm64 macOS runner 上交叉编译后由后补 job 上传到同一个 Release。
5. validate 先调用 `docs-linhay/scripts/ci-validate-mode.sh` 分类变更范围：
   - docs/skill-only：运行 `docs-linhay/scripts/verify.sh --ci-docs`，覆盖文档结构、diff whitespace、版本脚本和 release/skill packaging 契约。
   - swift-only：只跑 Swift tests、CLI release build 与 release/homebrew contract checks，跳过 CocoaPods lint；适用于 `Sources/TritonKitCLI/`、`CLI/Package.swift`、`CLI/Package.resolved`、`Tests/`、`Package.swift`、`Package.resolved`。
   - contracts-only：只跑 release/homebrew/CI contract checks；适用于 `.github/workflows/` 与发布、版本、Homebrew、CI 分类相关脚本。
   - podkit-only：跑 Swift tests、`TritonKit.podspec` lint 与 contract checks；适用于 `Sources/TritonKit/` 与 `TritonKit.podspec`。
   - full：运行 Swift tests、`TritonKit.podspec` lint、Homebrew formula template、版本脚本和 release automation 契约；适用于未分类脚本和 fixtures。
6. CI 中保留名为 `Validate` 的聚合 job；full validate 内部拆成 `Validate Swift Tests`、`Validate Podspec (TritonKit)` 与 `Validate Contracts` 并行执行，降低 wall-clock 等待时间，同时保持分支保护只需依赖稳定的 `Validate`。`docs` 与 `contracts` 短路径的实际检查直接在 `Classify Validate Scope` job 内完成，避免额外启动一个 Ubuntu job。
7. `Validate Swift Tests` 使用 `actions/cache@v4` 缓存 `.build` 与 SwiftPM dependency cache，cache key 基于根 package 与 `CLI/` package 的 manifest / resolved 文件。
8. CLI build 执行 `swift build --package-path CLI --scratch-path .build/cli -c release --product triton`，根 `Package.swift` 只保留 iOS embedded SDK 依赖边界。
9. 按架构打包 CLI，发布顺序为 arm64 先发、x86_64 后补；x86_64 使用 SwiftPM `--triple x86_64-apple-macosx14.0` 在 arm64 macOS runner 上交叉编译，并用 `file` 校验产物架构：
   - `triton-macos-arm64.tar.gz`
   - `triton-macos-x86_64.tar.gz`
10. CI 写入版本号与 build metadata：
   - CLI：更新 `Sources/TritonKitCLI/CLIBuildInfo.swift` 中的 `TritonKitBuildInfo.cliVersion`，`triton version --json` 输出该版本。
   - skill：打包前向 `SKILL.md` front matter 写入 `metadata.version`。
   - skill 包：在 `TritonKit.skills/BUILD_INFO.json` 写入包名、版本、release tag、git commit / dirty flag、构建时间与包含的 skill 列表。
   - tag `v1.2.3` 解析为 `1.2.3`；非 tag 构建解析为 `0.1.0-dev+<short-sha>`。
11. 生成 checksum manifest：
   - `tritonkit_checksums.txt`
12. 打包 skill：
   - `tritonkit-skills.tar.gz`，顶层包含 `TritonKit.skills/`，其内包含 `tritonkit-dev-feedback`、`tritonkit-emulator-cli-takeover`、`tritonkit-real-project-regression` 与 `tritonkit-update`
13. 所有包先作为 workflow artifact 上传；tag 发布时 arm64 包与 skill 包先作为 GitHub Release asset 上传，x86_64 包成功后再补传。
14. arm64 发布完成后触发 Homebrew tap 更新 workflow；x86_64 后补完成后再次触发 tap 更新，让 Intel formula 分支拿到 checksum。
15. 整体发布必须先同步所有对外包入口版本：`TritonKit.podspec`、`Web/package.json` 与 `Web/package-lock.json` 都必须等于 release tag 版本；`release.sh` 在打 tag 前通过 `verify-release-package-versions.sh` 强制校验。
16. Release workflow 的 arm64 与 x86_64 build job 使用 `actions/cache@v4` 缓存 SwiftPM dependency/build 输出；cache key 分别包含 `release-cli-arm64` 与 `release-cli-x86_64`，避免为了 Intel 产物回退到慢 Intel runner。

Skill 源码分层约束：release packaging 只能读取 `TritonKit.skills/`。`.agents/skills/` 只存放 repo 维护、治理、实现和监督用 skill，不进入 `tritonkit-skills.tar.gz`，也不作为 release packaging 源。

Skill 打包流程参考 `harmony-next.skills` 的独立脚本式产物生成：TritonKit 使用 `docs-linhay/scripts/package-public-skills.py` 统一完成 public skill 复制、版本 stamp、命令存在性校验、`TritonKit.skills/BUILD_INFO.json` 写入和 `tritonkit-skills.tar.gz` 生成。与 `harmony-next.skills` 不同，TritonKit 保持既有 release 契约：只发布合并后的 tar.gz，不发布 `.skill.zip` 或单个 skill tarball。

Public skill 中的 literal `triton` 命令必须通过 `docs-linhay/scripts/verify-public-skill-commands.py`。它以 `public-skill-command-schema.json` 为事实快照校验所有 root，并严格校验 `act` / `debug` 子命令；快照由 CLI test 与 `commandSchemas()` 全量对齐。这样 `find/tap/type/paste/clear/focus/set-text/input` 被误写回顶层，或 `ax/geometry` 未放到 `debug` 下时，会在 tarball 创建前失败。当前官方 bundle 不包含 `tritonkit-runtime`；外部同名 skill 不得被描述成 TritonKit release asset 成员。

安装与升级约定：外部用户默认把整个 `TritonKit.skills/` 文件夹放到对应 agent skills 目录下。若用户曾按旧文档安装过顶层目录 `tritonkit-dev-feedback`、`tritonkit-emulator-cli-takeover`、`tritonkit-real-project-regression` 或 `tritonkit-update`，升级到本版时先删除这些旧目录，再安装 `TritonKit.skills/`。维护者可用 `docs-linhay/scripts/install-public-skills.sh <agent-skills-dir> [--from-tar tritonkit-skills.tar.gz]` 自动完成删除与安装。

补充约束：`workflow_dispatch` 的非 tag 构建只验证 release asset 集合并上传 workflow artifact，不渲染 Homebrew formula。原因是非 tag 版本形如 `0.1.0-dev+<short-sha>`，不是可发布的 Homebrew release tag；只有真实 `v*` tag 构建才使用 `GITHUB_REF_NAME` 渲染 formula 并做 Ruby 语法检查。

GitHub Actions 的 `actions/checkout` 固定使用 Node 24 兼容版本，避免 Node.js 20 deprecation annotation 干扰失败判断。

## 产物契约

发布产物必须至少包含：

1. `triton` CLI 可执行文件包，最终必须同时覆盖 macOS arm64 与 x86_64；arm64 是首发门槛，x86_64 是后补资产。
2. 面向外部使用者的项目级 skill 合并包 `tritonkit-skills.tar.gz`，当前至少包括 `TritonKit.skills/tritonkit-dev-feedback`、`TritonKit.skills/tritonkit-real-project-regression`、`TritonKit.skills/tritonkit-emulator-cli-takeover` 与 `TritonKit.skills/tritonkit-update`。
3. `tritonkit_checksums.txt`，用于 Homebrew formula 渲染和用户校验。
4. CLI 与 skill 包必须携带同一个 CI 解析出的版本号；skill 使用 `metadata.version`，保持 skill front matter 兼容。

后续新增面向使用者的项目级 skill 时，应同步纳入 CI/release packaging。

## v0.2.12 发布边界

`v0.2.12` 汇总 GitHub issues #146–#154 的修复，发布边界保持为 macOS 双架构 `triton` CLI、checksum manifest、四个 public skills 的合并包，以及同步版本的 SwiftPM/CocoaPods/Web 分发入口。本次不扩大到真机产品面、Web/Wails 业务控制入口或 CocoaPods trunk 自动推送；podspec 只随 tag 对齐并完成 lint，是否推送 trunk 必须单独执行并记录。

tag 前必须先在 `main` 完成版本契约、本地门禁和远端 validate；tag 后再以 Release assets、checksum、Homebrew formula/安装测试、CLI version、public skill build info 与仓库外 packaged Web HTTP smoke 作为完成证据。arm64 首发成功不代表完整发布完成，必须等待 x86_64 后补 job 与第二次 tap 刷新成功。

2026-07-20 的 `v0.2.12` 发布已按上述完整口径验收：Release workflow 双架构、两次 tap 更新均成功，四个资产与 checksum 一致，Homebrew 从 `0.2.9` 升级到 `0.2.12` 后通过 formula test，仓库外 packaged Web 在 `127.0.0.1:34127` 返回 HTTP 200。CocoaPods 仅完成 podspec lint，未推送 trunk。

## v0.2.15 发布边界

`v0.2.15` 汇总 `v0.2.14` 之后 GitHub issues #159–#165 的修复：UIKit alert modal tap boundary、Xcode one-off build settings、embedded screenshot PNG 契约、iOS 真机 launch selector、Xcode 26.6 xcresult shape、iOS Simulator host-composited evidence screenshot，以及 Xcode schemes discovery/timeout recovery。

本次继续保持既有完整发布面：macOS arm64/x86_64 `triton` CLI、bundled Web、checksum manifest、四个 public skills、Homebrew formula，以及同 tag 版本的 SwiftPM/CocoaPods/Web 分发入口。CocoaPods 只要求 `TritonKit.podspec` 版本对齐并通过 lint，不自动推送 trunk；若后续实际推送，必须另行记录凭据、命令与结果。

发布完成判定仍需等待 x86_64 backfill 和第二次 tap 刷新，并独立复验公开 checksum、双架构 Mach-O、CLI/skill build info、Homebrew upgrade/test 与仓库外 packaged Web HTTP smoke；不能只以 arm64 Release 已出现作为完成。

2026-07-23 的 `v0.2.15` 已按上述完整口径发布：Release workflow `29974713055` 的双架构构建、arm64 首发、x86_64 backfill 与两次 tap 更新全部通过；重新下载的三个 tarball 与公开 checksum manifest 一致，两个 CLI 分别验证为 arm64/x86_64 Mach-O 且均报告 `0.2.15`。public skill bundle 的 `BUILD_INFO.json` 与四个必需 skill 均为 `v0.2.15` / commit `29798f0d`。Homebrew 从 `0.2.14` 升级到 `0.2.15` 并通过 formula test，仓库外 packaged Web 返回 HTTP 200。CocoaPods 仅完成 podspec lint，未推送 trunk。

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
- 本地运行 `swift build --package-path CLI --scratch-path .build/cli -c release --product triton` 通过。
- 本地运行 `docs-linhay/scripts/verify.sh --local` 覆盖项目级默认门禁。
- CI docs/skill-only fast path 使用 `docs-linhay/scripts/verify.sh --ci-docs`；只允许 README、AGENTS、docs/memory/references/screenshots、`TritonKit.skills/` 与 `.agents/skills/` 进入 fast path，`Sources/`、`Tests/`、podspec、workflow、`docs-linhay/scripts/` 和 fixtures 默认触发 full validate。
- 本地运行 `docs-linhay/scripts/verify-ci-validate-mode.sh` 验证 fast/full 分类边界。
- Swift-only fast path 会跳过 CocoaPods lint，只允许 CLI target、tests 和 SwiftPM manifest/lockfile；iOS runtime 与 Shared model 改动仍触发 full validate。
- Contract-only fast path 会跳过 macOS Swift 和 CocoaPods job，只验证 CI/release/Homebrew 脚本契约；`v*` tag 固定走该路径，让 release asset packaging 尽快启动。podkit-only 只保留 `TritonKit.podspec` lint。
- Docs-only 与 contract-only fast path 不再单独启动 `Validate Docs` / `Validate Contracts` job；它们复用分类 job 的 checkout 与 runner，聚合 `Validate` 只负责检查 `Classify Validate Scope` 成功。
- Full validate 在 CI 中并行运行 Swift tests、`TritonKit.podspec` lint 与 release/homebrew 契约检查；本地仍可用 `docs-linhay/scripts/verify.sh --ci-validate` 串行复现完整门禁。
- 使用临时目录复现 CI 打包命令，生成 CLI 与 skill 的 `.tar.gz` 产物。
- 公开资产复验必须下载到新的临时目录，并等待 `gh release download` 完整退出且返回成功后再执行 `shasum -a 256 -c`、`gzip -t` 与解包检查。若下载中的本地文件明显小于 Release API 记录的 size，且 `gh release download` 进程仍存在，应先等待下载完成；不能把流式下载中的截断文件误判为远端 checksum 损坏，更不能据此覆盖已发布资产。
- 运行 `docs-linhay/scripts/verify-skill-package.sh`，验证 `package-public-skills.py` 生成的 `tritonkit-skills.tar.gz` 顶层包含 `TritonKit.skills/`、四个 public skills、版本 stamp 和 `BUILD_INFO.json`，验证安装脚本会删除旧四个独立目录，并用注入的 retired root fixture 证明旧命令层级不能进入 release 包。
- 运行 `docs-linhay/scripts/verify-homebrew-formula.sh`，验证 formula 模板可用。
- 运行 `docs-linhay/scripts/verify-version-stamping.sh`，验证 CI 版本解析、Swift 版本常量写入和 skill front matter `metadata.version` 写入。
- Release tarball README 校验必须先把 `tar -xOf ... README.txt` 写入临时文件，再对临时文件执行 `grep -Fq`；禁止直接把 `tar` 输出管给 `grep -q`，否则 grep 命中后提前关闭 pipe，GNU tar 可能在 x86_64 runner 上因 stdout write error 失败。
- 用 Python YAML parser 校验 `.github/workflows/ci.yml` 与 `.github/workflows/release.yml` 语法可解析。
- `docs-linhay/scripts/verify-release-automation.sh` 必须防止 Release workflow 回退到 `macos-15-intel`，并检查 x86_64 cross build triple、架构校验、SwiftPM cache key 与 x86 publish checkout。

## 交付辅助脚本

- `docs-linhay/scripts/gh-run-summary.sh --watch <run-id>`：低噪音观察 GitHub Actions run，只输出 job 状态和 URL；失败后再进入详细日志。
- `docs-linhay/scripts/gh-issue-comment-file.sh <issue> <markdown-file>`：通过 `gh issue comment --body-file` 发送 Markdown，避免正文里的反引号命令被 shell 执行。
- `docs-linhay/scripts/check-docs.sh`：固定 TritonKit 的 文档门禁入口。当前 文档记录 CLI 不支持 `update/embed` 按 collection 过滤，所以脚本仍会执行全量 `docs-linhay/scripts/check-docs.sh`。
