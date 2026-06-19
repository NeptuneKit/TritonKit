# 20260619 Lookin Hierarchy Viewer

## 背景

用户指出当前 Web Device Hub 的设备画布只展示平面 screenshot，不具备 Lookin 风格的视图层级分层、三维展开和旋转能力。TritonKit 面向 AI agent 与自动化脚本，真实业务控制仍以 CLI / HTTP 机器可读契约为事实入口；Web 只作为可视化 mock 与只读检查器，不承载新的控制闭环。

Lookin 的关键价值不是单张截图，而是把 view hierarchy、节点几何、层级深度和节点截图组织成可检查的分层场景。TritonKit 第一阶段先落地三端一致的 hierarchy viewer 数据形态和 Web 端 3D 可视化，后续再把 DTO 接到 iOS runtime hierarchy、Android uiautomator dump 和 Harmony uitest dumpLayout 等真实采集入口。

参考事实：

- Lookin 官方站点定位为 iOS view debugging 的 macOS App，可查看和修改 iOS App 里的视图对象：https://lookin.work/
- Lookin GitHub README 说明使用 macOS App 需要在 iOS 项目 Debug 配置集成 LookinServer，且不应在 Release / AppStore 配置集成：https://github.com/hughkli/Lookin
- 本期只借鉴“视图层级、几何 frame、层级深度、可旋转分层检查器”的产品形态，不引入 LookinServer 依赖或 Lookin 对外 API。

## 目标

- 在 `Web/` 设备画布中新增 Lookin 风格的层级分层视图。
- iOS Simulator / Android Emulator / Harmony DevEco Emulator 三端 target 都能显示对应平台的 hierarchy layers。
- 视图支持本地旋转，能看出节点之间的 z-depth 分层关系。
- 左侧 `视图树` 与中央 3D layers 使用同一组 DTO，避免树和画布表达不一致。
- 保持 Web mock 只读边界：不新增 Web 侧 create / update / execute / approve / deny 操作。

## 范围

- 新增三端 `HierarchyScene` DTO mock 数据，字段覆盖节点 id、父子关系、role/type、label/name、frame、depth、platform、visible、interactive、color。
- 在 Web 设备画布中提供 `点选 / 探测` 工具；`探测` 模式展示 3D hierarchy viewer。
- 使用 Three.js 渲染 3D 分层主视图；保留 DOM fallback / overlay，确保测试环境没有 WebGL 时仍能验证数据和状态。
- iOS、Android、Harmony 三端 mock target 切换时，3D hierarchy viewer 同步切换节点、平台色、统计和可见层。
- 文档与 memory 写回当前实现边界和后续真实契约方向。

## 不在本期范围

- 不完整复刻 Lookin 客户端。
- 不在本期采集真实 per-node screenshot、solo screenshot 或 group screenshot。
- 不从 Web 触发真实 hierarchy dump、App instrumentation、ADB/HDC 命令或 iOS runtime 请求。
- 不把 Web 变成正式 Wails / 产品 UI。
- 不引入对外 HTTP 产品面或远端设备云。

## BDD 场景

### 场景：三端 target 都能打开 3D 层级视图

- Given Web Device Hub 展示 iOS、Android、Harmony 三端 target
- When 用户选择任一 target 并点击设备控制胶囊的 `探测`
- Then 中央设备画布进入 Lookin 风格 3D hierarchy viewer
- And 3D 视图显示该 target 对应平台的 hierarchy layer
- And 视图标题、节点数量、层级数量与当前 target 同步

### 场景：3D 层级视图可以旋转

- Given hierarchy viewer 已打开
- When 用户在 3D 画布上水平或垂直拖动
- Then viewer 的 rotationX / rotationY 发生变化
- And 可见图层按新的旋转角度重新呈现
- And 不发送任何 host input 或平台控制命令

### 场景：视图树与 3D layers 使用同一数据

- Given 用户切换到左侧 `视图树`
- When 用户选择 iOS / Android / Harmony target
- Then 视图树根节点、主要子节点与 3D layers 的节点名称一致
- And 节点数量与层级数量来自同一 DTO 统计

### 场景：WebGL 不可用时仍可验证

- Given 测试环境没有可用 WebGL context
- When hierarchy viewer 挂载
- Then DOM fallback 仍渲染 hierarchy layer 列表和旋转状态
- And 自动化测试可以断言三端数据、按钮状态和旋转状态

### 场景：窄屏标题可切换设备

- Given 窄屏布局隐藏左侧设备列表
- When 用户点击 toolbar 标题里的当前设备名称
- Then Web 展示只读 target 切换菜单
- And 用户选择另一个 target 后，标题、设备画布和检查器都切换到该 target
- And 菜单关闭，不触发任何 CLI / HTTP 业务控制动作

## 验收方式

- `npm --prefix Web test`
- `npm --prefix Web run build`
- `git diff --check`
- 必要时启动 `127.0.0.1:34127` 后用浏览器验证：点击 `探测` 后中央画布出现 Lookin 风格 3D 分层视图，切换 iOS / Android / Harmony target 后层级内容同步变化。

## 2026-06-19 P0 验证记录

- Web DOM 测试覆盖：QA fallback 下点击 `探测` 后，iOS 展示 `UIStackView/questionList`，Android 展示 `AndroidComposeView/settingsList`，Harmony 展示 `ArkUIRoot/settingsContent`，并验证拖动会改变 rotation 状态。
- 浏览器验证：`http://127.0.0.1:34127/?__tritonkit_mock_host_targets=request-failed` 下三端 target 均可切换到 3D hierarchy viewer。
- 像素验证：对 iOS hierarchy viewer 截图做 PNG 像素扫描，样本非零像素 `2808/2808`，sample unique pixels `1085`，确认渲染区域不是空白。
- 截图：`docs-linhay/spaces/20260619-lookin-hierarchy-viewer/screenshots/20260619/20260619-web-lookin-hierarchy-ios-after-v01.png`。

## 2026-06-19 探测模式去设备框反馈

- 用户指出三维层级模式不需要继续显示手机设备外框；该模式应是 Lookin-style 层级检查器，而不是屏幕镜像。
- Web `探测` 模式已从 `.device-frame` / `.device-screen` 中拆出，改为独立 `.hierarchy-stage` 承载 `HierarchySceneViewer`；普通 `点选` 镜像模式仍保留设备外框、侧边按键、截图和输入 relay。
- 浏览器 DOM 验收：点击 `探测` 后 `frameCount=0`、`screenCount=0`、`hierarchyStageCount=1`、`viewerCount=1`，active button 为 `探测`。
- 截图：`docs-linhay/spaces/20260619-lookin-hierarchy-viewer/screenshots/20260619/20260619-web-lookin-hierarchy-no-frame-after-v01.png`。

## 2026-06-19 探测模式无外框与单轴旋转修正

- 用户继续反馈三维模式仍像渲染了一个框，并质疑切片为什么同时向两个方向旋转。
- 修正：`.hierarchy-stage` / `.hierarchy-scene-viewer` 不再绘制圆角背景、阴影或容器背景；三维层级直接浮在设备画布上，避免再出现类似手机壳或面板框的视觉容器。
- 修正：层级切片保留固定 `-18deg` 俯仰角用于表达深度，只允许水平拖动改变 yaw；纵向拖动不再改变 pitch，状态文案改为 `水平旋转 <deg>°`。
- DOM 测试补充：纵向拖动后旋转状态不变，水平拖动后旋转状态变化。

## 2026-06-19 LookInside 参考收敛

- 用户给出 LookInside 参考截图，明确目标不是彩色抽象块堆叠，而是“左侧 hierarchy tree + 中央真实屏幕切片 + 背后等距透明层级 + 右侧属性检查器”的调试器形态。
- 探测态画布改为浅色检查器背景，避免深蓝舞台和大面积玻璃卡片干扰层级判断。
- Three.js 场景新增真实截图主切片；hierarchy node 改为低透明度描边薄片并向后展开，root 大面板不再用高透明彩色块覆盖内容。
- WebGL 成功时隐藏 DOM fallback 图层，避免 WebGL canvas 和 DOM fallback 同时渲染导致双影、发糊和过度拥挤；DOM fallback 仍保留给无 WebGL / 自动化测试环境。
- 点击 `探测` 时左侧自动切到 `视图树`，让 Web mock 的信息架构更接近 LookInside 的工作流；该切换仍是纯 Web UI 状态，不新增 CLI / HTTP 控制动作。

## 2026-06-19 独立节点切片样式还原

- 用户指出 LookInside 会在独立节点切片上还原视图样式，而不是只画几何线框。
- WebGL hierarchy viewer 已为每个可见节点生成 canvas texture，并贴到对应独立切片上；当前按 `type/name/frame/interactive/color` 做近似样式：
  - `UINavigationBar` / `Toolbar` / `Navigation` 渲染为浅色导航栏和标题。
  - `UIButton` / `Button` / `Toggle` / `Image` 渲染为圆角控件或图标按钮。
  - `UILabel` / `Text` 渲染为文本切片。
  - `TextInput` / `TextField` / `Search` 渲染为输入框。
  - `Scroll` / `RecyclerView` / `StackView` / `Column` / `Card` / `Row` 渲染为列表、卡片或容器纹理。
- 这仍不是完整 LookInside parity：真实还原还需要 Triton runtime / host hierarchy DTO 继续提供 backgroundColor、cornerRadius、alpha、font、shadow、border、CALayer / Compose / ArkUI 样式等机器可读字段。

## 2026-06-19 节点样式契约补齐方案

- 用户追问“还原缺少什么数据”；已新增方案文档：`plans/20260619-node-slice-style-contract.md`。
- 方案明确当前缺口：真实文本/状态、视觉样式、图层样式、布局语义、per-node slice 资产、平台 raw payload、质量与来源字段。
- 设计目标：`slice` 精确节点截图优先，`style` 跨平台样式次之，`type/name` fallback 只作为临时降级；结构节点只画淡描边，不再显示整张大截图或大色块。
- Web 过渡实现已移除探测态主截图平面，继续只展示独立节点切片和结构描边；右下缩放控件在探测态贴近画布底部。

## 2026-06-19 层级 z 轴方向修正

- 用户指出需要旋转到约 168 度后才看到子节点切片在前。
- 原因：WebGL 过渡实现把 `depth` 越大的节点放到更负的 z 值，并且透明材质 `renderOrder` 随 depth 递减，等于默认把子节点放在父节点后方并更早绘制。
- 修正：`depth` 越大的节点现在 z 值越大、更靠近相机，`renderOrder` 也随 depth 递增，子节点默认就在父节点前方，不需要翻转到背面才能看清。

## 2026-06-19 Web dev bridge hierarchy endpoint

- 新增只读 `/web/host-hierarchy?platform=<ios|android|harmony>&target=<target>` dev bridge endpoint，返回 `HostHierarchyResponse` 与 `HierarchyScene`。
- Web `探测` 模式优先请求 `/web/host-hierarchy`；请求失败、平台不支持或 dev bridge 不存在时，回退到内置三端 mock DTO，保证原型可演示和自动化测试稳定。
- `/web/host-hierarchy` 已从内置 mock 改为调用 `triton hierarchy --platform <platform> --target <target> --json`，由 CLI 侧输出 `HostHierarchyResponse.scene`。
- 桥接测试覆盖 iOS / Android / Harmony 成功响应，以及 unsupported platform 返回 `web_host_hierarchy_platform_not_supported`。

## 2026-06-19 CLI hierarchy scene contract

- `triton hierarchy` 保持向后兼容：不带 `--platform` 时仍读取旧 iOS embedded runtime raw hierarchy / tree。
- 新增 `triton hierarchy --platform ios|android|harmony --json` scene 模式，输出 `TKHostHierarchyResponse`：
  - iOS：基于 embedded runtime `runtimeSnapshot` / AX tree 生成 scene。
  - Android：基于 host-side UIAutomator XML 生成 scene。
  - Harmony：基于 host-side `uitest dumpLayout` 生成 scene。
- 新增 shared DTO：`TKHierarchyViewport`、`TKHierarchyLayerNode`、`TKHierarchyScene`、`TKHierarchySourceInfo`、`TKHostHierarchyResponse`。
- `triton capabilities --json` 与 `triton schema --command hierarchy --json` 已暴露 `hierarchy-scene`、`android-hierarchy`、`harmony-hierarchy`。
- 当前 scene 先统一节点 frame、depth、visible、interactive、source 和平台色；per-node screenshot / surface slice 仍未接入，不能声明完整 Lookin parity。

## 2026-06-19 窄屏设备切换菜单

- 用户指出窄屏时 toolbar 标题区域应可点击并弹出菜单切换设备；此前左侧设备列表在窄屏隐藏后，Web mock 缺少 target 切换入口。
- `DeviceHubToolbar` 标题已改为可访问按钮，点击后展示只读 `切换设备` listbox；菜单项来自当前 `pageTargets`，不受侧栏搜索过滤影响。
- 选择 target 后只更新本地 `selectedId` 并关闭菜单；不新增 Web 侧业务控制闭环，也不调用平台命令。
- DOM 回归测试覆盖 QA fallback 下从 `DXY iPhone 15` 切到 `Pixel API 35`，并断言 toolbar、应用卡片和菜单关闭状态同步。

## 2026-06-19 现场三端证据

证据目录：`docs-linhay/spaces/20260619-lookin-hierarchy-viewer/evidence/20260619/`。

- Triton-first 事实源已保存：`status.json`、`doctor.json`、`capabilities.json`、`schema-hierarchy.json`。
- 新增 schema 事实源：`schema-device.json`、`schema-app.json`。`device` schema 已补 `start --platform android|harmony --plan-only` 能力，启动 argv、PID、sourceCommands 和 wait-ready nextAction 都能机器可读返回。
- iOS Simulator 现场通过：`hierarchy-ios-f4e55b8e-after-fix.json` 返回 `ok=true`、`platform=ios`、`nodeCount=9`、`runtimeScope=runtime-tree`。
- iOS 另一台 Booted simulator `60667794-96F8-40E6-8664-85538EC4663E` 未连接 embedded runtime target，`hierarchy-ios-60667794.json` 返回 `target_not_found`，说明 scene 依赖目标 App 接入/连接 Triton runtime。
- Android 工具与 AVD 已确认存在：`device-doctor-android-emulator.json` 显示 `adb` 与 Android `emulator` 可用，`android-emulator-list-avds.txt` 列出 `Dxyer_API_34`、`Neptune_API_34`。早期 raw fallback 曾无法把 AVD 启动到 ADB 可见状态：
  - `android-emulator-dxyer-window.log` 显示 UI 模式启动后 `Created extended window`，随后进程退出，Triton `device-list-android-lowmem-after-error.json` 仍为空。
  - `android-emulator-dxyer-lowmem.log` 记录低内存/软件渲染启动失败：`Failed to create DisplaySurfaceGl`。
  - `android-emulator-dxyer-headless-swiftshader.log` 显示 headless swiftshader 能启动到 GRPC / display 初始化阶段，但随后进程退出，Triton `device-list-android-headless-swiftshader-poll-*.json` 仍为空。
  - `hierarchy-android-default-json-envelope.json` 已按 JSON envelope 返回 `target_not_found`，不再输出裸文本错误。
- 新增 Triton-first Android 启动契约后，`device-start-android-dxyer-plan.json` 返回 planned sourceCommand，`device-start-android-dxyer-execute.json` 返回 `started=true` 和 detached pid。随后 `device-list-android-after-start.json` 发现 `emulator-5554` 且 `ready=true`，`device-wait-ready-android-emulator-5554-after-start.json` 通过，`hierarchy-android-emulator-5554-after-start.json` 返回 `ok=true`、`platform=android`、`nodeCount=33`、root `android:host:0`。
- Harmony 工具与 HVD 已确认存在：`device-doctor-harmony-emulator.json` 显示 `hdc` 与 DevEco `Emulator` 可用，`harmony-emulator-list-details.txt` 列出 `Codex Test Phone` 与 `Pura 90 Pro Max`。早期 raw fallback 曾无法把 HVD 连接到 HDC：
  - `harmony-emulator-list-details-after-start-path.txt` 一度显示 `Codex Test Phone` 为 `isRunning=true`。
  - `harmony-codex-qemu-log-tail.txt` 显示 guest OS boot completed，且 `express_bridge` 监听 `port 10100`。
  - `hdc-tconn-10100.txt` 返回 `[Fail]Connect failed`，最终 `device-list-harmony-emulator-after-start-failed.json` 仍为空。
  - `device-list-harmony.json` 只发现一个 sensitive real-device，因此未把真机作为本期本机 emulator 验收替代。
- 新增 Triton-first Harmony 启动契约后，`device-start-harmony-codex-plan.json` 返回 DevEco start 与 `hdc tconn` follow-up，`device-start-harmony-codex-execute.json` 返回 `started=true` 和 detached pid，`harmony-hdc-tconn-10100-after-device-start.txt` 返回 `Target is connected`。随后 `device-list-harmony-after-device-start.json` 发现 `127.0.0.1:10100` 且 `ready=true`，`device-wait-ready-harmony-10100-after-start.json` 通过，`hierarchy-harmony-10100-after-start.json` 返回 `ok=true`、`platform=harmony`、`nodeCount=93`、root `harmony:host:0`。
- 现场修复：`hierarchy --platform android --json` 未指定设备时不再被 `triton:local` 默认值污染；resolver 会走 Android host target selection，并保持 JSON 错误契约。

结论：iOS / Android / Harmony 三端本机 simulator / emulator 均已通过 Triton-first hierarchy scene 验收。当前仍未实现 Lookin per-node screenshot / surface slice，也未把 Web 变成业务控制入口；三端启动、ready 和 hierarchy 证据均保留在本 space evidence 目录。
