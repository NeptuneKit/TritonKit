# SP-183 Device Hub 官方设备能力适配

2026-10-12：[真机只读验收](./plans/20261012-real-device-verification.md)在2台在线 iPhone 上通过设备信息/锁状态/readiness/Crash metadata，另通过4个App容器与1个App Group的SDK语义绑定；管理命令仅计划，真实写入与诊断仍未验收。

> 建立 2026-10-08，更新 2026-10-12。当前开始专门平台真实验收，执行修复位于 `SP-183-live-platform-acceptance`。tvOS/watchOS SDK 构建通过，runtime 官方下载遭遇 MobileAsset 网络错误 47，尚无真实输入成功证据。此前 runner gate 的单测不证明可执行闭环；本轮修正请求传递、附件与审计。用户已授权测后本地合并，未授权推送/发布或真机配对、解除配对、诊断采集。历史段落仅记录当时状态。

[会话沉淀与四批后续计划](<./plans/20261010-session-recap-v01.md>)统一记录已接入能力、证据分层和提交范围。历史“未提交”段落保留当时快照；本次授权不覆盖主仓SP-181/182或扩展真机动作范围。

## Requested / 范围

用户选择「官方设备能力」首片：设备发现、目标身份、就绪状态和 Xcode 27 devicectl JSON。复用 `device / target / app`，单点命令继续可组合，不新增 GUI、hub 根命令或高级执行引擎。不安装/启动/输入/改设备，不提交推送合并。

分支 `feat/SP-183-device-hub-official-adapter`；工作区 `../TritonKit-worktrees/SP-183-device-hub-official-adapter/`。主仓 SP-181/182 是未提交研究文档，本分支从 HEAD 隔离，未复制那些改动；本分支当前空间数量因此与主仓不同，编号183来自全局登记，181/182仍保留于主仓。

## Observed / 官方与本机证据

- [官方 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)：details v5 弃用旧三字典；list 文本优先UDID/ECID，官方说其JSON unaffected。不能由此臆测 list shape。
- [官方命令行说明](https://developer.apple.com/documentation/xcode/interacting-with-devices-using-the-command-line)：devicectl 管理 physical/simulated；启动模拟器仍 simctl，JSON版本化。未给完整新schema/统一ready枚举。
- 已安装 CLI `0.2.22` 的 version/status/doctor/capabilities/device/target/app schema/plan 和 `device list --platform ios --scope all --json` 全部 exit0；这是旧二进制事实，不是本轮代码验收。
- 该命令保留的 devicectl 原始 artifact 实际 `jsonVersion=5`, `version=651.13.5`，同时包含 physical/simulated、旧三字典、properties 与 deprecation notice。确认 `properties.hardware.reality`, `properties.state.bootState`, `properties.connection.state`, `properties.software.osVersionNumber.stringValue` 以及关联值 developerModeStatus.enabled 对象。局部shape实测，不泛化全量Apple schema。
- 原始 artifacts 仅本机各工作区忽略的 references目录（含敏感身份，不公开）。测试用匿名最小字段；new-only变体是兼容性合成样本，不声称安装工具已删除旧字典。
- 旧代码把CoreDevice模拟器投影为真机，并可能将shutdown+paired判ready；scope=all拼接重复且失败静默吞掉。

## BDD / TDD

1. 新-only、混合v5：新字典优先，模拟器canonical `sim:<UDID>`；OS版本嵌套值可读，不复活旧镜像。
2. Shutdown/未知boot与未知kind/就绪：ready=false，unknown不是false业务条件，也不是可操作证明。
3. 旧v3 paired lazy tunnel：保留development-service激活eligibility，不把disconnected一律offline；这不是解锁/业务ready证明。
4. real scope只含明确physical；all合并按身份去重，simctl生命周期事实优先，保留两个来源。
5. all任一backend失败：原错误透传，不能给完整发现成功；默认simulator路径不查询physical backend。
6. CoreDevice simulator回到simctl/app目标时用UDID，不用CoreDevice UUID；真机保留hash ID与内部UDID/ECID别名，不公开原始别名。

## Evidence / 验证记录

- shared新测试RED：exit1，实际证明分类、名称/版本、shutdown、unknown和ECID兼容缺口，再实现GREEN；不把synthetic sample当本机完整schema。
- shared focused GREEN：48 tests/2 suites，exit0，包括旧版fixture回归。
- CLI discovery RED：5 tests/7 issues（真实scope/去重/失败/dispatch）；selector+schema RED追加8 issues；UUID alias RED追加2 issues。先证明失败再修复，旧typed-real scope期望因精确分流改为real，原raw selector保留all。
- 边界审查后追加 shared 空/null/partial、非iOS、缺UDID、modern lazy、非法identity/failed outcome、physical shutdown/future visibility；均先验证已覆盖或RED再修复。
- 最终 focused GREEN：shared 54 tests/2 suites，CLI 173 tests/4 suites，均exit0。CLI此前一次rename漏掉ready polling导致编译失败，已改为同一real-scope发现入口并通过回归。
- 两轮只读审查：首轮发现typed simulator选择器错误扩all，已TDD修复；末轮确认alias合并复制primary全部字段、scope隔离及JSON脱敏，无阻断Bug。审查不替代主控测试。
- 完整CLI默认并行首轮：缺少scratch外CLI默认路径下binary，且进程全局stdout/stderr捕获/墙钟deadline出现干扰，失败run已取消；同类并行suite问题SP-180已有记录。本轮不改相关产品代码或断言；改为`--no-parallel`并显式`TRITON_CLI_PATH`指向本轮built binary重跑。串行绿不证明并行问题已修复。
- 完整串行CLI：1002 Swift Testing/80 suites＋14 XCTest，0fail，26.852s；根包281 Swift Testing＋7 XCTest，0fail。
- 本地产品门禁：依赖边界/DEBUG隔离、Release CLI构建与smoke、Harmony host/iOS runtime observe smoke通过；`TRITON_VERIFY_XCODE=0`主动跳过本片之外Simulator工程构建。完整local exit1：先修正SP183登记链接label，再独立重验确认strict docs检查因隔离基线缺SP181/182不连续失败；不放宽checker或复制无关未提交研究。集成后必须复验完整local。
- 本轮Release配置CLI（开发版本`0.1.0-dev`，非已安装0.2.22、非发布）只读验收通过：官方JSON5/651.13.5，raw5simulated+3physical，合并14simulator+3real=17唯一目标，解析成功，不存在sim目标仅一个失败JSON/预期exit1。原始capture仅ignored私有目录；[脱敏验证摘要](./plans/20261008-verification.json)。
- 失败并行run取消后仅终止根据PID/父子关系/精确worktree命令确认的本任务孤儿SwiftPM和helper，以释放本任务scratch锁；未删锁/cache或停止外部服务。源码与测试断言未为串行绿而修改。
- 可复跑 [只读验收脚本](./plans/20261008-readonly-acceptance.py)：读取本轮binary和官方capture，比对physical集合、模拟器UDID、去重、scope隔离、target解析及单一失败JSON；原始输出仅调用方私有目录。

## 新旧Xcode命令兼容补片（22:27继续）

用户明确要求命令层同时支持新旧Xcode，而不是只兼容JSON或给Triton改名。本片保留公共入口与共用argv，不按版本号臆造另一套命令；尊重选中DEVELOPER_DIR，不切全局Xcode，不以写动作试探或失败后盲重发。

BDD：旧/新help契约下同一discovery argv成立；只读commandSupport揭示实际子命令/必需参数支持；旧工具链缺devicectl时simulator仍可用、all/real必须诚实失败；工具链选择环境继承/显式覆盖不泄漏全局。现有doctor仅root tool探测，all忽略devicectl缺失、simulator仍查询physical后端，先补失败测试再修复。当前本机Xcode27.1/27A9275；常见安装目录仅发现一个Xcode，旧版本真实安装验证未完成，不把合成旧help或26/27配置fixture称实测。

本轮Triton-first status为server_unavailable/exit1，host doctor/capabilities/schema均exit0；不启动serve，host命令help不依赖App runtime。因为Triton尚不提供细分upstream help/flags，记录只读xcrun帮助回退，所有探测exit0。只读subagent未给出结果，事实均由主控直接复核。

补片收口：完整CLI1011 Swift Testing/81 suites＋14 XCTest、root281＋7全部通过，Release构建通过。新binary的doctor三scope均ok，2/4/6个子命令契约help宣告支持，标记help-advertised-only，不声称执行设备动作。可复跑脚本再次通过，发现仍14simulator＋3real/17唯一目标、单一失败JSON。详见[新旧命令兼容矩阵](./plans/20261009-command-compatibility.md)及[只读命令验收](./plans/20261009-command-acceptance.py)。旧工具链真实实测、集成后docs/local及既有并行测试干扰仍明确待验。

## Xcode26旧命令保留与授权隔离验收（2026-10-09继续）

用户明确Xcode26支持是保留原有命令，不要求下载安装旧SDK；新增发现及diagnostic不能移除旧入口或强制Run。BDD新增旧sim/app/device/xcode注册与单点参数保留，以及专用Simulator上的create/boot/install/info/launch/terminate/uninstall/shutdown。真实动作只允许本次新建实例，不允许真机、业务Simulator或全局Xcode切换。

执行偏差：第一轮用了原有Shutdown标准设备而非新建专用实例，已移除本次测试App并恢复Shutdown；不将该轮称为隔离验收。随后通过Triton sim create新建SP183专用实例，独立ownership和原始输出仅ignored私有目录保留。单点生命周期已通过；截图虽生成但黑屏，不作为业务渲染成功证据。专用实例的xcode run先因Shutdown安装失败；显式boot后安装阶段触发30秒timeout，而只读app info证明安装已经完成，禁止盲重装。

发现可复现契约缺口：xcode run --timeout只传给build/settings，simulator install/launch仍用30秒默认。BDD要求显式timeout传递到这两阶段，nil保持旧默认；用注入runner先RED后最小修复，不改共用argv、不切backend、不重发不确定写动作。旧入口回归1013 Swift Testing/82 suites＋14 XCTest已通过。

收口：timeout显式覆盖两阶段先RED（2issues）后GREEN，nil默认保持。focused12测试、完整CLI1014 Swift Testing/83 suites＋14 XCTest（19.773秒）、Release build（123.65秒）通过。先只读确认超时安装完成，再明确卸载本次fixture后用新binary进行fresh run，专用实例高级build/install/launch通过（5277ms）；App info/terminate/uninstall通过，最终user app数0、Shutdown，保留供复验。原有标准设备恢复Shutdown，已有业务booted实例仍Booted。Xcode list自动删除的tracked resolution文件已恢复baseline原字节，不混入本片。详见[脱敏动作摘要](./plans/20261009-action-verification.json)和[兼容矩阵](./plans/20261009-command-compatibility.md)。未声称业务ready或SDK26实测，未提交/合并/发布。

## 全能力接入启动（2026-10-09）

目标升级为官方Device Hub逐能力接入，不能将发现/模拟器生命周期切片叫完整支持。继续CLI/shared/schema，不新增GUI/hub根/强制Run；旧26命令保留。无真机写操作、无业务Simulator写操作、无提交合并发布。两次只读审计subagent均在返回前失败，不能当完成证据；主控直接核对官方目录与源码。

首片BDD：新增`device info --platform ios --device <selector> [--scope simulator|real|all] [--lock-state]`。信息命令不要求ready、不自动boot/pair/unlock，不推断锁状态为业务ready。CoreDevice details通过官方文件JSON解析，现代properties（包括null/partial）优先，旧格式保持兼容；只公开白名单硬件信息，不公开UDID/ECID/serial/IP/screenViewingURL/raw JSON。可选lockState只公开实际`passcodeRequired`和`unlockedSinceBoot`（缺失保持unknown），不将其伪装为screenLocked。目标身份不匹配、错误outcome、缺JSON/畸形JSON、backend失败必须失败而非回退成功；sourceCommands中所有private aliases脱敏。timeout要传到每次只读query；非iOS平台在调用backend前拒绝。模拟器CoreDevice查询要求其已启动，不能自动启动或将Shutdown失败静默降级。

Triton-first旧schema不含info，doctor与all discovery通过后回退只读Apple details/lockState help与JSON形状探测；当前27.1 details result为单记录/现代properties加旧镜像，lockState result含deviceIdentifier/passcodeRequired/unlockedSinceBoot。原始数据仅ignored私有目录，现有机器不是SDK26实测。完整能力矩阵及后续优先级将持续追加；首片完成不代表总目标完成。

[逐能力清单](./plans/20261009-full-capability-matrix.md)与[可复跑info验收](./plans/20261009-device-info-acceptance.py)为本轮事实入口。新增[shared info parser](../../../Sources/TritonKitShared/TKHostAdapterDeviceInfoModels.swift)、[CLI command/runtime](../../../Sources/TritonKitCLI/CLIHostDeviceInfoCommands.swift)、[output contract](../../../Sources/TritonKitCLI/CLISchemaDeviceInfoContracts.swift)。RED证明命令/schema缺失、physical旧alias不能校验其它record、结构化unsupported不能归为普通失败、error/result矛盾不能成功；全部有回归。实际真机readonly details+lockState已成功，专用Simulator锁查询CoreDevice1001明确unsupported，按structured file JSON映射稳定`unsupported_device_info_query`；不将此推广为全部Simulator永久限制。省略标志可独立查详情，不是失败后fallback。独立验收显式断言此限制与恢复专用实例，绝不将其当成锁查询成功。

本轮完整CLI1028 Swift Testing/84 suites＋14 XCTest、root287＋7、Release（124.18s）、真机只读/专用Simulator独立详情与unsupported边界/状态恢复实测通过；实际身份脱敏和0700/0600权限通过。[脱敏验收摘要](./plans/20261009-info-verification.json)记录完整事实。local依赖/DEBUG/root/Release（181.00s）/smoke/Harmony/iOS-runtime子门禁过，通用Simulator build明确skip，docs仍只因隔离基线缺181/182失败。后续public files/copy/manage/diagnose/rename help已保存，只算help-advertised-only，继续推进不complete。

## 第二批BDD：Simulator重命名

Given 公开simctl rename语法与已有sim schema缺项，When `sim rename <uuid> <name> [--timeout <seconds>] --json`，Then 独立提交一次目标明确的argv，不要求Run/boot，不删除/clone数据。显式UUID限定单设备，拒绝booted/all/real/无效ID；空白名称/控制字符和非正有限timeout在backend前拒绝。Unicode、空格、shell字面符号作为单个argv传递，不作shell解释。成功沿用host.action并仅表示提交；独立device list观察名称、canonical ID和state，专用实例验收最后恢复原名且其它实例不变。旧命令subset保留，schema usage/输出/错误码可发现；实测只在本次owned Simulator，无真机写。

第二批先RED2tests/4issues，focused CLI59＋shared1、完整CLI1033 Swift Testing/85 suites＋14 XCTest、root288＋7、Release131.74s全部通过。新binary在owned Shutdown实例执行Unicode重命名，独立device list证明name变更且ID/state不变；恢复原名后所有其它实例name/state不变。local产品子门禁过（Release178.80s），generic Simulator build明确skip，docs仍仅缺181/182基线。见[脱敏rename验收](./plans/20261009-rename-verification.json)与[可复跑脚本](./plans/20261009-simulator-rename-acceptance.py)。

files/DeviceFS只读审查subagent有closing，主控复核Apple文章并真实probe：owned Simulator的files返回CoreDevice1001 listFiles unsupported，mountpoint成功（result.dataPath），query后恢复Shutdown/其它实例不变；物理设备systemCrashLogs仅metadata shallow list成功，不取文件内容、不写设备。文件JSON result含deviceIdentifier/domain/files[]及每项metadata/name/relativePath/resources；原始标识/path/文件名仅私有0700/0600证据。下一片按[files/DeviceFS契约](./plans/20261009-files-devicefs-contract.md)推进，不统一unsupported crashLogs、不查temporary域、不用help代动作证据。

## 第三批BDD：device files浅层元数据

Given 已捕获physical crashLogs真实文件JSON及Simulator structured listFiles restriction，When `device files --domain-type appDataContainer|appGroupDataContainer|systemCrashLogs [--domain-identifier <id>] [--subdirectory <relative>] [--username <user>] --device <selector> --json`，Then 独立readonly file JSON query，显式no-recurse，不copy/创建temporary空间、不自动boot/pair/unlock/fallback；app域需要identifier，crashLogs不带identifier。非法path/domain/budget在discovery/backend前拒绝。绑定deviceIdentifier/domain，strict Bool/UInt metadata，无error/result矛盾成功。默认entry token及安全metadata，无原始名字/path/domainID/owner/xattrs/文件内容；显式include-sensitive仅开放name/relativePath，不开放device IDs或原始host mount路径。JSON byte和entry count是本地acceptance限制，不声称远端磁盘/遍历硬限额。真实只读physical验metadata，Simulator restriction必须明确失败且finally恢复专用实例。

第三批files已实现并真实验收：entry/schema RED4issues、parser/limit RED3、schema recovery family RED1（同步product诊断/plan分类，不削弱测试）；readonly审查有closing，目录/username错配先RED4issues再fail-closed，日期任意文本先RED1再ISO格式白名单。focused shared6/CLI81、完整CLI1046 Swift Testing/86 suites＋14 XCTest、root294＋7、Release129.75s过。新binary physical crashLogs浅metadata成功，count与private backend一致，raw identity及default name/path不inline，0700/0600真实验证，1byte实际limit返回device_files_limit_exceeded；owned Simulator files请求明确unsupported_device_file_query，finally恢复Shutdown，所有Simulator names/state不变。[脱敏验收](./plans/20261009-files-verification.json)/[可复跑脚本](./plans/20261009-device-files-acceptance.py)，[parser](../../../Sources/TritonKitShared/TKHostAdapterDeviceFilesModels.swift)/[runtime](../../../Sources/TritonKitCLI/CLIHostDeviceFilesRuntime.swift)/[contract](../../../Sources/TritonKitCLI/CLISchemaDeviceFilesContracts.swift)。无文件内容取得/真机写/temporary query；DeviceFS CLI、recursive/pagination与写policy等继续，不complete。

## 第四批BDD：独立DeviceFS mountpoint查询

Given owned Simulator native mountpoint成功且result只有dataPath（无设备identity），When `device mountpoint --platform ios --device <selector> [--scope simulator|real|all] [--timeout <seconds>] [--max-json-bytes <bytes>] --json`，Then 独立metadata query、不依赖files成功/Run/server，不自动boot/pair/unlock或替换backend；file JSON commandType/outcome必需成功，info.arguments唯一--device与本次实际raw请求精准匹配，error/result矛盾、missing/malformed/非零/超限/identity错配fail closed。dataPath为私有绝对规范路径，不公开或访问该路径，不创建文件内容/显式挂载或卸载/列目录（CoreDevice服务通信、日志及私有artifact仍有host副作用）、不启动Finder；公开仅target、opaque mountpointToken、private artifacts、sourceCommands设备ID脱敏、executed-file-json、businessReadinessVerified=false、hostFilesystemInspected=false、contentsListed=false。不得从returned path宣称路径存在、已挂载、可读/可写或所有Simulator文件访问unsupported。限制为local JSON acceptance，不是远端硬限。未知feature失败不猜unsupported映射。验收仅owned Simulator boot/query/finally恢复，names/state全体比较；真实物理mountpoint本片不做未授权写或隐式namespace操作。下一片再独立实现安全DeviceFS浏览，不直接拿不可信dataPath遍历。

第四批mountpoint已验，见[脱敏ledger](./plans/20261009-mountpoint-verification.json)/[复跑脚本](./plans/20261009-device-mountpoint-acceptance.py)、[shared protocol](../../../Sources/TritonKitShared/TKHostAdapterMountpointModels.swift)/[runtime](../../../Sources/TritonKitCLI/CLIHostDeviceMountpointRuntime.swift)/[contract](../../../Sources/TritonKitCLI/CLISchemaDeviceMountpointContracts.swift)。entry/schema RED3与parser实际shape/byte budget RED5，focused4/88→CLI1053＋14，补mandatory echo exact/optional primary UUID规范化/physical stale alias拒绝三向回归后CLI1054＋14（21.678s）/root298＋7过；Release145.79s、owned CLI metadata/private0700-0600/真实1byte拒绝及finally状态恢复过、全体name/state不变。两轮readonly审查有closing且无改写/执行；implementation审查对大小写的担忧经主控核对是既有primary UUID规范化（非alias），有三向测试证明不削弱echo严格性。local产品子门禁过（Release146.55s），genericbuild显式skip，仅known isolated docs181/182 registry gap，checker未改。无physical mountpoint query、返回路径访问/explicit mount-unmount/Finder/file contents。安全浏览、temporary side-effect policy、其它平台/配对等继续，完整目标active。

## 第五批：DeviceFS reader内部基础（公开CLI未接）

[reader安全边界BDD](./plans/20261009-devicefs-reader-boundary.md)/[实现](../../../Sources/TritonKitCLI/CLIHostDeviceFSReader.swift)/[测试](../../../CLI/Tests/TritonKitCLITests/DeviceFSReaderTests.swift)/[ledger](./plans/20261009-devicefs-reader-verification.json)。Owned mountpoint与metadata shape probe→finally Shutdown/所有names-state不变，无content/DeviceFS写/physicalquery；实际根不直接有DiagnosticReports，root是设备filesystem namespace，不能猜crash域。原设计subagent失败无closing，实际reader只读审查有closing，发现Darwin变长dirent不能先拷整d_name tuple、nilrelative path预算+1过严；补两测试RED3issues→raw指针指定nameoffset/count且record容纳NUL校验、准确分隔符预算、F_DUPFD_CLOEXEC。首次APFS非法UTF8 fixture无法创建是fixture错误不是product问题，改测实际name-byte decoder；守护页边界及FIFO/relative-path追加验证；reader9tests、完整CLI1063＋14（20.666s）/root298＋7、Release127.48s过，旧preaudit Release停止且不计postfix证据。仅private nonEncodable shallow metadata，未来public路径绑定/domainpolicy/DTO/schema与实测链路未完成，不当DeviceFS public能力已验。

## 第六批BDD：显式fs list mount-root浅metadata

Given当前设备选择和fresh严格绑定mountpoint私有payload，When `device fs list --platform ios --device <selector> [--scope simulator|real|all] [--include-sensitive] [--timeout <seconds>] [--max-json-bytes <bytes>] [--max-entries <count>] --json`，Then 独立且显式DeviceFS backend（不是files失败fallback）；仅mount-root一层metadata，不接受agent任意hostpath/relative目录，不猜App/crash/temporary域映射。nativepath须exact当前用户标准Library/Developer/CoreDevice/DeviceFS根及device-<UUID>.localized，UUID仅当前发现primary，Simulator可用本次发现aliases，physical不可stale alias；customroot/unknownUUID/其它设备根backend后reader前fail closed。从/全层nofollow descriptor遍历，最终device root归当前用户，再私有reader浅list；不打开内容/entrysymlink、不recursive、不创建temporary/Finder/explicitmount。不自动boot/pair/unlock。default token/kind/sizeOnlyRegular，名字仅include-sensitive；源命令只能生成command redaction，private JSON/log0700/0600不自动publish。timeout限mountpoint query，不声称阻断FUSE/readDir系统调用或远端hardlimit/原子snapshot。budgets beforeIO、超entries失败不partial；public flags contentsRead=false/recursive=false/businessReadinessVerified=false、hostFilesystemInspected=true但readWriteAuthorizationVerified=false。不把root名猜成domain，根列表完成不等于domain浏览/写policy完成。OwnedSimulator真实CLI root metadata/count/privacy/limit/finally恢复及全体names-state比较；本片不physical实测或业务实例动作。

第六批[fs list ledger](./plans/20261009-devicefs-list-verification.json)/[可复跑owned验收](./plans/20261009-devicefs-list-acceptance.py)/[runtime](../../../Sources/TritonKitCLI/CLIHostDeviceFSListRuntime.swift)/[schema](../../../Sources/TritonKitCLI/CLISchemaDeviceFSListContracts.swift)已验限定mount-root：entryRED3/runtimeRED8/ownerRED1→focused22→首次全CLI仅recoverytaxonomy RED1→product+taxonomy diagnose/plan修复→最新CLI1070＋14（19.156s）/root298＋7、Release193.99s；真实owned default/optin tokens一致/privacy0700-0600/entries1与JSON1拒绝/Shutdown恢复/allnamesstate不变。初验脚本substring词root碰到mount-root而误断，先确认finally状态恢复，再改exactJSON stringvalues+fields白名单成功复跑，不冒充product回归或隐藏失败；privateevidence保留。两次readonly设计/实现审查有closing/no writes-build-device，没有阻断实现问题；sourcequery stdout/physicalraw private，SimulatorUDID按原discovery合约公开，不笼统称全UUID脱敏。本片无domain导航/内容/recursive/temporarypolicy/physicalfs实测，全目标active。

## 第七批BDD：DeviceFS显式container namespaces

Given严格freshJSON/currentUUID标准设备根绑定，When `device fs list --view mount-root|app-data-containers|app-group-containers`，Then 默认mount-root兼容不变，新view仅将固定AppDataContainers/AppGroupContainers作为单组件relative目录，在同一FD链上先校验设备根owner、后nofollow打开namespace且finalowner检查；任意view/path/subdirectory/crash/temporary在parser前拒，scope/platform/budget前IO验证。只指定namespace一层元数据、不guess app/groupidentifier、不遍历container/root/tmp、不read content/leafsymlink，不recursive或fallback；defaulttokens/kind/regularsize、nameoptin。新namespace entries token须绑定view避免同name跨namespace碰撞，旧root token保持。readonly审查、owner-root/final/symlink fixture、viewdispatch/schema与currentfreshidentity回归，实际ownedSimulator两个namespace列表（零项也是成功空metadata，不冒充app存在）、privacy/count/budgets、finallyShutdown/allnamesstate比较；physical未查询，完整goal继续。

第七批[namespace ledger](./plans/20261009-devicefs-namespace-verification.json)/[真实CLI复跑](./plans/20261009-devicefs-namespace-acceptance.py)/[故障metadata诊断](./plans/20261009-devicefs-namespace-diagnostic.py)；entry/schema RED3、namespace/token RED5、真实rootownerbypass RED1（root/private/tmp owner与自有child相异）后fix同FDrootcheckpoint+finalowner。首新namespaceCLI actualread_failed，不用fixtures/readonlyclosing顶替；finallyrestore单独对全names-state后受限元数据诊断证native同FDtype=devicefs，readdir/stat合成inode不同且独立第二stat相同。purehelper实际shape RED1→仅exact fstatfs devicefs容许差异，所有FS双nofollowstat ino/dev/kind稳定、非devicefs保留dirent比较，noatomicSnapshot/mountprovenance/authclaim；DTO声明entryIdentityVerification。三view owned实际root4/data35/group34、default/optin tokens一致、privacy0700-0600/actualentries1与JSON1拒绝/allnamesstate Shutdown恢复过，postnativeCLI1076＋14（21.107s）/root298＋7/Release158.41s通过。后续只读审查指出helper承袭旧zero-dirent宽容不满足新严格表述，补RED5→移除非devicefszero豁免（Darwin readdir本就跳zero，不伪造已观测nativezero漏洞），更严完整CLI1076＋14（21.304s）/root298＋7/Release131.56s及三view owned实际CLI复跑通过；local产品子门禁过（Release184.23s）/genericbuild明确skip/仅isolated181/182docs缺号。审查另提artifact路径隐私经主控裁决：本机CLI有意给privatehost diagnostic refs、sourcecommand同类引用，不是nativeDeviceFS dataPath；不改既有契约，补输出refs允许/nativepath禁止测试，refs不得copy公开issue。bundle/groupID与crash导航、temporarypolicy未完成，全goalactive。

## 第八批 BDD：显式单容器浅metadata

- Given已有三固定view，When明确`--container-identifier <native-child-name>`，Then仅app-data/app-group view接受一个原始目录名组件（非path、不声称bundle/group身份/安装证明），mount-root组合冲突；omitted保持现有namespace输出及旧tokens。
- Given空/dot/dotdot/slash/controls/超过255UTF8bytes，WhenCLI或runtime执行，Thenparameter_conflict在discovery/artifact/runner/reader前拒绝且不回显输入；不自动补ID/选first/fallback。Unicode按原始bytes不normalize。
- Given合法nativechild，Thenfresh标准rootidentity不变，在同一FDchain root和每个relative层owner/nofollow检查，最终container浅metadata；不content/recursive/linktarget/任意subdirectory/temporary/Finder/explicitmount/autoprep，空成功不业务ready。
- Default不输出requestedidentifier/nativepath，以不含私名的directoryToken区分容器，entry token按view+container scope隔离；include-sensitive仅entrynames不泄漏container输入。same-name不同container tokens不同；旧namespace/mount-roottokens不变。
- Actualowned只从明确opt-in namespacemetadata选kind=directory的一个child，各view显式一次浅list（默认/optin/privacy/限额/privateartifact）；noinstall/launch/文件写，finallyShutdown及allnamesstate恢复。fixtures/readonly审查不顶替live。

第八批[container ledger](./plans/20261009-devicefs-container-verification.json)/[actual owned script](./plans/20261009-devicefs-container-acceptance.py)：入口/schemaRED2tests4issues，runtimeRED2tests44issues后实现`--container-identifier`私有单nativechild组件，不verifiedbundle/group身份。同FDroot及每relative层owner，255byte/NFC-NFD rawbytes+distinctcorrelation tokens、两层nofollow/FIFO/不读nested fixtures，最新完整CLI1083+14（25.411s）/root298+7过。初次actualowned两view单容器5/2项/defaultoptin stabletokens/private0700-0600/actualentries1+JSON1拒绝、finallyShutdown及allnamesstate恢复过；postcontract Release141.68s及owned相同5/2项privacy/budgets/allnamesstate恢复再验过；local产品子门禁过（Release191.21s）、genericSimulatorbuild明确skip，末尾仅已知isolated181/182docs缺号。构建曾变慢且观察到其它CPU/storage高负载，不推断因果、不停止其它用户进程、不在build中改Swift。readonlyreviewclosing/no写-build-device，非阻断255byte/NFDgap已补，不能chown伪造middle-ownerfixture，原root/finalowner测试保留且代码每层检查。leafname可与输入偶合是明确optin metadata非scope echo，schema/acceptscript按字段与leafnames whitelist而非整JSONsubstring判断，避免历史root误判重演。目录scope只directoryToken，不授权/秘密/physical-object-equality，omitted旧tokens不变。matrixpartial，arbsubdir/语义身份/crash/temporary等继续，fullgoalactive。

## 第九批 BDD：显式容器内相对子目录

- Given app-data/app-group view且explicitcontainer，When`--subdirectory <relative-directory>`，Then输入1...32原始组件/总UTF8<=4096/每组件1...255，无absolute/slash空段/dot/dotdot/control；omitted仍containerroot，不自动补容器，不normalize或URLdecode。无container或mountroot组合、非法片段在CLI discovery/runtime artifacts前parameter_conflict，静态hint不echo私输入。
- Fresh标准root/fileJSON+UUID不变，返回后在实际directory IO前再校验组合root+relative全深<=64/总bytes<=16384；同FD链每层owner/noFollow、leaf双noFollowstat浅metadata，不跟随symlink、不content/recursive/Finder/explicitmount/autoprep/fallback。相对appcontainer的tmp目录不等于DeviceFS Temporary域创建。
- directoryToken和entry scope加入精确subdirectorybytes；omitted保持旧root/namespace/containertokens。选择subdir/identifier不作为scope字段echo，onlyoptin leafnames（可偶合），token非秘密/认证/原生同对象证明。empty不业务ready。
- Tests：边界32vs33、4096vs4097、255vs256、NFC/NFD原始bytes、相同leaf不同子目录token、ancestor/container/selected symlink拒绝与浅非递归；actualowned仅从optin containermetadata明确选directory，各view一次default+optin子目录list/JSONlimit/实际entryoverflow若可证/privatepermissions/finally全namesstate恢复。不创建目录、安装launch或physical写，不以fixture/审查代替live。

第九批[subdirectory ledger](./plans/20261010-devicefs-subdirectory-verification.json)/[actualowned script](./plans/20261010-devicefs-subdirectory-acceptance.py)：入口RED2tests3issues、runtime宏try修正后实际RED4tests33issues；fullCLI先行唯一失败是旧subdirectory unknown-option断言，更新为unknownhostpath且实际非法组合parameter_conflict保留，不skip功能checker。可预测标准root36-byte UUID形状64depth/16384bytes pre-discovery/artifact加强（spyRED1issue→fix，占位不IO/identity），fresh实际root仍exactbinding/budget再验；第一readonlyreview误读>=ownerpredicate为root/final-only，由主控actualread/第二review裁决不采纳，所有relative层仍同FDowner/nofollow，system祖先只nofollow。主控真实复现Swift canonicalUnicode String prefix/equality接受NFC/NFD不同homebytes（RED1test2issues）→UTF8prefix/suffix精确匹配，不normalize原路径、UUID等价不变；组合exact64/16384纯budget补测非nativeNAME_MAX/path存在证明，middleowner无privilegedchown不伪造。

最新完整CLI1092/91suites（21.017s）+14XCTest、root298+7、Release124.94s通过；bytefix后owned双view选中已存在子目录实际2/2项，defaultoptin fresh目录/entrytoken稳定且区别containerroot/private0700-0600/实际entries1+JSON1拒绝/最终Shutdown/allSimulatornamesstates恢复过；local产品子门禁过（Release174.94s）、genericSimulatorbuild明确skip，末尾仅既有isolated181/182docs缺号，未改checker。仅selecteddirectory浅metadata、不selectionfield echo、onlyoptinleafname（可偶合）/rawsubdirscope/nil旧tokens；无content/recursive/outsidecontainer/Temporary-domain创建/Finder/explicitmount/autoprep/fallback。全matrix仍partial，语义bundle/group/crash/temporarypolicy及其它平台动作继续，goalactive、未提交发布。

## 第十批 BDD：pair/unpair/diagnose 独立只读计划

- Given explicit fresh-discovered iOS real target，When`device pair|unpair|diagnose --plan-only`，Then仅生成policyreview、不执行拟定native动作；omittedplan/non-iOS/non-real/invalidtimeout/诊断missingoutput在discovery/help前parameter_conflict。与已有`sim pair/unpair/diagnose`不同，不删除旧26入口，不requireRun/server。
- SDKhelp pair/unpair `manage ... --device`，diagnose只有单显式`--devices`且`--archive-destination`/`--no-finder`/`--no-include-host-sysdiagnose`；诊断JSON必须path非stdout。诊断仍可能包含hostCoreDevice logs，关闭hostsysdiagnose不等于device-only，archive覆盖/permissions/NOFOLLOW/限额/内容scope/授权及fileJSON动作postconditions未验，executability始终false。
- Private plannedTKHostCommand只在memory，主identity和诊断输出都redacted，publictarget再生成ios-real hash、不输出rawaliases/names/inputpaths；JSON/log用planned-private placeholders，不分配动作artifacts、不inspectpaths、不mountDDI，不记录credentials。metadata discovery/help的service/cache sideeffects如实保留。
- Requiredflags当前SDKhelp可广告时提供redactedplannedSourceCommand；缺flags仍可生成ok policyreviewplan，但supported=false、plannedcommand=nil/blockers显式，无尝试或替代backend重试。help-advertised-only不动作/配对/诊断archive/business验收；三命令只plan不能执行，noexecutionrunner API。TDD验证语法/schema、beforeIO guards、单target诊断/安全flags、secretredaction、missingSDKhelp、maliciousnativearg及未知operation；真实CLI只meta计划/preflight，无真机pair/unpair/diagnose。

第十批已通过policy-plan-only验收：[ledger](<./plans/20261010-device-administration-verification.json>)。Entry实际RED2tests7issues，runtime实际RED3tests48issues（uninitialized ArgumentParser fixture修正非functionalRED）；readonly审查发现resolver错误透传privacy真实gap，主控补实际RED1test11issues后全部错误仅保留稳定code与静态message/hint、不rawlogs/paths/candidates，JSONmissing/parser/timeout/nonzero/NSError/ambiguous六分支及实际CLI missing-selector单JSON/privacy过。最新CLI1098+14/93suites（22.381s）、root298+7、Release150.99s过；currentSDK三命令真实fresh-real policyplan均help广告/preview脱敏、executed/executable=false/privatearchive未创建。首次PATHwrapper脚本trace空是固定/usr/bin/xcrun导致的验收设计错，不修改安全解析或伪称trace；新script明确source/DI/actualenvelope分层，不能算动作/physicalstate。第一次postprivacyfull遗漏TRITON_CLI_PATH造成10fixturebinarymissing，恢复显式路径后全过，未削弱测试。local产品子门禁过（Release194.93s），genericSimulatorbuild明确skip，仅既有SP181/182隔离docs缺号；本片无Simulator生命周期/真机写/diagnose采集，完整goal仍active，下一Apple平台模型报告/语义ID/crash/temporary/acceptednativebackend与archivepolicy继续，未提交发布。

## 第十一批 BDD：Apple平台目录及只读Simulator平台计数

Given legacy ios namespace/IDs/argv保持，When独立`device platforms --json`，Then静态catalog涵盖ios/ipados/watchos/tvos/visionos/macos，明确partial/shared-ios-adapter/gap/workflow-only与plan-only、不当前SDK/device/action/business保证；默认zero host queries。`--apple-platform`仅筛catalog（unknown拒绝），不是新`--platform`控制路由。When显式`--inventory`，Then只读已available Simulator JSON一次（无boot/physicalquery），按严格native runtime标识ASCII numericversion分类ios/watchos/tvos/xrOS-or-visionOS，其它unknown；不deviceName猜iPadOS、Mac或读全Applecapabilities自动enable。计数是availableSimulator metadata非物理inventory，也不以0证明平台不可用。catalog筛选不缩窄SDK查询或改变全局计数。无IDs/names/rawruntime/target/candidates/logs/path inline；所有inventory失败静态message原稳定code。schema/actualCLI默认和inventory/错误单JSON，解析未知参数、fixtureunknown/恶意runtime/私label、filter与provider计数、full/root/Release/local/docs/skills/memory验收；不要求server/Run，不改旧输出模型。

第十一批验收完成：[ledger](<./plans/20261010-apple-platform-verification.json>)。Entry实际RED2tests3issues、runtimeRED4tests17issues后最小实现；CLI1104+14/95suites26.331s、root298+7、Release188.48s过；actualcatalog六family/watchfilter/defaultemptyinventory/unknown单parameter_conflict/一次availableSimulator实际15条聚合privacy过，没有IDs/name/rawruntime/physicalquery或boot/control。零默认query与filter preIO计数由source/DI证实非externaltrace，0count不SDK不可用、iOS runtime不iPadOS/设备硬件证明。catalog control/auth false仅本报告未验授权非旧功能denial。local产品子门禁过（Release211.16s）、genericSimulatorbuild明确skip，仅隔离既有181/182docs缺号；source/目标模型/旧命名空间IDs/argv保持，rootShared无新依赖。下一physical/逐target硬件platformprovenance、专门控制、语义ID/crash/temporary/acceptedadministration execution继续；无生命周期/真机写/采集/SDK切换/提交发布或installedCLI替换。

## 第十二批 BDD：device info逐目标硬件观察来源

Given fresh identity-bound existing device info JSON，When读取hardware.platform/deviceType/reality，Then新增optional hardware.platformObservation，仅显式exact已知SDK白名单映射systemFamily/deviceFamily/reality与modern/legacy来源；不name/marketing/productType/runtime/capabilities或旧target.platform ios默认值推断。reported iOS+iPad deviceType仍systemFamily ios/deviceFamily ipad，不擅自改成iPadOS；未知/null/非法值不回显原值、不falsephysical。properties只要present（null/partial/wrongtype）即不复活deprecatedhardwareProperties。CLI沿用既有freshselection/details identity匹配、sourceprivacy、old IDs/argv/dispatch行为，不因metadata给控制授权/业务ready；old Codable hardware缺新optional字段仍decode兼容。先实际RED/后最小Shared解析DTO及CLI nested schema传播，现代/旧镜像冲突/unknown/非ASCII或private字段/unsupportedfamilies回归，actualreadonly physical info不write/pair/boot；fullCLI/root/Release/local/docs/skills写回。

第十二批验收完成：[ledger](<./plans/20261010-hardware-observation-verification.json>)。shared实际RED5tests19issues、CLI metadata schema实跑14tests其中1fail3issues，nestedruntime先已green；最小exactASCII解析DTO/optionaloldCodable/nested schema传播后CLI1104+14/95suites22.054s、root303+7（knownfamilies追加所有device spellings后再全跑）、Release150.10s过；actualfreshprimary-bound iOS/iphone/physical modernhardware observed，不control/business/硬件真实性或全部family验收。oldlegacy layouts/privateunknown/nullpartial-modern覆盖及oldID/argv/dispatch不变；无rootCLI-only依赖。local产品子门禁过Release176.87s、genericSimulatorbuild明确skip；自建private日志含-final触发既有traceable-name门禁，经检查精确absolute源/目标路径后改为knownfamilies保留证据，未削弱checker，修正后directdocs复验应仅既有181/182isolatedgap。README/dev/四skills/M镜像/matrix写回，无Simulator lifecycle/physicalwrites/diagnosecollection/SDKswitch/提交发布/installedCLI替换。下一nonIOSphysical发现/selection及perfamilyprovenance接受、专门控制、语义ID/crash/Temporary/administrationexecution继续active。

## Remaining risk

发现/选择、专用Simulator生命周期和新增只读info为当前切片，不声称全能力Device Hub、UI控制、输入、屏幕、真机端到端或业务ready。锁状态缺失仍未知，preparednessState未公开枚举不得推断；不新增映射的设备能力不能因Apple capability名称而自动启用。跨平台无显式platform的best-effort发现保持既有契约，本期严格完整性针对显式iOS scope=all。

## 实现入口

- [shared parser](../../../Sources/TritonKitShared/TKHostAdapterDevicectlModels.swift)
- [shared匿名测试](../../../Tests/TritonKitSharedTests/TKDeviceHubOfficialAdapterTests.swift)
- [host discovery](../../../Sources/TritonKitCLI/CLIHostDeviceRuntime.swift)
- [CLI测试](../../../CLI/Tests/TritonKitCLITests/DeviceHubDiscoveryTests.swift)

## 四批实际能力推进（2026-10-10）

以[四批实施与验收](./plans/20261010-capability-batches.md)和[能力矩阵](./plans/20261009-full-capability-matrix.md)为当前事实。SDK bundle/group 原生容器绑定独立于 DeviceFS 名称；Temporary 明确可能创建、完整策略/审计前拒绝；管理动作仅隔离fixture；专门平台后端缺口诚实保留。基线SP-181/182已存在，本轮补登记解除旧docs索引缺口；主工作区既有三处UU保持原样。

## 2026-10-11 真实验收启动

见[真实验收执行记录](plans/20261011-live-platform-acceptance.md)。双平台独立 App/XCTest 已实际 build-for-testing，通过不等于动作验收；无 runtime 不创建业务实例替代。
