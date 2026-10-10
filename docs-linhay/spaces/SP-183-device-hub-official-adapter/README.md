# SP-183 Device Hub 官方设备能力适配

> 建立2026-10-08，更新2026-10-10；状态：全能力接入中／独立worktree未集成；本次用户授权本地整理提交，不推送/合并/发布，不以切片称完整；local文档子门禁受隔离基线缺号影响。

[会话沉淀与四批后续计划](<../../../../TritonKit-worktrees/SP-183-device-hub-official-adapter/docs-linhay/spaces/SP-183-device-hub-official-adapter/plans/20261010-session-recap-v01.md>)：容器语义/Crash/Temporary → 管理执行后端 → 专门平台控制 → 全矩阵收口。主仓混合研究、索引和memory不进入本次分支提交；原始证据保持ignored，历史未提交语句仅当时快照。

## Requested

用户先对接 Device Hub，并选择「官方设备能力」：统一设备发现、目标身份、就绪状态和 Xcode 27 devicectl JSON 兼容。复用既有 `device / target / app` 入口，不新增窗口或 `hub` 根命令；单点命令保持可自由组合。

## 边界

- 影响 shared parser、macOS CLI host adapter、机器可读 schema 与测试；不改 embedded/UI/HTTP 产品面，不实施SP-182架构。
- 官方 `devicectl` 管理设备，`simctl` 保留模拟器枚举与生命周期职责；details release notes不单独证明list shape，实际只读capture为证。
- 保留旧版 payload、paired lazy tunnel及其他平台兼容。未知身份/平台/状态/就绪不得自动成为ready；物理ready仅development-service eligibility，不证明锁状态、App runtime或业务成功。
- 真机仅既有只读发现兼容，不新增远控能力；不安装/启动/停止/输入/改偏好或配对设备。
- 不提交、推送、合并、发布，不替换安装CLI；不覆盖或复制主工作区已有SP-181/182未提交文档。

## 工作区

- 基线：`0231d8833eefae8ccb54207390f2171c7979c41d`。
- branch：`feat/SP-183-device-hub-official-adapter`。
- worktree：`../TritonKit-worktrees/SP-183-device-hub-official-adapter/`。
- 主仓仅登记、memory与ignored私有capture；代码、schema、测试、skill与详细记录在[独立worktree space](../../../../TritonKit-worktrees/SP-183-device-hub-official-adapter/docs-linhay/spaces/SP-183-device-hub-official-adapter/README.md)。后续集成需逐文件核对，不能覆盖主仓183条登记。

## BDD / TDD结果

1. 旧v3 paired/lazy tunnel与显式DDI blocker兼容通过。
2. 实际JSONv5包含5simulated+3physical；旧安装CLI0.2.22误投影8real，加入14simctl条目共22。新本轮Release构建（开发版本`0.1.0-dev`）只读验收返回14simulator+3real，共17个唯一目标。
3. `properties`存在即权威，包括空/null/partial；不以旧镜像补ready。现代hardware reality判kind，typed OS/developer mode正确解析；未知状态与非法identity/failed outcome拒绝假成功。
4. 显式iOS all后端失败不吞掉；canonical `sim:<UDID>`去重，simctl生命周期优先，同时保留CoreDevice私有alias。公开JSON不包含raw alias。
5. typed simulator无显式scope只走simctl；typed real只走CoreDevice，未知raw iOS selector仍需all；跨平台未指定platform的既有best-effort未改。
6. 本轮CLI仅发现/解析和错误验收，不启动App/设备，不建立输入/屏幕会话，不声称业务就绪。

## 验证

| 验证 | 结果 |
| --- | --- |
| 最终focused | shared54、CLI173，exit0 |
| 完整CLI | 显式本轮`TRITON_CLI_PATH`＋`--no-parallel`：1002 Swift Testing/80 suites＋14 XCTest，0fail |
| 根包测试 | 281 Swift Testing＋7 XCTest，0fail |
| 本地产品子门禁 | 依赖边界、DEBUG隔离、Release CLI build/smoke、Harmony host smoke、iOS runtime observe smoke通过 |
| 真实只读CLI | all/real/simulator、schema、模拟器target解析exit0；不存在sim selector仅一个合法失败JSON，预期exit1 |
| 完整local门禁 | exit1：先修正登记链接label，再确认隔离分支SP-181/182缺号；未跳过或放宽原检查 |

完整CLI默认并行首轮还出现缺built-binary路径及既有全局stdout/deadline干扰，失败run取消后仅清理已确认属于本任务的孤儿SwiftPM/helper，不停其他进程、不删除锁或cache。串行通过不等于并行suite已修复。`TRITON_VERIFY_XCODE=0`主动跳过非本片的iOS Simulator工程构建，不将skip算成功。

### 文档门禁条件

主仓含183个space；独立基线仅180个，加本片为181个。原检查要求物理目录与编号连续，故隔离分支严格文档门禁不能通过。保持这项可复现限制，集成主仓已有SP-181/182后再复验完整local；不为绿灯复制无关未提交研究或修改checker。主仓最终`verify.sh --ci-docs`、`check-docs.sh`与`git diff --check`均exit0（183spaces），[每日memory](../../memory/2026-10-08.md)已写回；这不替代隔离分支集成后完整local复验。

## 新旧Xcode命令兼容补片（2026-10-09）

保留共用simctl/devicectl argv和文件JSON，未按版本号臆造新版命令。新doctor按scope查询nested help与必需参数，公开commandSupport/help-advertised-only；simulator不依赖CoreDevice，real不查询simctl，all缺CoreDevice不再误报ok。版本探测经xcrun尊重选中DEVELOPER_DIR，未切全局Xcode或重试写动作。

补片新增9项命令契约测试，完整串行CLI1011 Swift Testing/81 suites＋14 XCTest、root281＋7、Release构建通过。本机Xcode27.1/27A9275的三scope doctor与只读发现再验通过，仍14simulator＋3real/17唯一目标。常见安装目录仅找到一个Xcode；旧工具链只有合成help、既有argv/旧JSON及环境配置fixture覆盖，**未做旧Xcode真实运行**，也未执行boot/install/launch。

[兼容矩阵与复跑方法](../../../../TritonKit-worktrees/SP-183-device-hub-official-adapter/docs-linhay/spaces/SP-183-device-hub-official-adapter/plans/20261009-command-compatibility.md)与[补片memory](../../memory/2026-10-09.md)已写回；独立分支docs缺号及既有并行suite风险不变，未提交合并发布。

## Xcode26旧命令保留与授权动作继续（2026-10-09）

用户明确旧26命令保留即可，不要求安装旧SDK。新增固定sim/app/device/xcode共67项注册（含隐藏兼容命令）及旧单点参数回归，不强制Run。第一轮误用原有Shutdown标准设备而非新建专用实例，已移除本次测试App、恢复Shutdown，不计隔离验收；随后通过Triton新建专用实例，单点完整生命周期通过。专用高级run发现timeout只作用build/settings；先RED两处，再两行withTimeout修复install/launch，nil保持默认及metadata。超时安装只读确认已完成后才卸载本次App，不盲重装。

最终focused12、完整CLI1014 Swift Testing/83 suites＋14 XCTest、Release及专用实例高级build/install/launch通过；App info/terminate/uninstall通过，最终user apps=0、Shutdown并保留供复验，已有业务booted目标仍Booted。截图黑屏不算业务渲染证明。Xcode list更改的resolution已恢复baseline，不混入任务。详见[脱敏动作验收](../../../../TritonKit-worktrees/SP-183-device-hub-official-adapter/docs-linhay/spaces/SP-183-device-hub-official-adapter/plans/20261009-action-verification.json)。未操作真机、全局Xcode、提交合并或发布；旧SDK26非实测。

## 全能力接入进行中（2026-10-09）

用户要求开始完整接入，目标保持active，不以发现或生命周期首片称完整。主控建立[逐能力矩阵](../../../../TritonKit-worktrees/SP-183-device-hub-official-adapter/docs-linhay/spaces/SP-183-device-hub-official-adapter/plans/20261009-full-capability-matrix.md)，分清implemented/partial/missing/no-public-backend-evidence/platform-unsupported。本轮新增`device info --platform ios --device <selector> [--lock-state] --json`及shared白名单parser：不要求Run/ready，不自动boot/pair/unlock；现代properties优先，身份不匹配、backend失败或JSON异常fail-closed，所有raw identity/alias/serial/IP/URL保持私有。

先RED命令/schema4issues，再实现；审查发现错误physical记录可凭旧hardware alias通过，补RED1issue修复。完整CLI1028＋14、root287＋7、Release通过；[脱敏info验收摘要](../../../../TritonKit-worktrees/SP-183-device-hub-official-adapter/docs-linhay/spaces/SP-183-device-hub-official-adapter/plans/20261009-info-verification.json)保存完整事实与未完成边界。真实只读真机details及lock-state已通过，实际字段是passcodeRequired/unlockedSinceBoot，不是screenLocked/业务ready。专用Simulator details可读，但实际lockState query返回CoreDevice1001 capability unsupported；保留失败并恢复Shutdown，不伪装成功，结构化unsupported错误映射及独立验收已通过；所有其它Simulator状态不变，私有artifact权限0700/0600与实际身份脱敏通过。local产品子门禁过，docs仅隔离基线缺181/182失败。真机无写动作。后续files/DeviceFS/配对诊断/平台和GUI-only调查继续；无提交合并发布。

第二批新增独立`sim rename <uuid> <name> [--timeout <seconds>] --json`，显式目标、opaque Unicode、invalid name/timeout before IO，无Run/boot/clone/delete。RED4issues→focused59/shared1、CLI1033＋14/root288＋7/Release131.74s过；owned Shutdown实例新名独立list观察并恢复，ID/state与其它实例name/state不变。local产品子门禁过（Release178.80s），docs仅隔离基线缺号。[rename验收](../../../../TritonKit-worktrees/SP-183-device-hub-official-adapter/docs-linhay/spaces/SP-183-device-hub-official-adapter/plans/20261009-rename-verification.json)保存事实。files/DeviceFS审查与实际只读probe已完成：owned Simulator files=CoreDevice1001 listFiles unsupported、mountpoint=success，恢复Shutdown；physical systemCrashLogs浅metadata list=success，无内容获取/设备写。接着按[files契约](../../../../TritonKit-worktrees/SP-183-device-hub-official-adapter/docs-linhay/spaces/SP-183-device-hub-official-adapter/plans/20261009-files-devicefs-contract.md)实现，不把public backend probe称Triton完整能力。

第三批`device files` shallow metadata已通过新CLI实测，覆盖三个readonly域的机器契约；temporary仍需side-effect policy。Default tokens/安全metadata，不inline names/path/owner/xattr/content/rawID；include-sensitive只给file names/relative paths。绑定设备/domain/App ID及requested目录/用户，strict Bool/UInt/ISO日期、local JSON/count接受限额、不copy/auto boot/pair/unlock/fallback。RED4entry+3parser+1taxonomy+4namespace+1date，focused6/81、CLI1046＋14/root294＋7/Release129.75s过；physical crashLogs浅metadata/实际privacy0700/0600及1byte limit拒绝过，owned Simulator restriction明确unsupported_device_file_query并finally恢复Shutdown，全部names/state不变。[files验收](../../../../TritonKit-worktrees/SP-183-device-hub-official-adapter/docs-linhay/spaces/SP-183-device-hub-official-adapter/plans/20261009-files-verification.json)。local产品子门禁过（Release185.67s），generic Simulator build显式skip，docs仍仅隔离基线缺181/182。后续DeviceFS mountpoint、recursive/pagination、temporary/write policy、配对诊断/平台继续，goal active。

第四批独立`device mountpoint`已实现并通过owned Simulator CLI真实验收：result无identity，严格commandType/outcome/唯一实际raw --device回显绑定；native dataPath仅私有JSON，公开token与private artifact refs，不访问/归一化/stat/realpath/list该路径，不Finder/显式mount-unmount/auto boot-pair-unlock/fallback。filesystem/mount/content/business验证均false；服务通信/日志与artifact仍有host副作用。entry/schema RED3、parser实际shape/预算RED5→focused4/88、最新CLI1054＋14/root298＋7、Release145.79s过；实际private0700-0600/1byte拒绝/onlyowned恢复Shutdown，所有names/state不变。只读实现审查closing里UUID大小写建议经主控核对是同一primary UUID规范化（非跨identity alias），补三向测试：optional同UUID容许、mandatory echo大小写仍exact、physical stale alias拒绝。local产品子门禁过（Release146.55s）、genericbuild显式skip、docs仅isolated181/182缺号；[mountpoint验收](../../../../TritonKit-worktrees/SP-183-device-hub-official-adapter/docs-linhay/spaces/SP-183-device-hub-official-adapter/plans/20261009-mountpoint-verification.json)。仍无安全浏览/physical mountpoint实测/temporary写policy，全能力目标active，不complete。

DeviceFS安全浏览内部基础推进中：task-owned mountpoint metadata probe及root一层probe均finally恢复Shutdown/全体names-state不变，无内容读/DeviceFS写。实际root无直接DiagnosticReports，不能猜crashLogs映射；root内是设备filesystem namespace，不代表文档通用域模型已验。新增descriptor no-follow private reader，尚无公开fs CLI/DTO/schema/目标root-domain绑定；参见[安全reader边界](../../../../TritonKit-worktrees/SP-183-device-hub-official-adapter/docs-linhay/spaces/SP-183-device-hub-official-adapter/plans/20261009-devicefs-reader-boundary.md)。设计审查subagent失败无closing不计通过；新实际reader审查指出Darwin变长dirent不能整tuple值读取，另发现nil-relative路径预算+1过严，RED2tests/3issues后已修复（指定rawoffset/count字节、record/NUL、准确separator预算），guard-page短record、FIFO metadata、symlink/UTF8/path/depth/count及relative fixtures已跑完整CLI1063＋14（20.666s）、root298＋7、Release127.48s通过；只internal foundation非public reader验收。旧preaudit Release已停止不混作postfix证据。

第六批显式 `device fs list` mount-root浅metadata已验（非domain导航）：fresh私有mountpoint复用、标准父根/current-discoveryUUID绑定（physicalprimary-only/simUUIDalias）、保持原path字节、同finalFD owner/no-follow、default tokens/kind/regularsize、names opt-in、no contents/domain guessing/recursive/temporary/Finder/explicitmount/autoprep/fallback。entryRED3/runtimeRED8/ownerRED1→focused22→完整CLI1070＋14（19.156s）、root298＋7、Release193.99s过；fullCLI首次taxonomy RED1后diagnose/plan映射修复，不削弱checker。owned真实CLI root default/opt-in稳定token/privacy0700-0600/实际entries1和JSON1限制、finallyShutdown及全体names-state比较过；首脚本隐私substring误判root词与mount-root协议文本重合，改exactJSON string values+field白名单，第一次也独立确认已恢复再复跑。设计/实现readonly审查closing收到，无写/build/设备操作、不把审查代替livegate。参见[fs list ledger](../../../../TritonKit-worktrees/SP-183-device-hub-official-adapter/docs-linhay/spaces/SP-183-device-hub-official-adapter/plans/20261009-devicefs-list-verification.json)。域导航/temporary写policy/其它能力仍继续、goalactive、不提交发布。

第七批固定container namespace views已实现并初验（mount-root/data/group实际4/35/34），entryRED3/runtime-tokenRED5/rootownerbypassRED1后同FDroot-before-relative及finalowner修复。首actual namespace read_failed保留、finally后全names-state已复核；受限metadata诊断证同FDdevicefs syntheticdirent/statIDs不等、独立double-stat稳定。pureRED1后仅exactdevicefs放开dirent差异，所有FS双nofollowstat ino/dev/kind稳定，no atomic/mountauthclaim。后只读审查提出非devicefszero宽容，真实helperRED5后收窄；Darwinreaddir本跳zero，未假称nativezero漏洞。privateartifactrefs有意本机定位/sourcecommand引用，不是nativeDeviceFSdataPath，补允许refs/禁止nativepath测试；refs不得公开复制。最新完整CLI1076＋14（21.304s）/root298＋7，postfixRelease131.56s/三view实际CLI复跑过，local产品子门禁通过（Release184.23s），genericbuild明确skip，末尾仅isolated181/182docs缺号。namespace选项仅固定目录、不bundle/groupID/crash导航/temporarypolicy，不content/recursive/fallback/Finder/autoprep；见[namespace ledger](../../../../TritonKit-worktrees/SP-183-device-hub-official-adapter/docs-linhay/spaces/SP-183-device-hub-official-adapter/plans/20261009-devicefs-namespace-verification.json)，全goalactive、不提交发布。

第八批`--container-identifier`显式appview单nativechild浅metadata，非verifiedbundle/group identity，不arbitrarysubdir。entryRED4/runtimeRED44后pre-discovery/artifact one-component1...255UTF8bytes/no dotdot/slash/control/no normalization、sameFDroot及每relative层owner/nofollow；directoryToken/entryviewsalt保私有selector，omitted旧tokens不变。最新fullCLI1083+14（25.411s）/root298+7及255byte/NFC-NFD原始bytes/两层FIFO-link-nested fixtures过，先行owned app/group单容器实际5/2项/private0700-0600/defaultoptin tokens稳定/actualentries1+JSON1拒绝/Shutdown/allnamesstate恢复；最新postcontract Release141.68s及owned5/2项privacy/budgets/allnamesstate恢复再验过，local产品子门禁过（Release191.21s）、genericSimulatorbuild明确skip、末尾仅既有isolated181/182docs缺号；不以readonlyclosing顶替live。见[container ledger](../../../../TritonKit-worktrees/SP-183-device-hub-official-adapter/docs-linhay/spaces/SP-183-device-hub-official-adapter/plans/20261009-devicefs-container-verification.json)。leafname与selector偶合可explicitoptin，仅不echo scope字段；不内容/递归/安装launch/physicalwrite/Finder/autoprep/fallback，不atomic/mountauth/businessclaim。arbsubdir/语义身份/crash/temporary/其余matrix继续，goalactive、未提交发布。

## 第九批：显式容器相对子目录浅metadata

`device fs list ... --container-identifier <native-child-name> --subdirectory <container-relative-directory>`已接入appviews，原始1...32组件/4096UTF8bytes/255每组件，无absolute/dot/dotdot/empty/control、不normalize/URLdecode；输入+标准root形状64depth/16384bytes beforediscovery/artifact（UUID模板不IO/identity），fresh实际UTF8parent/currentUUID绑定及组合重检在directoryIO前，同FDroot/每relativeowner/nofollow+双leafstat、onlyselecteddirectory浅metadata，默认输入fields/names私有、optinleafnames可偶合，exactsubdir scope tokens/nil旧算法兼容。无outsidecontainer/content/recursive/Temporary域创建/Finder/autoprep/fallback，非verifiedbundle/group身份或业务proof。

entry真实RED2tests3issues、runtime编译修正后实际4tests33issues、预算spyRED1issue与UTF8homeNFC/NFDauthorityRED2issues后fix；新CLI1092+14/root298+7/Release124.94s过，bytefix后owned双view实际子目录2/2项/defaultoptin token稳定且区别parentcontainer/private0700-0600/actualentries1+JSON1拒绝/Shutdown/allnamesstates恢复过。local产品子门禁过（Release174.94s）、genericSimulatorbuild明确skip、末尾仅既有isolated181/182docs缺号。第一review错读>=ownerpredicate已由主控/第二review裁决，未改正确root及每relative owner逻辑；组合64/16384等纯边界补测，不伪造middleUIDchown。见[subdirectory ledger](../../../../TritonKit-worktrees/SP-183-device-hub-official-adapter/docs-linhay/spaces/SP-183-device-hub-official-adapter/plans/20261010-devicefs-subdirectory-verification.json)。完整goalactive，语义ID/crash/temporary及其余matrix继续，未提交合并发布或installedCLI替换。

## 第十批 administration 独立只读计划（非操作完成）

Given explicit fresh iOS real target，When `device pair|unpair|diagnose --plan-only --json`（diagnose还需privateZIP --output），Then仅policy review，always executable/executed=false；old sim/26 argv保留、no mandatoryserver/Run。缺plan/nonios/nonreal/无selector/invalidtimeout/output在discovery/help前拒绝；freshprimary rehash、previewtarget/destination脱敏、SDKhelp exactflags仅advertised，不配对/采集/Finder/profile/DDI或存凭据；diag关闭hostsysdiagnose仍可能hostCoreDevlogs，不device-only/crash等价。metadata service/cache effects如实。SDKunsupported仍ok仅policyplan/support=false/no preview/blockers，execution/auth/audit/nativefileJSON/postconditions/archivecontent/permissions/nooverwrite/nofollow/size未accepted。

Entry实际RED2tests7issues/runtimeRED3tests48issues后最小实现；审查privacy真实gap：resolver错误原样透传，补RED1test11issues后统一静态message/hint、原稳定code、不rawlogs/candidate/path，六类失败fixture与真实missing-selector单JSON/privacy过。最新CLI1098+14/93suites22.381s、root298+7、Release150.99s过；actualfresh-real三plan均当前SDKhelp广告、previewredaction/executable-executedfalse/archive未创建（不是physicalaction/state验收）。PATHwrapper trace因固定/usr/bin/xcrun为空，保留失败/纠正script证据分层，不改安全resolver或伪称trace。遗漏TRITON_CLI_PATH的10fixturebinarymissing失败后显式路径重跑全过。local产品子门禁过Release194.93s，末尾仅既有isolated181/182docs缺号，genericSimulatorbuild明确skip；本片不Simulator生命周期/真机写/diagnose采集。见[第十批ledger](<../../../../TritonKit-worktrees/SP-183-device-hub-official-adapter/docs-linhay/spaces/SP-183-device-hub-official-adapter/plans/20261010-device-administration-verification.json>)。目标仍active/未集成发布，Apple平台报告/语义ID/crash/temporary/acceptedexecution与archivepolicy继续。

## 第十一批 Apple平台目录与可选Simulator metadata计数

Given oldios namespace/IDs/argv保持，When独立device platforms --json，Then六family compiledintegration catalog，默认zerohostquery，--apple-platform只filtercatalog，--inventory一次availableSimulator readonly JSON/globalOSfamilycounts。只runtime exactASCII numericversion分类ios/watchos/tvos/xrOS-or-visionOS，unknown保留/no name-ID-rawruntime；iOS不证明iPadOS或iPhone-iPad、不假定MacSimulator，0非platformunavailable，不cap数组/genericcmd自动enable。report control/auth false只是本报告未验授权，非旧actiondenial；SDK/action/business/physicalinventory/provenance不承诺，失败staticmessage原稳定code/no logs-path-candidates，无server/Run/physicalquery/boot/control。

Entry实际RED2tests3issues/runtimeRED4tests17issues→CLI1104+14/95suites26.331s、root298+7/Release188.48s过；actualcatalog六family/watchfilter/unknown单JSON及一次availableSimulator实际15条计数privacy过，defaultzeroquery/filter preIO由source/DI计数证明，不externaltrace；local产品子门禁过Release211.16s，genericSimulatorbuild明确skip，仅既有isolated181/182docs缺号。physical/逐target/hardware平台provenance、specializedcontrols、语义ID/crash/Temporary/administrationacceptedexecution继续全goalactive；不Simulator生命周期/真机写/diagnose采集/SDK切换/commitmergepublish或installedCLI替换。见[第十一批ledger](<../../../../TritonKit-worktrees/SP-183-device-hub-official-adapter/docs-linhay/spaces/SP-183-device-hub-official-adapter/plans/20261010-apple-platform-verification.json>)。

## 第十二批 device info硬件观察来源

Given freshprimary identity-bound info，Then optional hardware.platformObservation仅exactASCII explicit hardware platform/deviceType/reality，modern/legacy source；iOS+iPad保留ios/ipad，不name/product/marketing/runtime/cap/旧ios假设OS/iPadOS/physical，unknown原值不在观察DTO回显，modernpresent/null/partial禁deprecatedfallback。old hardware Codable缺字段nil-compatible；旧命名空间ID/argv/dispatch不改，不action/business/硬件真实性证明。当前physicaliOS info回报ios/iphone/physical/modern，其他family仅fixtures。

shared实际RED5tests19issues、CLI schema实跑14tests1fail3issues（nestedruntime已green）→CLI1104+14/95suites22.054s、root303+7、Release150.10s过；knownfamilies所有device spellings追加后再full；local产品子门禁过Release176.87s/genericSimulatorbuild明确skip，自己private-final日志触发traceable-name门禁，精确absolute源/目标检查后改为knownfamilies并保留记录、不改checker；postrepair directdocs复验仅既有181/182isolatedgap。见[第十二批ledger](<../../../../TritonKit-worktrees/SP-183-device-hub-official-adapter/docs-linhay/spaces/SP-183-device-hub-official-adapter/plans/20261010-hardware-observation-verification.json>)。no生命周期/真机写/diagnose采集/SDKswitch/commitmergepublish/installedCLI替换；nonIOSphysical discovery-selection/perfamilylive、专门control、语义ID/crash/Temporary/adminexecution/fullmatrix继续active。

## 原发现兼容切片验收状态（非全能力）

- [x] 官方契约及本机Triton-first facts保存，敏感标识仅本地。
- [x] 先失败测试再实现，合成new-only与本机mixed shape明确区分。
- [x] focused、完整串行测试、产品门禁与只读本轮binary验收通过。
- [x] schema/README/内部和公共skill、space及memory同步，无提交发布。
- [ ] 集成后完整local文档子门禁：待SP-181/182进入同一基线后复验。
