---
name: tritonkit-ops-governance
description: TritonKit 流程治理：任务或交付切片收尾时自动检查并沉淀经验，用户纠正、缺陷、验证失败、返工或交付遗漏时自动更新原权威资料；同时覆盖 CLI/HTTP/Wails 开发回路、文档记忆写回、AGENTS 同步及显式整理请求。
metadata:
  version: 0.1.0-dev
---

# TritonKit Operations & Governance

开工与交付按[经验索引](../../../docs-linhay/memory/EXPERIENCE.md)只读命中主题，未命中再检索；读取、证据、修订与退出遵循[治理闭环](../../../docs-linhay/dev/20260619-agent-workflow-skill-governance.md)。

## CLI / HTTP / Wails 开发回路

- 新单需求优先在 `docs-linhay/spaces/SP-<三位序号>-<topic>/README.md` 写清 BDD 场景和验收边界；历史或项目级规格再使用 `docs-linhay/features/`。
- 新 space 使用 `SP-<三位序号>-<topic>` 规范名，例如 `SP-001-hybrid-transport-smoke`；序号全局递增且永不复用。历史目录通过 `docs-linhay/spaces/INDEX.md` 映射，不在普通需求中直接重命名。
- `docs-linhay/spaces/INDEX.md` 是全量编号登记册，`docs-linhay/spaces/README.md` 是路线总览；新建 space、状态变化、独立 worktree 待集成或需求收口时，同步更新编号、迁移进度、当前队列、下一步和历史归档。
- 先补失败测试，再实现最小代码。
- HTTP handler 用 `httptest` 优先验证，只有进程生命周期或信号处理才启动真实 server。
- CLI 行为优先测试参数解析和命令分发，不在单元测试里长期占用端口。
- AI agent 首期只需要 CLI/HTTP 机器可读契约；能通过 CLI/HTTP 完成读取和控制时，不新增 Web/SSE 渲染入口。
- CLI helper 若已经打印了机器可读错误 envelope 并通过 `ExitCode.failure` 终止，外层 catch 必须透传 `ExitCode`，不能再二次包装成另一个 `{ok:false,error:...}`。验证时要检查失败输出仍是单个合法 JSON 对象。
- Emulator 接管当前产品边界是本机 CLI + 本机 iOS Simulator / Android Emulator / HarmonyOS DevEco Emulator；不要把该方向扩展成真机、远端 agent、设备云、Web/Wails UI、对外 HTTP 产品面或中台服务，除非另建 space 重新定边界。
- 本机 emulator / simulator 动作必须 Triton-first：agent 在调用裸 `xcrun` / `simctl`、`hdc`、`adb`、DevEco Emulator CLI、XcodeBuildMCP 或裸 `xcodebuild` 前，必须先保存 `triton status/doctor/capabilities/schema/plan` 的机器可读事实；只有 Triton 返回失败、unsupported 或 schema/capability 未覆盖时才 fallback，且报告中必须保留 Triton 命令、错误码或 unsupported 证据和 fallback 命令。
- 真实项目回归或 issue 证据优先用 `triton evidence capture --case <case> --output <dir.tritonevidence> --json` 生成 manifest + artifacts；需要拆解时再单独跑 `status/list/ax/screenshot/export`。
- `evidence capture --json` 的 stdout 必须是单一 manifest；消费方必须联合检查 `ok`、`partial`、顶层 `error` 与 `skipped[].error`。预期 unsupported 可返回 `ok:true, partial:true`；请求或写入失败返回 `ok:false, partial:true`、稳定 `evidence_capture_partial` 并以非零状态退出，不能只凭已存在的少量 artifacts 判断 capture 成功。
- 完整回归报告优先用 `triton evidence capture --case <case> --output <dir.tritonevidence> --json`；最终 pass/fail 判断优先用 `triton verify text-exists|text-not-exists <text> --json`，重复文本用 `--within` / `--role` / `--count` 收敛。
- 可复跑真实项目 smoke 优先沉淀为 `.tritonplan`：`record` 只生成模板，`plan inspect` 做离线摘要，`replay --dry-run` 先校验变量和脱敏命令，真实 `replay` 再执行并在失败步骤停止。
- 同文案多目标点击先用 `triton act find "<text>" --all --json` 获取候选；已知目标点位时优先用 `triton act tap "<text>" --at x,y --json` 消歧，也可用 `--index <n>` 或 `--within x,y,width,height`。`--within` 表示区域过滤，只有一个点位时不要把 width/height 伪造成 0。
- WebView 内 H5 控件命中问题优先保持 agent 高层入口：使用 `triton act tap --webview-aware --selector <css> --webview-id <id> --page-session-id <id> --expect-text <text> --json`，不要把 `webview tap/click` 暴露成主操作面。DOM click 为 `trusted=false`，没有 `--expect-text` 或其它显式验证时结果必须是 `uncertain`，不能宣称业务成功；`expect-request`、CDP/远程调试、任意 JS eval 和 trusted HID 合成需另建切片。
- 面向 agent 的 action 命令统一走 `triton act find/tap/swipe/type/paste/clear/press/focus/set-text/select-segment/set-switch/input`，默认要求机器可读输出。旧 action root 不再作为兼容入口；raw layout / AX 排查走 `triton debug ax --json` 或 `triton debug hierarchy --json`。
- 设备控制先区分 embedded runtime 与 macOS host adapter：embedded 仅承诺公开 UIKit 可验证的 in-app 控制；Simulator tap/swipe 使用内置隔离 HID helper，不调用外部 Baguette、不保留其 override/通用进程hook。其它设备级动作按各自现有 provider/unsupported 契约判断，不能把上游工具的能力名当作已接入能力。
- 新增 host-side fallback 时，默认 embedded 路径必须保持 fail-closed；只有显式 opt-in、目标 scope 和 geometry 校验通过后才能调用 adapter，并在结果中保留 source/strategy/geometry/sourceCommands 与 `verification.required` 边界，同时更新对外 public skill 的使用与验收说明。
- 可安装 artifact discovery 必须遵守平台安装性约束：Harmony `assembleApp` 只选择可识别为 signed 的 HAP；没有 signed 候选时沿用单一 `hap_artifact_not_found` 失败 envelope，不把 unsigned 产物伪装成 real-device installable artifact；兼容性更宽的 emulator/debug build 路径要单独标注。
- Wails 绑定先测绑定对象和 DTO；有真实 UI 后再补桌面窗口验收。
- 当前已有 `Web/` React / Vite mock 工程，但它只是可运行设计原型，不是业务控制入口或 Wails 复活；任何恢复正式 Web/Wails 产品体验的工作仍必须先新建或更新 `space` 与 BDD 场景，并优先使用 `tritonkit-web-mock-ui`。
- Package Manager 集成时，embedded TritonKit runtime 由 package 内部 Debug compile flag `TRITONKIT_RUNTIME_ENABLED` 控制；Debug package build 启用，Release package build API 保持可编译但 runtime 必须 no-op，不按端类型或 UIKit 可导入性决定是否启用。
- 业务 App 侧 iOS 接入示例必须把所有 TritonKit 符号放进独立 Debug bootstrap 文件，并用文件级 `#if DEBUG` 包住 `import TritonKit` 与 `TritonKit.shared.start()` / `start { config in ... }` facade；AppDelegate、SceneDelegate 或 SwiftUI 入口只保留 `#if DEBUG` 调用点，不能只依赖 package 内部 Release no-op。只有需要自定义 delegate 或消息路由时才使用低层 `delegate` / `connect(host:port:)`。
- SwiftPM 支持 configuration-scoped build settings / compile conditions，但 SwiftPM / Xcode package product dependency 没有 CocoaPods-style Debug-only product dependency 开关；对外接入指南必须明确：默认走 package Debug compile flag + 源码级 `#if DEBUG` bootstrap + Release no-op runtime，若生产 Release target 必须完全不链接 TritonKit，则使用独立 Debug-only app target / scheme。
- Package Manager 分发同时覆盖 SwiftPM 与 CocoaPods；用户接入面只显式选择 / 添加 `TritonKit`，不得要求业务 App 手写或看到独立 `TritonKitShared` CocoaPods 入口；内部仍保留 `TritonKitShared` / `TritonKit` 两个 SwiftPM module 边界，CocoaPods 由 `TritonKit.podspec` 直接打包 shared 源码，CI 只校验 `TritonKit.podspec` 可 lint。 新增runtime Swift文件中的 `import TritonKitShared` 必须沿用 `#if !TRITONKIT_COCOAPODS_SINGLE_POD` 条件，否则SwiftPM/模拟器测试可通过而pod lint报module missing；新增文件的分发验收须实际运行pod lint（PR #233）。
- SwiftPM 根 `Package.swift` 只描述业务 App 可依赖的 embedded SDK product，不声明 `triton` CLI executable、不声明 Hummingbird / ArgumentParser 等 CLI-only package dependencies；macOS CLI 统一由 `CLI/Package.swift` 构建，命令为 `swift build --package-path CLI --scratch-path .build/cli -c release --product triton`，避免 iOS App 解析 SwiftPM 时拉入 CLI 依赖。
- Swift 源文件超过 1500 行即进入治理范围；新增或扩展 CLI 能力时，默认按 `*Commands.swift`、`*Runtime.swift` / `*Service.swift`、`*Models.swift` 拆分。`*Models.swift` 只放 Codable/Encodable/Argument enum 等 wire contract，`*Commands.swift` 只放 ArgumentParser 参数和 glue，执行逻辑进入 runtime/service 文件。
- 新增配置项时同步覆盖默认值、环境变量覆盖和非法值。
- 新增外部依赖时先说明必要性；首期优先 Go 标准库。
- GitHub CI / Release 最终必须产出 macOS arm64 / x86_64 `triton` CLI tar 包、checksum manifest 和合并后的对外项目级 `tritonkit-skills.tar.gz`；发布顺序是 arm64 CLI + skill 包先创建 Release / 更新 Homebrew，x86_64 CLI 在 arm64 macOS runner 上通过 SwiftPM `--triple x86_64-apple-macosx14.0` 交叉编译后补上传，并再次刷新 checksum / tap。该 skill 包只能从 `TritonKit.skills/` 打包，当前至少包含 `tritonkit-dev-feedback`、`tritonkit-real-project-regression`、`tritonkit-emulator-cli-takeover` 与 `tritonkit-update`，便于外部使用者拿到开发阶段反馈流程、真实项目回归流程、本机模拟器 CLI 接管流程和 TritonKit 自更新流程。
- Public skill 打包必须走 `docs-linhay/scripts/package-public-skills.py`，参考 `harmony-next.skills` 的独立脚本产物生成方式，在包内 `TritonKit.skills/BUILD_INFO.json` 写入 metadata，但仍保持 TritonKit 的合并 `tritonkit-skills.tar.gz` 契约，不新增 `.skill.zip` 或单独 skill tarball。安装默认以整个 `TritonKit.skills/` 文件夹为单位；升级旧安装时先删除 agent skills 目录下的三个独立 public skill 目录。
- `triton` CLI 的外部分发必须支持 Homebrew 二进制安装与更新；维护者默认用 `docs-linhay/scripts/release.sh <version>` 发布，脚本负责前置检查、tag 推送、CI 观察、Release 资产验证和 Homebrew fetch 验证。
- 整体发布、各端内置包版本同步、Homebrew/Web/SwiftPM/CocoaPods/public skill 包一致性发版，优先使用 `tritonkit-release-package-governance`。
- 涉及多个 agent / 多份计划 / 多个 PR 策略需要裁决时，优先使用 `tritonkit-plan-arbiter`；输出必须是 adopt / hybrid / revise-first 中的一种，并列出验证门禁和拒绝项。
- 发版前必须保持主仓 worktree 完全干净，包含 memory、临时截图、未跟踪 space 和并行 issue WIP；若 release 途中需要抢修本地门禁 blocker，只做最小 release-blocker commit，推送 `main` 后重新跑 release 脚本，不把未完成 WebView/issue work 混入 tag。
- Homebrew 默认 tap 仓库是 `NeptuneKit/homebrew-tap`；`NeptuneKit/TritonKit` 必须配置 `TAP_GITHUB_TOKEN`，让 `v*` tag release 自动推送 `Formula/triton.rb`。
- `v0.1.0` 起 GitHub Release 和 `NeptuneKit/homebrew-tap` 已可用；对外接入文档和 skill 默认优先给 `brew install NeptuneKit/tap/triton`，只有验证未发布源码变更或 release/tap 不可用时才使用 `swift build --package-path CLI --scratch-path .build/cli -c release --product triton` fallback。
- 手动更新已在 `PATH` 上的 `triton` CLI 时，如果 `triton serve` 可能正从该路径运行，禁止文档或 skill 推荐直接 `cp` 覆盖目标文件；必须先停止 server，或先写 `triton.new` 再用同目录 `mv` 原子替换。
- CLI 和对外发布的 skill 必须带版本号；CI 负责从 `v*` tag 或当前 commit 解析版本，写入 `Sources/TritonKitCLI/CLIBuildInfo.swift` 中的 `TritonKitBuildInfo.cliVersion` 和打包后的 `SKILL.md` front matter `metadata.version`。
- 普通 `main` push / PR 的 CI 只阻塞 validate；双架构 CLI、skill 包、checksum 与 release asset 打包只在 `v*` tag 或手动 `workflow_dispatch` 执行。
- 手动 `workflow_dispatch` 只验证 release asset 集合并上传 workflow artifact，不渲染 Homebrew formula；只有真实 `v*` tag 构建才用 `GITHUB_REF_NAME` 渲染 formula，避免 dev 版本 `0.1.0-dev+<sha>` 被拼成无效 release tag。
- 本仓库默认本地门禁入口是 `docs-linhay/scripts/verify.sh --local`；CI validate 先用 `docs-linhay/scripts/ci-validate-mode.sh` 分类，docs/skill-only 走 `docs-linhay/scripts/verify.sh --ci-docs`，CLI/test/SwiftPM-only 走 Swift tests、CLI release build 与 release/homebrew 契约检查并跳过 podspec lint，workflow/release 脚本类只跑契约检查，`Sources/TritonKit/` 与 `Sources/TritonKitShared/` 走 podkit，运行 Swift tests、`TritonKit.podspec` lint 和 release/homebrew 契约检查；本地仍用 `docs-linhay/scripts/verify.sh --ci-validate` 串行复现完整门禁。
- 用户明确要求“实现完成再测试 / 分段提交”时，每个切片先完成代码、测试、schema、文档与 memory 的一致性改动，再集中跑该切片的 focused tests、必要 schema tests、完整回归和文档门禁；不要在同一切片里每改几行就停下来跑测试，除非正在定位失败。
- 有副作用或共享状态的命令必须单飞，不进入 `multi_tool_use.parallel`：`git add/commit/tag/push/merge`、会写同一 scratch path 的 SwiftPM build/test、会启动/停止服务或修改本机/模拟器状态的命令。只有只读检查或彼此独立的文件读取、搜索、不同 scratch path 的纯构建验证，才适合并行。
- 多 worktree 首次 SwiftPM 编译前检查 `swift test --help` 的默认 build-system；Xcode 27.1 本机默认为 swiftbuild，不能从 `--jobs 2` 推断 SwiftBuild 的全局并发已限流。批量 issue 验证优先冻结候选后在独立联合 worktree 使用单个 `--build-system native --jobs 2` scratch；若需要并行，先用真实进程数量验证预算。出现过载只停止已绑定的本任务进程树，保留日志并明确“编译中断、测试未执行”，不杀其他任务的同名进程。
- 跟踪长构建进度先绑定本任务的tool session、启动命令/cwd/scratch和实际父子PID；不能从同名swift-frontend、SWBBuildService、dsymutil或别会话产物推断本候选阶段。进程消失/CPU活跃不等于成功，最终以本命令退出码及同候选日志/产物核实。
- CLI 全量测试若暴露 host command timeout、fake tool timeout 或 proxy serve `Connection refused`，先排查测试基础设施和并发资源竞态，不要只调大 timeout。`Process`/pipe runner 不应把阻塞式 `read`、`waitUntilExit` 大量投到 `DispatchQueue.global`；优先用专用 queue、`terminationHandler`、有界 pipe drain 和明确 cleanup。并发网络测试不要 `bind(0)` 取端口后无登记释放给多个用例抢用；同一 test runner 内应有 reservation 或其它唯一端口策略。
- 宿主输出收尾不能只等直接子进程退出：后代可能继承stdout/stderr写端。用真实自有shell/FD夹具分别验证内存/stdout-artifact/combined runner，外部watchdog防挂、仅清理精确自有PID。post-exit pipe预算需持续可读也检查，worker独占非阻塞read/close并join同步结果；真实EOF、字节cap、未EOF和读错误分开。失败证据保留实际exit与部分计数，不用incomplete遮住非零；磁盘open/write/close不是pipe deadline可取消范围，见[SP-224](../../../docs-linhay/spaces/SP-224-host-process-drain-integration/README.md)。 execution-timeout夹具应让deadline先于intentional interrupt；否则早到SIGINT可能在shell安装trap前形成合法duration成功，不能当超时回归。独立保留intentional-success测试，修正测试时不改生产timeout或放宽错误类型断言。
- GitHub issue / PR 评论若包含 Markdown 命令片段，必须通过文件传给 `gh --body-file`，优先使用 `docs-linhay/scripts/gh-issue-comment-file.sh`，避免 shell 执行反引号内容。
- 上报 GitHub issue 前必须脱敏工程和个人信息：真实工程名、App 名、bundle ID、team ID、组织名、用户名、账号、邮箱、手机号、内网域名、绝对私有路径、完整私有日志、未脱敏截图和证据包不得进入公开 issue；必要时使用 `<private-app>`、`<bundle-id>`、`<user>`、`<internal-host>`、`<repo-path>` 等占位符，并保留平台版本、TritonKit 版本、命令、错误码和最小可复现片段。
- GitHub 控制面遇到 DNS 失败时，不得把网络暂时不可达当成 issue 已处理，也不要改写 remote URL；可用 `dig +short @1.1.1.1 github.com A` / `api.github.com A` 获取临时地址，用 `GIT_SSH_COMMAND='ssh -o HostName=<github-ip> -o HostKeyAlias=github.com ...' git push origin main` 和 `curl --resolve api.github.com:443:<api-ip> ...` 直连复核。token 只放进进程环境或 shell 变量，不打印；push 后必须用远端 SHA、CI run 和最终 open 查询重新确认。API 直连评论/关闭时仍沿用 body-file 内容，不在 shell 中执行 Markdown。
- GitHub Actions 状态观察优先使用 `docs-linhay/scripts/gh-run-summary.sh --watch <run-id>`；失败后再拉完整日志，避免 `gh run watch` 重复输出淹没关键状态。
- 发布脚本查找 GitHub Actions run 时必须从 `gh run list --json headBranch,url` 的 URL 字符串解析 run id；不要通过 `databaseId` + Go template 渲染大整数，避免被格式化成科学计数法后导致 `gh run view` 404。
- Release 脚本完成后，完成定义是 arm64 CLI 包、skill 包、checksum manifest、GitHub Release 和 Homebrew tap 已可用；x86_64 CLI 资产由 arm64 macOS runner 交叉编译后补，不阻塞 Apple Silicon 发布闭环。若额外开了 `gh-run-summary --watch` 观察 backfill，release 脚本完成后可停止本地 watcher，但不要取消当前有效发布的 GitHub Actions run；只有被新 tag 明确 supersede 的旧 run 才可取消。
- Release tag 推送完成后再写 memory 时，只用 docs-only commit 推回 `main`，不要移动 tag；随后观察该 docs-only main CI 通过，作为整理收尾证据。

## UIKit 与 CLI 验证证据

- `#if canImport(UIKit)` 测试在 macOS `swift test` 不执行；涉及 UILabel/手势/cell 行为时应在独立 Simulator 的真实 iOS destination 运行，并记录实际测试数量，不把宏条件跳过算通过。
- UIKit 的 key window、scene 与 registry 是进程共享状态。多个 `@Suite(.serialized)` 仍可跨 suite 并行；共享窗口的 fixtures 应置于同一外层串行 suite，先断言真实 window 可见及 runtime 选择一致，不为测试放松生产安全校验。动态色需要真实 trait 树；pinch 需要 viewForZooming；坐标应从实际 view 转到 window。
- UIKit 输入焦点不能按“最深 descendant”推断：非输入 wrapper 可能转发 isFirstResponder，公共 UITextField 又包含内部 field editor。解析优先已聚焦 UIKeyInput owner，再穿过非输入 wrapper；真实 App-hosted 回归同时核对文本、targetOID 与未聚焦负例，不能只看文本插入成功（SP-238）。
- UIKit presentation 测试必须等待真实 completion 与目标 view 的 window 挂载，不能把 `present(animated:false)` 或 `Task.sleep` 当作展示完成。hostless runner 无法完成 presentation 时，不宣称展示验收通过；纯 responder/alert 路由测试可用真实 alert controller 的窗口夹具，但必须断言目标实际挂载、活动窗口及背景 fallback candidate 确实存在。`UIView.alpha` 与 backing `CALayer.opacity` 联动，同批 patch 应按真实执行顺序验证最终值，并分别覆盖两个入口；不要要求同一 backing value 同时保持不同值。
- CLI 测试使用自定义 scratch 时显式设置 `TRITON_CLI_PATH` 为本次构建产物。含全局 stdout/stderr capture 的整套测试使用 `swift test --package-path CLI --no-parallel`，避免 Swift Testing 进度混入 JSON；异步 stdout/stderr reader 必须完成有界 drain 后才发布最终字节数。

- UIKit enabled与unsupported平台的恢复契约测试都应编码真实强类型payload；unsupported提前返回可能掩盖空payload错误。目标释放场景先有界观察真实weak目标归零，再验targetGone；一次main queue turn不是CA/ARC释放证据，不放松生产identityChanged规则。SP-196发布候选修复两旧夹具后真实App-hosted76项通过，见[发布验收](../../../docs-linhay/spaces/SP-196-upstream-optimization-delivery/plans/20261014-release.md)。

- 原生手势交互的中间态需要独立截图/断言；松手截图只能证明结束状态。跨进程UI测试与CLI动作使用显式ready交接，不能凭selection已出现就执行业务动作。连续导航同时验收菜单持续可用、目标可见和按钮位置稳定。
- Xcode输出测试结果不代表进程已退出；失败后的simctl诊断可能继续占用通道。下一次同DerivedData/设备构建前用`triton xcode status`核对，必要时只清理已确认属于本轮的诊断进程并保留证据。整理提交时核对被忽略的截图是否已显式暂存，避免文档存在而引用证据缺失。

## 文档与记忆

- Space 编号索引：`docs-linhay/spaces/INDEX.md`；路线总览：`docs-linhay/spaces/README.md`。
- 需求与验收：`docs-linhay/features/`。
- 架构、技术方案、测试策略：`docs-linhay/dev/`。
- 关键决策、里程碑、风险结论：`docs-linhay/memory/YYYY-MM-DD.md`。
- 长期稳定入口：`docs-linhay/memory/MEMORY.md`；其中必须保留 spaces 总索引的固定路径。
- 用户要求“整理会话”时，先用 `git status --short --branch` 和 `git diff --stat` 隔离已提交代码、未提交文档、外部仓验证和临时产物；只 stage 本次整理相关文件，不默认 `git add -A`。
- 用户要求 subagent 并行处理多个 GitHub issue 且强调不要串工作时，按 issue 建独立 `space` / `feat/<space-key>` / `../TritonKit-worktrees/<space-key>/`；主控 agent 逐 worktree 检查 clean status、commit、测试、docs/memory，不把多个 issue 或主仓并行改动混成一个提交。
- 用户要求“其他 worktree 都结束了就合并到主分支后删除”时，收尾顺序固定为：`git worktree list --porcelain` 枚举，逐 worktree 跑 `git status --short --branch`，用 `git log main..<branch>` 和 `git merge-base --is-ancestor` 判断是否还有未合入提交，对需要合入的分支先用 `git merge-tree --write-tree main <branch>` 做无副作用冲突预检；合入主仓后必须在主仓跑门禁，通过后再 `git worktree remove <path>`，最后复查 registered worktree 只剩主仓。空包装目录可在确认不是 registered worktree 且为空后用 `rmdir` 清理；本地/远端分支不随 worktree 默认删除。若 `git branch -d` 因分支尚未合入 `origin/main` 拒绝删除，但它已经合入本地 `HEAD`，先推送 `main` 并 `git fetch origin main`，再重试非强制 `git branch -d`，不要直接升级到 `-D`。
- 已被主线吸收的 dirty worktree 不能只凭 branch tip 是 main 祖先就清理：先逐文件比对冻结候选和 main，再归档未提交/未跟踪文件、ignored 原始证据及 SHA 清单。需要保留历史副本时，可按明确文件清单写入 snapshot tree/commit，保存 `refs/archive/<date>/<scope>` 后切到该 snapshot 的 detached HEAD，确认 clean 再普通 `git worktree remove`；源分支仍指向已合入提交，使用 `git branch -d`。归档提交不重新合入 main，不使用 stash、强制删除或回灌旧索引；先确认对应会话已停止写入。
- 多个 worktree 并行时，`git stash` 是仓库级全局操作（跨 worktree 共享 stash 列表），在一个 worktree `stash push/pop/drop` 会串扰到其它 worktree 的暂存内容——执行过程中可能把别人的 WIP 拉进来、或把自己的 stash 变成不可达引用。并行 issue 场景应彻底避免 `git stash`；需要保存中间态时改用临时分支或独立文件，主控核对每个 worktree 的最终完整度并回收即可。合并冲突的共享文件（如某 issue 改动了 `CLIActionCommands.swift`/schema 而另一 issue 也要改同一文件时）由主控按文件逐一裁决，不依赖 stash 找回。
- 发布前运行 `pod lib lint` 时，CocoaPods lint 走 ObjC-interop 的固定布局模式，可能比本机 SwiftPM `swift test` 更严格执行成员初始化器（memberwise init）的实参声明顺序；本地 SwiftPM 编译通过的代码，`pod lib lint` 仍可能报 `argument 'X' must precede argument 'Y'`。因此含新 DTO/成员初始化器的改动，发布门禁必须包含 `pod lib lint`，不能只以 `swift test`/`verify.sh --local` 的通过作为发布依据。
- 对仅部分完成、应保留 OPEN 的 issue，提交和 merge message 不使用 `fixes/closes/resolves #<id>` 等 GitHub closing keyword；否则 push 到默认分支会自动关闭。推送后核对 issue events，误关时恢复 OPEN 并解释未完成边界。
- 用户要求在 issue 合并后推送并关闭对应 GitHub issue 时，先确认 `main` 已推送成功，再关闭本轮已实现和验证的 issue；若 open 列表里出现新 issue，不顺手关闭。关闭评论写明实现提交、合并提交、integration fix 和验证范围；评论含命令片段或复杂 Markdown 时用 `--body-file`。
- 用户要求处理“线上全部 GitHub issue”时，先用 `gh issue list --state open --limit 100 --json number,title,url,labels` 固定初始队列；每个 issue 仍作为独立可审计交付单元完成 BDD/TDD、focused/full 门禁、提交与 main CI，不能因为目标是清零就把多个未验证修复混成一次关闭。关闭已验证 issue 后同步归档 space / memory，再重新执行同一 open 查询；只有返回空数组且最后一次归档 push 的 CI 通过，才能宣称 issue 清零。若复查出现新 issue，把它作为新队列项继续处理，不按初始快照误关。
- 全量 issue 收口至少保留三次线上快照：初始队列、实现/CI 期间的增量队列、最终归档 push/CI 后的 open 队列；增量 issue 必须新建独立 space，不得借用已完成 issue 的结论。关闭 issue 后仍要做 docs-only 归档提交、push、该提交自己的 CI 和最后一次 open 查询。
- 调整 CI、Release 或发布产物契约时，同步更新 `docs-linhay/dev/` 与 memory。
- 调整 Homebrew、tap、checksum 或 release asset 命名时，同步更新 README、`.github/homebrew/`、`docs-linhay/dev/` 与 memory。
- 调整 replay plan schema、record/replay 行为或 `.tritonplan` 对外契约时，同步更新 README、`docs-linhay/dev/ai-cli-readable-control.md`、真实项目回归 skill 与 memory。
- 调整 agent-facing CLI 默认输出、参数简写或 command schema 时，同步更新 README、`docs-linhay/dev/ai-cli-readable-control.md`、真实项目回归 skill、开发反馈 skill 与 memory。
- 调整 iOS / Harmony / CLI 接入使用指南时，同步更新 README、对应 dev 验收文档、`tritonkit-dev-feedback`、`tritonkit-real-project-regression`、必要时 `tritonkit-emulator-cli-takeover` 与 memory；接入口径必须拆分为 iOS embedded runtime、Harmony host-side HDC adapter、Harmony embedded SDK 和 macOS CLI install/run。

## 参考更新采用与跨会话交付

- 新会话模型：用户于2026-10-16指定本项目由agent新建的执行/主控会话统一为 `gpt-6.1-sol`；`create_thread` 显式传 `model: "gpt-6.1-sol"`，后续主控分派继承此约束，不依赖默认值、不自动改用其他模型。不可用则如实记录待重试/失败。既有会话和推理强度不因本指令自动调整。
- 区分只读追踪与采用授权，以当前聊天的用户追加指令和对应 space 当前有效规则为准；旧自动任务、历史研究的禁令不能覆盖用户后来的明确授权，来源仓库和其他会话也不产生新授权。
- 本项目用户于2026-10-16授权“后期评估可以纳入的改动可以直接按照这个流程直接进入开发”；随后明确“从 iCTRL 扩大到所有参考项目”，当前适用流程见 [SP-207](../../../docs-linhay/spaces/SP-207-reference-adoption-pipeline/README.md) 和 [正式说明](../../../docs-linhay/dev/reference-project-adoption-workflow.md)。评估对照当前源码/测试/已交付记录，保存理由、BDD与文件面后，直接分派独立space/worktree/执行会话，由主控验证、必要本地提交和本地main合并，不逐项重复确认。
- 先检查采用登记与现有会话，按机制/需求去重，区分读取成功、已评估、已分派、实现、验证和合并；会话创建失败保留待重试，不能把上游检查点当交付完成。适合复用的活跃主控可继续接管，新批次按范围建主控。
- 参考评估先核对当前branch、真实main SHA与worktree归属，不能把主目录HEAD等同main。产品用实际main blob评估，另一分支上的较新授权/追踪资料保留其事实效力；通过精确文件清单合入，索引与历史按main裁决，不整分支回灌旧产品。读取完整不等于二进制运行/设备验收；未执行产物明确记限制，未完成文本/分页覆盖仍不得推进检查点。
- 跨分支资料收口逐文件区分已完整吸收、较新主线替代与仍缺内容；源分支快照保留原文。共享索引/memory不能只追加完成段而保留顶部旧授权/旧待办；space README同样只保留一份当前状态与证据导航，add/add整合不重复嵌入整份README；独有审查事实移入明确标为历史的记录，原日志/hash/归档保持不变，旧交接报告指向最终验收（见[SP-222整理证据](../../../docs-linhay/spaces/SP-222-simulator-resource-retry-integration/plans/20261026-audit-history.md)）；采用登记同时核对state、controller_state、真实历史worktree路径与清理状态。文档门禁只证明结构，不能代替这些语义检查；最终以产品路径blob一致性及分支祖先关系证明没有回灌旧实现。 用户要求主目录回归 main 时，结束前核对主目录 branch、源 tip 的祖先关系、远端 SHA 和剩余 worktree。干净源目录完成整合后解除临时 checkout 对 main 的占用，再切回原目录；先归档 ignored 证据后正常移除临时 worktree，不使用强制删除掩盖未归档文件。
- 主控串行集成已冻结候选，保留其他WIP，独立验证实际联合差异并收口space/索引/memory；必要协调限于本批次执行会话。push/tag/release、依赖安装升级、设备/签名/DDI或产品边界扩展仍按各自明确授权处理，不从自动采用推导。

## 会话整理与模式沉淀

### 默认自动触发

自动沉淀经验：无需用户提醒。每个任务或交付切片收尾前执行治理闭环；有复用价值的用户纠正、缺陷、验证失败、返工或交付遗漏发生时立即查同主题资料并记录，证据齐备后在交付前补齐原文、索引和验证。未归因明确未知，不把临时猜测固化成规则；同一事件只更新原记录一次，不因多处引用重复计数。可安全收尾的阻塞移交也保留已知边界和下一步，不冒充完成。

自动执行范围仅为当前授权维护的资料；外部仓、生产、消息、付费调用、提交和后台定时运行仍按当前明确授权判断。没有可复用新经验时可以不改文件，最终结果简短说明“经验检查完成，无新增”；有更新则给出原文位置和证据范围。这是交付必经步骤，不能用“以后需要可再整理”替代。

### CLI 缓存清理与递归 schema 的证据规则

- 单并发验证默认使用项目默认 build/scratch（如 `swift test --package-path CLI --no-parallel`）；只有真实并行隔离或发布交叉编译等明确需要时才指定 scratch。同一 scratch 的测试与构建串行。
- 递归 schema 必须逐层核对模型、解码/编码、规范化/复制转换、最终 CLI JSON 与真实 parser；补旧 JSON 兼容、嵌套 round-trip、子树非空和完整 argv 测试。不能只给模型加字段就声称端到端支持。
- 不通过增加未使用父参数、删除真实错误码或跳过通用输出参数来换取测试绿色。测试应在实际参数所属命令验证，不能以放宽覆盖代替修复。
- SP-179已取消通用自动删除，当前只维护inspect/preview与confirm fail-closed；不继续派发删除实现。未来若另行立项缓存生命周期，删除验收必须包含精确根目录白名单（不用字符串 contains）、symlink/路径逃逸、活动构建、权限、替换竞态、部分失败、dry-run 不变和 confirm 删除边界的临时 fixture。重解析路径不等于消除 TOCTOU；不跟随 symlink 不等于删除父目录时保留内部链接。
- 报告区分 focused tests、完整 CLI、根包、local gate、发布资产和安装 smoke；局部绿色、发布脚本成功、资产存在均不替代删除安全验收。已发布后发现证据缺口应如实记入 space/memory，后续 patch 修复，不移动 tag。
- 门禁链必须在失败时停止（shell使用set -e或显式检查exit）；最终检查包含新增文件的暂存差异与完整候选diff，不能仅检查未暂存tracked diff。新证据文件同样遵守可追溯命名，避免latest/final路径；失败后修复再跑，不以前一版docs通过替代新增产物检查。


用户明确说“整理”“沉淀”“整理沉淀”“整理，沉淀，提交”“收尾整理”等时，再补做本轮完整回看；这些关键词是追加触发，不是默认自动沉淀的前提，不再追问是否需要沉淀。

沉淀按治理闭环先查同主题权威入口；本轮场景、原因/未知边界、可执行检查与验证证据写入原文，再按需更新经验索引。已解决项退出待办、被替代项注明历史关系，同一事件不重复计数，无新经验可不新增文件。

沉淀顺序：

1. 先用 `git status --short --branch` 和 `git diff --stat` 隔离已提交代码、未提交文档、外部仓验证和临时产物。
2. 抽取可复用模式，再区分稳定性边界：
   - 只在本次会话出现的，丢弃。
   - 后续还会重复的，先沉淀到项目级 skill。
   - repo-wide 且长期稳定的，再考虑更新 AGENTS。
3. 同步写入对应 `docs-linhay/dev/`、`docs-linhay/memory/` 或相关 `space`。
4. 运行 `git diff --check` 和 `docs-linhay/scripts/check-docs.sh`；若被既有文档结构问题阻塞，写清具体路径和与本次改动的关系。
5. 用户指令包含“提交”时，沉淀完成并验证后只 stage 本次整理相关文件并创建整理提交；不要默认 `git add -A`。

SwiftPM / CLI 修复沉淀：

1. 记录症状对应的 SwiftPM 边界：根 `Package.swift`、`CLI/Package.swift`、local path dependency、product/target identity。
2. 若修复是本地 path dependency identity，优先沉淀为显式 `.package(name:path:)` 规则，不把它误写成 product rename、target rename 或锁文件更新。
3. 验证顺序写清楚：先跑最小失败面，例如 `swift test --package-path CLI --filter <Suite>`；再跑完整 nested package；最后跑根 package。
4. 整理结论必须说明是否有 `Package.resolved`、生成文件或 build artifact 变化；没有变化时明确写“无需提交锁文件/生成文件”。
5. 这类流程优先写入对应 `docs-linhay/spaces/<space>/README.md` 的 session note；只有跨多个 space 重复出现时再升级到 ops governance 或 AGENTS。

## AGENTS 同步

- 只有 repo-wide、长期稳定、每次都应遵守的规则才进入 `AGENTS.md`。
- 对外发布的 TritonKit skills 源码统一进入 `TritonKit.skills/`；内部治理、实现、监督和规划 skill 作为真实目录进入 `.agents/skills/`。Release packaging 只能读取 `TritonKit.skills/`，不能从 `.agents/skills/` 打包。
- 单个领域或流程的可复用动作优先补充既有 skill；新增 skill 前先判断它是 `public` 还是 `internal`，避免对外使用者拿到内部治理规则。
- 新增 skill 前先判断是否能补充既有 skill，避免入口膨胀。
- skill 的 front matter `description` 只写触发场景和能力边界，详细规则写正文。
- 吸收外部 agent workflow skill 时，优先本地化触发条件、证据格式、停止条件和验收门禁；不要直接复制 hosted 服务依赖、模型品牌绑定或与 TritonKit 产品边界冲突的交互面。
- 大 diff / PR / worktree / 会话复盘可吸收 visual recap 的结构化方法，但默认产物是 `docs-linhay/spaces/<space-key>/plans/<YYYYMMDD>-recap-v01.md` 或 `docs-linhay/dev/<YYYYMMDD>-<topic>.md`；不把 Agent-Native hosted Plan 作为默认依赖。
- 涉及第三方快速变化 API、SDK、CLI、CI、包管理、Xcode、Android Emulator、DevEco / Harmony、Homebrew 或 GitHub 行为时，先读本地 repo docs/schema/generated types 或官方文档 / release notes，再写契约和示例。

## Subagent 监督交付

- 当任务可安全拆分且并行能明显提升速度或质量时，主控 agent 主动启用 subagent；用户明确要求时同样启用。简单、紧耦合或共享副作用任务保持单 agent / 串行。
- 主控 agent 负责边界、拆分、集成、验证、文档和最终完成判断。
- subagent 任务必须有清晰写入面；多个 subagent 不应写同一批文件。
- issue 级并行任务默认一 issue 一 worktree；主仓已有未提交改动时只读核对，不 stage、不重置、不顺手修。
- 主控 agent 不把“代码已改完”当作完成，必须跑完验证与写回。

## 完成检查

- 默认自动沉淀检查已执行：回看命中经验，核对证据与交付阶段；有新结论已更新原权威入口/索引并验证，无新增时最终结果说明原因。
- BDD 场景满足。
- 相关测试已运行并通过，或明确说明阻塞和风险。
- 文档与 memory 已更新。
- Space 新增、状态变化、worktree 集成或收口时，`docs-linhay/spaces/INDEX.md` 与 `docs-linhay/spaces/README.md` 已同步。
- 若产生可复用模式，已更新对应 skill 或说明暂不沉淀。
- 若任务要求“从头开始”，需同步检查 docs、skills 和 AGENTS 是否仍残留旧方向规则。

- 根包测试跨suite共享TritonKit.shared配置，suite内.serialized不足以隔离；本地/CI根包使用swift test --no-parallel。等待注入provider进入必须有界失败，不能无限Task.yield把能力门禁拒绝误成永久等待。发布Web测试先构建同候选CLI，再显式绑定TRITONKIT_TRITON_BIN。
