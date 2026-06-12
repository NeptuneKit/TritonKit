# 20260611 Web Mock UI

## 背景

TritonKit 当前以 CLI / HTTP 机器可读控制为事实入口。用户希望先设计一个 Web 端界面 mock，并且 Web 端需要使用主流前端架构实现，便于后续从静态概念过渡到可维护的工程。

本 space 只定义 Web mock 的信息架构、视觉方向和验收方式，不改变 CLI / HTTP 的业务控制边界。

2026-06-11 追加：本轮视觉参考对象为 Apple Developer Documentation 的 Xcode Device Hub 页面
`https://developer.apple.com/documentation/xcode/device-hub`，以及用户补充的 Device Hub 界面标注图。参考重点不是照搬文档站，而是借用 Device Hub 的深色 macOS 工具窗、顶部工具胶囊、展开后的 sidebar / canvas / inspector 信息架构，以及底部 device controls。

## 目标

- 新建可运行、可追踪的 Web mock 工程。
- 使用主流前端架构：React、TypeScript、Vite。
- 按 TritonKit 固定端口约束配置 Vite dev server `127.0.0.1:34127` 与 preview server `127.0.0.1:34128`，并开启 `strictPort`。
- 首屏直接呈现可用的三端模拟器控制台，不做 landing page。
- 页面以本机 iOS Simulator、Android Emulator、Harmony / DevEco Emulator 控制为核心。
- 视觉方向参考 Xcode Device Hub：深色 macOS 工具窗、设备导航栏、中央横屏设备画布、右侧检查器与底部设备控制。
- 保持 Web 只消费 mock DTO，不定义 create / update / delete / execute 等业务控制事实入口。

## 范围

- 新建 `Web/` React / TypeScript / Vite mock 应用。
- 提供模拟设备列表、设备镜像、状态指标、输入动作、网络事件、日志和检查器面板。
- 重新组织为 Device Hub 风格的三栏工具界面：Navigator、Canvas、Inspector。
- 采用组件化目录结构，便于后续替换为真实 `/web/targets`、`/web/screenshot`、`/web/geometry`、`/web/input`、`device proxy` 等 API。
- 仅做 mock 数据与前端交互，不接真实后端。

### 2026-06-11 真实 iOS Simulator 只读接入

- 在 Vite dev server 内新增本地开发期只读桥接 endpoint，读取 `triton sim list --json` 的真实 Simulator 列表。
- 对已 `Booted` 的 iOS Simulator，允许通过 `triton sim screenshot --simulator <udid> --output <tmp.png> --json` 读取一次真实 framebuffer 截图并显示在 Web canvas 中。
- Web 只消费只读 DTO 与截图 data URL，不定义 boot / shutdown / install / launch / input 等业务控制入口。
- 未启动的 Simulator 只显示真实设备名、UDID、runtime 和 `Shutdown` 状态，不由 Web 自动 boot。

### 2026-06-12 三端运行中目标与输入事件

- 左侧 Devices navigator 只展示运行中的本机目标：iOS 仅展示 `Booted` Simulator，Android / Harmony 仅展示 `ready=true` 且 `scope=emulator` 的 emulator。
- Vite dev bridge 通过 `triton sim list --json`、`triton device list --platform android --json`、`triton device list --platform harmony --json` 汇总三端运行中目标，并把命令输出写入 Logs。
- 真实截图区域捕获 click / drag，按 screenshot framebuffer 宽高换算坐标，再通过 `triton tap` / `triton swipe` 执行；Web 不直接调用 `xcrun`、`adb` 或 `hdc`。
- 输入执行结果必须显示 stdout / stderr / exit code；执行后刷新当前目标 screenshot。

## 不在本期范围

- 不恢复 Wails 桌面壳。
- 不新增真实业务控制 HTTP API。
- 不接真实 streaming、SSE、WebSocket 或代理抓包。
- 不从 Web 触发 `sim boot`、`sim shutdown`、`app install`、`app launch`、tap/type/swipe 等状态改变命令。
- 2026-06-12 例外：用户要求 screenshot 区响应点击/滑动后，本地 dev bridge 可通过 Triton CLI 合约转发 `tap` / `swipe`，但不得绕过 TritonKit 调用原始平台工具。
- 不处理登录、权限、多用户、远端 agent、设备云。

## BDD 场景

### 场景：打开 Web mock 控制台

- Given 开发服务运行在 `127.0.0.1:34127`
- When 浏览器打开 `/`
- Then 首屏直接展示 Device Hub 风格的 TritonKit 本机设备窗口
- And 页面展示三端目标、当前选中设备画布、Inspector 和底部证据分栏

### 场景：切换三端目标

- Given 页面展示 iOS、Android、Harmony 三个 mock target
- When 用户点击任一 target
- Then 设备画布、Inspector 指标、动作预设、网络事件和日志切换到对应 target

### 场景：保持 Device Hub 参考风格

- Given 页面已加载
- When 用户查看首屏
- Then 页面呈现深色 macOS / Xcode 工具窗式布局
- And 顶部展示 add / filter / interaction / canvas / expand / inspector 工具胶囊
- And 左侧为 target navigator，中间为横屏 device canvas，右侧为 inspector，底部为 device controls 与 evidence strip

### 场景：按真实 Simulator framebuffer 显示横竖屏

- Given 用户选中一个真实且已 Booted 的 iOS Simulator
- When `/web/ios-simulator/screenshot?simulator=<udid>` 返回 `pixelWidth` 与 `pixelHeight`
- Then 中央 device canvas 按真实 framebuffer 宽高显示为横屏或竖屏
- And 真实截图按原始宽高比自适应设备内容区，不裁掉状态栏，也不额外生成黑边
- And 该展示只消费截图元数据，不触发真实 Simulator 旋转、orientation 写入或输入命令
- And 未 Booted 的 Simulator 不伪造当前真实方向，只显示等待真实截图的占位状态

### 场景：观察设备运行态

- Given 一个 target 被选中
- When 用户查看主区域
- Then 页面展示平台、运行状态、framebuffer 尺寸、App 标识、proxy 状态、最近动作和网络事件

### 场景：保持工程可验证

- Given Web mock 工程已创建
- When 执行 `npm run build`
- Then TypeScript 与 Vite production build 通过

### 场景：读取真实 iOS Simulator 列表

- Given 本机存在 `CLI/.build/debug/triton`
- When Vite dev server 收到 `/web/ios-simulator/targets`
- Then endpoint 执行 `triton sim list --json`
- And 返回真实 Simulator 的 name、udid、runtime、state、isBooted 与 readonly source metadata

### 场景：显示真实 iOS Simulator 状态

- Given Web 页面打开
- When 只读桥接 endpoint 返回真实 iOS Simulator 列表
- Then 左侧 Devices navigator 优先展示真实 iOS Simulator
- And 右侧 Inspector 显示真实 runtime、UDID、state 和只读来源

### 场景：读取 Booted Simulator 截图

- Given 用户选择一个真实且已 Booted 的 iOS Simulator
- When Web 请求 `/web/ios-simulator/screenshot?simulator=<udid>`
- Then endpoint 通过 `triton sim screenshot --json` 生成临时 PNG
- And Web canvas 显示该 PNG
- But endpoint 不启动模拟器、不安装 App、不发送输入事件

### 场景：只显示运行中的三端模拟器

- Given 本机存在 iOS Simulator、Android Emulator、Harmony / DevEco Emulator
- When Vite dev server 收到 `/web/host-targets`
- Then endpoint 通过 Triton CLI 查询三端 host targets
- And Web 左侧只展示 Booted iOS Simulator、ready Android Emulator、ready Harmony Emulator
- And Shutdown / Offline / real-device target 不进入 Devices 列表

### 场景：截图区域响应点击和滑动

- Given 用户选中一个有真实 screenshot 的运行中目标
- When 用户在 screenshot 区域点击
- Then Web 将浏览器坐标换算为 framebuffer 坐标
- And 通过 `/web/host-input` 调用 `triton tap ... --json`
- And screenshot 上短暂显示 tap 触点反馈
- And 输入执行期间显示 dispatching / refreshing 状态徽标
- And Logs 显示命令、exit code、stdout / stderr 摘要
- And iOS runtime input 会继续按 embedded runtime 的 `screenWidth/screenHeight` 从 framebuffer pixel 坐标转换为 UIKit point 坐标
- And 执行后刷新 screenshot 时保留旧截图，直到新截图成功返回，不能中途露出 mock 占位图

- Given 用户在 screenshot 区域拖动
- When pointer up 结束拖动
- Then Web 将起止点换算为 framebuffer 坐标
- And screenshot 上短暂显示 swipe 轨迹、起点与终点反馈
- And 通过 `/web/host-input` 调用 `triton swipe ... --json`
- And 执行后刷新当前目标 screenshot

### 场景：底部 Logs 显示真实输出

- Given host bridge 完成 target discovery 或 input execution
- When 用户查看底部 Logs
- Then Logs 至少展示对应 `triton ...` 命令、成功/失败状态，以及 stdout / stderr 摘要

### 场景：底部 Logs 不撑高窗口

- Given Logs 连续进入多条 `triton ...` 输出
- When 用户在窄桌面视口查看 Device Hub mock
- Then 底部工具区高度保持受控，不继续挤压上方 canvas
- And Logs 内容在 `.log-rows` 内部滚动

### 场景：隐藏和恢复底部 Logs

- Given Logs 面板正在显示
- When 用户点击 Logs 标题栏的 Hide logs 控制
- Then Logs 面板从底部工具区隐藏
- And 底部工具区高度收缩，canvas 获得更多可用高度
- And 用户仍可通过底部 device controls 的 Logs 图标恢复面板

### 场景：全局刷新 host 数据

- Given Web mock 已展示运行中的本机模拟器
- When 用户点击右上工具区 Adjust 旁边的 Refresh all data 按钮
- Then Web 重新请求 `/web/host-targets`
- And 刷新当前选中 target 的 screenshot
- And Logs 记录 refresh action 与三端 discovery 命令输出
- And Logs 隐藏状态保持不变，刷新过程中不显示 mock 占位图

## 验收标准

- `Web/` 工程可通过 `npm install` 安装依赖。
- `npm run build` 通过。
- `npm run dev -- --host 127.0.0.1` 可在 `127.0.0.1:34127` 启动。
- 浏览器检查首屏非空，关键文案和 mock 数据可见。
- 页面视觉是参考 Device Hub 的工具界面，不是营销页。
- 1200px 左右桌面视口无横向溢出。
- 中央 device canvas 根据真实 Simulator framebuffer 宽高显示横屏或竖屏；未 Booted 时不伪造真实方向。
- 底部 Logs 输出增多时只在面板内部滚动，不把窗口或底部工具区继续撑高。
- Logs 支持隐藏和恢复，隐藏后不保留空白日志区域。
- 右上工具区提供全局刷新按钮，可刷新 targets、bridge command outputs 和当前 screenshot。
- 有真实 screenshot 的设备画布在 tap / swipe 时显示触点或轨迹反馈，并在 Triton CLI input 执行与 screenshot 刷新期间显示非阻塞状态徽标。

## 实现记录

- Web 工程位置：`Web/`。
- 架构：React 19 + TypeScript + Vite 7 + lucide-react。
- Dev server：`127.0.0.1:34127`，`strictPort=true`。
- Preview server：`127.0.0.1:34128`，`strictPort=true`。
- 入口：`Web/src/main.tsx`。
- 页面状态与组件：`Web/src/App.tsx`。
- Mock DTO：`Web/src/data/mockData.ts`。
- 样式：`Web/src/styles.css`。

## 视觉参考记录

- 参考页面：Apple Developer Documentation / Xcode / Device Hub。
- 参考截图：`docs-linhay/spaces/20260611-web-mock-ui/screenshots/20260611/20260611-web-device-hub-reference-baseline-v01.png`。
- 可复用信息架构：add devices、filter / sort devices、device interactions、canvas controls、compress / expand window、sidebar、canvas、device controls、inspector。
- 本期转译策略：保留 TritonKit 三端 mock DTO 与只读边界，视觉层改为深色 macOS 工具窗、Xcode 式 inspector、横屏设备 canvas 和底部 device controls。

## 验证记录

- `npm install` 通过，0 vulnerabilities。
- `npm run build` 通过。
- 浏览器打开 `http://127.0.0.1:34127/`，页面 title 为 `TritonKit Web Console Mock`。
- Console error 为 0；仅有 Vite dev client 与 React DevTools 提示。
- 1200px 视口检查无横向溢出：`document.documentElement.scrollWidth === window.innerWidth`。
- 目标切换验证：
  - iOS 默认显示 `丁香园`、`cn.dxy.iDxyer`、`1206 x 2622`。
  - Android 切换后显示 `Overloaded`、`sdk_gphone64_arm64`、`Mock lane armed`。
  - Harmony 切换后显示 `Triton Smoke`、`Pura X Emulator`、`Proxy unavailable`。
- 验收截图：`docs-linhay/spaces/20260611-web-mock-ui/screenshots/20260611/20260611-web-mock-dashboard-after-v01.png`。

### 2026-06-11 Device Hub 风格迭代

- `npm run build` 通过。
- 浏览器打开 `http://127.0.0.1:34127/`，页面 title 为 `TritonKit Web Console Mock`。
- Console error 为 0。
- 1200px 视口检查无横向溢出：`document.documentElement.scrollWidth === window.innerWidth`。
- 目标切换验证：
  - iOS 默认显示 `丁香园`、`cn.dxy.iDxyer`、`Proxy recording`。
  - Android 切换后显示 `Overloaded`、`overloaded.cn.debug`、`Mock lane armed`。
  - Harmony 切换后显示 `Triton Smoke`、`Pura X Emulator`、`Proxy unavailable`。
- 参考截图归档：`docs-linhay/spaces/20260611-web-mock-ui/screenshots/20260611/20260611-web-device-hub-reference-baseline-v01.png`。
- 验收截图：`docs-linhay/spaces/20260611-web-mock-ui/screenshots/20260611/20260611-web-device-hub-after-v04.png`。
- `git diff --check` 通过。

### 2026-06-11 真实 iOS Simulator 只读接入

- `npm run test` 通过，覆盖 `triton sim list --json` 输出到 Web 只读 DTO 的映射。
- `npm run build` 通过。
- `git diff --check` 通过。
- `CLI/.build/debug/triton sim list --json` 通过，当前本机返回 20 台 iOS Simulator，runtime 为 `iOS 26.5`，当前均为 `Shutdown`。
- `curl http://127.0.0.1:34127/web/ios-simulator/targets` 通过，返回 `source.command=triton sim list --json` 与真实 Simulator 列表。
- 浏览器打开 `http://127.0.0.1:34127/`，页面显示 `Real iOS Simulators`、真实设备名 `clash-li Dedicated iPhone 17`、`iOS 26.5`、`Shutdown` 与 `triton sim list --json` 来源。
- Console error 为 0。
- 1200px 视口检查无横向溢出，页面高度未被真实 Simulator 长列表撑高。
- 当前未执行 `sim boot`，因此截图 endpoint 的正向显示只对后续已 Booted Simulator 生效；本期未从 Web 触发任何状态改变命令。
- 验收截图：`docs-linhay/spaces/20260611-web-mock-ui/screenshots/20260611/20260611-web-real-ios-simulator-after-v02.png`。

### 2026-06-12 三端 running targets 与输入事件

- `npm run test` 通过，覆盖 iOS 只保留 Booted Simulator，以及 Android / Harmony 只保留 ready emulator target。
- `npm run build` 通过。
- `git diff --check` 通过。
- `curl http://127.0.0.1:34127/web/host-targets` 通过，当前本机只返回 1 个 running target：`iPhone 17` / `60667794-96F8-40E6-8664-85538EC4663E` / `Booted`；Android 当前无 running emulator，Harmony 仅发现 Offline emulator，因此均被过滤出左侧列表。
- 浏览器页面显示 `Running Emulators`，左侧仅展示运行中的 `iPhone 17`；底部 Logs 显示 `triton sim list --json`、`triton device list --platform android --json`、`triton device list --platform harmony --json` 的真实 stdout 摘要。
- 点击真实 screenshot 后，Web 捕获坐标并调用 `/web/host-input`；当前 iOS SpringBoard 因缺少 embedded runtime 返回 `server_unavailable`，该 `triton tap ... exit=1` 输出已显示在 Logs。Android / Harmony running emulator 可通过同一 endpoint 转发到 `triton tap --platform android|harmony` / `triton swipe --platform android|harmony`。
- iOS host-side Simulator tap/swipe 仍不是当前 Triton CLI 稳定能力，Web 不绕过 TritonKit 调用 raw `xcrun` 或私有 UI automation；后续若要直接控制 SpringBoard，需要先补 CLI/HTTP 机器可读契约。
- 验收截图：`docs-linhay/spaces/20260611-web-mock-ui/screenshots/20260612/20260612-web-running-targets-input-logs-after-v02.png`。

### 2026-06-12 Logs 固定高度响应式修正

- `npm run test` 通过 3 tests。
- `npm run build` 通过。
- `git diff --check` 通过。
- 浏览器在 863px 宽窄桌面视口验证：`.device-hub-window` grid rows 为 `64px 522.562px 193.438px`，`.hub-bottom` 高度固定约 193px，`.log-strip` 高度约 96px。
- Logs 内容验证：`.log-rows.clientHeight=48`、`.log-rows.scrollHeight=140`、`overflowY=auto`，说明日志增多后在 Logs 内部滚动，不再撑高底部面板。
- 横向溢出验证：`document.documentElement.scrollWidth - document.documentElement.clientWidth === 0`。
- 验收截图：`docs-linhay/spaces/20260611-web-mock-ui/screenshots/20260612/20260612-web-logs-fixed-height-after-v01.png`。

### 2026-06-12 Logs 隐藏/恢复交互

- `npm run test` 通过 3 tests。
- `npm run build` 通过。
- `git diff --check` 通过。
- 浏览器在 863px 宽窄桌面视口验证：显示态 `hasLogStrip=true`、`Hide logs` 控制存在；隐藏后 `hasLogStrip=false`、`Show logs` 控制存在。
- 隐藏态布局验证：`.device-hub-window` grid rows 为 `64px 628px 88px`，`.hub-bottom` 高度收缩到约 88px，`.hub-canvas` 高度提升到约 628px。
- 恢复验证：点击底部 device controls 中的 `Show logs` 后 Logs 面板恢复，底部重新回到固定 evidence 区布局。
- 横向溢出验证：`document.documentElement.scrollWidth - document.documentElement.clientWidth === 0`。
- 验收截图：`docs-linhay/spaces/20260611-web-mock-ui/screenshots/20260612/20260612-web-logs-hidden-after-v01.png`。

### 2026-06-12 iOS input 坐标转换修正

- 现场问题：Logs 出现 `server_unavailable` 后，启动 `triton serve --host 127.0.0.1 --port 19421` 使 runtime server 可达；随后同一点击暴露出 `Point is outside key window bounds`，原因是 Web 把 Simulator screenshot framebuffer 像素坐标 `1206 x 2622` 直接传给了 embedded runtime，而 runtime 期望 UIKit point 坐标 `402 x 874 @3x`。
- 修正：`/web/host-input` 对 iOS 输入先调用 `triton hierarchy --target <udid> --json` 读取 `appInfo.screenWidth/screenHeight/screenScale`，再把 tap / swipe 坐标从 framebuffer pixel 转为 runtime point；Android / Harmony 继续使用 host framebuffer 坐标。
- 测试：`normalizeIosRuntimeInput` 覆盖 `619,2338 @ 1206x2622` 转为 `206,779 @ 402x874`。
- 实机验证：`curl -X POST /web/host-input` 使用原 framebuffer 坐标 `619,2338`，bridge 实际执行 `triton tap --target 60667794-96F8-40E6-8664-85538EC4663E --x 206 --y 779 --json`，CLI 返回 `ok=true` 并命中 `UIButton`。
- 浏览器验证：UI 点击后 Logs 中命令已使用 runtime point 坐标，不再出现 `Point is outside key window bounds`；若点中非 UIControl，会显示 runtime 的真实业务命中错误，例如 `Hit view does not expose a public UIControl tap action`。
- `npm run test` 通过 4 tests。
- `npm run build` 通过。
- `git diff --check` 通过。

### 2026-06-12 iOS 点击刷新不闪占位图修正

- 现场问题：用户点击真实 screenshot 后，Web 会先删除 `screenshotById[selected.id]` 再重新请求截图，导致刷新间隙渲染 mock 占位画面，看起来像“中途出现一个占位图片”。
- 修正：点击/滑动执行后改为后台调用 `refreshScreenshot(selected)`，新截图返回前保留旧 screenshot；刷新失败只显示错误信息，不清空当前画面。
- 浏览器验证：在 863px 视口点击截图底部按钮区域，`placeholderAppeared=false`、`hasImage=true`、`hasPlaceholder=false`，Logs 显示 `triton tap ... --x 113 --y 786 --json exit=0 Dispatched UIControl.touchUpInside`。
- 说明：若点击区域命中 `UIStackView` 等非 `UIControl`，runtime 会返回 `Hit view does not expose a public UIControl tap action`；这代表业务命中失败，不再是坐标越界或 Web 未发出点击。
- 验收截图：`docs-linhay/spaces/20260611-web-mock-ui/screenshots/20260612/20260612-web-ios-click-no-placeholder-after-v01.png`。

### 2026-06-12 全局刷新按钮

- 右上 Inspector tools 胶囊中，在 `Adjust` 左侧新增 `Refresh all data` 图标按钮。
- 点击后执行全局刷新：重新拉取 `/web/host-targets`、更新 `bridgeOutputs`、保持当前可用 target 选择，并后台刷新当前 screenshot。
- 刷新中按钮进入 `Refreshing all data` 禁用状态并旋转，避免并发刷新；刷新完成后恢复。
- 浏览器验证：工具按钮顺序为 `Refresh all data`、`Adjust`、`Document`、`Info`；点击后 Last 显示 `Refreshed host targets and screenshot`，Logs 头部出现 `refresh all host data`、`triton sim list --json exit=0 ok`、`triton device list --platform android --json exit=0 ok`、`triton device list --platform harmony --json exit=0 ok`。
- 刷新验证：`placeholderAppeared=false`、`hasImageAfter=true`、`hasPlaceholderAfter=false`、横向溢出为 0。
- 验收截图：`docs-linhay/spaces/20260611-web-mock-ui/screenshots/20260612/20260612-web-refresh-all-after-v01.png`。

### 2026-06-12 Triton 融合 Baguette host-HID 能力

- 用户明确纠正边界：Baguette 是参考项目，TritonKit 要直接融合其有价值能力，Web 不应长期直接依赖 `baguette` CLI。
- 修正：`runWebHostDeviceInput` 的 iOS host target 从 `unsupported` 改为 Triton host-HID adapter；`/web/input?target=host:ios:<udid>` 不再优先回退 embedded runtime，而是直接执行 host-side Simulator input。
- 当前小切片：Swift CLI 层参考 Baguette 的能力契约，读取 Simulator chrome layout，将 Web screenshot framebuffer 坐标缩放为 host screen points，再执行 host-HID tap / swipe；后续继续把 Baguette 的私有符号注入实现下沉为 Triton 原生实现。
- Web 修正：Vite dev bridge 不再执行 `baguette tap/swipe`，而是自动拉起或复用 `triton serve --host 127.0.0.1 --port 19421`，并 POST 到 `triton serve /web/input?target=host:ios:<udid>`；Android / Harmony 仍走现有 `triton` 路径。
- 测试：`SingleDeviceWebPageTests` 覆盖 iOS host input 坐标转换和 Baguette-compatible host-HID argv 构造；Web dev bridge 测试不再包含 Baguette 依赖。
- 实机验证：`curl -X POST /web/host-input` 返回 `ok=true`，`command=triton serve POST /web/input?target=host:ios:60667794-96F8-40E6-8664-85538EC4663E`，stdout 为 `iOS Simulator tap was submitted through Triton host-HID adapter.`。
- 浏览器验证：点击真实 screenshot 后 Logs 头部显示 `triton serve POST /web/input?... exit=0 iOS Simulator tap was submitted through Triton host-HID adapter.`，不再暴露 `baguette tap`。
- 剩余 P0：当前 Swift adapter 仍以 Baguette CLI 作为内部兼容后端；完整移植的完成定义是把 `chrome layout`、tap、swipe 的 private Simulator host-HID bridge 原生落到 Triton Swift 代码中，发布包不再需要用户安装 `baguette`。
- `npm run test` 通过 4 tests。
- `npm run build` 通过。
- `swift test --package-path CLI --filter SingleDeviceWebPageTests` 通过 16 tests。
- 验收截图：`docs-linhay/spaces/20260611-web-mock-ui/screenshots/20260612/20260612-web-triton-host-hid-after-v01.png`。

### 2026-06-12 Device controls 迁入 Canvas

- 用户指出底部左侧 `Device controls` 应移动到 SpringBoard 区域左下角。
- 修正：`DeviceControls` 从 `.hub-bottom` 移入 `DeviceCanvas`，作为 `.hub-canvas` 左下角浮层渲染；底部 evidence 区域收敛为 Network / Logs 两列。
- 浏览器验证：`.device-controls.parentElement.className=hub-canvas`，controls 坐标位于 canvas 内，且 `controlsAboveBottom=true`、横向溢出为 0。
- `npm run test` 通过 4 tests。
- `npm run build` 通过。
- `git diff --check -- Web/src/App.tsx Web/src/styles.css` 通过。
- 验收截图：`docs-linhay/spaces/20260611-web-mock-ui/screenshots/20260612/20260612-web-canvas-controls-after-v01.png`。

### 2026-06-12 Live preview、Controls 去卡片与侧边栏收起

- 用户指出 canvas 不应只是静态截图，应为实时流；当前短期实现改为 live preview 自动连续拉取 `/web/host-screenshot`，保持画面持续更新且不向 Logs 写入每一帧。
- 用户指出 `Device controls` 外层卡片不要；已移除 `.device-controls` 外层背景、边框、阴影、圆角和 padding，只保留内部工具胶囊与 Last 状态块。
- 用户指出顶部 `Toggle sidebar` 需要支持收起侧边；已增加 `isSidebarVisible` 状态，点击后 `.hub-sidebar` 不渲染，`.hub-body` 改为 `canvas + inspector` 两列，再次点击恢复。
- 浏览器验证：2.2 秒后 `img.real-screenshot` data URL 变化，Live badge 显示 `Live / 1 fps`；`.device-controls` computed style 为透明背景、无阴影、0px 边框；点击 sidebar 按钮后 `hasSidebar=false`、`.hub-body.is-sidebar-hidden` 生效，再点恢复。
- `npm run test` 通过 4 tests。
- `npm run build` 通过。
- `git diff --check -- Web/src/App.tsx Web/src/styles.css` 通过。
- 验收截图：`docs-linhay/spaces/20260611-web-mock-ui/screenshots/20260612/20260612-web-live-sidebar-controls-after-v01.png`。

### 2026-06-12 Sidebar panel switch 与 View hierarchy

- 用户指出左侧区域需要支持切换面板：`设备列表` 与 `当前视图树列表`，视图树参考 Lookin / LookInside 的层级检查器风格。
- 修正：左侧 sidebar 增加 `Devices / View Tree` segmented tab，`Devices` 保持当前 running emulator 列表；`View Tree` 渲染 monospaced view hierarchy、disclosure marker、缩进层级与选中行。
- 当前 Web mock 的视图树仍为 DTO-shaped 静态样例，用于先验证信息架构与交互，不把真实 AX / SwiftUI tree 采集能力定义在 Web；后续真实数据源应落回 Triton CLI/HTTP 机器可读契约。
- 浏览器验证：点击 `View Tree` 后显示 `VIEW HIERARCHY`、`UIWindowScene mainScene`、`UIStackView questionList` 选中行；点击 `Devices` 可恢复设备列表；侧边栏收起后 `.hub-sidebar` 不渲染，`.hub-body.is-sidebar-hidden` 生效；横向溢出为 0。
- `npm run test` 通过 4 tests。
- `npm run build` 通过。
- 验收截图：`docs-linhay/spaces/20260611-web-mock-ui/screenshots/20260612/20260612-web-sidebar-view-tree-after-v01.png`。

### 2026-06-12 Canvas zoom controls

- 用户指出顶部 `Canvas controls` 中的放大、缩小、实际大小按钮未实现。
- 修正：新增 `canvasZoom` 状态与固定 zoom ladder：`75% / 90% / 100% / 115% / 130% / 150%`；`Zoom out`、`Actual size`、`Zoom in` 均接入真实点击事件，并在 aria-label / title 中展示当前比例。
- `DeviceCanvas` 增加 `device-stage`，对 `.device-frame` 应用 `transform: scale(var(--canvas-zoom))`；缩放只影响 canvas 视觉，不改变 screenshot framebuffer 数据源，点击/滑动坐标仍通过缩放后的 `getBoundingClientRect()` 映射到真实 screenshot 像素。
- 浏览器验证：100% 时 frame 约 `173 x 361`；点击 `Zoom in` 后进入 `Canvas zoom 115%`，frame 约 `198 x 415`；点击 `Actual size` 回到 100%；点击 `Zoom out` 进入 `Canvas zoom 90%`，frame 约 `155 x 325`；全程横向溢出为 0。
- `npm run test` 通过 4 tests。
- `npm run build` 通过。
- `git diff --check -- Web/src/App.tsx Web/src/styles.css` 通过。
- 验收截图：`docs-linhay/spaces/20260611-web-mock-ui/screenshots/20260612/20260612-web-canvas-zoom-after-v01.png`。

### 2026-06-12 Remove canvas last-action chip

- 用户指出 canvas 左下角 `Device controls` 旁边的 `Last / Ready for screenshot and Triton input` 状态块需要移除。
- 修正：`DeviceControls` 仅保留工具胶囊，不再渲染 `.last-action`；同步删除 `.last-action` 与 `result-*` 死 CSS。
- 浏览器验证：`.last-action` 不存在，controls 只剩 1 个 `.control-pill` 子节点，尺寸收缩到约 `198 x 38`，横向溢出为 0。
- `npm run test` 通过 4 tests。
- `npm run build` 通过。
- `git diff --check -- Web/src/App.tsx Web/src/styles.css` 通过。
- 验收截图：`docs-linhay/spaces/20260611-web-mock-ui/screenshots/20260612/20260612-web-controls-last-action-removed-after-v01.png`。

### 2026-06-12 Inspector localization

- 用户指出右侧 Inspector 需要本地化。
- 修正：右侧检查器静态 UI 改为中文：`信息 / 应用 / 配置`、`已启动`、`帧率 / 延迟 / AX 节点 / HTTP 错误`、`设备 / 传输 / 来源`、`过滤 / 开发者`；`UDID`、设备名、bundle id 与 `triton ...` 命令输出保留原始契约文本。
- 浏览器验证：`.hub-inspector` aria-label 为 `检查器`，静态英文 `Info / Apps / Profiles / Booted / Latency / AX Nodes / HTTP Errors / Device / Transport / Source / Filter / Developer` 不再出现，横向溢出为 0。
- `npm run test` 通过 4 tests。
- `npm run build` 通过。
- `git diff --check -- Web/src/App.tsx` 通过。
- 验收截图：`docs-linhay/spaces/20260611-web-mock-ui/screenshots/20260612/20260612-web-inspector-localized-after-v01.png`。

### 2026-06-12 Remove sidebar bridge status

- 用户指出左侧设备列表顶部的 `Running Emulators / triton sim list --json ...` bridge 状态条需要移除。
- 修正：`DeviceListPanel` 不再渲染 `.bridge-status`，`TargetNavigator` 不再向设备列表传入 `bridge` prop；同步删除 `.bridge-status` 样式，并把设备列表标题上移。
- 浏览器验证：`.bridge-status=false`，左侧不再包含 `Running Emulators` 文案，设备 panel 子节点只剩 `sidebar-section-title` 与 `device-list`，横向溢出为 0。
- `npm run test` 通过 4 tests。
- `npm run build` 通过。
- `git diff --check -- Web/src/App.tsx Web/src/styles.css` 通过。
- 验收截图：`docs-linhay/spaces/20260611-web-mock-ui/screenshots/20260612/20260612-web-sidebar-bridge-status-removed-after-v01.png`。

### 2026-06-12 Hide canvas metadata label

- 用户指出 canvas 顶部 `SpringBoard / UDID / portrait ...` metadata label 不显示。
- 修正：`DeviceCanvas` 不再渲染 `.canvas-label`，同步删除 `.canvas-label` 基础样式和移动端覆写；Live badge、真实截图与占位卡片内的 orientation 信息保留。
- 浏览器验证：`.canvas-label=false`，canvas 文本不再包含 `SpringBoard + portrait` 组合，真实 screenshot 与 `.live-preview-badge` 仍存在，横向溢出为 0。
- `npm run test` 通过 4 tests。
- `npm run build` 通过。
- `git diff --check -- Web/src/App.tsx Web/src/styles.css` 通过。
- 验收截图：`docs-linhay/spaces/20260611-web-mock-ui/screenshots/20260612/20260612-web-canvas-label-hidden-after-v01.png`。

### 2026-06-12 Web shell localization

- 延续右侧检查器本地化，把 Web mock 工具窗外壳静态文案同步中文化：toolbar 分组、sidebar 搜索与切换、设备列表标题、Live badge、device controls、Network / Logs evidence、日志级别、button title / aria-label。
- `Web/index.html` 同步改为 `lang="zh-CN"`，页面标题改为 `TritonKit 设备中心原型`。
- 真实机器契约文本继续保留原样：`TritonKit` 品牌、UDID、bundle id、设备名、`triton ...` 命令输出、HTTP path / method 不做翻译。
- 浏览器验证：页面 title 为 `TritonKit 设备中心原型`，`html.lang=zh-CN`，`englishLeftovers=[]`，`.canvas-label=false`、`.bridge-status=false`、`.last-action=false`，横向溢出为 0。
- 交互验证：点击 `视图树` 后显示 `视图层级` 与 `UIWindowScene`；点击 `放大` 后 `.device-stage` aria-label 更新为 `画布缩放 115%`；点击日志面板 `隐藏日志` 后 `.log-strip=false` 且 `显示日志` 恢复入口存在。
- `npm run test` 通过 4 tests。
- `npm run build` 通过。
- 验收截图：`docs-linhay/spaces/20260611-web-mock-ui/screenshots/20260612/20260612-web-shell-localized-after-v01.png`。

### 2026-06-12 Device canvas gesture feedback

- 真实 screenshot 画布新增 tap / swipe overlay：tap 显示触点，drag 显示起点、终点和轨迹，用于人工确认浏览器坐标到 framebuffer 坐标的映射。
- 输入执行期间新增 per-target activity badge：先显示 dispatching，再在 Triton CLI 返回后进入 refreshing，并触发即时刷新与短延迟二次刷新。
- 自动化验证使用合成 pointerdown / pointermove / pointercancel，只验证 overlay DOM 与清理行为，不触发 pointerup，因此不发送真实 `triton tap` / `triton swipe`。
- 浏览器验证：页面 title 为 `TritonKit 设备中心原型`；`.gesture-touch=true`、`.gesture-swipe=true`；等待清理后 `.gesture-touch,.gesture-swipe=false`；Console error 为 0；当前 863px 视口横向溢出为 0。
- `npm run build` 通过。
- `git diff --check` 通过。
- 验收截图：`docs-linhay/spaces/20260611-web-mock-ui/screenshots/20260612/20260612-web-device-canvas-gesture-swipe-after-v02.png`。

### 2026-06-12 Host emulator foreground App identity

- 用户指出 Harmony / DevEco 仿真器设备列表没有显示运行中的 App 名。定位到当前 Web dev bridge 的上游 `triton device list --platform harmony --json` 只返回 target / state / transport，不包含 `appName` 或 `bundleIdentifier`，`triton app list --platform harmony --device <target> --json` 也要求预先知道 bundle，不能作为当前前台 App 发现入口。
- 修正：`HostWebTarget` 与 Web dev bridge 先透传可选 `appName` / `bundleIdentifier`；`mapHostTargetToDeviceTarget` 使用上游 App identity 优先，否则明确显示 `前台 App 未识别`，不再把 `Harmony Emulator` / `DevEco 仿真器` 当成 App 名。
- 左侧设备行显示改为 `App 名 · 设备类型`。当前 Harmony target 的浏览器验证结果为 `127.0.0.1:5555前台 App 未识别 · DevEco 仿真器`，避免误导；后续 CLI/HTTP 一旦补齐 foreground app identity，Web 会自动显示真实 App。
- 已按开发反馈流程创建 issue：`https://github.com/NeptuneKit/TritonKit/issues/45`。
- 验证记录：`npm run test` 通过 4 tests；`npm run build` 通过；`git diff --check -- Web/src/App.tsx Web/src/styles.css Web/src/types.ts Web/src/data/iosSimulatorClient.ts Web/dev/iosSimulatorBridge.mjs Web/dev/iosSimulatorBridge.test.mjs` 通过；浏览器刷新后左侧设备列表文案符合预期。
