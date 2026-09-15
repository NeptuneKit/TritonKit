# SP-178 issue 213 real device runtime

## 边界

- Issue：[#213](https://github.com/NeptuneKit/TritonKit/issues/213)。影响 CLI `smoke ios` 的 embedded runtime 就绪诊断与单一 JSON 输出，不修改 SDK、HTTP server 监听默认值或桌面/Web。
- 采用 issue 允许的「精确 readiness failure + 真机 setup 路径」方案，而非自动网络发现或 endpoint 注入。host install/launch 成功不代表 runtime 或业务就绪。
- 复用既有 `feat/SP-177-issue-213-real-device-runtime` worktree 和提交 `4369552f`，补齐提交为 `240985db`。用户随后授权提交、发布、回复及关闭 issue；集成主线时发现 SP-177 已被资源管理 space 占用，因此本 issue 正式登记为 SP-178，旧分支/worktree 名仅作历史来源保留。
- 非目标：自动开放 LAN 服务、USB runtime 隧道、自动真机/runtime identity 绑定、真机截图、新增设备控制面。

## BDD

1. Given host 真机 open-url 成功但 server/runtime 不可达，When 执行 smoke，Then host step 仅为 `businessReady=false`，failure 为 `runtime.connect/runtime_not_connected`，不执行 wait/assert/evidence。
2. Given live runtime resolver 连接失败，When smoke 捕获原始错误，Then resolver 不预先打印 CLI error envelope，最终输出只有 smoke summary，保留原始错误而不是 `ExitCode`。
3. Given 真机连接失败，Then hint 说明 Debug bootstrap、Mac LAN endpoint、App 进程环境注入、runtime target 选择和文档路径；不把设备端 loopback 或仅在 Mac shell export 当成可用路径。
4. Given runtime 已就绪，Then 既有有界 wait/assert/evidence 流程保持不变；显式 `--target` 来自 `triton list --json`，host selector 不等于 runtime target。

## 验收与状态

- 状态：已随 [v0.2.21](https://github.com/NeptuneKit/TritonKit/releases/tag/v0.2.21) 发布并于 2026-09-15 回复关闭 #213；tag 指向 `2a814fde3ad780540997662635ae2ae32d619799`。
- 主线集成门禁：CLI 983 tests / 77 suites、root 269 tests / 34 suites、Web build、CocoaPods lint、public skill/版本/发布契约与本地门禁通过；主线 CI `34942529692`、tag CI `34943378446` 成功。
- Release workflow `34943378497` 双架构、x86_64 后补与两次 Homebrew tap 更新全部成功。全新下载的三个压缩包通过 checksum/gzip；双架构 CLI 与四个 skills 均为 0.2.21、skill git metadata 对齐 tag。
- Homebrew 从 0.2.19 升级到 0.2.21 并通过 formula test；仓库外隔离端口 34129 的 packaged Web HTML/JS/CSS 均 HTTP 200，验收进程已停止，不重启共享 runtime/server。
- [关闭回复](https://github.com/NeptuneKit/TritonKit/issues/213#issuecomment-5676856920) 保留真机端到端未复测、不提供 USB tunnel/自动绑定的边界；CocoaPods 仅 lint，未推送 trunk。
- 总门禁：`TRITON_VERIFY_XCODE=0 docs-linhay/scripts/verify.sh --local` 通过，根包 269 tests / 34 suites、Release CLI build、CLI/Harmony/iOS runtime observe 脚本 smoke、docs 与 diff 检查通过；明确跳过真实 Simulator build，不等于真机端到端验收。
- Red：旧实现下 5 tests 中 2 failed，共 5 个断言失败（resolver 打印额外 JSON 并抛 ExitCode，真机 hint 缺少可执行 setup）。
- Green：focused 5/5；CLI 全量 978 tests / 76 suites 通过。
- 本轮复查 open 队列仍仅 #213，无增量 issue；主仓仅保留用户原有 `CLAUDE.md` 改动。
- 日志：worktree `.build/issue-213-focused.log`、`.build/issue-213-cli-full.log`、`.build/issue-213-local-gate.log`（本地构建证据，不提交）。
- focused：`swift test --package-path CLI --scratch-path .build/cli --no-parallel --filter SmokeRuntimeTests`。
- CLI 全量：指定本次 `TRITON_CLI_PATH`，使用 `--no-parallel`。
- 本地总门禁：`TRITON_VERIFY_XCODE=0 docs-linhay/scripts/verify.sh --local`；本轮不改 UIKit，不擅自操作 Simulator/真机。
- 真实真机验收需提供已集成 Debug bootstrap 的签名 App、可达 Mac LAN endpoint、本地网络许可与目标 runtime 身份；未执行前不得宣称端到端通过。
- Setup：[iOS integration guide](../../dev/20260519-ios-integration-guide.md)。
