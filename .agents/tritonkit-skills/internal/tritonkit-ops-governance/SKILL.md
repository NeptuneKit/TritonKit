---
name: tritonkit-ops-governance
description: TritonKit 流程治理：CLI/HTTP/Wails 开发回路、文档记忆写回、AGENTS 同步与 qmd 索引。
metadata:
  version: 0.1.0-dev
---

# TritonKit Operations & Governance

## CLI / HTTP / Wails 开发回路

- 需求变更先写 `docs-linhay/features/` 的 BDD 场景。
- 先补失败测试，再实现最小代码。
- HTTP handler 用 `httptest` 优先验证，只有进程生命周期或信号处理才启动真实 server。
- CLI 行为优先测试参数解析和命令分发，不在单元测试里长期占用端口。
- AI agent 首期只需要 CLI/HTTP 机器可读契约；能通过 CLI/HTTP 完成读取和控制时，不新增 Web/SSE 渲染入口。
- Emulator 接管当前产品边界是本机 CLI + 本机 iOS Simulator / Android Emulator / HarmonyOS DevEco Emulator；不要把该方向扩展成真机、远端 agent、设备云、Web/Wails UI、对外 HTTP 产品面或中台服务，除非另建 space 重新定边界。
- 真实项目回归或 issue 证据优先用 `triton evidence --name <case> --output <dir.tritonevidence> --json` 生成 manifest + artifacts；需要拆解时再单独跑 `status/list/ax/screenshot/export`。
- 完整回归报告优先用 `triton capture --case <case> --output <dir.tritonevidence> --json`；最终 pass/fail 判断优先用 `triton assert text-exists|text-not-exists <text> --json`，重复文本用 `--within` / `--role` / `--count` 收敛。
- 可复跑真实项目 smoke 优先沉淀为 `.tritonplan`：`record` 只生成模板，`plan inspect` 做离线摘要，`replay --dry-run` 先校验变量和脱敏命令，真实 `replay` 再执行并在失败步骤停止。
- 同文案多目标点击先用 `triton find "<text>" --all` 获取候选；已知目标点位时优先用 `triton tap "<text>" --at x,y` 消歧，也可用 `--index <n>` 或 `--within x,y,width,height`。`--within` 表示区域过滤，只有一个点位时不要把 width/height 伪造成 0；默认 `tap "<text>"` 仍选择第一个候选以兼容旧脚本。
- 面向 agent 的 action 命令 `find/tap/swipe/type/paste/clear/press` 默认输出 JSON；示例默认省略 `--json`，只在人读调试时显式使用 `--format text`。`triton type <text>` 与 `triton press <button>` 是首选入口，旧的 `triton type --text <text>` / `triton press --button <button>` 只作为兼容路径，均必须二选一。
- 设备控制参考 Baguette 时，先区分 embedded TritonKit runtime 与 macOS host-side adapter：embedded runtime 只能承诺公开 UIKit API 可验证的 in-app 控制；SimulatorKit / HID / Home / App Switcher 等设备级动作必须等 host-side adapter，当前要返回明确 unsupported。
- Wails 绑定先测绑定对象和 DTO；有真实 UI 后再补桌面窗口验收。
- 当前前端为空白 Wails 静态入口；任何恢复 UI 的工作必须先新建或更新 `space` 与 BDD 场景。
- Package Manager 集成时，embedded TritonKit runtime 只在 `DEBUG` 编译配置下生效；Release 下 API 保持可编译但 runtime 必须 no-op，不按端类型或 UIKit 可导入性决定是否启用。
- 业务 App 侧 iOS 接入示例必须把所有 TritonKit 符号放进独立 Debug bootstrap 文件，并用文件级 `#if DEBUG` 包住 `import TritonKit` 与 `TritonKit.shared.start()` / `start { config in ... }` facade；AppDelegate、SceneDelegate 或 SwiftUI 入口只保留 `#if DEBUG` 调用点，不能只依赖库内部 Release no-op。只有需要自定义 delegate 或消息路由时才使用低层 `delegate` / `connect(host:port:)`。
- SwiftPM / Xcode package product dependency 没有 CocoaPods-style Debug-only 配置开关；对外接入指南必须明确：默认走源码级 `#if DEBUG` bootstrap + Release no-op runtime，若生产 Release target 必须完全不链接 TritonKit，则使用独立 Debug-only app target / scheme。
- Package Manager 分发同时覆盖 SwiftPM 与 CocoaPods；CocoaPods 规格必须保留 `TritonKitShared` / `TritonKit` 两个 Swift module，避免 `TritonKit` 中的 `import TritonKitShared` 在 pod 集成时失效。
- SwiftPM 根 `Package.swift` 只描述业务 App 可依赖的 embedded SDK product，不声明 `triton` CLI executable、不声明 Hummingbird / ArgumentParser 等 CLI-only package dependencies；macOS CLI 统一由 `CLI/Package.swift` 构建，命令为 `swift build --package-path CLI --scratch-path .build/cli -c release --product triton`，避免 iOS App 解析 SwiftPM 时拉入 CLI 依赖。
- 新增配置项时同步覆盖默认值、环境变量覆盖和非法值。
- 新增外部依赖时先说明必要性；首期优先 Go 标准库。
- GitHub CI / Release 必须同时产出 macOS arm64 / x86_64 `triton` CLI tar 包、checksum manifest 和合并后的对外项目级 `tritonkit-skills.tar.gz`；该 skill 包只能从 `.agents/tritonkit-skills/public/` 打包，当前至少包含 `tritonkit-dev-feedback`、`tritonkit-real-project-regression` 与 `tritonkit-emulator-cli-takeover`，便于外部使用者拿到开发阶段反馈流程、真实项目回归流程和本机模拟器 CLI 接管流程。
- `triton` CLI 的外部分发必须支持 Homebrew 二进制安装与更新；维护者默认用 `docs-linhay/scripts/release.sh <version>` 发布，脚本负责前置检查、tag 推送、CI 观察、Release 资产验证和 Homebrew fetch 验证。
- Homebrew 默认 tap 仓库是 `NeptuneKit/homebrew-tap`；`NeptuneKit/TritonKit` 必须配置 `TAP_GITHUB_TOKEN`，让 `v*` tag release 自动推送 `Formula/triton.rb`。
- `v0.1.0` 起 GitHub Release 和 `NeptuneKit/homebrew-tap` 已可用；对外接入文档和 skill 默认优先给 `brew install NeptuneKit/tap/triton`，只有验证未发布源码变更或 release/tap 不可用时才使用 `swift build --package-path CLI --scratch-path .build/cli -c release --product triton` fallback。
- 手动更新已在 `PATH` 上的 `triton` CLI 时，如果 `triton serve` 可能正从该路径运行，禁止文档或 skill 推荐直接 `cp` 覆盖目标文件；必须先停止 server，或先写 `triton.new` 再用同目录 `mv` 原子替换。
- CLI 和对外发布的 skill 必须带版本号；CI 负责从 `v*` tag 或当前 commit 解析版本，写入 `Sources/TritonKitCLI/main.swift` 中的 `TritonKitBuildInfo.cliVersion` 和打包后的 `SKILL.md` front matter `metadata.version`。
- 普通 `main` push / PR 的 CI 只阻塞 validate；双架构 CLI、skill 包、checksum 与 release asset 打包只在 `v*` tag 或手动 `workflow_dispatch` 执行。
- 手动 `workflow_dispatch` 只验证 release asset 集合并上传 workflow artifact，不渲染 Homebrew formula；只有真实 `v*` tag 构建才用 `GITHUB_REF_NAME` 渲染 formula，避免 dev 版本 `0.1.0-dev+<sha>` 被拼成无效 release tag。
- 本仓库默认本地门禁入口是 `docs-linhay/scripts/verify.sh --local`；CI validate 先用 `docs-linhay/scripts/ci-validate-mode.sh` 分类，docs/skill-only 走 `docs-linhay/scripts/verify.sh --ci-docs`，CLI/test/SwiftPM-only 走 Swift tests、CLI release build 与 release/homebrew 契约检查并跳过 podspec lint，workflow/release 脚本类只跑契约检查，`Sources/TritonKit/` 只跑 `TritonKit.podspec` lint，Shared/iOS/未分类改动在 CI 中并行跑 Swift tests、两个 podspec lint 和 release/homebrew 契约检查；本地仍用 `docs-linhay/scripts/verify.sh --ci-validate` 串行复现完整门禁。
- GitHub issue / PR 评论若包含 Markdown 命令片段，必须通过文件传给 `gh --body-file`，优先使用 `docs-linhay/scripts/gh-issue-comment-file.sh`，避免 shell 执行反引号内容。
- 上报 GitHub issue 前必须脱敏工程和个人信息：真实工程名、App 名、bundle ID、team ID、组织名、用户名、账号、邮箱、手机号、内网域名、绝对私有路径、完整私有日志、未脱敏截图和证据包不得进入公开 issue；必要时使用 `<private-app>`、`<bundle-id>`、`<user>`、`<internal-host>`、`<repo-path>` 等占位符，并保留平台版本、TritonKit 版本、命令、错误码和最小可复现片段。
- GitHub Actions 状态观察优先使用 `docs-linhay/scripts/gh-run-summary.sh --watch <run-id>`；失败后再拉完整日志，避免 `gh run watch` 重复输出淹没关键状态。
- 发布脚本查找 GitHub Actions run 时必须从 `gh run list --json headBranch,url` 的 URL 字符串解析 run id；不要通过 `databaseId` + Go template 渲染大整数，避免被格式化成科学计数法后导致 `gh run view` 404。

## 文档与记忆

- 需求与验收：`docs-linhay/features/`。
- 架构、技术方案、测试策略：`docs-linhay/dev/`。
- 关键决策、里程碑、风险结论：`docs-linhay/memory/YYYY-MM-DD.md`。
- 写回 docs 或 memory 后执行 `qmd update` 与 `qmd embed`。
- qmd 写回同步优先使用 `docs-linhay/scripts/qmd-sync.sh`。当前 qmd CLI 不支持 `update/embed` 按 collection 过滤，脚本仍会执行全量维护并显式提示这一限制。
- 用户要求“整理会话”时，先用 `git status --short --branch` 和 `git diff --stat` 隔离已提交代码、未提交文档、外部仓验证和临时产物；只 stage 本次整理相关文件，不默认 `git add -A`。
- 调整 CI、Release 或发布产物契约时，同步更新 `docs-linhay/dev/` 与 memory。
- 调整 Homebrew、tap、checksum 或 release asset 命名时，同步更新 README、`.github/homebrew/`、`docs-linhay/dev/` 与 memory。
- 调整 replay plan schema、record/replay 行为或 `.tritonplan` 对外契约时，同步更新 README、`docs-linhay/dev/ai-cli-readable-control.md`、真实项目回归 skill 与 memory。
- 调整 agent-facing CLI 默认输出、参数简写或 command schema 时，同步更新 README、`docs-linhay/dev/ai-cli-readable-control.md`、真实项目回归 skill、开发反馈 skill 与 memory。
- 调整 iOS / Harmony / CLI 接入使用指南时，同步更新 README、对应 dev 验收文档、`tritonkit-dev-feedback`、`tritonkit-real-project-regression`、必要时 `tritonkit-emulator-cli-takeover` 与 memory；接入口径必须拆分为 iOS embedded runtime、Harmony host-side HDC adapter、Harmony embedded SDK 和 macOS CLI install/run。

## AGENTS 同步

- 只有 repo-wide、长期稳定、每次都应遵守的规则才进入 `AGENTS.md`。
- TritonKit-owned skill 源码统一进入 `.agents/tritonkit-skills/`：对外发布 skill 放 `public/`，内部治理、实现、监督和规划 skill 放 `internal/`；`.agents/skills/` 只保留 symlink 作为本地 agent 发现入口，不作为 release packaging 源。
- 单个领域或流程的可复用动作优先补充既有 skill；新增 skill 前先判断它是 `public` 还是 `internal`，避免对外使用者拿到内部治理规则。
- 新增 skill 前先判断是否能补充既有 skill，避免入口膨胀。
- skill 的 front matter `description` 只写触发场景和能力边界，详细规则写正文。

## Subagent 监督交付

- 只有用户明确要求 subagent / 并行 agent / 监督交付时才启用。
- 主控 agent 负责边界、拆分、集成、验证、文档和最终完成判断。
- subagent 任务必须有清晰写入面；多个 subagent 不应写同一批文件。
- 主控 agent 不把“代码已改完”当作完成，必须跑完验证与写回。

## 完成检查

- BDD 场景满足。
- 相关测试已运行并通过，或明确说明阻塞和风险。
- 文档与 memory 已更新。
- `qmd update` 与 `qmd embed` 已执行。
- 若产生可复用模式，已更新对应 skill 或说明暂不沉淀。
- 若任务要求“从头开始”，需同步检查 docs、skills 和 AGENTS 是否仍残留旧方向规则。
