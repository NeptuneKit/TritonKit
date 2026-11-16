---
name: tritonkit-ops-governance
description: TritonKit 流程治理：任务或交付切片收尾时自动检查并沉淀经验，用户纠正、缺陷、验证失败、返工或交付遗漏时自动更新原权威资料；同时覆盖 CLI/HTTP/Wails 开发回路、文档记忆写回、AGENTS 同步及显式整理请求。
metadata:
  version: 0.1.0-dev
---

# TritonKit Operations & Governance

开工与交付按[经验索引](../../../docs-linhay/memory/EXPERIENCE.md)只读命中主题，未命中再检索；读取、证据、修订与退出遵循[治理闭环](../../../docs-linhay/dev/20260619-agent-workflow-skill-governance.md)。

## 原始业务数据职责

- 修改原始采集或导入时，按[根规则的原始数据职责](../../../AGENTS.md#12-原始数据职责2026-11-12-用户裁决)验证 provider → 模型 → 实际 JSON 或产物原值，并核对无法读回时的结果。实施证据见 [SP-286](../../../docs-linhay/spaces/SP-286-raw-business-data/README.md)。

## CLI / HTTP / Wails 开发回路

- 新需求先写 Space 与 BDD，编号登记、归档和资料落点见[项目治理流程](../../../docs-linhay/dev/20260619-agent-workflow-skill-governance.md)。
- 并行分配新 Space 编号时联合核对主索引和当前 main 的登记状态。独立未提交候选也占用编号；若碰号，仅调整本轮未提交候选并记录旧证据路径。前序 Space 尚未整合时，可精确提交真实需求/BDD/归属和源摘要的登记记录，明确产品 WIP 未纳入；不能复制未整合交付断言、捎入其他产品或放宽连续编号门禁。
- HTTP handler 优先用现有 `HummingbirdTesting` 的 `Application.test(.router)` 验证。涉及进程生命周期、信号或真实网络边界时启动实际 server。
- CLI 行为优先测试参数解析与命令分发。根包多 suite 共享 `TritonKit.shared` 配置，使用 `swift test --no-parallel`；等待注入 provider 须设置失败期限。
- CLI helper 若已经打印了机器可读错误 envelope 并通过 `ExitCode.failure` 终止，外层 catch 必须透传 `ExitCode`，不能再二次包装成另一个 `{ok:false,error:...}`。验证时要检查失败输出仍是单个合法 JSON 对象。
- 模拟器、真机和 Xcode 的范围、Triton-first 顺序与 fallback 证据从[对应内部 skill](../README.md)进入。
- 真实项目回归或 issue 证据优先用 `triton evidence capture --case <case> --output <dir.tritonevidence> --json` 生成 manifest + artifacts；需要拆解时再单独跑 `status/list/ax/screenshot/export`。
- `evidence capture --json` 的 stdout 必须是单一 manifest；消费方必须联合检查 `ok`、`partial`、顶层 `error` 与 `skipped[].error`。预期 unsupported 可返回 `ok:true, partial:true`；请求或写入失败返回 `ok:false, partial:true`、稳定 `evidence_capture_partial` 并以非零状态退出，不能只凭已存在的少量 artifacts 判断 capture 成功。
- 文本验收优先使用 `triton verify text-exists|text-not-exists <text> --json`，重复文本用 `--within`、`--role` 或 `--count` 收敛。
- 可复跑真实项目 smoke 优先沉淀为 `.tritonplan`：`record` 只生成模板，`plan inspect` 做离线摘要，`replay --dry-run` 先校验变量和脱敏命令，真实 `replay` 再执行并在失败步骤停止。
- 同文案多目标点击先用 `triton act find "<text>" --all --json` 获取候选；已知目标点位时优先用 `triton act tap "<text>" --at x,y --json` 消歧，也可用 `--index <n>` 或 `--within x,y,width,height`。`--within` 表示区域过滤，只有一个点位时不要把 width/height 伪造成 0。
- WebView 内 H5 控件命中问题优先保持 agent 高层入口：使用 `triton act tap --webview-aware --selector <css> --webview-id <id> --page-session-id <id> --expect-text <text> --json`，不要把 `webview tap/click` 暴露成主操作面。DOM click 为 `trusted=false`，没有 `--expect-text` 或其它显式验证时结果必须是 `uncertain`，不能宣称业务成功；`expect-request`、CDP/远程调试、任意 JS eval 和 trusted HID 合成需另建切片。
- 面向 agent 的 action 命令统一走 `triton act find/tap/swipe/type/paste/clear/press/focus/set-text/select-segment/set-switch/input`，默认要求机器可读输出。旧 action root 不再作为兼容入口；raw layout / AX 排查走 `triton debug ax --json` 或 `triton debug hierarchy --json`。
- 设备控制先区分 embedded runtime 与 macOS host adapter：embedded 仅承诺公开 UIKit 可验证的 in-app 控制；Simulator tap/swipe 使用内置隔离 HID helper，不调用外部 Baguette、不保留其 override/通用进程hook。其它设备级动作按各自现有 provider/unsupported 契约判断，不能把上游工具的能力名当作已接入能力。
- 新增 host-side fallback 时，默认 embedded 路径必须保持 fail-closed；只有显式 opt-in、目标 scope 和 geometry 校验通过后才能调用 adapter，并在结果中保留 source/strategy/geometry/sourceCommands 与 `verification.required` 边界，同时更新对外 public skill 的使用与验收说明。
- 可安装 artifact discovery 必须遵守平台安装性约束：Harmony `assembleApp` 只选择可识别为 signed 的 HAP；没有 signed 候选时沿用单一 `hap_artifact_not_found` 失败 envelope，不把 unsigned 产物伪装成 real-device installable artifact；兼容性更宽的 emulator/debug build 路径要单独标注。
- Wails 绑定先测绑定对象和 DTO；有真实 UI 后再补桌面窗口验收。
- iOS 接入按[示例契约](../../../TritonKit.skills/tritonkit-real-project-regression/references/ios-integration.md)维护文件级 Debug bootstrap 与 Release no-op。新增示例只在 app lifecycle 或 SwiftUI 入口保留 Debug 调用，只有需要自定义 delegate/消息路由时才用低层 `delegate` 或 `connect(host:port:)`。
- SwiftPM 支持 configuration-scoped build settings / compile conditions，但 SwiftPM / Xcode package product dependency 没有 CocoaPods-style Debug-only product dependency 开关；对外接入指南必须明确：默认走 package Debug compile flag + 源码级 `#if DEBUG` bootstrap + Release no-op runtime，若生产 Release target 必须完全不链接 TritonKit，则使用独立 Debug-only app target / scheme。
- SwiftPM 根 `Package.swift` 只描述业务 App 可依赖的 embedded SDK product，不声明 `triton` CLI executable、不声明 Hummingbird / ArgumentParser 等 CLI-only package dependencies；macOS CLI 统一由 `CLI/Package.swift` 构建，命令为 `swift build --package-path CLI --scratch-path .build/cli -c release --product triton`，避免 iOS App 解析 SwiftPM 时拉入 CLI 依赖。
- Swift 源文件超过 1500 行即进入治理范围；新增或扩展 CLI 能力时，默认按 `*Commands.swift`、`*Runtime.swift` / `*Service.swift`、`*Models.swift` 拆分。`*Models.swift` 只放 Codable/Encodable/Argument enum 等 wire contract，`*Commands.swift` 只放 ArgumentParser 参数和 glue，执行逻辑进入 runtime/service 文件。
- 发版、升级、产物与 Homebrew 验收使用[发布 skill](../tritonkit-release-package-governance/SKILL.md)和[发布契约](../../../docs-linhay/dev/20260519-github-ci-release-artifacts.md)。涉及竞争方案时使用[计划裁决 skill](../tritonkit-plan-arbiter/SKILL.md)。
- 本地验证从 `docs-linhay/scripts/verify.sh` 进入。CI 以[实际范围分类器](../../../docs-linhay/scripts/ci-validate-mode.sh)和 [workflow](../../../.github/workflows/ci.yml)为准。
- 用户明确要求“实现完成再测试 / 分段提交”时，每个切片先完成代码、测试、schema、文档与 memory 的一致性改动，再集中跑该切片的 focused tests、必要 schema tests、完整回归和文档门禁；不要在同一切片里每改几行就停下来跑测试，除非正在定位失败。
- 共享有副作用命令按[根规则](../../../AGENTS.md#1-基础工作方式)串行。互相独立的读取或使用不同 scratch path 的纯构建可并行。
- 同一 scratch build/test 串行执行；批量 issue 验证先冻结候选，在当前 main 依次运行并核对真实进程预算。出现过载只停止已绑定的本任务进程树，保留日志并明确“编译中断、测试未执行”，不杀其他任务的同名进程。
- 构建开始后冻结整个被编译 module 的全部 Sources/Tests；`--filter` 仅筛选执行，不减少测试模块编译输入。即使目标测试文件未改，其它 taxonomy/helper 改动仍可触发 `input file was modified during the build`。该失败只记编译竞态，不能当行为红证据；恢复冻结后重跑。
- 跟踪长构建进度先绑定本任务的tool session、启动命令/cwd/scratch和实际父子PID；不能从同名swift-frontend、SWBBuildService、dsymutil或别会话产物推断本候选阶段。进程消失/CPU活跃不等于成功，最终以本命令退出码及同候选日志/产物核实。
- CLI 全量测试若暴露 host command timeout、fake tool timeout 或 proxy serve `Connection refused`，先排查测试基础设施和并发资源竞态，不要只调大 timeout。`Process`/pipe runner 不应把阻塞式 `read`、`waitUntilExit` 大量投到 `DispatchQueue.global`；优先用专用 queue、`terminationHandler`、有界 pipe drain 和明确 cleanup。并发网络测试不要 `bind(0)` 取端口后无登记释放给多个用例抢用；同一 test runner 内应有 reservation 或其它唯一端口策略。
- 宿主输出收尾不能只等直接子进程退出：后代可能继承stdout/stderr写端。用真实自有shell/FD夹具分别验证内存/stdout-artifact/combined runner，外部watchdog防挂、仅清理精确自有PID。post-exit pipe预算需持续可读也检查，worker独占非阻塞read/close并join同步结果；真实EOF、字节cap、未EOF和读错误分开。失败证据保留实际exit与部分计数，不用incomplete遮住非零；磁盘open/write/close不是pipe deadline可取消范围，见[SP-224](../../../docs-linhay/spaces/SP-224-host-process-drain-integration/README.md)。 execution-timeout夹具应让deadline先于intentional interrupt；否则早到SIGINT可能在shell安装trap前形成合法duration成功，不能当超时回归。独立保留intentional-success测试，修正测试时不改生产timeout或放宽错误类型断言。
- GitHub issue / PR 评论若包含 Markdown 命令片段，必须通过文件传给 `gh --body-file`，优先使用 `docs-linhay/scripts/gh-issue-comment-file.sh`，避免 shell 执行反引号内容。
- 上报 GitHub issue 前必须脱敏工程和个人信息：真实工程名、App 名、bundle ID、team ID、组织名、用户名、账号、邮箱、手机号、内网域名、绝对私有路径、完整私有日志、未脱敏截图和证据包不得进入公开 issue；必要时使用 `<private-app>`、`<bundle-id>`、`<user>`、`<internal-host>`、`<repo-path>` 等占位符，并保留平台版本、TritonKit 版本、命令、错误码和最小可复现片段。
- GitHub 控制面遇到 DNS 失败时，不得把网络暂时不可达当成 issue 已处理，也不要改写 remote URL；可用 `dig +short @1.1.1.1 github.com A` / `api.github.com A` 获取临时地址，用 `GIT_SSH_COMMAND='ssh -o HostName=<github-ip> -o HostKeyAlias=github.com ...' git push origin main` 和 `curl --resolve api.github.com:443:<api-ip> ...` 直连复核。token 只放进进程环境或 shell 变量，不打印；push 后必须用远端 SHA、CI run 和最终 open 查询重新确认。API 直连评论/关闭时仍沿用 body-file 内容，不在 shell 中执行 Markdown。
- GitHub Actions 状态观察优先使用 `docs-linhay/scripts/gh-run-summary.sh --watch <run-id>`；失败后再拉完整日志，避免 `gh run watch` 重复输出淹没关键状态。

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

- 资料落点、各索引的职责和写回顺序见[项目治理流程](../../../docs-linhay/dev/20260619-agent-workflow-skill-governance.md)。
- 显式整理项目或会话时，先用 `git status --short --branch` 和 `git diff --stat` 区分本轮资料、其他 WIP、外部仓验证和临时产物。用户明确要求提交时，门禁通过后只暂存本轮差异与必要的归档证据。
- 同时处理多个 issue 时参照[主控监督流程](../tritonkit-subagent-supervision/SKILL.md)，按 issue 固定证据和文件面。
- 已吸收进 main 的 dirty 工作区不能只凭提交祖先关系清理：先逐文件比对当前候选和 main，再归档未提交/未跟踪文件、ignored 原始证据及 SHA 清单。归档后仍保留 main 工作区，不能使用 stash、强制重置或整目录覆盖；先确认对应会话已停止写入。
- 对仅部分完成、应保留 OPEN 的 issue，提交和 merge message 不使用 `fixes/closes/resolves #<id>` 等 GitHub closing keyword；否则 push 到默认分支会自动关闭。推送后核对 issue events，误关时恢复 OPEN 并解释未完成边界。
- 用户要求在 issue 合并后推送并关闭对应 GitHub issue 时，先确认 `main` 已推送成功，再关闭本轮已实现和验证的 issue；若 open 列表里出现新 issue，不顺手关闭。关闭评论写明实现提交、合并提交、integration fix 和验证范围；评论含命令片段或复杂 Markdown 时用 `--body-file`。
- 用户要求处理“线上全部 GitHub issue”时，先用 `gh issue list --state open --limit 100 --json number,title,url,labels` 固定初始队列；每个 issue 仍作为独立可审计交付单元完成 BDD/TDD、focused/full 门禁、提交与 main CI，不能因为目标是清零就把多个未验证修复混成一次关闭。关闭已验证 issue 后同步归档 space / memory，再重新执行同一 open 查询；只有返回空数组且最后一次归档 push 的 CI 通过，才能宣称 issue 清零。若复查出现新 issue，把它作为新队列项继续处理，不按初始快照误关。
- 全量 issue 收口至少保留三次线上快照：初始队列、实现/CI 期间的增量队列、最终归档 push/CI 后的 open 队列；增量 issue 必须新建独立 space，不得借用已完成 issue 的结论。关闭 issue 后仍要做 docs-only 归档提交、push、该提交自己的 CI 和最后一次 open 查询。
- 调整 CI、Release 或发布产物契约时，同步更新 `docs-linhay/dev/` 与 memory。
- 调整 Homebrew、tap、checksum 或 release asset 命名时，同步更新 README、`.github/homebrew/`、`docs-linhay/dev/` 与 memory。
- 调整 replay plan schema、record/replay 行为或 `.tritonplan` 对外契约时，同步更新 README、`docs-linhay/dev/ai-cli-readable-control.md`、真实项目回归 skill 与 memory。
- 调整 agent-facing CLI 默认输出、参数简写或 command schema 时，同步更新 README、`docs-linhay/dev/ai-cli-readable-control.md`、真实项目回归 skill、开发反馈 skill 与 memory。
- 调整 iOS / Harmony / CLI 接入使用指南时，同步更新 README、对应 dev 验收文档、`tritonkit-dev-feedback`、`tritonkit-real-project-regression`、必要时 `tritonkit-emulator-cli-takeover` 与 memory；接入口径必须拆分为 iOS embedded runtime、Harmony host-side HDC adapter、Harmony embedded SDK 和 macOS CLI install/run。

## 功能地图、skills 覆盖与静态图导出

- 功能实现、CLI/schema、public skill 文档覆盖、已安装 bundle 与真实平台验收是不同层。核对“skills 是否全有”时按功能族登记实际入口/部分覆盖/未找到，不用关键词命中或 command snapshot 打包通过证明所有流程完整；内部 skill 不代表外部已分发。优先补已有 skill/reference，不按每个命令膨胀 skill 数量。
- 功能图保留候选日期、HEAD/WIP、provider 前提和源码来源；后续提交不反写历史图为新的发布/现场证明。整理时当前 HEAD 已变化须另记收口基线。
- 浏览器导出以同一自包含 HTML 为唯一视觉源。独立固定 viewport、deviceScaleFactor、画布范围与未选中态，禁用 transition/animation、等待字体和实际绘制后导出；每次最终复导出都要再实际看图。DOM 矩形完整、0 文本溢出及 PNG 尺寸正确仍不能单独证明图片没有 scroller 裁切、空白或残留选中态。
- 正式成图与失败草稿分开；检查引用、PNG 原字节 hash/IHDR、离线资源与可移植脚本，精确提交正式版本。临时本机 URL/目录不作长期开机服务，不提交个人绝对路径；保留必要原始日志的本机副本并单独说明未纳入版本的范围。
- 补齐 public references 时同时验证源码目录与实际打包 tar 内的入口/链接可达；包内 guide 不能依赖 `docs-linhay/` 等仓库专用相对路径，跨四个 public skill 的引用仍要留在 bundle 内。新增专题接入 SKILL/feature-index，负例覆盖删文件、断路由、代码块伪链接及越界链接；只检查打包前文件存在不够。示例参数对照真实源码/定向 schema，help/parser 与设备/模型验收分开；验收辅助脚本的总体pass必须联合校验末步exit、ok与typed终态，不能只记录失败字段后继续报pass，采用独立负例复核门禁；可复跑证据见 [SP-288](../../../docs-linhay/spaces/SP-288-public-skills-completion/README.md)。
- 本轮可复跑边界与反例见 [SP-287 验收](../../../docs-linhay/spaces/SP-287-feature-map/plans/20261112-validation.md)；覆盖口径见 [skills 核对](../../../docs-linhay/spaces/SP-287-feature-map/plans/20261112-skills-coverage.md)。

## 参考更新采用与跨会话交付

- 用户授权新建本项目的执行或主控聊天时，模型参数遵循[项目新会话规则](../../../docs-linhay/dev/reference-project-adoption-workflow.md)。
- 区分只读追踪与采用授权，以当前聊天的用户追加指令和对应 space 当前有效规则为准；旧自动任务、历史研究的禁令不能覆盖用户后来的明确授权，来源仓库和其他会话也不产生新授权。
- 本项目用户于2026-10-16授权“后期评估可以纳入的改动可以直接按照这个流程直接进入开发”；随后明确“从 iCTRL 扩大到所有参考项目”，当前适用流程见 [SP-207](../../../docs-linhay/spaces/SP-207-reference-adoption-pipeline/README.md) 和 [正式说明](../../../docs-linhay/dev/reference-project-adoption-workflow.md)。评估对照当前源码/测试/已交付记录，保存理由、BDD与文件面后，直接在 main 串行实现、验证、提交和回写，不创建独立 branch/worktree。
- 长期追踪原始证据须在推进检查点前归档至scratch之外的持久目录，并登记路径、size/hash和复核时间；`.build`不能作为唯一证据位置，也不能把archives挂在将整体清理的worktree根下。当前参考监控使用独立`TritonKit-archives/reference-monitor/`，保留manifest并逐文件复核载荷；目录存在或旧hash通过不证明当前可恢复。历史读取成功与当前raw evidence可用性分开，缺失原因未知即记unknown；重取固定SHA只能标恢复副本，不能冒充旧API响应/执行日志。
- 先检查采用登记与现有会话，按机制/需求去重，区分读取成功、已评估、已分派、实现、验证和合并；会话创建失败保留待重试，不能把上游检查点当交付完成。适合复用的活跃主控可继续接管，新批次按范围建主控。
- 参考评估先核对当前 branch、真实 main SHA 和 `git status --short --branch`，不能把旧路径或历史快照等同当前 main。产品用实际 main blob 评估；较新的授权/追踪资料按文件清单写回 main，不整分支回灌旧产品。读取完整不等于二进制运行/设备验收；未执行产物明确记限制，未完成文本/分页覆盖仍不得推进检查点。
- 资料收口逐文件区分已完整吸收、较新主线替代与仍缺内容；源资料快照保留原文。共享索引/memory不能只追加完成段而保留顶部旧授权/旧待办；space README同样只保留一份当前状态与证据导航，add/add整合不重复嵌入整份README；独有审查事实移入明确标为历史的记录，原日志/hash/归档保持不变。文档门禁只证明结构，不能代替语义检查；最终以 main 产品路径 blob 一致性证明没有回灌旧实现。
- 主控串行集成已冻结候选，保留其他WIP，独立验证实际联合差异并收口space/索引/memory；必要协调限于本批次执行会话。push/tag/release、依赖安装升级、设备/签名/DDI或产品边界扩展仍按各自明确授权处理，不从自动采用推导。

## 会话整理与模式沉淀

### 默认自动触发

自动沉淀经验：无需用户提醒。收尾执行[治理闭环](../../../docs-linhay/dev/20260619-agent-workflow-skill-governance.md)，在原权威入口补记录与证据。用户显式要求整理时追加完整回看。

### CLI 缓存清理与递归 schema 的证据规则

- 单并发验证默认使用项目默认 build/scratch（如 `swift test --package-path CLI --no-parallel`）；只有真实并行隔离或发布交叉编译等明确需要时才指定 scratch。同一 scratch 的测试与构建串行。
- 递归 schema 必须逐层核对模型、解码/编码、规范化/复制转换、最终 CLI JSON 与真实 parser；补旧 JSON 兼容、嵌套 round-trip、子树非空和完整 argv 测试。不能只给模型加字段就声称端到端支持。
- 不通过增加未使用父参数、删除真实错误码或跳过通用输出参数来换取测试绿色。测试应在实际参数所属命令验证，不能以放宽覆盖代替修复。
- SP-179已取消通用自动删除，当前只维护inspect/preview与confirm fail-closed；不继续派发删除实现。未来若另行立项缓存生命周期，删除验收必须包含精确根目录白名单（不用字符串 contains）、symlink/路径逃逸、活动构建、权限、替换竞态、部分失败、dry-run 不变和 confirm 删除边界的临时 fixture。重解析路径不等于消除 TOCTOU；不跟随 symlink 不等于删除父目录时保留内部链接。
- 报告区分 focused tests、完整 CLI、根包、local gate、发布资产和安装 smoke；局部绿色、发布脚本成功、资产存在均不替代删除安全验收。已发布后发现证据缺口应如实记入 space/memory，后续 patch 修复，不移动 tag。
- 门禁链必须在失败时停止（shell使用set -e或显式检查exit）；最终检查包含新增文件的暂存差异与完整候选diff，不能仅检查未暂存tracked diff。新证据文件同样遵守可追溯命名，避免latest/final路径；失败后修复再跑，不以前一版docs通过替代新增产物检查。

SwiftPM / CLI 修复沉淀：

1. 记录症状对应的 SwiftPM 边界：根 `Package.swift`、`CLI/Package.swift`、local path dependency、product/target identity。
2. 若修复是本地 path dependency identity，优先沉淀为显式 `.package(name:path:)` 规则，不把它误写成 product rename、target rename 或锁文件更新。
3. 验证顺序写清楚：先跑最小失败面，例如 `swift test --package-path CLI --filter <Suite>`；再跑完整 nested package；最后跑根 package。
4. 整理结论必须说明是否有 `Package.resolved`、生成文件或 build artifact 变化；没有变化时明确写“无需提交锁文件/生成文件”。
5. 这类流程优先写入对应 `docs-linhay/spaces/<space>/README.md` 的 session note；只有跨多个 space 重复出现时再升级到 ops governance 或 AGENTS。

## AGENTS 同步

- 项目硬约束、经验、内部与发布 skill 的落点遵循[项目治理流程](../../../docs-linhay/dev/20260619-agent-workflow-skill-governance.md)。
- skill 的 front matter `description` 只写触发场景和能力边界，详细规则写正文。
- 吸收外部 agent workflow skill 时，优先本地化触发条件、证据格式、停止条件和验收门禁；不要直接复制 hosted 服务依赖、模型品牌绑定或与 TritonKit 产品边界冲突的交互面。

## 完成检查

按[根规则的完成定义](../../../AGENTS.md#6-skill-路由与完成定义)核对 BDD、适用门禁、资料和证据。任务要求“从头开始”时，另检查 AGENTS、skill 和资料中的旧方向是否已退出。
