# Device Hub 全能力接入清单与推进顺序

> 2026-10-09；目标进行中，不是完整支持声明。两次subagent审计失败，无closing evidence；本表由主控依据实际源码和Apple文档直接建立。新增能力必须先BDD/TDD、schema、脱敏输出，再验收。既有实现与本轮真实验收严格分开。

## 范围与完成规则

沿用CLI/shared，单点无需Run，高级命令可组合；保留Xcode26旧命令。Apple Device Hub GUI功能不是公开CLI保证。逐叶项记录implemented（有代码）、partial、missing、no-public-backend-evidence（尚未发现公开自动化接口，不等于永久unsupported）、platform-unsupported（官方明确限制）；仅有help/代码/fixture不算动作实测。新readonly queries可以验证设备信息，不进行真机写操作。写动作仍限已拥有专用Simulator，创建/删除/erase/runtime安装等破坏性扩展不因full目标而自动授权；不修改全局Xcode、不提交合并发布。

完整收口要求：每个公开可自动化叶项有Triton机器可读契约、明确平台/系统约束、单元/参数/schema/失败边界测试与可复跑适用范围验收；无法公开自动化的GUI项单独标证据与fallback边界，不能靠统一unsupported掩盖缺项。真机动作和其它平台真实验收缺口必须保留，不能以Simulator绿替代。

## 官方事实源

- [Device Hub目录](https://developer.apple.com/documentation/xcode/device-hub)：其topic tree为本表边界，不纳入全部Xcode build/debug/test能力。
- [管理与配对](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub)
- [环境与尺寸](https://developer.apple.com/documentation/xcode/configuring-the-environment-of-a-simulated-device)
- [App及平台交互](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub)
- [visionOS交互](https://developer.apple.com/documentation/xcode/interacting-with-your-visionos-app-in-device-hub)
- [截图与视频](https://developer.apple.com/documentation/xcode/capturing-screenshots-and-videos-from-devices)
- [App管理](https://developer.apple.com/documentation/xcode/managing-apps-on-devices)
- [CLI、domains与DeviceFS](https://developer.apple.com/documentation/xcode/interacting-with-devices-using-the-command-line)
- [27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)

## 当前源码证据入口

- [发现/选择](../../../../Sources/TritonKitCLI/CLIHostDeviceRuntime.swift)、[现代/旧设备JSON](../../../../Sources/TritonKitShared/TKHostAdapterDevicectlModels.swift)、[device schema](../../../../Sources/TritonKitCLI/CLISchemaHostCommands.swift)
- [Simulator命令](../../../../Sources/TritonKitCLI/CLIHostSimCommands.swift)、[maintenance](../../../../Sources/TritonKitCLI/CLIHostSimulatorMaintenanceCommands.swift)、[输入](../../../../Sources/TritonKitCLI/CLISimulatorInputCommands.swift)
- [App](../../../../Sources/TritonKitCLI/CLIHostAppCommands.swift)、[app pull与domain限制](../../../../Sources/TritonKitCLI/CLIHostAppPullCommand.swift)
- [本轮info](../../../../Sources/TritonKitCLI/CLIHostDeviceInfoCommands.swift)、[info runtime](../../../../Sources/TritonKitCLI/CLIHostDeviceInfoRuntime.swift)、[info白名单parser](../../../../Sources/TritonKitShared/TKHostAdapterDeviceInfoModels.swift)

## 逐能力基线

| 组/叶项 | 现有Triton入口或缺口 | 状态 | 验收与限制 |
|---|---|---|---|
| Apple平台支持报告 | device platforms [--apple-platform <family>] [--inventory] | partial | 六family compiledcatalog，默认zero hostquery，filter仅catalog；可选一次availableSimulator metadata/全局OSfamily counts，actual15条metadata accepted/no rawID-name-runtime/no physical query/boot/action。iOS runtime不能猜iPadOS或iPhone-iPad，Mac不假定Simulator，unknown保留/0非unavailable；profile control/auth false仅本报告未验授权非旧功能denial。oldios namespace/IDs/argv不改，不capabilities数组/genericcmd自动enable。严格ASCII版本shape不是签名runtime/设备硬件/业务证明；仍缺physical/逐target/hardware provenance及各专门platformcontrol，[第十一批ledger](<./20261010-apple-platform-verification.json>) |
| 发现：sim/real列表、过滤、去重、状态 | device list/resolve/doctor | implemented | 当前27.1 readonly已验；unknown不当ready；发现是iOS范围，不是所有Apple平台 |
| 标识与硬件详情 | device info +hardware.platformObservation | implemented | 现代/旧JSON白名单，真实27.1真机readonly已验；第十二批optional explicit hardware platform/deviceType/reality来源/nestedCLI/oldCodable已验，actualios-iphone-physical，不legacyios/name/product/runtime猜OS/iPadOS/physical，现代present/null/partial不旧镜像，未知观察值不回显。CLI1104+14/root303+7；其他family仅fixtures/nonIOSphysicalselection与专门控制仍缺，[ledger](<./20261010-hardware-observation-verification.json>)。UDID/ECID/serial/IP/URL不公开；此前ownedSimulator无锁query独立输出/恢复仅历史切片，本片no lifecycle；旧SDK仅fixture |
| 锁/密码状态 | device info --lock-state（本轮） | implemented | 真机实际字段passcodeRequired/unlockedSinceBoot，不是screenLocked/业务ready；本机专用Simulator返回CoreDevice1001 unsupported，结构化映射unsupported_device_info_query，不自动降级成功；不能推广全部型号 |
| 创建模拟器 | sim create | implemented | 专用iOS27.1已验；型号/runtime适用性需分别检查 |
| 启动/关机 | sim boot/shutdown、device start/stop | implemented | 专用已验；只能指定拥有实例，不碰booted业务实例 |
| 重启 | 可组合shutdown/boot，无独立契约 | partial | 需失败/恢复、启动等待和目标隔离测试，不能声称已有restart |
| 重命名 | sim rename <uuid> <name> | implemented | 先RED命令/schema4issues；Unicode/非法输入/timeout/metadata/旧命令保留及完整回归过；owned Shutdown实例独立观察新名并恢复原名，ID/state及其它实例不变 |
| Hub侧边栏Remove与删除Simulator | 未映射 | missing | UI隐藏/移除≠simctl delete数据删除；需明确区分并确认风险 |
| 擦除内容与设置 | sim erase --confirm | implemented | 本轮未执行，不将registration算动作验收 |
| 模拟器watch/phone配对与clone/upgrade | sim pair/unpair/clone/upgrade | implemented | 非真机pair；本轮无真实watch/升级验收 |
| Runtime管理 | sim runtime | implemented | 已有list/verify/add/delete/match等，下载/安装非本轮默认授权 |
| 真机有线配对/解除配对 | device pair/unpair --plan-only 独立policy review | partial | 强制ios/real/explicitselector/plan flag在IO前，freshprimary hash、SDKhelp exactflags、previewredaction；always executable/executed=false，SDKunsupported ok仅policyplan/support=false/blockers/no preview。所有discovery错误仅静态message/原稳定code，不rawpaths/logs/candidates。没有acceptedexecution/auth/audit/nativefileJSON/postcondition，不真机写、不存凭据/profile/DDI；旧sim入口保留，[第十批ledger](<./20261010-device-administration-verification.json>) |
| 真机网络发现/无线配对/PIN | Hub官方GUI流程未映射 | no-public-backend-evidence | iOS/iPadOS/watchOS27新流程；需核对public manage命令能力，不猜PIN参数 |
| Developer Mode/信任/准备问题 | discovery blockedReasons | partial | 只读提示，未自动修复，不能替用户点Trust或启用Developer Mode |
| 真机/模拟器实时屏幕查看 | sim screenshot为单帧，无Hub屏幕会话 | missing | screenViewingURL是私有敏感字段，不自动打开，不等于可嵌入公开流 |
| Simulator点击/文本与AX | observe/wait/act及sim隐藏tap/type | partial | 有host/private依赖与embedded边界，不能推广真机/多平台 |
| 双击/长按/拖放 | 当前host高级act表面需逐backend审计 | partial | 不能由embedded UIKit动作推断Hub设备级支持 |
| 滚动/触控板缩放旋转 | 未对应公开Hub控制命令 | no-public-backend-evidence | pointer scroll/transform不等于真实双指touch |
| 鼠标/触控板模拟模式 | 无公开Hub模式入口证据 | no-public-backend-evidence | 实机iPad鼠标验证与Hub混合点击行为不同 |
| Home/锁屏/音量/Action/Siri/方向/慢动画 | 部分host act/press，缺官方Hub逐型号契约 | partial | 必须核对backend、系统/型号及坐标约束，不能同一枚举全平台enabled |
| 键盘输入与快捷键路由 | sim type部分、Hub路由未映射 | partial | ASCII和host输入不等于全部软件/硬件键盘模式 |
| 剪贴板读/写/同步 | sim pasteboard get/set/sync | implemented | 本轮未重新动作验收；公开可用simctl路径 |
| 外观light/dark | sim ui appearance | implemented | 需专用实例可逆设置实测及恢复 |
| 文字大小/增加对比度 | sim ui content-size/increase-contrast | implemented | 同上；不等于所有Hub accessibility设置 |
| VoiceOver/颜色滤镜/Liquid Glass | 无对应公开命令映射证据 | no-public-backend-evidence | 核对本机ui help及官方限制，不能靠改私有plist算支持 |
| 定位 | sim location list/set/clear/run/start | implemented | 当前验收未覆盖route及恢复 |
| 音频输入/输出/音量路由 | 无Hub对应入口 | no-public-backend-evidence | 按Simulator音频功能与真实backend分开验证 |
| 画布zoom/fit/physical size/bezel/window | 未映射Hub GUI | no-public-backend-evidence | GUI显示能力，不必新增Triton GUI；考虑可验证host可选adapter |
| 模拟iPhone屏幕尺寸resize | 无入口 | no-public-backend-evidence | linkedSDK约束与缩放不同；不能由自定义Simulator型号代替 |
| App列表/查询/过滤 | app list/info/inspect | implemented | 专用Simulator已验；真机及其它平台未全链路验收 |
| 安装/卸载 | app install/uninstall | implemented | 专用已验；真机未经写验收，不能称真机可靠支持 |
| 启动/env/args | app launch/xcode run | implemented | 专用fixture已验；per-phase timeout回归；不是业务ready |
| 停止App | app terminate | partial | 真机bundleID请求fail-closed，无已验证PID即不假装成功 |
| App data/App Group拉取 | app pull --domain app-data/app-group | partial | 仅ready iOS real、copy from且domainIdentifier必需；本轮未真实文件验收 |
| 容器路径/偏好 | app container/prefs | partial | Simulator路径，不等于真机容器浏览/替换或xcappdata全量支持 |
| 列出device files | device files（独立shallow metadata） | partial | 三个readonly域代码/fixtures及真机crashLogs CLI实测过；设备/domain/ID/目录/用户绑定、default token脱敏、ISO日期/Bool/UInt校验、JSON/count local限额；owned Simulator明确unsupported_device_file_query并恢复；recursive/pagination仍缺 |
| copy to/device写入 | 未封装 | missing | 必须确认目标/domain、审计、无覆盖及写入验收，不盲试真机 |
| systemCrashLogs/temporary domains | device files --domain-type systemCrashLogs；temporary policy guard | partial | crash不要求bundleID且实际physical metadata成功；temporary在IO前拒device_file_domain_policy_required，未查询/创建空间，不把缺side-effect policy说platform unsupported |
| DeviceFS mountpoint元数据 | device mountpoint（独立query） | implemented | owned Simulator新CLI实际query/1byte限制/privacy0700-0600/finally恢复通过；commandType/outcome/唯一--device exact绑定，native dataPath仅private JSON；token不是path/已挂载/存在/读写或业务证明；旧SDK仅保留旧入口，physical mountpoint本片未实测 |
| DeviceFS安全浏览 | 三固定view/显式native容器/受限容器相对子目录浅metadata；语义身份/crash/Temporary域仍缺 | partial | [第九批ledger](./20261010-devicefs-subdirectory-verification.json)：appview+explicitcontainer才可subdirectory，原始1...32组件/4096UTF8bytes/255每组件，不absolute/dot/dotdot/empty/control/normalize/URLdecode；输入+标准根UUID形状64depth/16384bytes pre-discovery/artifact预检（占位不IO/identity），fresh实际parent UTF8bytes/UUID绑定及组合重检在DirIO前，同FD root每relativeowner/nofollow+双leafstat，exactdevicefs合成ID例外不变。实际两view子目录2/2项default/optin稳定且区别containerroot tokens/private0700-0600/actualentries1+JSON1拒绝/全names-state Shutdown恢复过；nil旧root/namespace/container tokens兼容，不selectionfield echo/onlyoptinleafnames可偶合。CLI1092+14/root298+7/Release124.94s/local产品门禁过（仅既有181/182docs缺号），32/4096/255与组合64/16384纯边界、NFC/NFD homebytes拒绝及subdir rawbytes token分离/middle-selected link/no recursive fixture过。no verifiedID/crash/Temporary-domain creation/content/recursive/outsidecontainer/Finder/explicitmount/autoprep/fallback/FUSEdeadline/remotehardlimit/atomic/mountauth；privatehostartifactrefs可本机定位不可publish/nativeFSpath不inline |
| App数据容器下载/替换/xcappdata | 部分pull，无完整Hub契约 | partial | 目录安全/符号链接/限额已有pull边界，但不证明所有容器操作 |
| Simulator截图 | sim screenshot/device screenshot/evidence | implemented | 主framebuffer；此前黑截图不证明App渲染 |
| 真机截图 | 当前host明确unsupported | missing | 官方GUI有；当前devicectl无对应screenshot命令，需另查公开backend，不伪装App层截图 |
| Simulator录屏 | sim record | implemented | 已有编码sample时长验证；本轮还未复验 |
| 真机录屏 | 官方该文章仅承诺Simulator录屏 | no-public-backend-evidence | 不扩张官方承诺 |
| 日志/App console/Simulator诊断 | sim logs/app-console/diagnose | implemented | 不把unified log、console、crash日志混为同一来源 |
| 真机diagnostic下载/崩溃报告 | device diagnose --plan-only policy review；systemCrashLogs仅metadata | partial | 单--devices、privateZIP --output不echo/stat/create，--no-finder/--no-include-host-sysdiagnose/--archive/--archive-destination、privateJSON/log placeholders非stdout；无collection/execution/archive验收，authorization/content/path/permission/nooverwrite/nofollow/size未接受。关闭hostsysdiagnose仍可能hostCoreDevlogs，非device-only/crash等价；SDKhelp/plan非动作证明；Root固定/usr/bin/xcrun，PATH interception无trace证据，actualCLI envelopes及DI/source review明确分层 |
| watchOS Crown/侧边/Action输入 | 无专用契约 | missing | Simulator和physical不同；已有sim pair不是输入支持 |
| tvOS焦点/返回/选择 | 无专用Hub契约 | missing | 不复用iOS坐标假装支持 |
| visionOS注视/捏合/相机/视角捕获 | 无专用契约 | missing | 先确认公开自动化接口及平台schema |
| visionOS场景/光照/空间移动/游戏手柄 | 无专用契约 | no-public-backend-evidence | 游戏手柄官方限visionOS模拟器；非普通UIKit输入 |
| visionOS SharePlay参与者/Control Center | 无专用契约 | no-public-backend-evidence | 不能把运行一个App算这些功能完成 |
| 物理Vision Pro屏幕/输入 | 官方明确不支持Hub查看/输入 | platform-unsupported | 其它设置/DeviceFS不随之禁用 |
| 双指触摸注入 | 官方Hub限制 | platform-unsupported | 不与pointer transform事件混淆 |
| Shake | release notes已知不可用 | platform-unsupported | 时间/版本敏感限制，后续版本重新probe，不永久硬编码 |
| CLI/help/版本化fileJSON | doctor/schema、shared builders | implemented | help-advertised-only；不用文本解析、旧--show、新-only参数或版本猜测 |

## 执行队列（持续推进，不提前complete）

1. 已推进而非下一片重复排队：info/lock-state、files readonly metadata、mountpoint、DeviceFS fixed namespace/nativecontainer/boundedsubdirectory（含bytesidentity/owner/nofollow/bounds）与sim rename；仍以各片ledger限定真实accepted scope。
2. 第十批：独立pair/unpair/diagnose --plan-only与SDKhelp/privacy/preIO/readonlyCLI合同；不是execution、pairingstate、archive或business验收，无授权不执行真机写/诊断采集。跟进acceptednativefileJSON/action-specific授权/audit/postconditions与archivepolicy，但不得以猜测result形状替代证据。
3. 第十一批Apple catalog/availableSim聚合actual15及第十二批identity-bound hardwareObservation currentphysicalios-iphone-physical已验（CLI1104+14/root303+7），并非full platform支持；nonIOSphysical discovery-selection/perfamilylive及专门controls仍缺。下一优先核实semantic bundle/group App metadata→native container绑定与Crash/Temporary公开SDKdomain契约，在既有fixednamespace/受限目录metadata基础上推进，不文件内容/physicalwrites/凭据采集。继续保留oldios namespace/IDs/argv、explicit与legacy/unknown分开、不deprecatedmirror/name/runtime/iPadOS猜测或cap数组自动enable。
4. DeviceFS verified bundle/group语义身份映射、Crash namespace来源映射、Temporary副作用policy仍未接入；不能猜root/Library语义、不domain-errorfallback，不以container tmp算Temporary域创建。
5. Simulator restart/delete/扩展io-ui、watch/tv/vision专门公开控制契约分别推进；owned可逆验收，新增destructive行为先明确授权，不借业务实例。
6. GUI-only/public接口未证项继续调查，准确限制/手动fallback，不新增Web/GUI控制面代替。持续full/root/Release/local/真实scope，SDKhelp、fixture、actualenvelope、liveaction分层；docs/skills/memory写回。本次用户已授权SP183本地整理提交，不合并/推送/发布，见[四批交付与沉淀](<./20261010-session-recap-v01.md>)，不得把切片提交当goal完成。

## 2026-10-10 四批实际能力更新

此前表格保留历史切片证据；当前新增SDK语义容器、Crash namespace、Temporary可能创建策略、管理执行后端、watch配对关系、Apple physical独立发现/选择，详见[当前四批能力矩阵](./20261010-capability-batches-matrix.md)。后端fixture、专用Simulator实际、仅计划、GUI描述/未支持分别列示；不能把历史“execution缺失”继续当成当前实现状态，也不能把本轮后端完成称为真机或所有专门平台完整接入。
