# Apple 专门平台输入后端核实

日期：2026-10-10。范围：CLI / shared host adapter 的后续可执行输入后端。本文是只读研究，不是实现或设备动作验收。

## 结论与当前状态

watchOS Digital Crown 旋转和 tvOS 方向、选择、菜单输入有公开 XCUIAutomation 后端，应标为「公共后端存在，Triton 尚未集成」，不能标为 GUI-only。它们需要 Xcode UI-test runner 上下文；当前 `triton xcode test` 能承接构建、运行和结果收集，但不能直接把 API 名转成即时设备控制。

watchOS 侧键在本次核实的公开按钮枚举中没有准确对应项；不能拿 Home 或 Action 代替。visionOS 需要细分：Apple 明确展示了 Designed for iPad 应用的 UI automation；SDK 也声明部分 visionOS UI 输入 API，但这不足以证明原生空间应用 runner 或空间交互已可用。视角、头部姿态、场景和光照目前仅查到 Device Hub GUI 控制，没有查到可接入的公开无界面控制 API。

所有下表项目均未在本轮执行；本轮没有设备、GUI、构建或测试动作。

| 能力 | 已核实后端 | 本批状态 | 最小下一步 |
| --- | --- | --- | --- |
| watchOS Crown 旋转 | `XCUIDevice.shared.rotateDigitalCrown(delta:)`，另有 velocity 重载 | 公共后端存在，未集成、未实测 | 独立 watchOS UI-test runner + 专用 fixture 验证有符号旋转 |
| watchOS 侧键 | Device Hub GUI；公开 `XCUIDevice.Button` 未发现 side 项 | 本次仅找到 GUI 操作，未支持 | 查到精确公开 API 或有独立风险策略的版本化私有 adapter 后再承诺 |
| watchOS Action 按钮 | `hasHardwareButton(.action)` + `press(.action)` | 公共后端存在，未集成；不是侧键 | 先做硬件能力判断，缺失时返回 unsupported |
| tvOS 焦点方向 | `XCUIRemote.shared.press(.up/.down/.left/.right)` | 公共后端存在，未集成、未实测 | fixture 焦点格 + `hasFocus` 前后断言 |
| tvOS 选择 / 返回 | `.select` / `.menu` | 公共后端存在，未集成、未实测 | 验证选择后的页面及 menu 导航结果 |
| visionOS 兼容 2D 应用 UI 输入 | Apple 官方 UI automation 工作流；元素 tap/swipe/press 等声明包含 visionOS | 公共后端存在，未集成、未实测 | 独立 runner 的编译和专用兼容 App 验证 |
| visionOS 原生空间输入 / Crown | 部分 public API 声明存在；Crown 声明在 `TARGET_OS_VISION` 条件内 | 候选后端，执行范围尚未证明 | 先核实原生空间 App 的 runner 支持及输入语义，不沿用兼容 2D 验收 |
| visionOS gaze / 6DoF 视角 / 场景 / 光照 | Device Hub GUI 文档；未找到公开自动化 API | 本次仅找到 GUI 操作，未支持 | 单独后端研究；不能把 GUI 快捷键描述成无界面 API |

`menu` 表示遥控器菜单键输入，业务中的“返回”效果需要后置断言。矩阵中的公共 API 只证明可编程入口存在；未声明 Triton 命令、专用 runner 或真实验收已经完成。

## 证据来源与读取边界

先读取本批已保存的 Triton schema / capabilities，再检查其未覆盖项。私有事实位于 ignored `docs-linhay/references/device-hub-batches/`，其中 `schema.txt`、`capabilities.txt` 和各命令 schema 是 Triton-first 依据。通用 focus 或 SDK capability 字符串不能证明 watch / tv / vision 专门控制已经实现。

本轮允许的原生命令仅为帮助读取：`xcrun simctl help`、`xcrun simctl help io`、`xcrun simctl help ui`。本机帮助中未提供 Crown、Apple TV 遥控器或 gaze 注入命令；`io` 列出的显示枚举、视频、截图、screenConfig 等不等于输入注入，`ui` 的外观、对比度、内容大小也不等于空间视角控制。这是当前安装版本的证据，不是对未来 simctl 的永久断言。

本机 public header 核实位置：

```text
/Applications/Xcode.app/Contents/Developer/Platforms/WatchSimulator.platform/Developer/Library/Frameworks/XCUIAutomation.framework/Headers/
/Applications/Xcode.app/Contents/Developer/Platforms/AppleTVSimulator.platform/Developer/Library/Frameworks/XCUIAutomation.framework/Headers/
/Applications/Xcode.app/Contents/Developer/Platforms/XRSimulator.platform/Developer/Library/Frameworks/XCUIAutomation.framework/Headers/
```

核实文件包括 `XCUIDevice.h`、`XCUIDeviceButton.h`、`XCUIRemote.h`、`XCUIElement.h`、`XCUIElementAttributes.h`。本机 header 与 Apple 当前官方文档相互印证；声明可见性和真实执行支持分别记录。

### watchOS

`XCUIDevice.h` 将 Crown 旋转声明放在 `TARGET_OS_WATCH || TARGET_OS_VISION` 下。Swift 调用为：

```swift
XCUIDevice.shared.rotateDigitalCrown(delta: 0.25)
XCUIDevice.shared.rotateDigitalCrown(delta: -0.25, velocity: 1.0)
```

delta 以圈计，1.0 为一整圈；正负表示两个方向，与 Crown 配置在表壳哪侧无关。velocity 为每秒圈数，方向由 delta 决定。接入时必须限制数值为有限值，设置绝对值预算，并由 fixture 验证滚动方向及最终位置，不能把请求接受当成 UI 成功。

Apple 的 WWDC21 演示直接使用 watchOS UI tests 验证 Crown；因此它不是仅从类型名推断出来的能力。[Crown API](https://developer.apple.com/documentation/xcuiautomation/xcuidevice/rotatedigitalcrown(delta:))、[带速度 API](https://developer.apple.com/documentation/xcuiautomation/xcuidevice/rotatedigitalcrown(delta:velocity:))、[WWDC21：Digital Crown 自动化](https://developer.apple.com/videos/play/wwdc2021/10208/)。

可用性应按证据层记录：WWDC21 说明 watchOS UI testing 从 Xcode 12.5 开始，Crown 旋转在 Xcode 13 中提供；当前 XCUIAutomation 模块文档标示 Xcode 16.3+，不应误写成 Crown 功能直到 16.3 才出现。本机这两个 Crown 方法没有独立 OS 最低版本注解，只有 watchOS / visionOS 编译条件；visionOS 的条件可见性不等于原生空间 runner 已验收。未来 adapter 需通过实际 Xcode/SDK 编译与执行结果确定自己的最低支持版本。

本机按钮枚举包含 Home、Action 等，但没有 side。Action 文档说明其 watchOS 场景对应 Apple Watch Ultra，应先 `hasHardwareButton(.action)` 再 press；不能用它代替普通侧键，也不能将 Home 的名称直接解释为侧键。[XCUIDevice](https://developer.apple.com/documentation/xcuiautomation/xcuidevice)、[Action 按钮](https://developer.apple.com/documentation/xcuiautomation/xcuidevice/button/action)、[Home 按钮](https://developer.apple.com/documentation/xcuiautomation/xcuidevice/button/home)。

另有 `supportsHandGestures` / `perform(handGesture:)`，属于可以后续核实的 watchOS 专门手势，不等于本轮已经接入。[手势 API](https://developer.apple.com/documentation/xcuiautomation/xcuidevice/perform(handgesture:))。

### tvOS

`XCUIRemote.h` 的类在 `TARGET_OS_TV` 下公开，支持方向、select、menu，也有长按重载。最小控制集合可直接对应下列原生事件：

```swift
XCUIRemote.shared.press(.right)
XCUIRemote.shared.press(.select)
XCUIRemote.shared.press(.menu)
```

焦点应使用 `XCUIElement.hasFocus` 验证，而不是用截图坐标或普通 tap 模拟方向导航。方向、选择和菜单键可以形成可落地的第一组专门平台输入。[XCUIRemote](https://developer.apple.com/documentation/xcuiautomation/xcuiremote)、[按钮枚举](https://developer.apple.com/documentation/xcuiautomation/xcuiremote/button)、[hasFocus](https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/hasfocus)。

本机基础六键及 press 方法没有独立最低 tvOS 版本注解，类受 `TARGET_OS_TV` 限制；pageUp/pageDown 等额外键有另行版本要求，本批最小方案不借此扩展按钮范围。

### visionOS

Apple WWDC25 UI automation 演示明确将 visionOS 支持范围表述为 Designed for iPad。该证据可以支持兼容 2D App 的测试工作流，不能据此泛化为所有原生空间 App 和 immersive scene。[WWDC25：UI automation](https://developer.apple.com/videos/play/wwdc2025/344/)。

本机 header 和官方符号页包含 visionOS 的 `tap()`、swipe、长按拖动等元素 API；Crown 也有 visionOS 编译条件。这些属于应继续做编译与 runner 验证的公共入口，不应误标为不存在后端。[tap](https://developer.apple.com/documentation/xcuiautomation/xcuielement/tap())、[swipeUp](https://developer.apple.com/documentation/xcuiautomation/xcuielement/swipeup())、[长按拖动](https://developer.apple.com/documentation/xcuiautomation/xcuielement/press(forduration:thendragto:))。

`XCUIElement.pinch(withScale:velocity:)` 在本机 header 的条件为 iOS 或 watchOS，官方可用平台也不含 visionOS，不能用它冒充空间 pinch 输入。[pinch API](https://developer.apple.com/documentation/xcuiautomation/xcuielement/pinch(withscale:velocity:))。

Device Hub 的官方文档提供鼠标点击、按住拖动、深度移动、键盘移动视角、场景与光照菜单；这是 GUI 的输入映射。未查到这些视角和场景操作的公共 headless API。文档同时指出 Device Hub 对物理 Vision Pro 的交互限制，不能把模拟器的 GUI 能力宣传成真机远程控制。[visionOS Device Hub 交互](https://developer.apple.com/documentation/xcode/interacting-with-your-visionos-app-in-device-hub)。

### 私有 SimulatorKit 仅作候选

只读检查本机 SimulatorKit 动态库导出符号，发现 `IndigoHIDMessageForDigitalCrownEvent`、`IndigoHIDMessageForButton`、`IndigoHIDMessageForGameControllerEvent` 等。它们没有本轮可用的公共 header/稳定 ABI 契约，符号存在也没有证明 dispatch 路径、side-button 枚举或空间单位。不能据此宣布实现，也不应优先于上述公开 XCTest 路径。若以后采用，必须单列私有后端、Xcode 版本兼容范围、显式选择策略和实际输入验收。

## 现有 Xcode 工作流能复用什么

代码事实：

- `Sources/TritonKitCLI/CLIXcodeCommands.swift` 的 `XcodeTest` 接收 project/workspace、scheme、sdk、destination、result bundle、only-testing 和 timeout 等参数。
- `Sources/TritonKitCLI/CLIXcodeRuntime.swift` 的 `runXcodeTest` 已复用原生命令执行、进度、结果收集；`resolvedXcodeDestination` 允许显式 destination。
- 同文件的 `xcodeSimulatorDestination` 将 UUID 形式的 `--simulator` 合成为 `platform=iOS Simulator`；`--device` 也沿用 iOS 真机路径。因此非 iOS 不能直接复用这两个选择器。
- `Sources/TritonKitShared/TKXcodeWorkflowModels.swift` 的 `TKXcodebuildCommand.test` 使用 `test` action；当前未提供 `build-for-testing`、`test-without-building` 或 `.xctestrun` 入口。

可复用的是执行和结果收集基础设施，必须新增一个能够编译的 UI Testing Bundle / runner；普通 macOS CLI 不能脱离 UI-test 会话直接调用 XCUIDevice 并获得相同效果。当前 `xcode test` 可能利用 Xcode 增量构建，但没有预构建 runner 的零构建执行契约。[添加测试 target](https://developer.apple.com/documentation/xcode/adding-tests-to-your-xcode-project)、[运行测试与结果](https://developer.apple.com/documentation/xcode/running-tests-and-interpreting-results)。

业务 App 源码依赖与 runner 编译依赖应分别说明：Apple 的 `XCUIApplication(bundleIdentifier:)` 文档明确说明 iOS / tvOS 会寻找构建产物；没有匹配产物时可启动已有安装 App。因此 tvOS 可以研究独立 runner 操作已安装 App，不要求把 Triton runtime 链入业务 App；但仍需要编译和配置 runner。该段官方说明没有给出 watchOS / visionOS 相同保证，不能未经验证直接扩展承诺。[外部 App proxy](https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/init(bundleidentifier:))。

## 最小可执行集成方案与成本

建议先交付 tvOS remote 和 watchOS Crown 两组。最小工程量是一个仓库自有 Xcode harness project、两个 UI Testing Bundle target、两个确定行为的 fixture App，加上有界输入协议和结果适配；无需修改业务 App。watchOS target 是否需要 companion 配置，应通过当前 Xcode 的 runner 编译探针核实，不预先假定独立部署已经成立。visionOS 独立做支持范围探针，再决定是否新增第三个 target。

第一阶段直接走既有 `triton xcode test`，显式传平台 sdk 和 destination，避免 workspace 默认的 iOS sdk / selector 进入错误路径。下列仅展示拟建 harness 的调用形状，项目和 scheme 尚不存在：

```text
triton xcode test --project <owned-harness.xcodeproj> --scheme <tv-ui-tests> --sdk appletvsimulator --destination 'platform=tvOS Simulator,id=<owned-id>' --only-testing <target>/<class>/<method> --result-bundle <private-output> --jsonl
triton xcode test --project <owned-harness.xcodeproj> --scheme <watch-ui-tests> --sdk watchsimulator --destination 'platform=watchOS Simulator,id=<owned-id>' --only-testing <target>/<class>/<method> --result-bundle <private-output> --jsonl
```

静态 `only-testing` 方法足够证明后端，但不是任意 App 的通用控制接口。若升级成 `triton` action，另需定义 action enum、有限数值/时长、平台与目标身份绑定、执行前审计、runner 回执、超时/部分执行/uncertain，以及测试失败和业务验证失败的区别。动态输入不能使用任意 Swift/脚本作为协议。目标绑定失败必须在 runner 启动前拒绝。

后续降低单次执行成本可增加准备 runner 缓存及 `test-without-building` / `.xctestrun` 工作流。缓存键至少包括 Xcode/SDK/架构、runner 协议和构建内容摘要；预构建 runner 仍是必须交付的编译产物。不能以“无业务 App 改动”宣传为“无需项目或编译产物”。

## 验收前提和 BDD

已保存 `sim-after.json` 只包含 iOS family，共 16 个目标，其中 1 个 Booted、15 个 Shutdown；此前快照为 15 个 iOS 目标。该摘要不包含身份或名称。它只证明本批 inventory 未记录 watchOS、tvOS、visionOS 可用目标，不能据此声称相应 runtime 未安装。未为本研究创建、启动、安装或操作任何目标。

1. Given 专门平台 runner 与专用目标已明确授权，When 平台、SDK、destination 或目标身份不匹配，Then 在任何输入前失败，保留审计且不回退到任意 booted 目标。
2. Given watch fixture 的可滚动确定内容，When 输入有界正、负 Crown delta，Then 分别验证位置变化及反向变化；NaN、无穷、超预算值在 host 端拒绝。Action 硬件缺失返回 unsupported；侧键在没有后端时维持 unsupported。
3. Given tvOS fixture 的焦点格和二级页面，When 依次发送方向、select、menu，Then 通过 hasFocus 和页面标记验证导航、进入和返回；单纯进程 exit 0 不算交互成功。
4. Given visionOS Designed for iPad fixture，When runner 编译并发送已声明元素输入，Then 验证 2D 行为，并单列其支持范围。原生空间 fixture、Crown、视角和场景各自需要独立验收，不能共享上述通过结论。
5. Given runner 超时或中途退出，Then 不报告成功；保留动作是否已发送的不确定性及有界结果包。完成输入的 receipt 与后置断言分别记录。

本轮只做资料与代码静态核实，未运行测试。文档和全批回归门禁由主控统一执行。没有新增 CLI action、runner、设备动作授权或公开支持承诺。
