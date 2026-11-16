# GitHub CI Release Artifacts

当前发行仅 macOS arm64，iOS 通过 SwiftPM（iOS 16+）。x86_64 与 CocoaPods 已于 2026-11-10 退役，带版本号的旧发布记录保留当时的证据。Homebrew 更新前由 `verify-public-release-assets.py` 匿名验证精确公开稳定 tag、checksum 与 arm64 字节大小/SHA，成功后仅传递已验证 arm64 checksum；draft/prerelease、404、超时、截断或歧义 manifest 均在 tap 写入前失败。离线测试见 [SP-283](../spaces/SP-283-homebrew-public-assets/README.md)。

## 背景

TritonKit 需要把云端验证和发布产物固定下来：使用者不仅要拿到 `triton` CLI，也要拿到项目级 skill 包，尤其是开发阶段反馈工作流 `tritonkit-dev-feedback`。

## Workflow

1. [CI](../../.github/workflows/ci.yml) 给 `main` push、PR 和手动 `workflow_dispatch` 提供 `Validate`。手动触发仅做校验。CI 在 `v*` tag 上使用 `contracts` 短路径。
2. [分类器](../scripts/ci-validate-mode.sh)决定 `docs`、`contracts`、`swift` 或 `full`。前两种在分类 job 内执行对应检查，后两种运行 `Validate Swift Tests` 和 `Validate Contracts`。现行 Swift job 使用 `swift test --no-parallel` 和独立 CLI release build。
3. [Release](../../.github/workflows/release.yml) 由 `v*` tag 触发。先运行发布契约检查，再构建 arm64 CLI、bundled Web 和 unsigned Runner，打包 public skills 与 checksum。打包 job 上传 workflow artifact 和 GitHub Release 资产，再调用 tap 更新流程。
4. 构建从 tag 解析版本。CLI 在 `CLIBuildInfo.swift` 注入版本，`triton version --json` 输出该值。skill 在 `metadata.version` 注入同一版本，`TritonKit.skills/BUILD_INFO.json` 同时记录 tag、提交、工作区状态、构建时间和包内清单。
5. tap 流程在公开资产验证通过后写入 formula。整体发布还需核对 `Web/package.json`、`Web/package-lock.json` 和 SwiftPM Git tag 的版本一致。运行步骤与实际安装证明见 [发布治理 skill](../../.agents/skills/tritonkit-release-package-governance/SKILL.md)。

Skill 源码分层约束：release packaging 只能读取 `TritonKit.skills/`。`.agents/skills/` 只存放 repo 维护、治理、实现和监督用 skill，不进入 `tritonkit-skills.tar.gz`，也不作为 release packaging 源。

Skill 打包流程参考 `harmony-next.skills` 的独立脚本式产物生成：TritonKit 使用 `docs-linhay/scripts/package-public-skills.py` 统一完成 public skill 复制、版本 stamp、命令存在性校验、`TritonKit.skills/BUILD_INFO.json` 写入和 `tritonkit-skills.tar.gz` 生成。与 `harmony-next.skills` 不同，TritonKit 保持既有 release 契约：只发布合并后的 tar.gz，不发布 `.skill.zip` 或单个 skill tarball。

Public skill 中的 literal `triton` 命令必须通过 `docs-linhay/scripts/verify-public-skill-commands.py`。它以 `public-skill-command-schema.json` 为事实快照校验所有 root，并严格校验 `act` / `debug` 子命令；快照由 CLI test 与 `commandSchemas()` 全量对齐。这样 `find/tap/type/paste/clear/focus/set-text/input` 被误写回顶层，或 `ax/geometry` 未放到 `debug` 下时，会在 tarball 创建前失败。当前官方 bundle 不包含 `tritonkit-runtime`；外部同名 skill 不得被描述成 TritonKit release asset 成员。

安装与升级约定：外部用户默认把整个 `TritonKit.skills/` 文件夹放到对应 agent skills 目录下。若用户曾按旧文档安装过顶层目录 `tritonkit-dev-feedback`、`tritonkit-emulator-cli-takeover`、`tritonkit-real-project-regression` 或 `tritonkit-update`，升级到本版时先删除这些旧目录，再安装 `TritonKit.skills/`。维护者可用 `docs-linhay/scripts/install-public-skills.sh <agent-skills-dir> [--from-tar tritonkit-skills.tar.gz]` 自动完成删除与安装。

## 产物契约

发布产物必须至少包含：

1. `triton-macos-arm64.tar.gz`，包含 CLI、bundled Web 和 unsigned Runner。
2. 面向外部使用者的项目级 skill 合并包 `tritonkit-skills.tar.gz`，当前至少包括 `TritonKit.skills/tritonkit-dev-feedback`、`TritonKit.skills/tritonkit-real-project-regression`、`TritonKit.skills/tritonkit-emulator-cli-takeover` 与 `TritonKit.skills/tritonkit-update`。
3. `tritonkit_checksums.txt`，用于 Homebrew formula 渲染和用户校验。
4. CLI 与 skill 包必须携带同一个 CI 解析出的版本号；skill 使用 `metadata.version`，保持 skill front matter 兼容。

后续新增面向使用者的项目级 skill 时，应同步纳入 CI/release packaging。

## v0.2.12 发布边界

`v0.2.12` 汇总 GitHub issues #146–#154 的修复，发布边界保持为 macOS 双架构 `triton` CLI、checksum manifest、四个 public skills 的合并包，以及同步版本的 SwiftPM/Web 分发入口。本次不扩大到真机产品面、Web/Wails 业务控制入口或 CocoaPods trunk 自动推送；podspec 只随 tag 对齐并完成 lint，是否推送 trunk 必须单独执行并记录。

tag 前必须先在 `main` 完成版本契约、本地门禁和远端 validate；tag 后再以 Release assets、checksum、Homebrew formula/安装测试、CLI version、public skill build info 与仓库外 packaged Web HTTP smoke 作为完成证据。arm64 首发成功不代表完整发布完成，必须等待 x86_64 后补 job 与第二次 tap 刷新成功。

2026-07-20 的 `v0.2.12` 发布已按上述完整口径验收：Release workflow 双架构、两次 tap 更新均成功，四个资产与 checksum 一致，Homebrew 从 `0.2.9` 升级到 `0.2.12` 后通过 formula test，仓库外 packaged Web 在 `127.0.0.1:34127` 返回 HTTP 200。CocoaPods 仅完成 podspec lint，未推送 trunk。

## v0.2.15 发布边界

`v0.2.15` 汇总 `v0.2.14` 之后 GitHub issues #159–#165 的修复：UIKit alert modal tap boundary、Xcode one-off build settings、embedded screenshot PNG 契约、iOS 真机 launch selector、Xcode 26.6 xcresult shape、iOS Simulator host-composited evidence screenshot，以及 Xcode schemes discovery/timeout recovery。

本次继续保持既有完整发布面：macOS arm64/x86_64 `triton` CLI、bundled Web、checksum manifest、四个 public skills、Homebrew formula，以及同 tag 版本的 SwiftPM/Web 分发入口。CocoaPods 只要求 `TritonKit.podspec` 版本对齐并通过 lint，不自动推送 trunk；若后续实际推送，必须另行记录凭据、命令与结果。

发布完成判定仍需等待 x86_64 backfill 和第二次 tap 刷新，并独立复验公开 checksum、双架构 Mach-O、CLI/skill build info、Homebrew upgrade/test 与仓库外 packaged Web HTTP smoke；不能只以 arm64 Release 已出现作为完成。

2026-07-23 的 `v0.2.15` 已按上述完整口径发布：Release workflow `29974713055` 的双架构构建、arm64 首发、x86_64 backfill 与两次 tap 更新全部通过；重新下载的三个 tarball 与公开 checksum manifest 一致，两个 CLI 分别验证为 arm64/x86_64 Mach-O 且均报告 `0.2.15`。public skill bundle 的 `BUILD_INFO.json` 与四个必需 skill 均为 `v0.2.15` / commit `29798f0d`。Homebrew 从 `0.2.14` 升级到 `0.2.15` 并通过 formula test，仓库外 packaged Web 返回 HTTP 200。CocoaPods 仅完成 podspec lint，未推送 trunk。

## v0.2.16 发布边界

`v0.2.16` 汇总 `v0.2.15` 之后当前 `main` 的修复与 agent-native test/reliability 合同，包括 CLI 默认 loopback、安全的 App/Xcode/collection target 约束、TestRec 导入与可靠性 gate/harness、focused XCTest 与 real-device destination，以及 packaged Web 对 iOS Simulator / Android / Harmony host input 的正确分流。

发布面继续保持 macOS arm64/x86_64 `triton` CLI、bundled Web、checksum manifest、四个 public skills、Homebrew formula，以及同 tag 的 SwiftPM/Web 版本入口。CocoaPods 仅执行 podspec lint，不自动推送 trunk。本次必须用安装后的 Homebrew `triton 0.2.16` 在仓库外复验 packaged Web，并对真实 iOS Simulator 执行 `/web/host-input` tap；仅验证 HTTP 200 不足以证明输入桥修复。

2026-07-28 的 `v0.2.16` 已按上述完整口径发布：Release workflow `30326964768` 的 contracts、双架构构建、arm64 首发、x86_64 backfill 与两次 tap 更新全部成功。四个公开资产重新下载后通过 checksum 与 gzip 校验；CLI 分别为 arm64/x86_64 Mach-O 且均报告 `0.2.16`，public skill bundle 的 `BUILD_INFO.json` 为 `v0.2.16` / commit `f986ba97`。Homebrew 从 `0.2.15` 升级到 `0.2.16` 并通过 formula test；安装版对真实 iOS Simulator 的 `/web/host-input` tap 返回 host-HID adapter 成功结果，原 `34127` 页面更新后同样显示 LIVE、tap 坐标且 console 0 error/warning。CocoaPods 仅完成 podspec lint，未推送 trunk。

## v0.2.17 发布边界

`v0.2.17` 汇总 `v0.2.16` 之后主线对 GitHub issues `#178–#197` 的实现与可靠性收口，并同步 GitHub issue 治理与 public skill 打包记忆。发布面继续保持 macOS arm64/x86_64 `triton` CLI、bundled Web、checksum manifest、四个 public skills、Homebrew formula，以及同 tag 的 SwiftPM/Web 版本入口。

2026-08-09 的 `v0.2.17` 已按完整口径发布：tag 指向提交 `7fa61e0567453cb30b1a9177bd44c82ab5801eea`；Release workflow `31302214544` 的 contracts、双架构构建、arm64 首发、x86_64 backfill 与两次 tap 更新全部成功。重新下载的四个公开资产通过 checksum 与 gzip 校验；两个 CLI 分别验证为 arm64/x86_64 Mach-O 且均报告 `0.2.17`；public skill bundle 的 `BUILD_INFO.json` 为 `0.2.17` / release tag `v0.2.17` / commit `7fa61e0`。Homebrew 从 `0.2.16` 升级到 `0.2.17` 并通过 formula test；安装版在仓库外的隔离端口 `34129` 启动 packaged Web 并返回 HTTP 200。CocoaPods 已通过 `TritonKit passed validation.`，仅完成 podspec lint，未推送 trunk。

GitHub Release：<https://github.com/NeptuneKit/TritonKit/releases/tag/v0.2.17>。

## v0.2.18 发布边界

`v0.2.18` 汇总主线对 GitHub issues `#198` / `#199` 的实现：Harmony `assembleApp` 的 signed HAP 选择，以及 iOS Simulator `UICollectionViewCell` 的显式、可审计 host-HID fallback。public skills 同步补齐这两个对外契约；发布面继续保持 macOS arm64/x86_64 `triton` CLI、bundled Web、checksum manifest、四个 public skills、Homebrew formula，以及同 tag 的 SwiftPM/Web 版本入口。

2026-08-10 的 `v0.2.18` 已按完整口径发布：准备提交 `af3650f8`，docs-only 收口提交 `adbfc92c`；Release workflow `31401954322` 的 contracts、双架构构建、arm64 首发、x86_64 backfill 与两次 tap 更新全部成功。重新下载四个公开资产后通过 checksum 与 gzip 校验；两个 CLI 分别验证为 arm64/x86_64 Mach-O 且均报告 `0.2.18`；public skill bundle 的 `BUILD_INFO.json` 为 `0.2.18` / release tag `v0.2.18` / commit `af3650f`。Homebrew 从 `0.2.17` 升级到 `0.2.18` 并通过 formula test；安装版在仓库外隔离端口 `34129` 启动 packaged Web 并返回 HTTP 200。CocoaPods 通过 `TritonKit passed validation.`，仅完成 podspec lint，未推送 trunk。

GitHub Release：<https://github.com/NeptuneKit/TritonKit/releases/tag/v0.2.18>。

## Homebrew

### 更新检查和版本验收（SP-208）

2026-10-16用户截图暴露Homebrew默认check跳过查询、nil target折成false的问题，历史v0.2.19与v0.2.29均存在；原测试还固定了此行为。截图tap 0.2.24来自本地缓存还是当时远端状态仍未知，维护机的0.2.29不能证明用户环境已修复。

修复候选见[SP-208](../spaces/SP-208-update-version-alignment/README.md)：check/dry-run必须解析目标或明确失败；执行更新刷新tap后先验证formula，再读取实际安装CLI版本。CLI与目标不符时停止skills更新；下载bundle在变更前核验BUILD_INFO、四个skill条目及frontmatter版本，安装后再次验证。`updated`只在实际CLI版本核验通过后成立，`currentVersion`仍表示更新前进程，`installedVersion`表示核验值。

发布验收必须分别记录远端Release、远端formula、本地formula、实际CLI及每个skills根目录，不能以维护机、命令exit 0、checksum或plan单独证明用户版本一致。源码修复、公开发布、安装接替与用户确认分开记录。

### 2026-10-16 更新检查误报审计

用户截图出现 CLI/skills `0.2.19`、tap `0.2.24`、GitHub Release `0.2.29`。本轮仅诊断与经验写回，未修改产品代码或安装状态，未发布。

- 在源码 HEAD `3000be92` 与历史 `v0.2.19` 中，`CLIUpdateRuntime.swift` 的 Homebrew 默认路径（未传 `--version`、未启用 `--include-skills`）直接将 release target 设为 nil；计划把未知 target 转为 `updateAvailable=false`。`--check` 立即返回，既未查询 GitHub latest，也未读取/刷新 tap。`UpdateCommandTests.homebrewUpdateWithoutExplicitVersionDoesNotRequireGitHubLatest` 还固定了这一行为。因此这个 false 不能证明已是最新版；这是该次审计时尚未修复的 CLI 状态契约缺口；后续修复见下述 SP-208。
- CLI 和 skills 分开更新：默认 CLI 更新不安装 skills；skills 需要显式 `--include-skills --skills-dir <dir>` 并核对安装后的 `BUILD_INFO.json`。Homebrew 更新执行成功后，当前实现也未重读实际 CLI 版本，不能以 `updated=true` 单独证明版本对齐。
- 只读核验：GitHub latest 为 `v0.2.29`；[Release workflow 38611166159](https://github.com/NeptuneKit/TritonKit/actions/runs/38611166159) 成功；远端 tap 提交 `4df6208669b30829ed32c3b56d64f942b6e28c73` 的 formula 为 `0.2.29`（UTC 2026-10-14 18:14:05）。当前维护机 Homebrew CLI、本地 tap 与 Codex/Agents 两处 skills BUILD_INFO 均为 `0.2.29`。安装版 `triton update --check --json` 仍返回 false 且无 target/latest 字段，符合源码分支。
- 截图环境与时间未独立确认，不能据当前维护机状态宣称截图用户已经更新，也不能仅凭截图判定远端漏发；其中 tap `0.2.24` 的具体来源仍未知。
- 下次先分别记录远端 Release、远端 formula、本地 formula、实际可执行文件及各 skills bundle 版本。检查输出没有明确 target/latest 时按“未查询/未知”处理；修复应补 Homebrew check 查询与失败分支、升级后实际版本核验的行为测试，再实现状态契约。此次只读审计不运行 Swift 测试；后续用户委托修复已在 [SP-208](../spaces/SP-208-update-version-alignment/README.md) 独立worktree通过完整CLI与本地门禁，已按SHA一致候选回写主工作区，并随 v0.2.30 发布。修复新增实际安装版本核验、skills元数据版本拒绝，以及部分失败保留已完成状态；完整发布证据见 [SP-208 发布验收](../spaces/SP-208-update-version-alignment/plans/20261016-release.md)。

新增 Homebrew 二进制安装链路：

1. `.github/homebrew/triton.rb.template` 定义 `triton` formula 模板。
2. `docs-linhay/scripts/render-homebrew-formula.sh` 从 release checksum manifest 渲染 formula。
3. `.github/workflows/update-homebrew-tap.yml` 支持 workflow call 与手动触发，默认更新 `NeptuneKit/homebrew-tap`。
4. `v*` tag 发布后，Release workflow 调用 tap 更新 job。该 job 使用 `TAP_GITHUB_TOKEN`。

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

- 本地总门禁使用 `docs-linhay/scripts/verify.sh --local`。用 `--ci-docs` 验证文档与 skill，用 `--ci-validate` 串行运行 Swift 与发布契约检查。范围判定以分类器及 `verify-ci-validate-mode.sh` 为准。
- 使用临时目录复现 CI 打包命令，生成 CLI 与 skill 的 `.tar.gz` 产物。
- 公开资产复验必须下载到新的临时目录，并等待 `gh release download` 完整退出且返回成功后再执行 `shasum -a 256 -c`、`gzip -t` 与解包检查。若下载中的本地文件明显小于 Release API 记录的 size，且 `gh release download` 进程仍存在，应先等待下载完成；不能把流式下载中的截断文件误判为远端 checksum 损坏，更不能据此覆盖已发布资产。
- 运行 `docs-linhay/scripts/verify-skill-package.sh`，验证 `package-public-skills.py` 生成的 `tritonkit-skills.tar.gz` 顶层包含 `TritonKit.skills/`、四个 public skills、版本 stamp 和 `BUILD_INFO.json`，验证安装脚本会删除旧四个独立目录，并用注入的 retired root fixture 证明旧命令层级不能进入 release 包。
- 运行 `docs-linhay/scripts/verify-homebrew-formula.sh`，验证 formula 模板可用。
- 运行 `docs-linhay/scripts/verify-version-stamping.sh`，验证 CI 版本解析、Swift 版本常量写入和 skill front matter `metadata.version` 写入。
- Release tarball README 校验先把 `tar -xOf ... README.txt` 写入临时文件，再执行 `grep -Fq`，避免匹配后提前关闭 pipe 造成 tar 写入失败。
- 用 Python YAML parser 校验 `.github/workflows/ci.yml` 与 `.github/workflows/release.yml` 语法可解析。
- `docs-linhay/scripts/verify-release-automation.sh` 验证现行 arm64 发布、tap 和打包契约。

## v0.2.21 发布边界

本版修复 GitHub #213 的 iOS 真机 smoke readiness 诊断与单一 JSON 输出，并发布完整真机 App endpoint 配置指引。采用 issue 允许的「精确失败 + setup 路径」方案，不承诺自动 endpoint 注入、USB tunnel 或已完成真机端到端验收。

版本对齐 `TritonKit.podspec`、`Web/package.json`、`Web/package-lock.json` 为 `0.2.21`；SwiftPM 通过 tag 解析，CLI 与四个 public skills 由 CI stamp 同 tag 版本。发布面保持双架构 macOS CLI、bundled Web、skills、checksum 和 Homebrew；CocoaPods 本轮只 lint、不推送 trunk。

2026-09-15 已发布 [v0.2.21](https://github.com/NeptuneKit/TritonKit/releases/tag/v0.2.21)，tag 指向 `2a814fde3ad780540997662635ae2ae32d619799`。主线 CI `34942529692`、tag CI `34943378446`、Release `34943378497` 全部成功，包含双架构构建、x86_64 backfill 及两次 tap 更新。重新下载的三个 tarball 通过 checksum/gzip，两个 Mach-O 分别为 arm64/x86_64 且都报告 0.2.21；四个 public skills 的 BUILD_INFO 对齐 tag/commit 且 dirty=false。Homebrew 从 0.2.19 升级至 0.2.21 后 formula test 通过，仓库外安装版 packaged Web 在隔离端口 34129 的 HTML/JS/CSS 均 HTTP 200，验证进程已停止。#213 已回复并关闭，仍明确真机端到端未复测；CocoaPods 仅完成 lint，未推送 trunk。

## 交付辅助脚本

- `docs-linhay/scripts/gh-run-summary.sh --watch <run-id>`：低噪音观察 GitHub Actions run，只输出 job 状态和 URL；失败后再进入详细日志。
- `docs-linhay/scripts/gh-issue-comment-file.sh <issue> <markdown-file>`：通过 `gh issue comment --body-file` 发送 Markdown，避免正文里的反引号命令被 shell 执行。
- `docs-linhay/scripts/check-docs.sh`：固定 TritonKit 的 文档门禁入口。当前 文档记录 CLI 不支持 `update/embed` 按 collection 过滤，所以脚本仍会执行全量 `docs-linhay/scripts/check-docs.sh`。

## v0.2.30 联合发布

用户授权发布main全部内容，包含SP-206安全、SP-201选择器、SP-208版本核验与SP-209原生SDK设置；[发布验收](../spaces/SP-208-update-version-alignment/plans/20261016-release.md)记录全部门禁和资产。Bonjour默认关闭需显式开启；Runner安全协议升级要求CLI/随包Runner同版并重新prepare/start，旧HTTP Runner不降级明文。

## v0.2.30 发布完成

main@ebfbb405全量推送，main CI38922511471/tag CI38924507762/Release38924507771全部成功；双架构、checksum、tap、Homebrew升级与test、两处skills同版receipt通过，packaged Web只读HTTP与真实浏览器通过。原最低iOS13标准pod lint在CI通过，未推送trunk。详见[发布验收](../spaces/SP-208-update-version-alignment/plans/20261016-release.md)。用户原机尚未代验，通知草稿未外发。

## v0.2.33 发布边界

本版发布SP-218真实显示查询兼容修复及其余已收口CLI契约，保留Resize AX/HID unsupported、DerivedData自动删除取消与resource replay提前拒绝边界。公开面仍为双架构CLI、Web、public skills、checksum和Homebrew，podspec/Web清单对齐0.2.33；CocoaPods仅lint。使用独立干净main检出发布，避免原工作区参考追踪WIP混入tag。结果见[发布验收](../spaces/SP-218-issue-222-device-hub-input/plans/20261024-v0.2.33-release.md)。

2026-10-24已发布[v0.2.33](https://github.com/NeptuneKit/TritonKit/releases/tag/v0.2.33)，tag指向 `e2b1d959564bc306308a283f73d8d5bc5cb6164f`；main CI40044736453、tag CI40046036564与Release40046036515全部成功，包含双架构与两次tap更新。公开资产完整下载后通过checksum/gzip、架构、Runner与skills元数据校验，双CLI实际版本均为0.2.33；Homebrew升级/test及仓库外packaged Web只读HTTP/浏览器验收通过。原最低iOS13的CI标准pod lint通过；本机标准失败与兼容lint通过分别留证，未推送trunk。自有验收Web已停止，其他任务服务保留。

## v0.2.34 复验经验

2026-10-27 的 [SP-227 发布记录](../spaces/SP-227-release-v0-2-34/plans/20261027-v0.2.34-release.md) 补充了两条可复用边界：

- packaged Web 必须从仓库外启动已发布二进制，并在 HTTP/浏览器探针前确认 `triton web --print-command --json` 返回 `mode=packaged`。从源码 checkout 启动，或传入内部源码/Web 路径参数，可能切换到 Vite dev server；这类探针不能作为发布包证据。
- CocoaPods 的原始最低部署版本 lint 与为本机新版 Xcode 设置较高目标的兼容 lint 是两类证据。后者只能说明当前工具链可检查，不能替代产品最低版本；本机工具链不兼容时保留标准失败日志，等待兼容 CI/环境复验。

本次对应 Release workflow [40464673488](https://github.com/NeptuneKit/TritonKit/actions/runs/40464673488) 的双架构、x86_64 回填和两次 tap 更新均成功；未改变发布资产契约，也未把本机 Homebrew 安装升级或 CocoaPods trunk 推送纳入自动范围。

## v0.2.35 公开产物与受限浏览器验收

[SP-242记录](../spaces/SP-242-release-v0-2-35/plans/20261028-release.md)绑定190c161f及同候选CI，双架构/checksum/skills/Runner/Homebrew全通过，CocoaPods仅lint。包外Web需resolve Homebrew share符号链接核对版本；`web --json`仅计划，真实启动不带JSON输出选项。默认页面实时流若409且doctor确认resize unknown，应保留失败并标受限；关闭流组件后工作台的零console error仅覆盖该布局，不得冒充默认页面或设备流通过。不得绕过安全保护取绿。
