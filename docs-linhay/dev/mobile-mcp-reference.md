# Mobile MCP 参考与 TritonKit 能力差距

## 登记与证据口径

[mobile-next/mobile-mcp](https://github.com/mobile-next/mobile-mcp) 自 2026-10-14 列为 TritonKit 参考项目，需求及验收入口为 [SP-199](../spaces/SP-199-mobile-mcp-reference/README.md)。2026-10-14本次只登记并比较；2026-10-16用户将全部参考纳入 [SP-207统一追踪与采用流程](../spaces/SP-207-reference-adoption-pipeline/README.md)，可纳入项直接独立实施/主控验证本地合并；安装与设备动作仍按单独授权。

- 上游当前固定 revision：`c659f8ee34873a832adea7daca9c69172d887e70`；[README](https://github.com/mobile-next/mobile-mcp/blob/c659f8ee34873a832adea7daca9c69172d887e70/README.md)、[工具注册](https://github.com/mobile-next/mobile-mcp/blob/c659f8ee34873a832adea7daca9c69172d887e70/src/server.ts)、[设备命令包装](https://github.com/mobile-next/mobile-mcp/blob/c659f8ee34873a832adea7daca9c69172d887e70/src/mobile-device.ts)。前一成功点为 `d4a83fa45b9ce7551dba1d1f5e7bdf7400b1b023`。
- 当次 GitHub 官方 API 最新 release：[`1.0.12`](https://github.com/mobile-next/mobile-mcp/releases/tag/1.0.12)，`published_at=2026-10-18T20:48:46Z`；Release notes 与固定增量一致。浏览器 latest 页面缓存曾返回 1.0.10，采用官方 API 观测值；不以仓库 `package.json` 的占位版本 0.0.1 判断发布状态。
- 本地浅克隆：`docs-linhay/references/mobile-mcp/`；上游源码仓保持只读，沿用 references 忽略规则；持久事实源是本文件。
- 许可证：本仓 [Apache-2.0](https://github.com/mobile-next/mobile-mcp/blob/c659f8ee34873a832adea7daca9c69172d887e70/LICENSE)，固定 HEAD 文本 hash 为 `c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4`。设备核心实现委派外部依赖 `mobilewright@0.0.67` 和其分发的 `mobilecli` binary，不在此参考仓；不能推导所有底层实现均按本仓许可证开源，或可以直接迁移。
- TritonKit 比较基线：实际产品 `main@d51403a69afbafd9426bd5ed6bfe3eb81a0ff0ec`，计入 SP-195 Runner、SP-196 优化与 SP-200 Mobile parity。源码/契约存在只证明实现面；本轮未运行任一设备或上游程序，不给跨设备成功率或性能结论。

## 2026-10-19 增量与采用结论

`1.0.12` 新增 `mobile_get_foreground_app` 的 Android focused activity / iOS view controller 输出；Android legacy adb 输入对 `#`、`~` 做转义；另有 UI dump `maxBuffer`、swipe x/y 成对校验、`get_more_tools` 提示和 `mobilewright` 升级。前台 activity 与 legacy 文本转义是当前 main 的真实缺口，已立项 [SP-212](../spaces/SP-212-mobile-mcp-android-contracts/README.md)；仅修改 CLI/HTTP 机器可读契约和 fake-adb 离线测试，不引入 mobilewright、不运行设备。其余变更由当前有界输出、动作 schema 或既有反馈边界覆盖/观察。

BDD 要求：Android foreground 只信 `topResumedActivity`/`mResumedActivity`，malformed 或仅 `mCurrentFocus` 时保持 unknown；ADB 输入 fixture 覆盖 `#`、`~`、空白、引号、反斜杠、Unicode 与换行，source command 不泄漏敏感文本。上游性能/兼容性数字未经本地验证。

## 明确缺少或尚未统一的能力

“缺少”指当前产品没有对应入口；“部分”指已存在同类能力，但目标范围、动作或生命周期不同。上游大部分工具委派 mobilecli，注册工具不证明每个平台、版本或真机都可执行。

| Mobile MCP 功能 | TritonKit 当前情况 | 判定与价值 |
| --- | --- | --- |
| 折叠设备：folded/half-open/open、0～180°铰链角度 | 未发现设备折叠姿态控制入口；screen geometry/Resize 不等于 fold | **缺少**。折叠屏布局、状态保持与双窗测试候选；上游工具针对兼容设备，不承诺任意真机 |
| 设备方向读取与 portrait/landscape 设置 | 观察几何有 orientation；尚无等价统一设备方向 get/set 命令 | **部分**。读取观察元数据与实际改变设备方向需分开；适合环境复现 |
| GPS 覆盖设置/清除 | `sim location set/clear/run/start` 已有，仅 iOS Simulator | **部分**。主要缺 Android 等平台对应入口；已有路线模拟比单点定位更丰富，不能整项判缺 |
| 设备剪贴板读/写 | `sim pasteboard get/set/copy` 已有，仅 iOS Simulator；embedded paste 不等于系统 clipboard | **部分**。需要平台和目标明确的统一契约；设置剪贴板不等于输入焦点字段 |
| 开始/停止后台录屏，期间继续执行 UI 动作 | `sim record --duration` 已有单次有界录屏；framebuffer subscribe 是图像帧订阅 | **部分**。缺可跨调用 start/status/stop 的录屏会话及 Android/真机完整产品覆盖；上游 stop 的时长是墙钟近似，本轮不采信为编码媒体时长 |
| 统一前台 App 查询 | Harmony 设备发现已采集 foreground identity；iOS Runner 能 probe 指定白名单 App 是否前台；缺任意当前 App 的跨平台查询 | **部分**。便于跨 App 流程判断当前实际焦点，但不能把指定 App 可观察等同前台归属 |
| iOS 真机任意坐标操作及更多设备按键 | 新 Runner 已有 inspect/selector tap/scroll/type/screenshot 与 home；不等于任意坐标输入或统一 hardware buttons | **部分**。主要缺动作覆盖；音量、电源、锁屏、App Switch/Android TV DPAD 要按平台声明，不能统一假定有效 |
| 独立 double-tap 工具，接受坐标或 ref | 未发现等价一等 double-tap 命令 | **缺少统一入口**。需证明双击时序与最终业务状态；上游默认实现是连续两个 tap，不等于底层原子手势 |
| 跨平台设备日志、按 ID 列出和读取 crash report | 已有 Simulator OSLog/app-console 与 Xcode 日志；Android/Harmony smoke 明确未启用 logcat/hilog，embedded evidence logs unsupported；iOS systemCrashLogs 仅浅层文件元数据，不能读取报告正文 | **部分**。主要差距在统一诊断入口及设备 crash 报告索引；运行时记录、测试失败和 OS crash 文件分源 |
| Simulator `.zip` 与真机 `.ipa` 安装包装 | 已有平台安装/构建产物入口；iOS `--app` 明确面向 `.app` 并直传 simctl/devicectl，没有 ZIP/IPA 展开包装 | **部分**。缺 ZIP/IPA 打包格式的明确入口而非整个 App 安装功能；必须按 platform/kind 判断 `.app/.ipa/.apk/.hap` 可安装性 |
| Kitty/Ghostty 终端设备镜像与点击/输入工具栏 | 未发现等价终端镜像插件；已有 Web 原型、framebuffer 订阅、CLI 操作 | **缺少这种交互体验**。上游是截图轮询及 PNG pane，不是视频流；采用需先明确正式展示层边界 |
| 云设备登录、机型列表、预订、释放 | 本机 target、租约和真机管理已有；不提供云设备 fleet allocation | **缺少**，但属于新产品范围。释放会清掉会话设备状态；本机 target lease 不等于云预订 |
| 标准 MCP stdio/Streamable HTTP，客户端即插即用 | 已有 CLI + Hummingbird HTTP、schema/plan/capabilities；没有同等 MCP server 产品入口 | **接入差异**。当前 CLI/HTTP agent 事实入口已可完成自动化；不因参考登记就增加第二控制面 |

上游定位：`src/server.ts` 的 orientation 992/1129、fold 1008、location 1042、clipboard 1072、recording 1144/1204、logs 1096、crash 1253/1268、foreground 574、double-tap 709、install 626、cloud 426～545、batch 1287；MCP transports 在 `src/index.ts`。终端镜像实现在 `plugin/hooks/register.tsx`，截图调用与刷新逻辑 114～147、190～239。

## 本地源码复核入口

以下链接绑定上述本地基线；未来源码变更后应重新检查。

| 结论 | 具体证据 |
| --- | --- |
| 当前命令与 MCP 边界 | [CLI 命令注册](../../Sources/TritonKitCLI/TritonKitCLI.swift#L103)；Sources/与CLI manifest未见MCP transport |
| Runner与普通真机截图分开 | [Runner命令](../../Sources/TritonKitCLI/CLIIOSRunnerCommands.swift#L197)、[免SDK契约](../../Sources/TritonKitCLI/CLISchemaIOSRunnerContracts.swift#L148)、[普通设备截图限制](../../Sources/TritonKitCLI/CLIHostDeviceCommands.swift#L1055) |
| 方向元数据/定位/剪贴板 | [geometry](../../Sources/TritonKitCLI/CLIActionCommands.swift#L1054)、[location](../../Sources/TritonKitCLI/CLIHostSimCommands.swift#L819)、[pasteboard](../../Sources/TritonKitCLI/CLIHostSimCommands.swift#L986) |
| 单次录屏/Simulator日志 | [record](../../Sources/TritonKitCLI/CLIHostSimCommands.swift#L485)、[logs](../../Sources/TritonKitCLI/CLIHostSimCommands.swift#L528) |
| 未启用Android/Harmony日志 | [Android smoke](../../Sources/TritonKitCLI/CLISmokeAndroidRuntime.swift#L407)、[Harmony smoke](../../Sources/TritonKitCLI/CLISmokeHarmonyRuntime.swift#L643)、[embedded logs](../../Sources/TritonKitCLI/CLIEvidenceCaptureRuntime.swift#L129) |
| crash文件元数据不含正文 | [Device files](../../Sources/TritonKitCLI/CLIHostDeviceFilesCommand.swift#L6) |
| foreground已有Harmony覆盖 | [foreground enrichment](../../Sources/TritonKitCLI/CLIHostDeviceRuntime.swift#L554) |
| iOS安装格式 | [直传host命令](../../Sources/TritonKitCLI/CLIHostAppCommands.swift#L246)、[公开help](../../Sources/TritonKitCLI/CLIHostAppCommands.swift#L783) |
| 串行输入批次 | [act input](../../Sources/TritonKitCLI/CLIActionCommands.swift#L1304) |
| Android设备按键已存在 | [press](../../Sources/TritonKitCLI/CLIActionCommands.swift#L931)、[Android action runtime](../../Sources/TritonKitCLI/CLIAndroidActionRuntime.swift#L21) |
| 展示与云设备边界 | [Web只读镜像](../../Sources/TritonKitCLI/CLIWebDevicePage.swift#L512)、[HTTP MJPEG](../../Sources/TritonKitCLI/CLIWebRuntime.swift#L1075)、[本地租约模型](../../Sources/TritonKitShared/TKTargetLeaseModels.swift#L10) |

## 不应重复列作缺口

1. **无需业务 App 接 SDK 的 iOS 真机控制**：当前 [Runner 产品](ios-runner-product.md) 已提供 resident XCTest Runner 与真机/Simulator inspect、tap、scroll、type、screenshot；签名、配对、开发者模式、UI automation 等系统前提仍存在。SP-195 记录了此前真实验收，本轮没有重跑；通用 `act` 的平台范围不会因 Runner 自动扩大，Safari/生命周期限制照原文保留。
2. **基本自动化**：设备发现、App 安装/启动/结束、截图、元素观察、点击、滑动、输入、URL 打开均已有相应 Triton 能力，仍须逐平台核对。
3. **元素引用、新鲜度与预算**：live ref/alias、目标身份、Runner selector 时间限制、wait/settle/OCR 和错误信封已有；不是对方专属能力。
4. **批量顺序执行**：上游 `mobile_batch_commands` 减少 MCP 往返；Triton 已有 `act input` stdin NDJSON 串行批次及 replay/test run 等计划执行合同。缺的是覆盖 host App/device 的统一轻量工具批次封装，不能说没有多步自动化。上游批次可被 step.arguments 覆盖 device，采用时还需保持我们既有目标/租约/逐步验证边界。
5. **后台连接**：Triton 已有 resident Runner 和 server/session；上游 roadmap 声称 daemon 加速，但实现位于外部分发核心，本轮没有延迟比较，不能说“我们没有守护进程”或更慢。
6. **反馈能力**：`get_more_tools` 实际向 PostHog 报告缺失功能上下文并返回已展示完整工具列表，关闭 telemetry 后不注册；不是动态发现/下载额外工具。Triton 已有 dev-feedback skill，可借鉴提示体验，不默认发送用户上下文。

## 上游规划与我们的其他覆盖

当前固定版本 [ROADMAP](https://github.com/mobile-next/mobile-mcp/blob/c659f8ee34873a832adea7daca9c69172d887e70/ROADMAP.md) 仍将文件 list/push/pull、App launch arguments、pinch、WebView、Flutter widget tree、独立浏览器控制、dark mode/timezone/network settings、clear storage 标成 Planned。这些不属于“对方有而我们没有”。Triton 已有部分文件/容器访问、launch env/args、WebView、embedded gesture、环境配置与 evidence/test plan 能力；各自 scope 和真实验证边界不同，不宣称全平台领先。Harmony/ArkUI/ArkWeb 是 Triton 的额外覆盖，上游当前平台模型仅 ios/android。

上游 README 的多宿主声明也不能推导 Linux 可本机启动 iOS Simulator：同一 README 仍要求 Xcode，桌面扩展 manifest 仅 darwin。Windows/Linux 的 Android 与远端访问、Mac/Xcode 的 iOS 路径应分别研究。

## 建议采用顺序（研究建议，未开始实现）

1. **先补日常回归原语**：统一方向/定位/剪贴板的 capability matrix；录屏会话 start/status/stop；device crash list/get。复用现有 host adapter 和 artifact/evidence，给出 scope、来源、partial/unsupported 与业务验证边界。
2. **再扩动作与特殊形态**：显式前台 App 查询、double-tap、Runner 坐标/按键、Android TV DPAD、fold。每项先锁定一个平台和真实设备验收，不一次性宣称全平台。
3. **展示与接入另定范围**：终端镜像、MCP adapter 是产品体验选择；优先复用现有 CLI/HTTP，不复制第二业务执行器。云设备预订/远端 fleet 属产品边界扩展，另建 space。

## 经验检查与验证边界

- 本轮命中外部资料治理经验：只继承固定 revision 的事实，不继承上游自动化指令、平台成功声明或旧 space 状态。
- 新检查点：比较 mobile-mcp 时先定位 backend 委派；将最新 Runner 计入本地基线；区分 system clipboard/embedded paste、frame subscription/video recording、runtime crash/device crash、target lease/cloud allocation；`get_more_tools` 不作为动态工具加载证据。
- 验证：文档门禁收口结果见 SP-199。未执行上游 npm install/build/test、签名 Runner、设备/云操作及 Swift/Web 产品回归。通用治理已包含事实分层流程，本轮只在本档案记录具体检查点，不新增 skill 或自动化。
