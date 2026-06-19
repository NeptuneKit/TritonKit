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

### 场景：网络和日志证据面板放在右侧开发者工具栏

- Given Web Device Hub 展示设备画布、检查器、网络证据和运行日志
- When 页面在桌面宽度打开
- Then 网络证据和运行日志不再占用底部横向空间
- And `网络` / `日志` 作为右侧顶部 DevTools tab，与 `配置` 位于同一组 tab 列表
- And 切换网络或日志只改变右侧 Web UI pane，不停止采集或改变 CLI / HTTP 证据契约

### 场景：移除做不好的 3D 探测模式

- Given Web Device Hub 展示设备画布和左侧视图树
- When 用户查看设备控制胶囊
- Then 不再出现 `探测` / 3D hierarchy viewer 入口
- And 中央画布始终保持普通设备镜像与输入交互
- And 左侧 `视图树`、节点 URL 路由、CLI / HTTP hierarchy 机器可读契约不被删除

### 场景：移除模拟器区域右下角缩放按钮组

- Given Web Device Hub 展示普通设备镜像
- When 用户查看模拟器画布右下角
- Then 不再显示独立 `画布缩放控制`
- And 网络/日志入口保留在右侧顶部 DevTools tab
- And 设备镜像继续由容器自适应布局展示，不依赖额外 CSS scale 控件

### 场景：移除模拟器区域左下角设备控制组

- Given Web Device Hub 已移除 3D 探测和画布缩放
- When 用户查看模拟器画布左下角
- Then 不再显示独立 `设备控制` 胶囊
- And `点选` 作为设备镜像默认交互模式保留在画布语义中，不再需要可点击模式按钮
- And `网络` / `日志` 通过右侧顶部 DevTools tab 常驻切换，不再从画布角落隐藏或恢复

### 场景：移除导航区右侧无动作按钮

- Given Web Device Hub 顶部导航区展示当前设备与右侧工具
- When 用户查看导航区右侧工具按钮
- Then 不再显示 `键盘`、`屏幕布局`、`展开`、`更多`、`调整`、`文档`、`信息` 等无动作占位按钮
- And 右侧工具区只保留真实触发 host target / screenshot / logs 刷新的 `刷新全局数据`

### 场景：导航区左侧只保留侧边栏按钮

- Given Web Device Hub 顶部导航区展示左侧工具
- When 用户查看导航区左侧
- Then 不再显示红黄绿窗口装饰灯、`添加目标`、`筛选与排序`
- And 左侧只保留一个 `收起侧边栏` / `展开侧边栏` 按钮

### 场景：移除右侧信息与应用 Tab

- Given Web Device Hub 右侧 DevTools 展示 tab 列表
- When 用户查看右侧顶部 tab
- Then 不再显示 `信息` / `应用`
- And 右侧 tab 只保留 `配置` / `网络` / `日志`

### 场景：日志 Tab 使用人类可读本地化展示

- Given Web Device Hub 右侧 DevTools 展示 `日志` tab
- When 用户切换到 `日志`
- Then 日志行显示本地化后的时间、级别、来源和中文消息
- And 常见 host / runtime / ADB / HDC / CLI 日志不直接暴露英文机器短语
- And 原始日志 message 仍保留在 DOM title 中，便于排查和对照机器证据

## 验收方式

- `npm --prefix Web test`
- `npm --prefix Web run build`
- `git diff --check`
- 必要时启动 `127.0.0.1:34127` 后用浏览器验证：设备控制胶囊不再出现 `探测`，页面没有 `.hierarchy-scene-viewer` / `.hierarchy-stage`，普通设备镜像和右侧 DevTools tabs 仍可用。

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
  - iOS：基于 embedded runtime Lookin-style `displayItems[]` / UIView-CALayer tree 生成 scene。
  - Android：基于 host-side UIAutomator XML 生成 scene。
  - Harmony：基于 host-side `uitest dumpLayout` 生成 scene。
- 新增 shared DTO：`TKHierarchyViewport`、`TKHierarchyLayerNode`、`TKHierarchyScene`、`TKHierarchySourceInfo`、`TKHostHierarchyResponse`。
- `triton capabilities --json` 与 `triton schema --command hierarchy --json` 已暴露 `hierarchy-scene`、`android-hierarchy`、`harmony-hierarchy`。
- 当前 scene 统一节点 frame、depth、visible、interactive、source、style、slice 和 render hints；iOS 已接入 per-node `screenshotRef` / `slice.dataRef`，完整 Lookin 客户端 parity 仍不包含属性编辑、完整 CALayer 样式面板等能力。

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

结论：iOS / Android / Harmony 三端本机 simulator / emulator 均已通过 Triton-first hierarchy scene 验收。iOS per-node screenshot / surface slice 已在后续 exact node slice 切片中接入；Web 仍不作为业务控制入口，三端启动、ready 和 hierarchy 证据均保留在本 space evidence 目录。

## 2026-06-19 iOS Lookin exact node slice 闭环

- 用户继续要求“还原成和 Lookin 一致”，并授权修改项目任意代码直到需求达成。
- iOS scene 事实源已从 AX-only \`runtimeSnapshot\` 改为优先使用 legacy Lookin-style \`displayItems[]\` 层树：\`triton hierarchy --platform ios --json\` 现在默认读取 embedded runtime \`hierarchy\`，把 \`UIView\` / \`CALayer\` class chain、frame、depth、hidden、alpha、backgroundColor、\`customDisplayTitle\` 和 \`screenshotRef\` 转成 \`TKHostHierarchyResponse.scene\`。Android / Harmony scene 路径保持 host layout。
- embedded runtime \`TKHierarchyBuilder\` 新增受预算保护的节点截图采集：当 runtime 已配置 \`/data\` uploader 时，hierarchy 请求会对可见、非全屏且像素面积受控的节点生成 PNG，并上传到 CLI \`/data\`，在 \`TKDisplayItem.screenshotRef\` 返回引用；无 uploader 时不内联大图，保持轻量 JSON。
- Shared slice contract 新增 \`TKHierarchyNodeSlice.dataRef\`：CLI 输出稳定的 \`/data\` 引用，Web dev bridge 可将其水合为 \`slice.dataUrl\`。 \`triton schema --command hierarchy --json\` 的 \`hierarchy.scene\` output contract 已同步说明 \`slice\` 支持 \`dataRef/dataUrl\`。
- Web dev bridge 对两条路径都支持真实纹理：
  - 新 CLI scene 已带 \`slice.dataRef\` 时，bridge 从 runtime data endpoint 拉取 PNG 并填充 \`slice.dataUrl\`。
  - 旧 iOS runtime fallback \`displayItems[].screenshotRef\` 时，bridge 同样转换为 \`slice.dataRef + slice.dataUrl\`。
- WebGL viewer 已独立加载 \`node.slice.dataUrl\`，即使没有整屏 screenshot，也能把真实节点截图贴到对应 3D plane；整屏 screenshot 裁剪只作为次级 fallback，最后才退到样式化 texture / 淡描边。
- 仍未声明 100% Lookin 客户端完整复刻：当前 exact slice 覆盖节点外观纹理，但属性面板、transform、mask、shadow、font、border、完整 CALayer 属性编辑等还未产品化；本轮目标中的“不是线稿图、真实节点切片还原”已经进入 CLI/HTTP/Web 同一契约链路。

验证：

- \`npm --prefix Web test\`：40/40 通过，新增覆盖 platform scene \`dataRef\` 水合与 legacy \`screenshotRef\` 水合。
- \`npm --prefix Web run build\`：通过，保留既有 Three.js chunk > 500KB 警告。
- \`swift test --package-path CLI --filter HierarchySceneRuntimeTests\`：通过，新增覆盖 legacy iOS \`displayItems\` 转 Lookin-style scene slices。
- \`swift test --package-path CLI --filter SchemaFactSourceSurfaceContractTests\`：通过。
- \`swift build --package-path CLI --product triton\`：通过。

## 2026-06-19 iOS Lookin 一致性真实采集入口

- 用户明确要求 iOS 侧 3D 视图“需要和 Lookin 一样还原，而不是线稿图”，并进一步要求扩大到真实采集控制入口。
- 本轮边界从纯 Web mock 展示扩展为受限 Web dev bridge 采集入口：`POST /web/host-hierarchy?platform=<platform>&target=<target>` 会触发 `triton hierarchy --platform <platform> --target <target> --json`，响应附带 `control.action=hierarchy.capture`、`entrypoint=web-dev-bridge`、`method=POST`、`readonly=true`、`mutatesApp=false`。Web 不直接调用 `xcrun` / `adb` / `hdc`，仍由 Triton CLI 契约作为事实入口。
- iOS 兼容修正：当新 scene 模式不可用，或 `triton hierarchy --platform ios --target <simulator-udid> --json` 因 runtime target 解析返回 `target_not_found` 时，dev bridge 会回退到旧 iOS runtime 命令 `triton hierarchy --target <target> --json`，并把 Lookin-style `displayItems[]` 转换为 Web `HierarchyScene`。这样已连接 Lookin/Triton runtime 的 iOS App 不再因为 scene schema 或 target resolver 差异退回 mock 线稿。
- Web `探测` 模式新增 `重新采集` 按钮，按钮走 POST 采集入口；自动进入探测时仍会尝试 GET 现场 scene。viewer 底部显示 `现场采集` / `手动采集` / `采集失败 · 使用 fallback` 状态，避免用户无法判断当前是现场数据还是 mock fallback。
- 视觉还原修正：当 target 已有真实截图时，WebGL 3D viewer 会优先按 hierarchy node frame 从真实整屏截图裁剪节点切片，并贴到对应 3D plane 上；结构节点、全屏容器或缺少截图时才降级为样式化 canvas texture / 淡描边。这把 iOS 画面从纯线框推进为 Lookin 式真实视图切片。
- 当前仍不是完整 Lookin parity：整屏截图裁剪只能近似节点外观，无法替代 runtime 提供的 per-node exact screenshot、遮挡关系、CALayer / UIKit style、transform、cornerRadius、shadow、font、alpha 等字段。完整一致性仍需按 `plans/20260619-node-slice-style-contract.md` 落地 `slice` / `style` / `raw` / `renderHints` 的真实采集。
- 契约推进：Shared `TKHierarchyLayerNode` 已补 `style`、`slice`、`raw`、`renderHints` 可选字段；`triton hierarchy --platform ... --json` 生成的 scene node 会声明标准化 `style`、不可用但具名的 `slice` 元数据、平台/source raw 信息和渲染优先级。`triton schema --command hierarchy --json` 已新增 `hierarchy.scene` output contract，Web 类型同步这些字段，后续 exact node slice 可以直接填充 `slice.dataUrl` 而不再改前端协议。
- 浏览器验证限制：代码修改后尝试重启 `127.0.0.1:34127` dev server 以验证当前页，sandbox 内启动 Vite 监听被 `listen EPERM` 拦截；经授权外部启动后 dev server 已恢复监听。随后 Browser 插件拒绝重新访问该本地 URL，原因是 Browser Use URL policy。未继续绕过该策略，改以 DOM/bridge 自动化测试和 build 作为本轮可重复验收。

验证：

- `npm --prefix Web test`：38/38 通过，新增覆盖 POST 采集入口、旧 iOS runtime fallback、`target_not_found` fallback、DOM 采集状态和手动重新采集。
- `npm --prefix Web run build`：通过，仍有既有 Three.js chunk > 500KB 警告。
- `swift test --package-path CLI --filter HierarchySceneRuntimeTests`：通过。
- `swift test --package-path CLI --filter SchemaFactSourceSurfaceContractTests`：通过。
- `swift test --package-path CLI --filter XcodeDiagnosticsTests/derivedDataCacheStateReportsWarmAndMissingPaths`：通过；本轮顺手补回 `xcodeDerivedDataCacheState`，解除 CLI test target 编译 blocker。
- `swift build --package-path CLI --product triton`：通过。
- `CLI/.build/debug/triton schema --command hierarchy --json`：确认 `hierarchy.scene` 暴露 `style` / `slice` / `raw` / `renderHints`。
## 2026-06-19 Demo + Simulator exact slice 验证与防闪动修复

- 用户要求用 Demo + iOS Simulator 验证，并追问 3D 视图为什么一直闪动。
- Triton-first 事实源已走通：
  - `triton sim list --json` 发现 booted simulator：`Overloaded-v2 Dedicated iPhone 16 Pro`，UDID `1B360513-22E7-46DB-A942-198EE522C6DC`，runtime iOS 26.5。
  - `triton xcode discover --path Examples/TritonKitDemo --json` 发现 `Examples/TritonKitDemo/TritonKitDemo.xcodeproj`。
  - `triton xcode schemes` 发现 `TritonKitDemo` scheme。
  - `triton xcode run --project Examples/TritonKitDemo/TritonKitDemo.xcodeproj --scheme TritonKitDemo --simulator 1B360513-22E7-46DB-A942-198EE522C6DC --derived-data-path .triton/DerivedData-demo-lookin --jsonl` build/install/launch 成功，bundle `com.neptunekit.tritonkit.demo`。
- 现场隔离修正：同一模拟器上曾同时挂着 `丁香园` 和 `TritonKitDemo` 两个 embedded runtime 连接，且 target id 相同，导致 `triton:local` 返回 `ambiguous_target`，指定 simulator id 时也可能采到旧 App。已通过 `triton app terminate --bundle-id cn.dxy.iDxyer` 隔离旧连接，再 `triton app launch --bundle-id com.neptunekit.tritonkit.demo` 重启 Demo；随后 `triton list --json` 只剩 `TritonKitDemo` 一个 target。
- Demo 真实采集结果：`triton hierarchy --platform ios --target triton:ios-simulator:1B360513-22E7-46DB-A942-198EE522C6DC --max-nodes 120 --json` 返回 `ok=true`、`platform=ios`、`nodeCount=120`、`sliceCount=32`，首个真实切片带 `slice.dataRef`，节点 id 已修复为真实 `ios:runtime:<oid>`，不再出现字面量 `ios:runtime:(oid)`。
- Web dev bridge 验证：`/web/host-hierarchy?platform=ios&target=triton:ios-simulator:1B360513-22E7-46DB-A942-198EE522C6DC` 返回 `ok=true`，并把 `slice.dataRef` 水合为 `slice.dataUrl=data:image/png;base64,...`，说明浏览器侧可直接渲染真实节点贴图。
- 闪动根因：
  - Web 端 `captureHierarchy` 依赖整个 `target` 对象；live preview 每秒刷新 screenshot 会生成新 target 对象，探测模式下因此反复触发 `/web/host-hierarchy`。
  - `HierarchySceneViewer` 在已有 node slice 时仍订阅 1fps 全屏 screenshot，导致 WebGL scene 每秒重建。
  - node slice 逐张加载时每张图片都会 `setSliceImages`，造成多次重建。
  - 透明 plane / edge 仍参与 depth test，斜视角下容易出现 z-fighting。
- 修复方式按 Lookin 思路收敛为“稳定采集结果 + 批量贴图 + 稳定渲染顺序”：层级采集只依赖稳定 target selector；有 `slice.dataUrl` 时不再订阅 live screenshot fallback；node slice 批量加载完成后一次性替换；透明 Mesh/Line 关闭 `depthTest/depthWrite`，依赖 `renderOrder` 控制绘制顺序。

验证：

- `npm --prefix Web test`：40/40 通过，新增覆盖“live screenshot refresh 不会重复触发 hierarchy capture”。
- `npm --prefix Web run build`：通过，保留既有 Three.js chunk > 500KB 警告。
- `swift test --package-path CLI --filter HierarchySceneRuntimeTests`：通过。
- `swift test --package-path CLI --filter SchemaFactSourceSurfaceContractTests`：通过。
- `git diff --check`：通过。
- `docs-linhay/scripts/check-docs.sh`：失败于既有空 space `docs-linhay/spaces/20260619-issue-68-harmony-app-target-failure` 缺 README，非本轮新增。

## 2026-06-19 Hierarchy viewer 捏合缩放

- 用户在 iOS Lookin-style 3D hierarchy viewer 上标注“需要支持捏合手势缩放”。
- Web viewer 新增独立 `zoom` 状态，默认 100%，范围 45% - 240%。单指横向拖动仍只控制水平 yaw；双指 pointer 距离变化控制 viewer zoom。
- WebGL 路径通过 `three.group.scale.setScalar(zoom)` 缩放整个层级 group；DOM fallback 同步通过 `--hierarchy-zoom` CSS 变量缩放，避免 WebGL 不可用时交互语义不一致。
- 触控板常见 `ctrl/meta + wheel` 缩放也接入同一 `zoom` 状态，方便桌面浏览器验证。
- 状态输出从 `水平旋转 xx°` 扩展为 `水平旋转 xx° · 缩放 yy%`，用于可访问反馈和自动化断言。

验证：

- `npm --prefix Web test`：40/40 通过，新增覆盖 hierarchy viewer 双指距离拉大后缩放百分比变化。
- `npm --prefix Web run build`：通过，保留既有 Three.js chunk > 500KB 警告。
- `git diff --check`：通过。

## 2026-06-19 设备与视图节点 URL 路由同步

- 用户要求切换设备、视图选中节点时同步改变 URL 路由。
- Web Device Hub 新增 query route 状态：`target=<target-id>` 表示当前设备，`panel=view-tree` 表示当前侧栏面板，`node=<hierarchy-node-id>` 表示当前视图层级节点。
- 初始 URL 可恢复设备、侧栏和节点选择；节点只在当前 target 的 hierarchy scene 中存在时保留，切到其它平台且节点不适用时会清除 `node`，避免跨设备误选。
- URL 写回保留既有诊断参数，例如 `__tritonkit_mock_host_targets=request-failed`，不影响 QA fallback / dev bridge 调试。
- 视图树行补充 `data-node-id`，让 DOM 回归测试可以直接断言当前选中的机器可读节点 id。

验证：

- `npm --prefix Web test`：55/55 通过。
- `npm --prefix Web run build`：通过，保留既有 Three.js chunk > 500KB 警告。

## 2026-06-19 DevTools 顶部证据 Tab 布局

- 用户要求“底部面板都放右侧，参考 chrome devtools 布局”。
- 用户进一步指出“上面不是有 tab 列表吗”，明确 `网络` / `日志` 应加入右侧顶部既有 `信息` / `应用` / `配置` tab 列表，而不是在下方新增一组 evidence tabs。
- Web Device Hub 已移除底部 `hub-bottom` evidence 区；右侧顶部 tab 现在为 `信息` / `应用` / `配置` / `网络` / `日志`，点击 `网络` 或 `日志` 时在同一右侧内容区切换对应 pane。
- 网络/日志隐藏仍是纯 Web UI 状态：隐藏按钮只控制 pane 可见性，恢复入口继续在设备控制胶囊中，不改变 CLI / HTTP 采集和证据契约。
- 中等宽度断点收紧左侧 target list 与右侧 DevTools 宽度，减少对设备画布的挤压；移动窄屏下右侧栏落到画布下方，避免内容重叠。
- 网络列表修正单条数据居中问题：`.network-rows` 与日志列表一样显式使用 `align-content: start`，避免 CSS grid 在只有一条记录时把单行拉伸到整块剩余高度。
- DOM 回归测试新增断言：顶部 tab 标签为 `信息 / 应用 / 配置 / 网络 / 日志`，网络与日志 pane 位于 `.hub-devtools` 内，且页面不再渲染 `.hub-bottom` 或额外 `.evidence-tabs`。
- 浏览器验证截图：`screenshots/20260619/20260619-web-devtools-tabs-after-v02.png`。

验证：

- `npm --prefix Web test`：55/55 通过。
- `npm --prefix Web run build`：通过，保留既有 Three.js chunk > 500KB 警告。
- in-app browser 验证当前 `http://127.0.0.1:34127/?target=ios-real%3A7a9d976cc4d4`：顶部 tab 为 `信息/应用/配置/网络/日志`，无 `.evidence-tabs`、无 `.hub-bottom`，点击 `网络`/`日志` 时对应 pane 可见且另一个 pane 隐藏。
- in-app browser 复验网络列表：切到 `网络` 后 `.network-rows` computed `align-content=start`，首条 `.network-row` 相对列表容器偏移为 `0`，页面横向溢出为 `0`。

## 2026-06-19 移除 3D 探测模式

- 用户明确要求“移除 3d 模式，我们做不好不如没有”。
- Web Device Hub 已移除中央画布的 `探测` 工具入口；设备控制胶囊只保留 `点选`、网络/日志显隐、缩放等稳定能力。
- 删除 Web 侧 `HierarchySceneViewer`、Three.js 动态渲染路径、`.hierarchy-*` 视觉样式，以及 `three` / `@types/three` 依赖；构建产物不再生成 Three chunk。
- 左侧 `视图树`、设备/节点 URL 路由和 CLI / HTTP `hierarchy` 机器可读契约保留，后续真实能力继续以契约和树形事实为主，不再通过 Web 3D mock 暗示 Lookin parity。
- DOM 回归测试改为负向断言：不应出现 `探测` 按钮、`.hierarchy-stage`、`.hierarchy-scene-viewer` 或 `.hierarchy-three-canvas`；视图树仍可跨 iOS / Android / Harmony target 展示节点。

验证：

- `npm --prefix Web test`：54/54 通过。
- `npm --prefix Web run build`：通过，产物只包含 `index-*.css` 与 `index-*.js`，不再有 Three chunk。
- `git diff --check`：通过。
- in-app browser 复验当前 34127 页面：`探测` 按钮数量为 `0`，`.hierarchy-stage` / `.hierarchy-scene-viewer` / `.hierarchy-three-canvas` 均为 `0`，普通 `.device-frame` / `.device-screen` 均为 `1`，横向溢出为 `0`。

## 2026-06-19 移除模拟器右下角缩放按钮组

- 用户追问模拟器区域右下角按钮组是否已经无用；确认该组只控制普通设备镜像的 CSS scale，在 3D 探测模式移除后已经不是核心工作流。
- Web Device Hub 已删除 `CanvasZoomControls`、`canvasZoom` 状态、`.canvas-zoom-controls` 样式和 `--canvas-zoom` transform。设备镜像继续由 `.device-frame` / `.device-screen` 的自适应尺寸承载。
- 网络/日志入口由右侧顶部 DevTools tab 承接，不再依赖画布角落的浮动按钮。
- DOM 回归测试新增负向断言：`[aria-label="画布缩放控制"]` 与 `.canvas-zoom-controls` 均不应存在。

验证：

- `npm --prefix Web test`：54/54 通过。
- `npm --prefix Web run build`：通过。
- `git diff --check`：通过。
- in-app browser 复验当前 34127 页面：`zoomControls=0`，普通 `.device-frame`、`.device-screen` 均为 `1`，横向溢出为 `0`。

## 2026-06-19 移除模拟器左下角设备控制组

- 用户继续追问左下角按钮组；确认该组也已经失去主要职责：`点选` 是唯一模式，网络/日志已经并入右侧顶部 DevTools tab。
- Web Device Hub 已删除 `DeviceControls` 组件、`.device-controls` / `.control-pill` / `.strip-action` 相关样式，以及网络/日志隐藏/恢复状态。画布不再显示左下角浮动工具胶囊。
- `网络` / `日志` tab 改为常驻可选，不再禁用，也不通过画布按钮隐藏或恢复；pane 内也不再显示隐藏按钮，避免 Chrome DevTools 风格 tab 与浮动控制重复。
- 设备画面仍保持 `tool-point` 与 `aria-label="设备画面，当前工具 点选"`，输入 relay / tap / long press / pinch 语义不变。

验证：

- `npm --prefix Web test`：55/55 通过。
- `npm --prefix Web run build`：通过。
- `git diff --check`：通过。
- in-app browser 复验当前 34127 页面：`.device-controls=0`、右下缩放控件 `0`、`点选/探测` 按钮均为 `0`，右侧 `信息/应用/配置/网络/日志` tab 全部可用，横向溢出为 `0`。

## 2026-06-19 移除导航区右侧占位按钮

- 用户继续指出导航区右侧两组按钮缺少明确用途；确认 `键盘`、`屏幕布局`、`展开`、`更多`、`调整`、`文档`、`信息` 都没有绑定动作，只是历史占位。
- Web Device Hub 已删除右侧 `.toolbar-center` 两组占位按钮，以及检查器工具组里的 `调整` / `文档` / `信息`。右侧工具区只保留有实际行为的 `刷新全局数据`。
- 顶部导航仍保留当前有效入口：左侧 target 辅助按钮、侧栏收起/展开、标题设备切换和右侧刷新；不新增 Web 侧业务控制闭环。

验证：

- `npm --prefix Web test`：56/56 通过。
- `npm --prefix Web run build`：通过。
- `git diff --check`：通过。
- in-app browser 复验当前 34127 页面：右侧检查器工具仅有 `刷新全局数据`，`键盘/屏幕布局/展开/更多/调整/文档/信息` 均不存在，`.toolbar-center=0`，横向溢出为 `0`。

## 2026-06-19 导航区左侧只保留侧边栏按钮

- 用户要求“左侧只留一个展开收起侧边栏的按钮”。
- Web Device Hub 已删除顶部左侧红黄绿窗口装饰灯，以及 `添加目标` / `筛选与排序` 这组无绑定占位按钮；左侧只保留 `收起侧边栏` / `展开侧边栏`。
- 顶部布局从五列收敛为三列：侧边栏按钮、设备标题切换、右侧刷新，不改变设备标题切换或右侧刷新行为。

验证：

- `npm --prefix Web run build`：通过。
- in-app browser 复验当前 34127 页面：`trafficLights=0`、`添加目标=0`、`筛选与排序=0`、侧边栏按钮 `1`，toolbar buttons 为 `收起侧边栏 / 切换设备 / 刷新全局数据`，横向溢出为 `0`。
- `npm --prefix Web test`：仍失败于既有旧用例期望 `QA mock fallback` / 静态 mock targets；当前产品代码与新用例已改为不挂静态 mock targets，非本轮导航清理引入。

## 2026-06-19 移除右侧信息与应用 Tab

- 用户要求移除右侧 DevTools 顶部 `信息` / `应用` 两个 tab。
- Web Device Hub 已将 `DevtoolsPanel` 收敛为 `config | network | logs`，默认选中 `配置`；右侧 tab 列表只渲染 `配置` / `网络` / `日志`。
- 原 `信息` / `应用` 不再作为 tab 出现；当前检查器内容继续由 `配置` pane 承载，网络与日志切换语义不变。

验证：

- `npm --prefix Web run build`：通过。
- `git diff --check`：通过。
- in-app browser 复验当前 34127 页面：tabs 为 `配置 / 网络 / 日志`，`信息=false`、`应用=false`，默认选中 `配置`，横向溢出为 `0`。
- `npm --prefix Web test`：仍失败于既有旧用例期望 `QA mock fallback` / 静态 mock targets；当前产品代码与新用例已改为不挂静态 mock targets，非本轮 tab 清理引入。

## 2026-06-19 日志 Tab 本地化与人类可读格式

- 用户要求 `日志` tab 的显示需要转换为人类可读格式并本地化。
- Web Device Hub 新增日志展示层 formatter：把 `LogEntry.message` 转成中文可读消息，并补齐 `时间 / 级别 / 来源 / 消息` 四列展示。常见来源包括 `iOS`、`Android`、`Harmony`、`应用`、`网络`、`CLI`。
- 已覆盖常见机器短语：host target selection、CLI DTO evidence missing、`triton ... exit=...`、`simctl framebuffer`、`ADB target ready`、`HDC target discovered`、`App launched`、`Network timeout` 等。
- 原始英文 message 不直接作为正文展示，但保留在 `.log-row[title]` 中，方便排查时对照原始机器证据。

验证：

- `node --test --test-name-pattern='renders bounded iOS host logs|keeps network and logs' dev/appFallbackDom.test.mjs`：日志本地化核心用例通过；另一个既有右侧 tab 用例仍失败于旧 `QA mock fallback` 等待语义。
- `npm --prefix Web run build`：通过。
- `git diff --check`：通过。
- in-app browser 复验当前 34127 页面：`日志` tab 行内容为中文本地化消息，`Selected host` / `ADB target ready` / `HDC target discovered` / `App launched` / `Network timeout` 等英文已不作为可见正文出现；原文保留在 `title`，横向溢出为 `0`。

## 2026-06-19 设置页与语言偏好

- 用户要求新增设置页面，用于配置语言偏好。
- 右侧 DevTools tab 新增 `设置`，作为 Web 展示偏好页；本轮只保存本机浏览器展示偏好，不新增 CLI / HTTP 业务控制入口。
- 语言偏好支持 `简体中文` 与 `English`，持久化到本机 `localStorage`。切换语言后，右侧 tab、设置页、网络模式标签和日志的级别 / 来源 / 正文会立即切换。
- 默认语言为 `简体中文`；刷新页面后继续使用上次选择的偏好。

验收：

- 默认打开页面时右侧 tab 为 `配置 / 网络 / 日志 / 设置`，日志正文为中文可读格式。
- 在 `设置` tab 选择 `English` 后，右侧 tab 切换为 `Config / Network / Logs / Settings`，日志正文切换为英文可读格式。
- 刷新页面后语言偏好保持不变。

验证：

- `npm --prefix Web run build`：通过。
- `node --test --test-name-pattern='renders bounded iOS host logs|keeps network and logs' dev/appFallbackDom.test.mjs`：2/2 通过。
- `git diff --check -- Web/src/App.tsx Web/src/styles.css Web/dev/appFallbackDom.test.mjs docs-linhay/spaces/20260619-lookin-hierarchy-viewer/README.md docs-linhay/memory/2026-06-19.md`：通过。
- Playwright 隔离浏览器验证当前 `34127` 页面：默认 tab 为 `配置 / 网络 / 日志 / 设置`；选择 `English` 后变为 `Config / Network / Logs / Settings`；日志正文为英文且不含中文日志正文；刷新后仍保持 English；横向溢出为 `0`。
- `npm --prefix Web test`：48/57 通过；失败 9 条仍集中在旧 request-failed fallback / 静态 mock target 断言，和当前“不再挂 QA mock targets”的产品方向冲突，非本轮设置页引入。
- `docs-linhay/scripts/check-docs.sh`：失败于既有 `docs-linhay/spaces/20260619-issue-68-harmony-app-target-failure` 缺 `README.md`。

## 2026-06-19 配置 Tab 绑定选中视图节点与热修改预览

- 用户指出配置 tab 没有显示 view-tree 当前选中节点信息，并要求支持类似 Lookin 的热修改。
- 当前边界：Web 仍不新增 CLI / HTTP 写入控制契约；热修改先作为本机 Web 调试预览，明确标记为“未写回 App runtime”。
- 配置 tab 需要在选中 view-tree 节点时展示节点名称、类型、id、frame、depth、可见性、交互性、颜色、opacity、cornerRadius 等机器可读 DTO 字段。
- 配置 tab 增加本地热修改 controls：`x / y / width / height / opacity / cornerRadius / backgroundColor / hidden`。修改后画布上的选中区域即时按 draft frame 和样式更新，方便对齐 Lookin 的调试心智。
- 支持重置当前节点修改，恢复到 `HierarchyScene` 原始 DTO。

验收：

- `panel=view-tree&node=<id>` 打开后，配置 tab 可见当前选中节点信息。
- 修改 `x` 或 `width` 后，画布 `.view-node-highlight` 的位置或尺寸即时变化。
- 修改 opacity / cornerRadius / backgroundColor 后，选中区域预览样式即时变化。
- 点击重置后，配置 tab 数值和画布高亮回到 DTO 原值。

验证：

- `npm --prefix Web run build`：通过。
- `node --test --test-name-pattern='shows selected view-tree node details' dev/appFallbackDom.test.mjs`：1/1 通过。
- Playwright 隔离浏览器验证当前 `?target=sim:...&panel=view-tree&node=ios:runtime:6`：配置 tab 显示 `ios:runtime:6` 节点信息；修改 X 后 `.view-node-highlight` 的 left 从 `0%` 变为 `4.97512%`；横向溢出为 `0`。
- `git diff --check -- Web/src/App.tsx Web/src/styles.css Web/dev/appFallbackDom.test.mjs docs-linhay/spaces/20260619-lookin-hierarchy-viewer/README.md docs-linhay/memory/2026-06-19.md`：通过。
- `npm --prefix Web test`：51/60 通过；失败 9 条仍为旧 request-failed fallback / 静态 mock target 断言，非本轮配置 tab 与热修改预览引入。
- `docs-linhay/scripts/check-docs.sh`：失败于既有 `docs-linhay/spaces/20260619-issue-68-harmony-app-target-failure` 缺 `README.md`。

## 2026-06-19 设备镜像快照模式

- 用户要求模拟器区域新增快照模式：模式下不实时刷新，必须手动刷新；点击画布不发送设备事件，而是选中视图节点。
- 本轮定义为 Web 设备镜像的 snapshot inspect mode，不恢复 3D 探测模式，不新增 CLI / HTTP 写入或控制契约。
- 默认仍是实时模式，保留当前输入链路；进入快照模式后停止 live screenshot 轮询，隐藏实时 fps 控制，显示 `快照模式` 与手动刷新按钮。
- 手动刷新会重新拉取 screenshot；如果当前已有 view-tree / hierarchy scene，则同步刷新 hierarchy scene，保证点击命中使用最新 frame。
- 快照模式下画布 click / pointer down 不走 `sendHostInput`，而是按 hierarchy scene 的 frame 做 hit-test，选择命中的最深可见节点，并同步左侧 view-tree / URL node。

验收：

- 切到快照模式后，等待超过 1 秒不会继续发 `/web/host-screenshot` live 轮询。
- 点击手动刷新后只发一次明确的 screenshot refresh；存在 hierarchy scene 时同时刷新 hierarchy。
- 快照模式下点击画布命中节点后，`selectedHierarchyNode` 和 URL `node` 改为命中节点；不会产生 `/web/host-input` 请求。
- 切回实时模式后，设备输入链路恢复。

验证：

- `npm --prefix Web run build`：通过。
- `node --test --test-name-pattern='snapshot mode stops live refresh|lets users tune live preview fps|keeps device canvas in point mode' dev/appFallbackDom.test.mjs`：3/3 通过。
- Playwright 隔离浏览器验证当前 `?target=sim:...&panel=view-tree&node=ios:runtime:6`：切到快照模式后 screenshot 请求数 1.3 秒内保持 `4 -> 4`；点击画面后选中节点变为 `ios:runtime:1318` 且 `/web/host-input=0`；点击手动刷新后 screenshot 请求 `4 -> 5`；横向溢出为 `0`。
- `git diff --check -- Web/src/App.tsx Web/src/styles.css Web/dev/appFallbackDom.test.mjs docs-linhay/spaces/20260619-lookin-hierarchy-viewer/README.md docs-linhay/memory/2026-06-19.md`：通过。
- `npm --prefix Web test`：52/61 通过；失败 9 条仍为旧 request-failed fallback / 静态 mock target 断言，非本轮快照模式引入。
- `docs-linhay/scripts/check-docs.sh`：失败于既有 `docs-linhay/spaces/20260619-issue-68-harmony-app-target-failure` 缺 `README.md`。

## 2026-06-19 Hierarchy viewer 快照模式停止定时刷新

- 用户指出“三维视图模式是快照，不用定时刷新”。
- Web 已将 hierarchy probe 模式标记为 snapshot mode：进入 `探测` 时父组件停止 live screenshot 轮询，退出到 `点选` 或切换 target 后恢复普通设备镜像刷新。
- 探测态不再显示右上角 `实时 1fps` 控件，避免 UI 继续表达实时流；hierarchy viewer 只在进入探测时 GET 采集一次，或用户点击 `重新采集` 时 POST 手动刷新。
- 回归测试更新：进入 probe 后等待超过 1 秒，`/web/host-screenshot` 请求数量必须保持不变，`/web/host-hierarchy` 仍只采一次，且 live preview badge 不存在。

验证：

- `npm --prefix Web test`：40/40 通过。
- `npm --prefix Web run build`：通过，保留既有 Three.js chunk > 500KB 警告。
- `git diff --check`：通过。

## 2026-06-19 Hierarchy capture evidence 与状态文案

- 用户把裁决整理为工程边界与验收清单，强调 Web 侧不能只看有没有 scene，而要根据机器可读 evidence 判断是否是真实节点切片。
- Web `HostHierarchyResponse` 新增 `captureEvidence`：
  - `captureId`、`capturedAt`
  - `target.id / ambiguous`
  - `source.kind = triton-hierarchy | fallback`
  - `source.nodeSlice = real | styled | none`
  - `source.screenshotSlice = real | none`
  - `hydration.dataUrlCount / nodeCount / failedNodeCount`
- Web dev bridge 在 `/web/host-hierarchy` 响应中生成 `captureEvidence`。当 `slice.dataRef` 被水合为 `slice.dataUrl` 时，`source.nodeSlice=real`、`hydration.dataUrlCount>0`；静态/样式化 scene 则标为 `nodeSlice=styled`。
- UI 状态文案改为 evidence-first：
  - `nodeSlice=real`：`现场采集 · 真实截图切片` 或 `手动采集 · 真实截图切片`
  - `nodeSlice=styled`：`样式化快照 · 非真实节点切片`
  - error：`采集失败 · 已显示 fallback scene`
  - loading：`正在采集快照…`
- DOM mock 测试不再假装真实 Lookin slice；没有真实切片的 mock scene 显示 `样式化快照`。bridge 水合测试断言真实 `dataRef -> dataUrl` 时 evidence 标为 `real`。

验证：

- `npm --prefix Web test`：40/40 通过。
- `npm --prefix Web run build`：通过，保留既有 Three.js chunk > 500KB 警告。
- `git diff --check`：通过。

## 2026-06-19 Hierarchy 叶子节点贴图，容器只保留结构

- 用户指出 3D 视图“每层都在重复渲染，Lookin 不是这样的”。
- 根因：iOS runtime 当前节点截图来自 `CALayer.render(in:)`；容器 layer 的截图会包含子 layer，因此如果父容器、子容器、叶子节点都作为真实纹理 plane 渲染，同一 UI 会在多个深度层重复出现。
- 修复：WebGL viewer 只把真实 screenshot slice 用在没有可见子节点的叶子节点上；任何有可见子节点的节点，即使带 `slice.dataUrl`，也只作为结构层/描边层渲染。这样容器负责表达层级，叶子节点负责表达内容纹理，更接近 Lookin 的层级心智。
- DOM fallback 同步增加 `data-render-mode=slice|structure`，便于测试和排查具体节点是贴图还是结构。
- 后续裁决已取代本节的 leaf-only 方案：默认渲染模型不再消费任何节点 `slice.dataUrl` 作为普通 layer texture；真实 slice 仅作为选中节点证据出现。

验证：

- `npm --prefix Web test`：41/41 通过，新增覆盖“父容器和叶子节点都有 dataUrl 时，父容器为 structure、叶子为 slice”。
- `npm --prefix Web run build`：通过，保留既有 Three.js chunk > 500KB 警告。
- `git diff --check`：通过。

## 2026-06-19 Hierarchy 默认渲染模型改为 main snapshot + structure

- 用户裁决明确：3D hierarchy viewer 是可复现快照调试器，默认不是“每个 node 一张真实 UI plane”。旧模型把 subtree screenshot 误用成 layer-own texture，导致父容器、子容器和叶子节点都携带同一份 UI 语义内容，透明度、z-spacing 或 leaf-only 过滤都不能从产品心智上解决问题。
- Web viewer 内部模型收敛为 `main-snapshot-with-structure | structure-only-fallback | selected-slice-evidence`：
  - 有完整 screenshot 时，只渲染一张 `main-snapshot-surface` 作为主视觉。
  - 所有 hierarchy node 默认只渲染结构 plane / outline，不默认贴 `node.slice.dataUrl`。
  - `node.slice.dataUrl` 继续作为 evidence 数据保留，但只对选中/聚焦节点额外渲染一个 `selected-slice` 证据层。
- WebGL 路径删除默认 per-node texture loop：不再遍历所有节点把 `slice.dataUrl` 转成独立材质；只加载选中证据节点的 slice image。DOM fallback 增加测试 hook：
  - 主 surface：`data-render-role="main-snapshot-surface" data-render-mode="main-snapshot"`
  - 默认节点：`data-render-mode="structure"`
  - 选中证据：`data-render-mode="selected-slice"`，后续由 `data-texture-source=<VisualSource.kind>` 标记来源。
- 状态文案按证据矩阵调整：`现场采集 · 真实截图切片可用` 表示真实 node slice 可用于选中证据；没有 node slice 但有主 screenshot 时显示 `现场采集 · 节点切片不可用`；无主 screenshot 但有真实 slice 时显示 `结构快照 · 局部切片可用`。
- 新增防回归测试卡死旧模型：默认 scene 中 `data-render-mode="node-slice"` 和 `data-render-mode="slice"` 必须为 0，`data-render-mode="structure"` 必须存在，`selected-slice` 最多只出现 1 个，避免未来重新把所有 `node.slice.dataUrl` 铺成 texture planes。

验证：

- `npm --prefix Web test`：41/41 通过。
- `npm --prefix Web run build`：通过，保留既有 Three.js chunk > 500KB 警告。
- `git diff --check`：通过。

## 2026-06-19 Layer Metadata Contract + Material Source Guard

- 用户裁决继续收敛：TritonKit 当前目标是 `Lookin-style snapshot hierarchy evidence viewer`，不是“用截图拼 Lookin”。真正逼近 Lookin-like object reconstruction 的前提是 runtime contract 能导出真实 layer geometry / contents / clipping / transform / visual effect 语义。
- 新增 hierarchy node contract：
  - `view?: HierarchyViewMetadata / TKHierarchyViewMetadata`
  - `layer?: HierarchyLayerMetadata / TKHierarchyLayerMetadata`
  - `visualSources?: HierarchyVisualSource[] / [TKHierarchyVisualSource]`
- `VisualSource.kind` 固化为 material/evidence 边界：
  - `layerOwnContents`：唯一允许进入默认 3D material 的真实内容源。
  - `subtreeSnapshot`：只能作为 evidence，不能默认重建 layer contents。
  - `mainScreenshotCrop`：只能作为 fallback evidence。
  - `styledFallback`：结构/样式降级，必须带 reason。
- Web 新增纯函数 policy：
  - `resolveDefaultMaterialSource(node)`：只返回 `layerOwnContents`，否则 `null`。
  - `resolveEvidenceSources(node)`：返回全部 evidence sources，legacy `node.slice` 会兼容映射为 `subtreeSnapshot`。
  - `getMaterialExplanation(node)`：解释当前节点为什么没有默认材质，以及有哪些 evidence。
  - `computeParityClaim(scene)`：有 `subtreeSnapshot` 或缺 `layerOwnContents` 时，明确 `canClaimLookinParity=false`。
- Web 3D viewer 改为通过 policy 选择 evidence source；`data-texture-source` 现在输出 `subtreeSnapshot/layerOwnContents/mainScreenshotCrop/styledFallback` 等 contract kind，不再使用旧的 `node-slice` 语义。
- Web dev bridge 兼容旧 `slice`，但会补 `visualSources[{kind:"subtreeSnapshot"}]`；hydration 与 captureEvidence 统计也改为基于 `visualSources`。CLI legacy iOS hierarchy scene 同步输出 `subtreeSnapshot`，host observe scene 输出 `styledFallback`。
- UI 增加降级 badge：
  - `Snapshot Evidence Mode · Lookin parity unavailable`
  - 当前节点视觉来源：`subtreeSnapshot / mainScreenshotCrop / styledFallback / layerOwnContents`

验证：

- `npm --prefix Web test`：45/45 通过，新增 subtreeSnapshot/default material、layerOwnContents、parity claim、material explanation 测试。
- `npm --prefix Web run build`：通过，保留既有 Three.js chunk > 500KB 警告。
- `swift test --package-path CLI --filter HierarchySceneRuntimeTests`：3 个 Swift Testing 用例通过。
- `swift test --package-path CLI --filter SchemaFactSourceSurfaceContractTests`：4 个 Swift Testing 用例通过。

## 2026-06-19 Runtime layer metadata 与节点 Inspector

- 在 Material Source Guard 基础上继续把真实 Lookin-like reconstruction 的前置字段往 runtime contract 下沉，而不是继续靠 Web 调参。
- embedded iOS runtime 的 `TKHierarchyBuilder` 现在从 `CALayer` 捕获 layer metadata，并写入 `TKDisplayItem`：
  - bounds / position / anchorPoint / zPosition
  - transform / sublayerTransform
  - masksToBounds / cornerRadius / opacity / hidden
  - contentsScale / contentsGravity / contentsRect
  - borderWidth / shadowOpacity / shadowRadius / shadowOffset
- CLI legacy iOS scene 会把这些字段映射到 `TKHierarchyLayerNode.layer`，同时输出 `view` metadata 和 `visualSources`。没有真实 layer own contents 时，旧截图来源仍只标记为 `subtreeSnapshot`，不能进入默认 material。
- Web hierarchy viewer 新增选中节点 Inspector，直接显示 Node / Layer / Visual Sources / Default Material 状态，便于解释“为什么当前节点不能声明 Lookin parity”。
- DOM 测试覆盖 Inspector 输出：选中节点展示 `UIView`、frame、depth、`layer.zPosition`、`layer.opacity`、`layer.masksToBounds`、`visualSources=subtreeSnapshot`，并继续断言默认 scene 不批量渲染 node slice texture。
- 当前仍不声明完整 Lookin parity：runtime 已有更多 CALayer metadata，但默认材质仍只允许未来的 `layerOwnContents`；`subtreeSnapshot` 继续只作为 evidence。

验证：

- `npm --prefix Web test`：45/45 通过。
- `npm --prefix Web run build`：通过，保留既有 Three.js chunk > 500KB 警告。
- `swift test --package-path CLI --scratch-path /private/tmp/triton-cli-test-layer-metadata --filter HierarchySceneRuntimeTests`：3 个 Swift Testing 用例通过。
- `swift test --package-path CLI --scratch-path /private/tmp/triton-cli-test-layer-metadata --filter SchemaFactSourceSurfaceContractTests`：4 个 Swift Testing 用例通过。
- `git diff --check`：通过。

## 2026-06-20 UIViewController 节点展示

- 用户指出 view-tree 里也需要显示 `UIViewController`。
- 运行时采集层已在 `TKDisplayItem.hostViewControllerObject` 暴露控制器对象，问题在转换层：CLI legacy iOS scene 与 Web dev bridge 之前只把 controller class 当作 view/layer class fallback，导致控制器不会作为独立节点进入树。
- CLI legacy iOS 转换现在在 `hostViewControllerObject.oid` 发生变化时插入语义节点：
  - `id = ios:controller:<oid>`
  - `source = runtime-controller`
  - `raw.role = UIViewController`
  - `style.display = controller`
  - `renderHints.preferredMode = structure`
- Web dev bridge 的 legacy iOS fallback 转换保持同样语义；实际 view/layer 节点挂到 controller 节点下，同一 controller 子树内不会为每个 subview 重复插入。
- 边界：只有 runtime DTO 明确提供 `hostViewControllerObject` 时才显示控制器节点；不会在 Web 端猜测或伪造 controller。

验证：

- `node --test --test-name-pattern='falls back to legacy iOS runtime hierarchy and converts it to a Web scene' dev/iosSimulatorBridge.test.mjs`：通过，断言 `ios:controller:88` 出现在 scene 中，且 collection view parent 指向该 controller。
- `npm --prefix Web run build`：通过。
- `swift test --package-path CLI --filter HierarchySceneRuntimeTests`：3 个 Swift Testing 用例通过，覆盖 controller 节点插入与 view 子节点挂载。
- 重启 `34127` Vite dev server 后，in-app browser 复验当前 simulator URL：view-tree 从 433 个节点变为 438 个节点，新增 `ios:controller:12 MainTabBarController#12`、`ios:controller:585 AppNavigationController#585`、`ios:controller:592 PhotosViewController#592`、`ios:controller:442 UITrackingElementWindowController#442`、`ios:controller:447 UIEditingOverlayViewController#447`，横向溢出为 `0`。

## 2026-06-20 模拟器壳标注当前 UIViewController

- 用户要求模拟器壳直接标注当前 `UIViewController` 类名，并确认采用 runtime 事实优先方案。
- 需求边界：
  - `HierarchyScene` 增加可选 `controllerContext`，由 iOS runtime / CLI hierarchy 转换输出当前 controller 事实。
  - Web 设备壳优先显示 `controllerContext.activeControllerName` 和 stack；没有该字段时，回退到现有 `ios:controller:*` 节点父链推导。
  - 不从 screenshot 像素、UIKit wrapper view 名称、appName 或静态 mock 名称猜测当前 controller。
- 验收场景：
  - Given iOS runtime hierarchy 返回 controller context，When Web 显示设备镜像，Then 模拟器壳上显示当前 `UIViewController` 类名。
  - Given 当前 view-tree 选中的是某个子 view，When 该子 view 位于 controller 节点下，Then 壳上显示该节点所属 controller。
  - Given 旧 runtime 不返回 `controllerContext`，When scene 中存在 `ios:controller:*` 节点，Then Web 使用父链 / 可见面积 fallback 显示 controller，且标注为 fallback 来源。
  - Given scene 中没有 controller 事实，Then 壳显示 `UIViewController 未暴露`，不伪造。

实现：

- `TKHierarchyScene` 新增 `controllerContext`，包含 `activeControllerId`、`activeControllerName`、`activeControllerClassName`、`stack` 与 `source`。
- iOS embedded runtime 在处理 `hierarchy` 请求时复用 `currentRouteState()` 同源 UIKit route 逻辑，按 root / presented / selected tab / navigation / split / page / custom visible child 生成 `runtime-route` controller stack。
- CLI legacy iOS scene 转换透传 runtime `controllerContext`；旧 runtime 没有该字段时，从 `runtime-controller` 节点生成 `scene-controller-node-fallback`。
- Web dev bridge 同步 legacy fallback；Web 设备壳优先显示选中节点所属 controller，再显示 scene `controllerContext.activeControllerName`，最后使用 scene controller 节点 fallback。
- 模拟器壳新增 `controller-shell-badge`，显示 `UIViewController · <ClassName>`；fallback 来源会显示 `fallback` 标记，避免把旧数据伪装成 runtime route 事实。

验证：

- `swift test --package-path CLI --filter HierarchySceneRuntimeTests`：3 个 Swift Testing 用例通过，覆盖 legacy scene controller context fallback。
- `node --test --test-name-pattern='falls back to legacy iOS runtime hierarchy and converts it to a Web scene|shows selected view-tree node details' dev/iosSimulatorBridge.test.mjs dev/appFallbackDom.test.mjs`：2/2 通过，覆盖 Web bridge fallback 和设备壳 badge。
- `npm --prefix Web run build`：通过。
- in-app browser 复验当前 simulator URL：壳上显示 `UIViewController · PhotosViewController`，由于当前模拟器 App 仍是旧 embedded runtime，badge 来源为 `fallback`；view-tree 中可见 `MainTabBarController#12`、`AppNavigationController#585`、`PhotosViewController#592` 等 controller 节点，横向溢出为 `0`。
- `swift test --filter TKHierarchySceneModelsTests` 被既有 `Tests/TritonKitSharedTests/TKXcodeWorkflowModelsTests.swift` 编译错误阻塞，错误仍是缺少 `TKXcodeDerivedDataCacheState` 与 Xcode progress / summary 初始化参数不匹配。
