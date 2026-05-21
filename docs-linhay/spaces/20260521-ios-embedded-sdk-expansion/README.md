# 20260521 iOS Embedded SDK Expansion

## 背景

TritonKit 当前 iOS embedded runtime 已能在 DEBUG 包内提供基础 App 信息、UIKit hierarchy、AX 安全控件树、geometry、hit test、截图，以及 `tap/swipe/type/paste/clear` 等首批 App 内控制能力。真实项目回归继续推进时，AI agent 需要更多“能判断业务状态、能解释失败原因、能稳定执行语义动作”的采集内容和操作命令。

本 space 用于规划 iOS 内置 SDK 的下一阶段采集与控制边界。核心原则是继续坚持 DEBUG-only、App 内、机器可读、可审计；系统弹窗、Home/App Switcher、SpringBoard、host framebuffer、安装卸载、deep link 提交等设备级能力仍归 host-side adapter。

## 北极星目标

本方向的目标不是单纯增加 CLI 命令数量，也不是把 embedded SDK 做成通用监控 SDK，而是让 AI 通过 `triton` CLI 直接和 App 内 embedded SDK 沟通，显著抬高 AI 操控 App 的能力边界上限。

CLI 是 AI 的稳定控制入口，embedded SDK 是 App 进程内的感知与执行层。两者之间的契约必须让 AI 能完成五件事：

1. **观察**：获取当前 App 内真实状态，而不是只看截图或猜测 UI。
2. **解释**：知道为什么某个元素可点、不可点、被遮挡、重复、disabled 或需要滚动。
3. **执行**：优先使用语义动作和公开 UIKit API，减少脆弱坐标操作。
4. **验证**：用机器可读状态、断言、snapshot 和 evidence 判断业务是否完成。
5. **复盘**：通过 ledger、source command、耗时、错误码和 redaction 状态定位失败原因。

因此后续所有能力优先级都按“是否提升 AI 通过 CLI 操控 App 的闭环能力”排序，而不是按 SDK 能否采集更多数据排序。

## 目标

1. 建立 AI-facing 的 App 内能力契约，使 `triton schema/capabilities/manifest` 能清楚告诉 AI 当前 SDK 能观察什么、能操作什么、为什么不能做某件事。
2. 扩展 iOS embedded runtime 的采集面，使 agent 能一次性读取 runtime manifest、App/scene/window 状态、导航/页面状态、UI 语义树、控件属性、first responder、截图元数据、runtime request/action ledger。
3. 扩展操作命令，使 agent 优先使用语义动作而不是脆弱坐标，包括 `focus`、`set-text`、`submit`、`select-segment`、`set-switch`、`set-slider`、`stepper`、`scroll-to-visible`、`scroll`、`wait-idle`。
4. 建立红线：embedded SDK 不采集生产 Release、不采集系统级 UI、不默认读取敏感持久化数据、不自动 hook 全量网络或日志。
5. 所有新能力先落到共享 DTO、CLI schema、HTTP request/response、测试和 evidence/capture，再考虑更高层封装。
6. 让真实项目回归可以通过 `triton snapshot`、`triton state`、`triton attrs`、`triton action` 类命令收集完整问题证据。

## 非目标

1. 不恢复 Web/Wails UI。
2. 不把 iOS embedded runtime 扩成真机设备控制、远端 agent、设备云或系统级 AX。
3. 不在首期做无差别 method swizzling、URLProtocol 全局注入、Keychain dump、文件系统 dump、剪贴板 dump。
4. 不承诺处理 SpringBoard/CoreSimulatorBridge 系统弹窗；embedded runtime 遇到系统遮挡应返回稳定 `runtime_ui_interrupted`。
5. 不让业务 App Release target 因 TritonKit 产生采集、上传或控制行为。

## 当前基线

已具备的 iOS embedded runtime 能力：

- 连接与基础信息：`ping`、`appInfo`、`status/list/inspect`。
- UI 结构：`hierarchy`、`nodes`、`node`、`ax`、`ax --with-hierarchy`、`hit`。
- 属性与对象：`attrs`、`object`，当前主要覆盖 class/layout/layer、UILabel、UIImageView、UIScrollView。
- 画面与几何：`geometry`、`screenshot`、`export archive`、`capture/evidence`。
- 输入：`tap`、`swipe`、`type`、`paste`、`clear`、`input` JSONL；`press` 在 embedded runtime 明确 unsupported。
- 回归：`find`、`wait`、`assert`、`record/plan inspect/replay`。

## 当前落地状态

截至 2026-05-21，本 space 已完成首批 S0-S4 agent-facing 闭环：

1. 能力发现：`triton runtime manifest --json` 输出 embedded runtime、capabilities、limits 与 redaction；manifest capability 名称、scope 和 boundary 在共享模型层使用枚举约束，wire JSON 继续保持稳定字符串。
2. 状态读取：`triton state app|scene|route|responder --json` 已输出 App、scene/window、route/controller、first responder/text traits。
3. 快照聚合：`triton snapshot --include app,scene,route,ax,geometry --json` 已返回 include、artifacts、skipped 与 truncation。
4. 语义动作：`focus`、`set-text`、`select-segment`、`set-switch` 已接入 CLI schema、selector 消歧和 embedded `semanticAction`。
5. 复盘：`triton ledger --limit 50 --jsonl` 已输出 runtime request/action/error ring buffer，并保留 secure input redaction 状态。

## 能力分层

### P0：可立即规划实现的 App 内公开 API 能力

P0 只使用 UIKit、Foundation、ProcessInfo、Bundle、UIAccessibility 这类公开 API，且全部可在单元测试或 iOS harness 中验证。

采集内容：

1. Runtime manifest：platform、transport、SDK version、build config、enabled、capabilities、redaction policy、payload limits。
2. App state：bundle id、display name、version/build、locale、preferred languages、interface style、dynamic type、process uptime、memory footprint 摘要。
3. Scene/window state：connected scenes、activation state、key window、safe area、orientation、screen scale、window level、visible window count。
4. Route/navigation state：top view controller、presented stack、navigation stack class/title、tab selected index/title、split view 状态；SwiftUI 只输出 hosting controller 和可见 UIKit 包装信息，不反射私有 SwiftUI tree。
5. Responder state：first responder class、oid、frame、text input traits 摘要、是否 secure、是否 editable。
6. Control attributes v2：Accessibility、Responder、UIControl、TextInput、SegmentedControl、Switch、Slider、Stepper、ScrollView、Table/Collection visible cell 摘要。
7. Unified snapshot：一次请求返回 app/scene/route/geometry/ax/hierarchy/screenshot metadata 的一致时间点摘要，并记录各 artifact freshness。
8. Runtime ledger：最近 N 条 Triton request、input action、error、unsupported reason、耗时和 source command；默认不包含业务日志正文。

操作命令：

1. `focus <selector>`：聚焦文本输入控件，不写入内容。
2. `set-text <selector> <text>`：清空并写入确定文本，支持 `--secure` 只回显长度。
3. `submit <selector>`：触发 `UITextField` return、search 或 primary action；无法确定时返回 unsupported。
4. `select-segment <selector> <title|index>`：按标题或 index 设置 `UISegmentedControl`。
5. `set-switch <selector> on|off|toggle`：设置 `UISwitch`，并触发 valueChanged。
6. `set-slider <selector> <value|ratio>`：按绝对值或 0...1 ratio 设置 `UISlider`。
7. `stepper <selector> increment|decrement|<value>`：控制 `UIStepper`。
8. `scroll <selector|region> --direction <up|down|left|right> --amount <points|page>`：稳定调整 `UIScrollView.contentOffset`。
9. `scroll-to-visible <selector>`：在当前可见 scroll 容器内尽力滚动到目标文本/identifier。
10. `wait-idle`：等待主线程下一轮 runloop、layout pass 和短暂动画窗口，不等价于业务完成。

### P1：需要较多 harness 验证的增强能力

1. Table/Collection 语义：visible index paths、section/item count、cell text summary、可滚动方向、目标 cell 定位解释。
2. Picker/DatePicker：选择 wheel/date，不使用私有子视图。
3. Alert/App 内弹窗：仅处理当前 App 内 `UIAlertController`，系统权限弹窗仍 unsupported。
4. Animation/transition state：短窗口内检测是否仍有 UIKit animation 或 view hierarchy 快照持续变化。
5. View lifecycle breadcrumbs：SDK 记录最近可见 controller 变化，不 hook 私有 API。
6. App-defined debug state：业务 App 可注册只读 provider，输出已脱敏的登录态、feature flag、mock 环境等。

### P2：必须 opt-in 的高风险或业务耦合能力

1. UserDefaults allowlist 读取：只读取业务显式 allowlist key，默认不 dump。
2. Network breadcrumbs：业务显式接入 URLSession wrapper 或 interceptor 后，记录 request summary、status、duration、redacted host/path；不默认全局 swizzle。
3. App logs：业务通过 `TritonKit.log(...)` 或 provider 上报结构化日志；不默认采集 OSLog 全量。
4. Crash/error breadcrumbs：记录 SDK 可见错误和业务显式上报 error；不接管 crash handler 作为首期能力。
5. File artifacts：业务显式导出某个 debug artifact；不扫描 sandbox。

## 建议 CLI 契约

优先保持现有顶层命令的简单性；新增命令必须进入 `triton schema --json`，并在 `capabilities` 中按 runtime scope 暴露。

采集命令建议：

```bash
triton runtime manifest --target triton:local --json
triton snapshot --target triton:local --include app,scene,route,ax,geometry,screenshot-metadata --json
triton state app --target triton:local --json
triton state scene --target triton:local --json
triton state route --target triton:local --json
triton state responder --target triton:local --json
triton attrs --target triton:local --oid <oid> --groups accessibility,responder,control,text,scroll --json
triton ledger --target triton:local --limit 100 --jsonl
```

操作命令建议：

```bash
triton focus "用户名" --json
triton set-text "用户名" "alice" --json
triton set-text "密码" "$PASSWORD" --secure --json
triton submit "搜索" --json
triton select-segment "协议" "HTTP" --json
triton set-switch "记住我" on --json
triton set-slider "音量" 0.75 --ratio --json
triton stepper "数量" increment --json
triton scroll "列表" --direction down --amount page --json
triton scroll-to-visible "退出登录" --json
triton wait-idle --timeout 2 --json
```

命名取舍：

1. `runtime manifest` 用于 SDK/能力发现，不和 host-side `device/app` 混淆。
2. `snapshot` 是一站式 App 内快照，不替代 `capture/evidence`；`capture` 仍负责写文件包。
3. `state <kind>` 聚焦 App 内状态，不读取 host-side simulator plist。
4. 语义操作命令最终仍可复用底层 `input` request，但 CLI 对 agent 暴露更稳定的 selector 与意图解释。

## BDD 验收场景

### 场景 1：agent 能发现 iOS embedded SDK 能力

- Given `triton serve` 已启动且 DEBUG iOS App 已连接
- When 执行 `triton runtime manifest --json`
- Then 输出 `platform=ios`、`transport=embedded-websocket`、`enabled=true`
- And 输出 SDK version、capabilities、payload limits 与 redaction policy
- And Release build 下 manifest 必须为 `enabled=false` 且 capabilities 为空或 no-op

### 场景 2：agent 能一次性采集 App 内快照

- Given 当前页面包含导航栏、输入框、分段控件、开关、列表和截图
- When 执行 `triton snapshot --include app,scene,route,ax,geometry,screenshot-metadata --json`
- Then 返回 app、scene、route、geometry、ax/hierarchy 摘要和 screenshot metadata
- And 每个 artifact 带 `capturedAt` 与 freshness
- And secure text 只返回 redacted/length，不返回原文

### 场景 3：agent 能解释当前页面位置

- Given App 位于嵌套 UINavigationController、UITabBarController 或 presented controller 下
- When 执行 `triton state route --json`
- Then 输出 top controller、presented stack、navigation titles、selected tab 和可见 controller class
- And 不依赖 SwiftUI 私有类型反射作为业务语义来源

### 场景 4：agent 能读取可操作控件属性

- Given AX 树中存在 `UITextField`、`UISegmentedControl`、`UISwitch`、`UISlider`、`UIStepper` 与 `UIScrollView`
- When 对对应 oid 执行 `triton attrs --groups accessibility,responder,control,text,scroll --json`
- Then 输出 label/value/identifier、enabled/selected/focused、first responder、text traits、segment titles/selected index、switch on、slider min/max/value、scroll content size/offset

### 场景 5：agent 使用语义命令完成表单操作

- Given 登录表单包含用户名、密码、协议选择和提交按钮
- When 执行 `focus`、`set-text --secure`、`select-segment`、`submit`
- Then 每条命令返回 ok、targetOID、targetClassName、strategy、elapsedMs 与 redaction 状态
- And 后续 `wait/assert/snapshot` 能验证页面进入预期状态

### 场景 6：embedded runtime 遇到系统级能力时明确拒绝

- Given 当前命令请求 `press home`、系统权限弹窗点击或跨 App 内容读取
- When 通过 embedded runtime 执行
- Then 返回 `ok=false`、`error.code=unsupported_runtime_scope`
- And hint 指向 host-side adapter 或人工处理路径

### 场景 7：ledger 能帮助复盘失败

- Given 一轮自动化执行了 snapshot、tap、set-text、assert 并发生失败
- When 执行 `triton ledger --limit 100 --jsonl`
- Then 输出最近请求、动作、错误、耗时、target 和 source command
- And secure input 不包含明文

## 测试门禁

1. Shared DTO：新增模型必须有 encode/decode、默认值、Release disabled/no-op、redaction 测试。
2. CLI schema：每个新增命令必须出现在 `schema --json`，覆盖参数、runtime scope、成功/失败 shape、示例和退出码语义。
3. HTTP/request：新增 request type 用 `httptest` 或 CLI mock 覆盖 route、JSON body、错误 envelope。
4. iOS runtime：用 Demo/ComplexHarness 覆盖 UIKit 控件属性与语义动作；不能在 macOS-only SwiftPM 环境强行编译 UIKit 测试。
5. Evidence/capture：`snapshot` 或新 artifact 进入 evidence 时必须写 manifest、freshness、redactionStatus 和 skipped reason。
6. Regression script：新增或扩展 `docs-linhay/scripts/verify-complex-harness.sh`，至少覆盖一条完整表单语义操作流。

## 分期计划

1. P0a 契约先行：新增 manifest、snapshot、state、attrs v2、semantic input DTO 和 schema 测试。
2. P0b Runtime 采集：实现 App/scene/route/responder/control attrs 与 runtime ledger。
3. P0c CLI 语义命令：实现 `focus/set-text/submit/select-segment/set-switch/set-slider/stepper/scroll/scroll-to-visible/wait-idle`。
4. P0d Evidence 集成：`capture/evidence` 可包含 snapshot、state、ledger artifact。
5. P1 真实项目验证：用 Overloaded 或新的业务 App smoke 验证导航、表单、列表和 App 内弹窗。
6. P2 Opt-in provider：再讨论 debug state、network breadcrumbs、UserDefaults allowlist 和 app logs。

## 风险与约束

1. UIKit 公开 API 覆盖不了所有 SwiftUI 语义；首期只承诺 hosting controller 与可见 UIKit/AX 线索。
2. 语义 selector 可能命中重复文本；所有命令必须支持 `--all`、`--index`、`--within`、`--at` 或返回 ambiguity。
3. `wait-idle` 只能证明短期 UI idle，不证明业务请求完成；业务完成仍用 `wait/assert/state/provider`。
4. P2 采集能力必须 opt-in 和 allowlist，否则容易越过 DEBUG 边界和隐私边界。
5. 新命令数量增加会抬高维护成本；实现时应尽量复用现有 `find`、`input`、`wait`、`assert` 和 error envelope。

## 参考链接

- [AI CLI Readable Control](../../dev/ai-cli-readable-control.md)
- [iOS integration guide](../../dev/20260519-ios-integration-guide.md)
- [Hybrid Transport Smoke](../20260516-hybrid-transport-smoke/README.md)
