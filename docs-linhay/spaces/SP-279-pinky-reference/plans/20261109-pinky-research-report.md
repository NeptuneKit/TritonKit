# SP-279 — Pinky 参考项目调研

## 任务与边界

用户要求下载 `https://github.com/DIYgod/pinky`、列为 TritonKit 参考项目并输出调研报告。本 space 只完成参考归档和静态研究，不运行 Pinky、Go/Kotlin 构建、第三方依赖、真实设备、MCP 服务或外部 agent；不修改 TritonKit 产品代码。

- 来源仓库：`DIYgod/pinky`
- 来源 URL：<https://github.com/DIYgod/pinky>
- 本地归档：[`docs-linhay/references/pinky`](../../../references/pinky/)
- 归档时间：2026-11-09（Asia/Shanghai）
- 固定版本：`v2026.1109.16`
- 固定提交：`209aa9e4b2ff1fd81edec3c393a64b21b79162fb`
- 默认分支：`main`
- 许可证：Apache-2.0；许可证文件 SHA-256：`c95bae1d1ce0235ecccd3560b772ec1efb97f348a79f0fbe0a634f0c2ccefe2c`
- 研究状态：已登记为正式参考项目；尚未形成产品采用任务

## BDD 与验收边界

- Given 用户指定 GitHub 仓库，When 参考归档完成，Then 本地目录保留可复核的完整 Git clone、远端 URL、固定提交和 tag。
- Given 参考项目需要进入长期登记，When 调研资料写回，Then `reference-state.json`、SP-207 入口、SP-279 space 和本日 memory 互相链接，且不把研究注册写成产品采用。
- Given 研究只基于源码和项目文档，When 输出结论，Then 明确区分源码观察、上游验收自述和本地未执行项。

## 项目定位

Pinky 是一个本地优先的“AI Agent 操作真实手机 + 人在回路安全网关”桌面应用。Agent 通过 MCP 调用统一的手机工具，桌面窗口展示手机画面、审批卡片、接管状态和任务历史；策略由网关执行，避免把“请 Agent 自己先询问”当成安全边界。README 将目标平台定义为 macOS、Windows、Linux，设备侧覆盖 Android 10–17 与 iOS 17.4+，当前项目自述仍为 pre-alpha。

源码布局显示它是单 Go 主程序加 Android Kotlin Companion：

| 层 | 主要路径 | 静态观察 |
| --- | --- | --- |
| CLI/桌面入口 | `cmd/pinky/`、`ui/` | 同一可执行文件提供桌面应用、daemon、MCP stdio、设备查询、token、退出和更新命令；MyGo 原生 UI，不使用 Electron/webview |
| 网关与 Agent 合同 | `internal/gateway/`、`internal/mcp/`、`internal/api/` | 会话、设备租约、工具调用、结果状态、stdio 转发、Streamable HTTP、sessionless HTTP 和上传链路集中在网关边界 |
| 策略与审批 | `internal/policy/`、`internal/approval/` | 规则判断与等待人工决策分离；审批绑定 session/device/lease/tool/args，单次消费，超时按拒绝处理 |
| 设备驱动 | `internal/driver/android/`、`internal/driver/ios/` | Android 走 adb/scrcpy/后台显示/Companion；iOS 走 go-ios/CoreDevice 与旧系统 WebDriverAgent 路径 |
| 画面与记录 | `internal/screen/`、`internal/video/`、`internal/history/`、`internal/recording/` | 统一 screen/result 表达、视频解码、截图、录屏、步骤历史与 HTML/JSON 导出 |
| Android Companion | `android/companion/`、`internal/driver/android/companion/` | Kotlin 无障碍服务通过 adb forward 到抽象 Unix socket，向 Go 端提供树、事件和文本输入能力 |
| 配置/遥测/更新 | `internal/secret/`、`internal/telemetry/`、`internal/update/` | 本地 secret、匿名统计/崩溃上报、跨平台自动更新和回滚相关逻辑独立成包 |

固定版本 `go.mod` 声明 Go 1.27.3，核心依赖包括 MCP Go SDK 1.8.0、MyGo、go-ios、purego、FFmpeg/视频相关库、SQLite、YAML/TOML 和 gVisor；没有 Node 前端工程，仓库中另有一个独立 `worker/` JavaScript 包。归档统计为 681 个 Go 源文件、280 个 Go 测试文件、10 个 Kotlin 文件和约 90 个文档文件（按 Git tracked 文件后缀统计）。

## 关键机制

### 1. MCP 入口与会话

`cmd/pinky/main.go` 将桌面应用、无 UI daemon 和 `mcp` stdio shim 统一到一个命令面；`pinky mcp` 在网关不存在时启动它，并通过本地 socket 转发 Agent 会话。`internal/mcp/http.go` 在 `/mcp` 提供 Streamable HTTP，要求 Bearer agent token，默认 session 空闲一小时失效；跨源请求和 loopback DNS rebinding 由 HTTP 保护层拦截。HTTP 会话关闭时会结束租约和撤回审批。

项目的 14 个工具围绕 `phone_connect`、`phone_observe`、tap/type/swipe/key/launch、batch、wait、files、request approval、handoff 和 release 组织。工具结果使用面向 Agent 的文本协议，状态包含 `settled`、`uncertain`、`approval_pending`、`blocked_by_policy`、`stale`、`user_took_over`、`paused`、`device_needs_setup` 等，错误单独使用 `lease_held`、`scope_denied`、`unsupported` 等错误码。

### 2. 网关审批与策略

`internal/approval/approval.go` 的注释和实现明确显示：

- 审批由桌面客户端决定，Agent-facing gateway 没有批准接口；
- 审批绑定调用的 session、device、lease、tool 和参数摘要，参数变化会拒绝复用；
- 审批是单次消费；
- 60 秒默认超时按 Deny 处理；
- session 关闭、任务停止或设备移除会撤回未执行审批。

`internal/gateway/agent.go` 将策略拒绝、人工审批、设备掉线和用户接管编码为不同结果。项目设计文档把“enforce, don't instruct”和“uncertain 时先观察、禁止盲目重试”列为产品原则，这与 TritonKit 现有的 fail-closed、typed status 和 evidence 边界高度相关。

### 3. Android 与 iOS 设备路径

Android 主路径通过 adb 连接，使用 scrcpy 做视频，Companion 仅在 Agent 工作期间启用无障碍服务，以较快地读取 UI 树、事件和文本输入；Android 13+ 支持后台虚拟显示，以便手机自己的屏幕保持锁定。Android 10 还保留 `adb tcpip` 迁移到 Wi-Fi 的兼容路径，Android 11+ 使用 Wireless debugging 配对。源码和文档同时覆盖品牌 USB 调试设置、网络发现、Tailscale 远程连接、OCR、密码/验证码字段限制和文件传输。

iOS 27+ 走 Xcode Device Hub/CoreDevice 协议，目标是无需在手机安装应用；iOS 17.4–26 通过一次性从 Xcode 安装的 WebDriverAgent helper 提供输入能力。连接方式、开发者磁盘映像、Wi-Fi 信任、屏幕共享影响和银行应用限制都在驱动/文档中分层描述。

### 4. 记录与本地优先

任务步骤、审批、截图、录屏和 HTML/JSON 导出由 history/recording 相关包负责。README 与设计文档声明默认留在用户电脑上；blocked app、密码、验证码和锁屏画面对 Agent 的可见性受到额外遮蔽。遥测文档则单独列出匿名计数、崩溃和可关闭的 `DO_NOT_TRACK=1` 开关，研究时需要把“本地业务数据保留”与“匿名运维数据外发”分开核对。

## 与 TritonKit 的相关性

| 结论 | 判断 | 依据与边界 |
| --- | --- | --- |
| 网关审批、租约、接管和 `uncertain` 结果 | 高相关，可作为设计参考 | Pinky 在网关内将策略、审批、session/lease 和设备动作绑定，适合对照 TritonKit 的 action/evidence/target lease 契约；尚未证明两者 wire/schema 兼容 |
| MCP stdio + Streamable HTTP 双入口 | 高相关，可作为协议参考 | `internal/mcp` 提供本地 shim、HTTP token、session 生命周期和无 session-id 兼容；TritonKit 应独立核对自身 MCP/HTTP 契约，不能直接复制实现 |
| Android Companion 与后台显示 | 中高相关 | 可对照 TritonKit Android Emulator / embedded runtime 的树、输入、后台显示与权限边界；Pinky 面向真实手机，设备权限与生命周期不等于本机模拟器 |
| iOS CoreDevice / WebDriverAgent 分层 | 中高相关 | 可对照 TritonKit 的 Xcode/Simulator/真机边界和 provider fallback；Pinky 的 iOS 27 Device Hub 实现未在本地运行或审计 |
| 任务历史、截图、录屏和 HTML 导出 | 中相关 | 可作为 evidence/回放产品体验参考；Pinky 的保留周期、隐私遮蔽和报告结构需要单独与 TritonKit evidence manifest 对齐 |
| MyGo 原生桌面 UI | 低至中相关 | 对 TritonKit Wails/Web mock 产品边界有比较价值，但技术栈和产品控制面不同；不据此引入 MyGo |
| 具体驱动代码和第三方依赖 | 当前不采用 | 依赖 Apple/Android 私有或平台条件，且本次没有运行、许可链和跨平台构建验证；不直接复制源码或依赖 |

## 可借鉴的设计要点

1. **审批应绑定动作事实。** 将 approval id 绑定到 session、设备租约、tool 和参数摘要，可阻断“等待期间换目标或换参数”造成的越权；TritonKit 的 action/evidence 设计可继续采用同样的绑定思路。
2. **把结果状态分型。** `uncertain`、`stale`、`device_needs_setup`、`blocked_by_policy` 和 `approval_pending` 分别表达执行不确定、屏幕变化、前置人工步骤、策略拒绝和等待决策，便于 Agent 选择观察、交接或停止，而不是把所有失败归成一个错误。
3. **统一 human-in-the-loop 入口。** Pinky 将审批、解锁、handoff、takeover 和 stop 聚合到桌面客户端的 Needs you 区域，减少不同动作各自实现确认 UI 的漂移。
4. **设备驱动与网关解耦。** 网关消费统一 screen/driver/result 接口，Android/iOS 通过 driver provider 接入；这与 TritonKit 的 provider/capability/target 分层方向一致。
5. **本地记录与 Agent 可见数据分离。** Agent 看到的是经过遮蔽和策略过滤的 screen/result，用户本地历史可以保留更多审计信息；两者应有明确的 evidence authority 和 retention 规则。

## 风险、限制与未知

- 本次只做源码和文档静态检查，未执行 `make check`、`go build`、`go test`、Gradle 构建、Pinky 二进制、MCP server、真实手机或模拟器。
- README、DESIGN.md 和 ACCEPTANCE.md 混合记录产品目标、已完成检查和待人工验证项；报告按文档明确标记保留，不能把 `[ ]` 项视为已交付。
- iOS CoreDevice、WebDriverAgent、Android Companion、FFmpeg、adb 和 go-ios 的跨平台兼容、签名、设备服务、权限和性能没有在 TritonKit 环境复验。
- 远程 HTTP 默认 token、loopback/DNS rebinding、上传一次性链接和 Tailscale 的安全性只依据源码观察；没有做网络边界测试。
- Pinky 的许可证是 Apache-2.0，但 go.mod 依赖和打包资源拥有各自上游许可；任何代码采用前必须逐依赖核对许可证、NOTICE、商标和发布条件。
- 项目源码在归档时保留了其嵌套 Git 元数据，归档目录用于参考与复核，不属于 TritonKit 产品源代码。

## 结论与后续

Pinky 已列为正式参考项目，当前最值得长期跟踪的是“网关强制审批 + 设备租约 + 可恢复/不可盲重试结果 + 本地任务记录”这一整套 Agent 操作安全模型，以及 MCP stdio/HTTP 的会话生命周期。它不自动触发 TritonKit 产品采用；如后续出现明确的本地缺口，应按“机制 + 当前 main 差距 + BDD + 独立 space/worktree + 验证证据”新建采用切片。

本轮未运行第三方代码、未安装依赖、未操作设备、未修改产品代码、未提交或推送远端。
