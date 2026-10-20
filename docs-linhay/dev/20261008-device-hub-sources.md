# Device Hub 深度调研来源台账

> 访问日期：2026-10-08。用于 [研究报告](../dev/20261008-device-hub-paradigm-research.md)。Apple 页面为动态更新文档，结论只对访问时内容成立；GitHub 核心源码固定 revision。O=官方，S=源码，P=项目声明，H=建议，U=未验证。链接与读取证据不代表构建/运行验收。

## A. 官方资料

| 编号 | 原始资料 | 本轮读取与关键事实 |
| --- | --- | --- |
| A01 | [Device Hub 总览](https://developer.apple.com/documentation/xcode/device-hub) · [DocC JSON](https://developer.apple.com/tutorials/data/documentation/xcode/device-hub.json) | O：真机/模拟器run destination管理，compact/expanded窗口、screen canvas与inspector；主控读取JSON |
| A02 | [WWDC26 Get the most out of Device Hub](https://developer.apple.com/videos/play/wwdc2026/260/) | O：统一交互、设备专用controls与Resize；前轮主控读取了部分transcript，本轮subagent称完整读取但没有最终报告；未经主控复核的timestamp不列为证据 |
| A03 | [Managing devices](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub) | O：配对/自定义模拟器入口；细分条件优先以A06 release notes与具体doc为准 |
| A04 | [Interacting with your app](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub) · [JSON](https://developer.apple.com/tutorials/data/documentation/xcode/interacting-with-your-app-in-device-hub.json) | O：模拟器launch打开compact；物理设备launch后需选device并View Screen；不同设备controls不同；不由UI推断touch CLI |
| A05 | [Devices using command line](https://developer.apple.com/documentation/xcode/interacting-with-devices-using-the-command-line) · [JSON](https://developer.apple.com/tutorials/data/documentation/xcode/interacting-with-devices-using-the-command-line.json) | O：devicectl管理physical/simulated、启动App覆盖二者；simctl启动模拟器；JSON版本化；DeviceFS默认共享挂载、mostly readonly、按domain权限；copy小节明确physical，不保证所有文件动作跨kind等价 |
| A06 | [Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes) · [JSON](https://developer.apple.com/tutorials/data/documentation/xcode-release-notes/xcode-27-release-notes.json) | O：macOS26.6+/Apple silicon；agent boot/install/launch/touch/screenshot；MCP工具扩展及Beta5无workspace服务预览；Device Hub输入/配对/Resize/Vision Pro/two-finger限制；devicectl v5 properties与deprecated字段、stdout支持 |
| A07 | [Configuring simulated environment](https://developer.apple.com/documentation/xcode/configuring-the-environment-of-a-simulated-device) · [JSON](https://developer.apple.com/tutorials/data/documentation/xcode/configuring-the-environment-of-a-simulated-device.json) | O：环境配置是独立能力；不承诺全量可读回/恢复、整机快照或对应稳定CLI |
| A08 | [Screenshots and videos](https://developer.apple.com/documentation/xcode/capturing-screenshots-and-videos-from-devices) · [JSON](https://developer.apple.com/tutorials/data/documentation/xcode/capturing-screenshots-and-videos-from-devices.json) | O：设备原生全分辨率截图覆盖physical/simulated；视频章节仅simulated |

### A06 可审计定位（release note issue IDs）

- `175179787`：agent boot/install/launch/synthesize touch/capture screenshot。
- `176935844`：MCP debugger、scheme/run destinations、build settings等。
- `172961797`：Preview Snapshot外观/方向/字号等variants。
- `178294840` / `178289210`：ACP / plugins。
- `162138432`：Xcode27仅Apple silicon；不等于不能为Intel back-deploy编译。
- `183772705` / `170812159`：JSON v5 details旧字段弃用与 `_deprecationNotice`。
- `63583278`：`--json-output` 支持stdout；具体参数语法仍须help核对，不在报告猜`-`或路径约定。
- `48372360`：scroll/transform pointer events与direct click的混合输入，不能当真实多触点重放。
- `169537162`：不支持two-finger touch。
- `142582218`：物理Vision Pro video/input不支持。
- `181945323` / `160482487`：旧模拟器输入下限与input OS限制。
- `179418483`：OS27+ nearby首次无线配对。
- `179416769`：iOS26及更旧SDK链接App的Resize不支持。
- `176809181`：parallel test simulator可能不在Device Hub显示，设备仍测试中。这进一步证明UI可见不等于设备存在/活动状态。
- `182553164`：物理设备退出Simulate Hardware Keyboard后可能最多2分钟不显示软键盘；自动恢复需要read-back而不是无条件声称完成。

## G. 固定开源源码

### OpenDeviceHub

Revision：`e50f07f1f4480cb14d57f192df7bf598ca26e708`；由GitHub目录HTML内currentOid核查。下面文件均由主控直接HTTP读取，不只引用subagent摘要。

| 编号 | 固定源码链接 | 读取结论 |
| --- | --- | --- |
| G01 | [SimctlService](https://github.com/Mastersam07/OpenDeviceHub/blob/e50f07f1f4480cb14d57f192df7bf598ca26e708/engine/Sources/OpenDeviceHubEngine/Simctl/SimctlService.swift) | S：public simctl list/boot/shutdown/bootstatus；不是纯窗口壳，也没重写稳定boot接口 |
| G02 | [AdapterFactory](https://github.com/Mastersam07/OpenDeviceHub/blob/e50f07f1f4480cb14d57f192df7bf598ca26e708/engine/Sources/OpenDeviceHubEngine/Adapter/AdapterFactory.swift) | S：最低major26、最新verified27、较新major advisory但允许运行；不是逐符号可用性完整验证 |
| G03 | [PanelInputSession](https://github.com/Mastersam07/OpenDeviceHub/blob/e50f07f1f4480cb14d57f192df7bf598ca26e708/engine/Sources/OpenDeviceHubEngine/Adapter/PanelInputSession.swift) | S：私有XPC endpoint、Indigo事件、screen target与activation；input发送不验证业务 |
| G04 | [CoordinateMapper](https://github.com/Mastersam07/OpenDeviceHub/blob/e50f07f1f4480cb14d57f192df7bf598ca26e708/engine/Sources/OpenDeviceHubEngine/Input/CoordinateMapper.swift) | S：aspect-fit letterbox拒绝、AppKit坐标与orientation逆映射，纯转换模块 |
| G05 | [TapCommand](https://github.com/Mastersam07/OpenDeviceHub/blob/e50f07f1f4480cb14d57f192df7bf598ca26e708/engine/Sources/odhub/TapCommand.swift) · [README](https://github.com/Mastersam07/OpenDeviceHub/blob/e50f07f1f4480cb14d57f192df7bf598ca26e708/README.md) | S：normalized tap began/ended后打印tapped；P：Simulator定位、私有framework、分发/签名/架构支持声明；本轮未运行测试 |

subagent另提供FrameRenderer/LatencyMeter/IOSurface可变帧时间的线索，但没有完整报告/固定文件证据，主控没有复核；本轮不将其性能测量描述列为已验证结论。

### device-hub-ios

Revision：`1fcdfb0a6799b62f05625d0cbb359bec57256b94`；由GitHub目录HTML内currentOid核查。

| 编号 | 固定源码/文档链接 | 读取结论 |
| --- | --- | --- |
| G06 | [DeviceSessionCoordinator](https://github.com/JaviSoto/device-hub-ios/blob/1fcdfb0a6799b62f05625d0cbb359bec57256b94/Packages/DeviceHubKit/Sources/DeviceHubFeature/DeviceSessionCoordinator.swift) | S：attempt/session隔离，旧effect不能关新session，输入授权撤回与cleanup |
| G07 | [RemoteSessionMedia](https://github.com/JaviSoto/device-hub-ios/blob/1fcdfb0a6799b62f05625d0cbb359bec57256b94/Packages/DeviceHubKit/Sources/DeviceHubFeature/RemoteSessionMedia.swift) | S：frame所属attempt/session校验、generation更新与拒绝 |
| G08 | [RemoteSessionInput](https://github.com/JaviSoto/device-hub-ios/blob/1fcdfb0a6799b62f05625d0cbb359bec57256b94/Packages/DeviceHubKit/Sources/DeviceHubFeature/RemoteSessionInput.swift) | S：映射viewport/target pixels/orientation，pending command序列与失败撤权；未实测输入落地 |
| G09 | [Rust session](https://github.com/JaviSoto/device-hub-ios/blob/1fcdfb0a6799b62f05625d0cbb359bec57256b94/Rust/DeviceHubFFI/src/session.rs) · [Rust protocol](https://github.com/JaviSoto/device-hub-ios/blob/1fcdfb0a6799b62f05625d0cbb359bec57256b94/Rust/DeviceHubFFI/src/protocol.rs) | S：主控读取HTTP文本、提取关键位置；generation/control gate/media emitter、RSD、UniversalHID/Indigo；非逐行安全审计 |
| G10 | [ProtocolSecurity](https://github.com/JaviSoto/device-hub-ios/blob/1fcdfb0a6799b62f05625d0cbb359bec57256b94/Docs/ProtocolSecurity.md) | P：persistent identity、认证fail-closed、existingDDI、HEVC组帧、新鲜帧输入gate、不stopAll、写入不等于落地；不能以文档代替加密/teardown测试 |
| G11 | [Architecture](https://github.com/JaviSoto/device-hub-ios/blob/1fcdfb0a6799b62f05625d0cbb359bec57256b94/Docs/Architecture.md) · [README](https://github.com/JaviSoto/device-hub-ios/blob/1fcdfb0a6799b62f05625d0cbb359bec57256b94/README.md) | P：Swift领域/状态与Rust传输分层；iOS27+、Beta3验证声明；非Apple开源、非官方支持；本轮未build/test |
| G12 | [idevice](https://github.com/jkcoxson/idevice) | 仅上游定位，未声称全仓审计；G10记录上游pin `a64b8867815b3da17b5c927531bdba877e8456ef` |

主控最初读取部分README/架构文档使用main/dev链接；固定revision在本轮核查，用于后续复跑的审计入口。没有在本仓vendoring或存储Apple代码/框架。

## C. 兼容性与替代展示宿主

| 编号 | 来源 | 证据等级与结论 |
| --- | --- | --- |
| C01 | [React Native CLI #2806](https://github.com/react-native-community/cli/pull/2806) · [实际diff](https://patch-diff.githubusercontent.com/raw/react-native-community/cli/pull/2806.diff) | S：主控已读diff，Simulator不存在时检测Contents/Applications/DeviceHub.app，使用devices://device/open?id=UDID；不传旧CurrentDeviceUDID；PR不是Apple长期API承诺 |
| C02 | [MiniSim #157](https://github.com/okwasniewski/MiniSim/pull/157) | P：PR摘要称新增Device Hub兼容；不作为本轮已合并或实测证据 |
| C03 | [NeoSimulator README](https://github.com/lynnswap/NeoSimulator) | P：Legacy/Neo/DeviceHub展示宿主选择，CoreSimulator仍持有模拟器；未读取其完整改偏好实现，也未运行install/use命令 |

## T. TritonKit 本地证据入口

基线 `0231d883`；下列是本地源码/历史文档，不是本轮运行回归：

- T01：[设备发现与scope拼接](../../Sources/TritonKitCLI/CLIHostDeviceRuntime.swift#L27-L130)。
- T02：[devicectl旧字段parser](../../Sources/TritonKitShared/TKHostAdapterDevicectlModels.swift#L243-L339)。
- T03：[baguette子进程framework resolver](../../Sources/TritonKitCLI/CLIHostSimulatorFrameworkEnvironment.swift#L3-L40)。
- T04：[Framebuffer framework loader](../../Sources/TritonKitCLI/CLIHostSimulatorFramebufferService.swift#L21-L75)。
- T05：[target lease opt-in gate](../../Sources/TritonKitCLI/CLITargetLeaseGate.swift#L4-L24)。
- T06：[observe source/confidence/candidateOnly](../../Sources/TritonKitCLI/CLIObservationModels.swift#L19-L33)。
- T07：[AX与geometry模型](../../Sources/TritonKitShared/TKObservationModels.swift#L38-L124)。
- T08：[host tap与unsupported type](../../Sources/TritonKitCLI/CLISimulatorInputCommands.swift#L18-L98)。
- T09：[full-screen/App-layer evidence](../../Sources/TritonKitCLI/CLIEvidenceCaptureRuntime.swift#L350-L524)。
- T10：[Web目标只读投影与real过滤](../../Sources/TritonKitCLI/CLIWebDeviceRuntime.swift#L133-L175)。
- T11：[SP-180验证与未封口边界](../spaces/SP-180-xcode27-simulator-frameworks/README.md#L24-L30)。
- T12：[历史Xcode target graph设计](../spaces/20260520-xcode-workflow-takeover/technical-design.md#L5-L55)；明确是设计，不等于当前完整聚合服务。

## 前轮结论修正

1. Device Hub不只是设备列表：保留，但不扩展成任意设备全功能支持。
2. Xcode27用DeviceHub替代旧Simulator展示入口：社区diff支持；旧CoreSimulator/simctl并未因此消失。
3. devices://：社区方案，不是本轮证明Apple公开稳定URL契约。
4. devicectl真机/模拟器：官方确认；启动模拟器仍simctl；文件copy小节physical限定需要保留。
5. Apple已有agent touch/screenshot/MCP与无workspace服务预览；不得把Apple无自动化作为机会依据。
6. OpenDeviceHub有管理与控制原语，不只是窗口；但单个tap命令没有业务verify。
7. device-hub-ios是非官方实现；MIT不等于Apple支持、私有接口不等于公有SDK。
8. 本轮不存在性能、协议稳定性、跨平台成功率或用户需求实测数据。

2026-10-20 后续：本页保留当时调研语义；原 Baguette resolver 已由 [SP-218](../spaces/SP-218-issue-222-device-hub-input/README.md) 的 Triton 内置 helper 与中性 framework resolver 接替，外部执行器/override/hook 已删除，源码链接改为现行替代位置。
