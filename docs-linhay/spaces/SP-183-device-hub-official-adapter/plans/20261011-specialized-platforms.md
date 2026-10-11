# 专门平台控制与跨平台兼容验收

本文件对应 SP-183 的第三、四批：专门平台控制、兼容矩阵收口。它把“有公开 API”“已接入 Triton”“专用目标实测”分开记录，避免将 SDK capability、GUI 操作或 XCTest API 误称为已实现能力。

## 状态分层

- **已实现**：CLI、host adapter、shared DTO 和 schema 已有可执行路径，并有隔离测试。
- **真实验收**：在允许的专用 Simulator 或已授权目标上执行过路径，并保存脱敏证据。
- **fixture**：仅用私有 fixture 验证解析、失败码、身份绑定、边界和安全预算。
- **计划**：已确认后端方向和契约，但尚未形成 Triton 可执行入口。
- **GUI-only / 未支持**：只能依赖人工 GUI 或缺乏可验证、稳定的编程后端；不得映射成 CLI 成功。

## watchOS

### 配对关系

- 状态：**已实现 + 真实验收（受限）**。
- 入口：`sim pairs` 保留既有关系查询；空集合成功和非空关系解析由 fixture 覆盖。
- 真实边界：空集合在专用环境已验证；没有把物理 Apple Watch 的配对、连接、安装或输入验收写成真实通过。

### Crown、Action 和侧键

- 状态：**runner 请求/附件/审计修复，双平台测试产物构建通过；真实输入受 runtime 下载失败阻塞**。
- 可编程方向：watch UI-test 可使用 `XCUIDevice.shared.rotateDigitalCrown(delta:)` 及 velocity 变体；Action button 可通过 `hasHardwareButton(.action)` 和 `press(.action)` 建模。
- 侧键：公开 XCTest 没有可稳定表达普通侧键的精确枚举；不得用 Action button 或 GUI 菜单替代。
- 接入前 BDD：
  1. Given 一个明确 watch UI-test target、设备身份和 hardware capability，When 发送 Crown/Action 事件，Then 只向该 target 发一次事件并返回结构化 receipt。
  2. Given 目标没有对应硬件，When 请求 Action，Then 返回 `unsupported` 或 `hardware_unavailable`，不伪造成功。
  3. Given UI 状态变化，Then 必须有元素状态或焦点后置断言；事件发送成功不能单独证明业务结果。
- 真实验收前置：独立 watch runner、事件 schema、超时/部分完成状态、专用 Simulator 或授权设备证据。

## tvOS

### 焦点导航、选择和返回

- 状态：**runner 请求/附件/审计修复，双平台测试产物构建通过；真实输入受 runtime 下载失败阻塞**。
- 可编程方向：`XCUIRemote.shared.press(.up/.down/.left/.right/.select/.menu)`；焦点后置断言使用 `XCUIElement.hasFocus`。
- `menu` 的返回语义必须由目标 UI 后置状态确认，不能只依据按键调用无异常。
- 接入前 BDD：
  1. Given tvOS UI-test target 和目标身份，When 发送方向键，Then receipt 绑定完整 argv、target 和事件序号。
  2. Given 选择或返回事件，Then 断言焦点、页面或导航栈变化；无法观察时返回 `unverified`。
  3. Given runner 不可用或目标类型错误，Then 返回 `unsupported`，不得回退到 GUI-only 伪成功。
- 真实验收前置：独立 tvOS runner、焦点 fixture、选择/返回后置断言和专用目标证据。

## Runner 执行门禁（本批新增）

- `device platform-control` 可在显式 `--execute-runner --confirm`、精确 Simulator UDID、`.xctestrun`、结果包和审计记录齐全时构建一次 `test-without-building` 调用。
- 执行前校验 Simulator runtime family；结果必须绑定 target/action/nonce/后置断言。普通 exit 0、缺少结果、超时和目标替换均保持 unknown/失败，不自动重试。
- 当前本机只有 watchOS/tvOS SDK，没有可用对应 Simulator runtime，仓库也没有专用 `.xctestrun`；本批仍无真实输入证据。详见 [runner 执行切片](./20261011-specialized-runner-execution.md)。

## visionOS

### 2D 兼容方向

- 状态：**计划**。Designed for iPad 的 2D UI automation 和普通元素查询可以作为独立 runner 方向。
- 这只覆盖 2D 元素，不代表 visionOS 空间控制已经实现。

### 原生空间、视角、场景、gaze、6DoF

- 状态：**未支持**。
- 当前没有稳定、可验证的 headless Triton 后端契约；不得用 GUI 菜单、模拟点击、SDK capability 名称或 pinch 事件冒充空间控制。
- 不支持项必须返回结构化 `unsupported`，并说明缺失的是编程后端还是目标能力。

## macOS 与非 iOS physical

- macOS Xcode build/test/run 继续走既有 Xcode workflow；Device Hub 观察/控制不因 Xcode workflow 存在而宣称支持。
- 非 iOS Apple physical 的发现、选择和硬件字段只接受 SDK 明确返回的 identity、platform 和 hardware metadata。未知字段保持 `unknown`；不得由目录名、App 名称或设备名称推断。
- watch/tv/vision/mac 的 fixture 只能证明 parser、选择器和失败契约，不能证明物理硬件可用。

## 兼容与回归

- 新旧 SDK 的数据布局通过 fixture 覆盖；未知字段保持向后兼容，缺失必需身份字段则拒绝。
- 旧 Xcode 命令、旧 namespace、旧参数顺序保留；新增参数必须是显式 opt-in，不改变旧调用的副作用语义。
- schema、public skill command snapshot、CLI parser、HTTP/DTO（如适用）必须来自同一事实源，不能通过放宽 fixture 解决漂移。
- 未安装 SDK26 或旧 Xcode 的环境只能记录 fixture 兼容，不得写成旧版本真实验收。

## 安全与执行边界

- 不读取业务文件内容；容器、Crash、DeviceFS 和诊断包按不同域建模。
- 可能隐式挂载的 DeviceFS 查询必须显式允许 mount、确认、执行 runner 和 audit record；结果中的 `mountCreated` 保持 `unknown`。
- pair/unpair/diagnose/Temporary 的执行必须先有持久 intent，再执行一次 native invocation；成功、失败、超时、部分完成和不确定状态分别建模。
- 审计目录和诊断归档使用私有权限、原始 FD/device+inode 校验、nofollow 和有界复制；目录替换后不可向替代路径报告成功。
- 诊断 ZIP 的大小上限是本地接纳和发布预算，不等于采集阶段磁盘峰值；不覆盖既有文件、不跟随符号链接、不解压业务内容。
- 不执行真机配对、诊断采集、临时域真实创建或未授权挂载验收。

2026-10-11 真实验收启动发现旧门禁未向 XCTest 传参、误解析 stdout、无持久审计；已进入修复回归。tvOS/watchOS 独立测试工程均实际 build-for-testing 通过，但 runtime 官方下载报 MobileAsset 网络错误 47，因此尚无输入送达或后置状态成功证据。Action 按钮的可验证后置断言仍未实现，不发送事件。
