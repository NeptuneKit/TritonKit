# Device Hub：从设备窗口到可验证开发对象

> 研究日期：2026-10-08；TritonKit 源码基线 `0231d883`。这是产品/架构研究，不是实施批准，也不是新能力的发布声明。来源编号见 [来源台账](./20261008-device-hub-sources.md)，阶段验收见 [验证路线](../spaces/SP-181-device-hub-paradigm/plans/20261008-validation-roadmap.md)。

## 1. 裁决摘要

**机会成立，但不能建立在“Apple 缺少 agent 工具”或“做一个更好看的模拟器壳”上。**

Device Hub 的可借鉴范式是：让真机与模拟器成为同一种可观察、可操控、可配置、可诊断的开发对象。设备屏幕是其中一种投影，不再是对象本身。TritonKit 应把这个范式推进为 **agent-native、跨平台、可复现、可验证的开发会话**。

推荐定位：**“移动应用开发的可验证执行层”**，而不是“开源 Device Hub”“另一套投屏软件”或“Apple 尚未提供的 MCP”。CLI/HTTP 仍是契约；桌面/Web 是只读证据投影；embedded runtime 是可选但有高语义价值的观察/控制源。

值得争取的最小闭环：

```text
明确目标 → 记录环境 → 绑定构建/App/runtime → 观察
      → 选择有证据的控制策略 → 执行 → 独立验证后置条件
      → 产出可复跑 plan + 可审计 evidence + 已知限制
```

“提交了输入”与“任务完成”必须分别表示；“设备能启动”与“App 可操作”也必须分别表示。SP-180 已经出现加载器恢复而 host 导航未验收的实际情况，这不是抽象架构偏好，而是当前痛点。

## 2. 证据规则与调研范围

- **O（官方事实）**：Apple 文档/release notes 的明确承诺，仅覆盖文档范围与版本。
- **S（源码事实）**：在固定 revision 读到的实现。证明代码存在，不证明我们设备上可运行、性能或业务正确。
- **P（项目声明）**：README/架构/安全文档的支持与测试声明，不代替本轮实测。
- **H（假设/建议）**：产品判断，必须由后续实验验证。
- **U（未知）**：没有足够证据，不向下补全为“支持”。

本轮只有 HTTP/源码只读研究和文档验证，没有配对、输入、构建、安装、服务启停或 Xcode 设置写入。两个只读 subagent 提供了中间线索，但均未正常返回最终报告；以下关键结论由主控直接复核官方与源码，未复核线索不升级为结论。Web search 401、bb-browser 未连接，匿名 GitHub API 部分限流；最终采用 Apple DocC JSON、GitHub HTML revision/目录与固定 raw 源码。没有借用户凭据绕过限制。

## 3. Apple 实际推进了什么

### 3.1 从平台专用窗口到统一设备工作台（O：A01–A04）

Device Hub 同时管理真机与模拟器，把设备侧栏、屏幕 canvas 与 inspector 放到一个独立 App。紧凑模式服务交互，展开模式服务管理/配置/诊断。运行 App、查看屏幕、配置环境、收集文件不再需要用户把多个不相干工具拼起来。

这里真正变化的是 **任务连续性和身份连续性**，不是增加一个设备列表。设备是 run destination；屏幕、App、环境与文件围绕同一对象展开。WWDC 的交互演示足以证明产品方向，但不能证明每一项 UI 能力都有稳定 CLI。

### 3.2 统一的不仅是展示，还有部分管理 API（O：A05）

Xcode 27 官方文档明确 `devicectl` 管理物理与已启动的模拟设备，例子包含枚举、信息、安装/启动 App、文件复制与挂载点获取。`--json-output` 格式版本化并向后兼容；终端文本不应被自动化解析。模拟器启动仍用 `simctl`。

这支持“公共管理优先、私有交互隔离”的实现路线，不支持“大迁移，一次性删掉 simctl”。新 devicectl 的设备标识、过滤、文件 domain 与旧解析器仍需 fixture 与真实矩阵验证。

Release notes 还明确 JSON v5 的 device details 已弃用 `hardwareProperties/deviceProperties/connectionProperties`，改用 `properties`，并新增 `_deprecationNotice`；`--json-output` 支持 stdout。当前 [device list parser](../../Sources/TritonKitShared/TKHostAdapterDevicectlModels.swift#L262-L339) 仍读取旧字段，字段缺失时可能令 blockedReasons 为空、ready 为真。这是需要 new-only/混合/未知字段 fixture 的**高优先风险**；官方这条弃用针对 details，不能据此断言本机 list 格式已移除旧字段或实际存在错误。未知 readiness 不应默认为已验证可操作。

### 3.3 DeviceFS：文件也进入设备对象（O：A05；细节按实际 domain）

文件系统访问与诊断不再只依赖到处散落的拷贝命令。重要边界是：挂载/可访问的共享内容与权限受设备服务和 domain 约束；不是越权读取任意设备根文件系统，也不等于完整 VM 快照。

对 TritonKit 的价值不是提供 Finder 替身，而是把目标 App 的文件/配置/日志变成 **受限且可脱敏的 evidence 输入**。只读取指定文件，不把整个挂载目录吞进证据包；可恢复的 App seed data 与只读 diagnostic 要分开。

### 3.4 Apple 同时进入 agent 闭环（O：A06）

Xcode 27 release notes 明确：agent 可以 boot simulator、install/launch App、synthesize touch、capture screenshot；新增 MCP 工具覆盖 debugger、scheme/run destination/build settings；预览快照支持外观/方向/字号；Beta 5 引入无需打开 workspace 的 MCP server 预览；还支持 ACP 和 agent plugins。

**因此以下推论不成立：**

- “Device Hub 只有 GUI，所以所有自动化都是我们的独占机会”；
- “Apple 的 agent 永远依赖打开 IDE/workspace”；
- “有合成触摸功能，等于 devicectl 已公开 touch 子命令”；
- “Xcode MCP 能力面，等于任意终端 agent 已拥有同样授权和服务发现能力”。

官方 agent 的实际覆盖、授权、tool schema、跨进程行为与外部客户端使用限制仍需单独 PoC。不直接加入现有产品依赖，也不把五月“不依赖 IDE bridge”的历史判断当作十月不需要再调研的理由。

### 3.5 必须保留的限制（O：A04/A06）

- Xcode 27 要求 Apple silicon；macOS Tahoe 26.6+。这不自动取消 TritonKit 现有双架构发布：旧 Xcode/其它 adapter 的 Intel 使用是独立产品矩阵。
- Device Hub 27 不支持物理 Apple Vision Pro 的屏幕观看/输入；支持管理设置与 DeviceFS 不等于支持远控。
- 较旧模拟器的输入支持下限、设备 debugging 下限、首次无线配对下限是不同条件，不能统一成“iOS 17+ 全能力”。
- 配置/Resize 支持与 App 链接 SDK 有关；旧 SDK App 不能自动获得所有新测试能力。
- 官方 UI 的鼠标/触控板交互不等于任意多触点重放；pinch/rotate 与 two-finger touch 不能混同。
- 截图文档覆盖真机与模拟器；录屏文章只文档化模拟器。不能从视频流存在推断所有真机有公开录屏 API。

## 4. 开源社区显示了两条不同路线

### 4.1 OpenDeviceHub：展示宿主可以与设备运行层分离（S/P：G01–G05）

固定 revision：`e50f07f1f4480cb14d57f192df7bf598ca26e708`。

直接读到：

1. `SimctlService` 使用公共 `xcrun simctl` 枚举/boot/shutdown/bootstatus，主动不使用私有 `bootWithOptions:`。展示项目也没有理由重写稳定管理层。
2. `AdapterFactory` 以 CoreSimulator adapter 统一 Xcode 26/27；更新 major 可以带 advisory 运行。TritonKit 的私有输入路径不应照搬这种默认宽松信任，应逐能力探测并保留 unverified 状态。
3. `PanelInputSession` 使用私有 XPC endpoint 和 `IndigoDigitizerEvent`，通过 `target` 选择屏幕；触摸、键盘、按钮分开。这证明多屏输入是 **screen identity** 问题，不只是宽高换算。
4. `CoordinateMapper` 独立处理 aspect-fit 空白区、AppKit 原点与方向逆变换；letterbox 点击被拒绝。这类纯几何模型比把逻辑分散在 Web 缩放层更值得吸收。
5. `TapCommand` 发送 began/ended 后打印 tapped，没有业务后置条件。它是可脚本化控制原语，不是完整 agent 执行结果。

README 声明定位为本地模拟器；私有框架和 arm64e 要求不应被解释成通用真机远控支持。其 MIT 代码许可也不授予 Apple 私有 API 支持承诺或 Apple 资源再分发权。

**吸收：** adapter 边界、几何转换、多屏 identity、公共管理优先。**不吸收：** 为了替代 Apple 窗口投入完整 AppKit 窗口/皮肤/菜单产品；把 input send 成功当任务成功；未验证 major 默认可执行。

### 4.2 device-hub-ios：重要资产不是 HEVC，而是会话正确性（S/P：G06–G11）

固定 revision：`1fcdfb0a6799b62f05625d0cbb359bec57256b94`。该项目明确为非官方 iOS/iPadOS 27 移植，基于 pinned/patched Rust `idevice` 与私有接口，不是 Apple Device Hub 源码。

协议文档描述链路：

```text
Bonjour 发现/认证 → pair verify → TLS-PSK CoreDevice tunnel
 → RSD → Developer Mode/DDI/service readiness
 → 初始截图 → HEVC video → UniversalHID / Indigo
```

直接源码核查：

- `DeviceSessionCoordinator` 的 command/close/replace 校验 attempt 与 session ID；旧 attempt 不能关闭新 session；授权撤回后 releaseAllInput，再 disconnect。
- `RemoteSessionMedia` 拒绝不同 attempt/session 的帧，并通过 generation 的 SessionUpdate 更新屏幕状态。
- `RemoteSessionInput` 校验命令序列、映射 viewport/targetPixels/orientation、串行发送 pendingCommands；命令失败撤回输入。
- Rust `session.rs` 有 generation、control gate、callback dispatcher 与媒体 emitter；`protocol.rs` 使用 UniversalHID、Indigo 及服务检查。源码与安全文档方向相符，但本轮没有执行其测试或协议实测。
- 安全文档明确不调用 `stopAll=true` 夺取其他主机媒体会话；输入写成功不视为目标落地证明；配对身份安全持久化、认证失败 fail-closed。这些属于 P，后续引入时应对相关 Rust 实现与测试进一步逐项审计。

**最值得吸收的范式：输入只对正确会话、正确 generation、正确屏幕几何和新鲜观察有效；退出只清理本次会话拥有的状态。**

不应现在照搬的成本：Rust FFI 发布链、配对秘密/DDI管理、HEVC/RTP纠错、真机多主机媒体竞争、私有协议 seed 变化。仓库已有原生 Swift CLI 和 Debug embedded 路径；为了演示“无需接入远控”马上把这套栈变成默认依赖，会放大维护成本而不是建立差异化。

## 5. 与 TritonKit 当前真实资产对齐

| 能力 | 已有源码/证据 | 当前边界 | 建议 |
| --- | --- | --- | --- |
| 统一 CLI/HTTP 契约 | shared command/output models；CLI schema | 不等于所有平台语义等价 | 延续共同契约，返回逐项能力/来源/限制 |
| 设备发现与平台 adapter | [CLIHostDeviceRuntime](../../Sources/TritonKitCLI/CLIHostDeviceRuntime.swift#L27-L130) | iOS simctl / devicectl real 两条发现；scope=all 直接拼接，错误时退回simulator | Xcode27 unified devicectl fixture先行；显式kind/标识映射/去重，不猜对象类型 |
| 语义观察 | [CLIObservationModels](../../Sources/TritonKitCLI/CLIObservationModels.swift#L19-L33)、[TKObservationModels](../../Sources/TritonKitShared/TKObservationModels.swift#L38-L83) | node来源、confidence、candidateOnly已存在；跨源帧/geometry一致性未由此证明 | 保留 embedded 高语义路径；补观察关联/失效契约，不只截图+VLM |
| Host HID | [CLISimulatorInputCommands](../../Sources/TritonKitCLI/CLISimulatorInputCommands.swift#L18-L61) | sim tap走host helper；type仍typed unsupported；不是全输入覆盖 | 策略选择与执行receipt统一；输入ACK与verify分账 |
| Xcode27兼容 | [框架子进程适配](../../Sources/TritonKitCLI/CLIBaguetteFrameworkEnvironment.swift#L3-L40)、[SP-180](../spaces/SP-180-xcode27-simulator-frameworks/README.md#L24-L30) | 修复仅选中baguette子进程；host navigation未封口 | P0先解决真实几何/后置条件，不称已全面兼容 |
| 流式画面 | [CLIHostSimulatorFramebufferService](../../Sources/TritonKitCLI/CLIHostSimulatorFramebufferService.swift#L21-L75) | 硬编码默认Xcode和旧SimulatorKit路径；不受baguette子进程修复自动覆盖 | shared resolver、per-capability probes；不要把本机偶然能加载当支持矩阵 |
| evidence | [CLIEvidenceCaptureRuntime](../../Sources/TritonKitCLI/CLIEvidenceCaptureRuntime.swift#L350-L524) | 已区分host full-screen与runtime app-layer，失效有partial/error；不是确定性回放保证 | 放大这项优势：输入前后、环境、来源、目标与verification成一条trace |
| target lease | [CLITargetLeaseGate](../../Sources/TritonKitCLI/CLITargetLeaseGate.swift#L4-L24) | opt-in；不传lease不检查；只读免门禁；不是设备排他锁 | lease（并发授权）与generation（连接正确性）必须分开；外部Device Hub操作不受现有lease控制 |
| Web/桌面 | [CLIWebDeviceRuntime](../../Sources/TritonKitCLI/CLIWebDeviceRuntime.swift#L133-L175) | DTO拼接runtime/host；真机过滤；是展示契约，不是统一session事实源 | 只读观察/evidence timeline先行，不开第二套业务写控制面 |
| App/构建/结果/plan | [既有Xcode设计](../spaces/20260520-xcode-workflow-takeover/technical-design.md#L5-L55)与现有命令 | 历史设计target graph不是已验证完整session编排 | 从现有plan/evidence服务做最小纵切，不另建大型调度中台 |

本轮全量 `Sources/**/*.swift` 文字检索未发现 Apple `DeviceHub.app`/`devices://`/旧 `Simulator.app` 启动硬编码；匹配的 Device Hub 名称主要是我们自己的 Web UI。**因此社区“替换 open Simulator”是风险清单，不是已确认的 TritonKit 启动 bug。** 当前更有证据的缺口是私有框架发现分散、geometry和观察关联、执行receipt与真实业务验收。

## 6. 我们要采用的范式

### 6.1 开发会话是聚合根，device 是其中一个实体（H）

```text
DevelopmentSession（建议模型，不是已有schema）
├─ build identity / app artifact / bundle / runtime instance
├─ target: platform + kind + physical identity + backend identity
├─ environment: OS/runtime + locale + appearance + type size + data seed
├─ control: strategy + scope + capability probe + lease
├─ observation: source + capture time + generation + geometry revision
└─ execution: action receipt → postcondition → evidence → replay recipe
```

身份不能靠“booted”“前台窗口名”或“最后打开的设备”；多候选 fail-closed。统一应统一 **意图与结果**，而不是把所有平台底层机制伪装成相同。

### 6.2 生命周期、画面、语义、输入四条数据面分开（H）

- lifecycle：公共管理CLI；不要求展示宿主在线。
- visual：截图/可选流；画面可用不代表输入ready。
- semantic：embedded/AX/平台树；像素推断仅是候选。
- input：在明确scope和authorization下执行；业务验证读取独立观察源。

显示窗口关闭不能默认关闭业务会话；会话退出只撤销自己拥有的输入/媒体/临时环境，不停止别人的设备或流。嵌入 App 的主动语义 API 仍然是独特资产；“零接入入口 + 可选 Debug 增强”比“必须接入才有价值”更容易采用，但零接入不保证同等可观测性。

### 6.3 环境从临时设置变成可声明、可恢复的测试输入（H）

环境配置不等于整机快照。每一字段都应有 read/apply/verify/restore 支持状态；不支持恢复就明确标记 irreversible / manual restore，不宣称完整恢复。顺序建议：locale/appearance/text size/既有location支持 → 权限和限定App数据 → 其它硬件/窗口变化，不能把foldable resize和旧SDK兼容作为首期前提。

### 6.4 从 `ok` 二值到执行与验证分离（H）

建议概念状态：prepared / sent / transport-acknowledged / observed / verified / uncertain / failed。最终对外不必枚举所有内部阶段，但至少独立表示 execution 与 verification。

在动画、网络错误、相同文本多个节点、AX stale、方向变化、设备切换、其它人操作时，系统应该可以说“命令提交成功，后置条件未满足”，而不是返回误导性的成功。截图/树只是证据，不自动证明任意业务成功。

## 7. 机会优先级与反证

| 顺序 | 假设 | 价值 | 最小验证 | 反证/停止条件 |
| --- | --- | --- | --- | --- |
| P0 | 少报一次假成功比多一个输入命令更有价值 | 当前SP-180痛点，建立可信执行 | 方向/比例/多目标/超时 fixture + 一条真实host操作独立verify | 无法稳定关联目标/几何则禁用该策略；不要修文案伪装完成 |
| P1 | 同一case跨iOS/Android/Harmony的结果契约降低agent操作成本 | Apple不跨这三平台，现有代码可复用 | 两平台一条同意图observe→act→verify→evidence；缺能力typed unsupported | 只有命令名统一而语义不可比较，则缩为平台特化trace |
| P1 | 声明环境+证据减少不可复现问题的往返 | 比窗口壳有更高工作流价值 | 一个受控App、两种字号/外观，保存apply/read-back/restore ledger | 无法read-back/restore，不能售卖确定性环境，退回记录-only |
| P2 | Apple官方agent服务可降低私有输入维护成本 | 顺势复用原生能力 | 有授权的外部客户端PoC，对比目标/输入/截图/错误/IDE依赖 | 需不接受的全局权限、不能绑定target、依赖不可控UI则不用默认backend |
| P2 | 无接入观察入口能提高首次采用率，embedded增强能提高质量 | 降低安装摩擦且保留差异化 | 比较陌生App/集成App同case的准备步骤、成功/uncertain数量 | 用户并不愿做SDK集成或语义优势不明显，重新定义采用模式 |
| P3 | 真机远控值得私有协议长期成本 | 可能扩大验收覆盖 | 先需求访谈与官方能力差距，再独立space协议PoC | 已被官方满足、授权/DDI/版本成本大于价值，停止协议产品化 |

这些是研究假设，不是确认的市场规模或护城河。Apple也在补强verify、诊断、预览和agent工作流，跨平台/语义/evidence不会因为今天有空隙就永久排他；必须靠实际采用、维护成本与可信结果验证。

## 8. 不做与替代方案

- 不做另一套 Simulator 皮肤/菜单大全；使用Apple/社区窗口作为可选display host。
- 不把Device Hub私有协议作为所有平台基础；公共工具优先，私有adapter隔离/可关闭。
- 不把 MCP 当新业务层；未来需要时仅薄适配CLI/HTTP契约，Apple backend研究也不改这一原则。
- 不把 Web 变成写控制面；先用只读timeline说明target/策略/环境/证据。
- 不立刻引入设备云、远端agent、多租户；当前研究不改变现有scope。
- 不承诺设备快照、跨平台完全相同UI、任意第三方App稳定语义、真机全系统AX/输入。
- 不修改Xcode全局偏好以劫持run destination；展示host选择与设备生命周期独立。

## 9. 本轮可交付与未完成证据

已完成：官方新范式与竞争面的纠错；两个固定开源revision的关键输入/会话/管理源码复核；当前TritonKit具体资产与缺口；阶段门禁与可证伪路线；research space/索引/memory归档。

未完成且不冒称：Device Hub真机控制实测、官方MCP tool schema/权限PoC、Xcode27 unified devicectl JSON fixtures、跨平台case对比、HEVC性能、OpenDeviceHub或device-hub-ios测试执行、host HID真实命中收口、市场采用验证。

下一步推荐：**先实施P0的“明确目标+几何一致性+独立verify”纵切，再做两平台同case的可验证会话。** 官方agent backend的只读契约调查可作为另一独立研究；真机私有协议暂不进入默认依赖。
