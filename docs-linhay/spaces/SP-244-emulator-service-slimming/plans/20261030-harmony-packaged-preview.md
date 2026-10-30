# 第六轮：鸿蒙与打包版真实预览验收

2026-10-30。用户明确要求继续真实验证鸿蒙和打包版，出现问题直接修复。本轮沿用SP-244 worktree，影响层为已有只读Web packaged HTTP路由和截图流生命周期；不新增业务写操作、远端能力或发布版本。

## BDD与验收

- 本机Harmony真实模拟器先Triton-first确认身份、可用性与截图；源码Web真实显示、后台/窗格隐藏停止采集、恢复保留目标/FPS、新连接出图。
- CLI与Web静态资产组成仓库外独立本地候选包，按发行目录结构启动，不传源码/内部Web路径覆盖；先证明mode=packaged、readonly=true，再校验HTML/JS/CSS和真实浏览器。
- Android/Harmony的预览路由不得落SPA HTML fallback；缺参/非法值返回单一JSON错误，不以200 HTML冒充图像。采集复用上一轮的session lease/最后释放/无首帧断连/terminal新订阅契约。
- 打包版每个平台验证可见、后台、恢复、两个订阅、仅一个隐藏、全部隐藏及卸载；检查实际进程内采集，不依赖开发代理或独立19421服务来伪造packaged成功。
- 只读输入完整DTO应返回405/web_host_input_readonly。iOS packaged既有路径作为回归：优先已有可用目标；不绕过resize/显示诊断保护，发现实际问题保留失败并窄修。
- 先保存真实缺口与失败测试，最小实现后跑focused/完整CLI、Web build、local与docs；服务/设备动作主控串行，子agent只负责独立文件代码与测试。

## 所有权

主仓SP-193/SP-207/SP-245等并行差异保留；本轮不提交、推送、安装覆盖用户版本或发布。现有Android及scrcpy属于外部持续使用，只读预览；只清理本轮新建服务和有明确所有权的Harmony实例。截图、进程/目标原始信息保留私有.triton/sp244-packaged，公开报告脱敏。

## 发现与修复过程（历史）

以下保留当时的进度与失败；当前结论以文末最终验收为准。

- 仓库外本地arm64基线确认mode=packaged/readonly=true；Android/Harmony两条MJPEG地址实际404/空body，修正第五轮仅凭源码推测SPA200的说法。
- 新增packaged路由并复用framebuffer subscription；统一SDK finder，缺参/非法FPS为JSON400，原只读405保留。iOS维持startup409，成功引用由RAII持有，HTTP body未执行和无帧断连均释放；相关runtime拆分均低于1500行。
- 显式Android/Harmony预览改用本平台轻量list与原selector解析，保留canonical/alias/存储current，只有未解析current可进入受限旧查询。修复后4次真实Harmony直连headers19–29ms、首字节223–443ms；16个ps样本观察到采集，未观察到simctl/devicectl/adb/aa dump。此窗口没有registry请求，避免把列表刷新当成预览热路径。
- source Harmony第一轮在恢复时失败，只有5秒代理abort和无首帧，未确定具体阻塞命令；第二轮16阶段/19断言、11采集观察窗口通过，保留失败不抹除。
- 更明确的后续反证：新轻量解析下，snapshot_display子进程运行约5秒后退出，再进行约2秒cleanup，最终HTTP200无帧；符合旧capture helper默认5秒预算耗尽。已将Harmony snapshot/recv分别设为15秒有界预算并补取消/超时测试；前端首帧探测改为单调时钟45秒。延长预算不保证实际截图失败能恢复，须以最终实测判断。
- iOS原生真实双订阅/最后释放/迟到帧检查通过；初始packaged iOS基线200+JPEG，首headers约5.96秒。新版packaged尚待完整浏览器验收。
- 初始iOS无帧旧逻辑红测teardown挂起，记录自有PID/sample后终止；加只用于有界收尾的测试running探针后红测正常退出。后续双订阅测试Bool等待与分开读取的计数不一致，具体原因未知；改为返回同锁快照并严格断言2/1/1→2/2/0，整合67项通过，未放宽断言。
- 并行SP-246把StreamCard迁为Rhine StreamPanel，自动暂停helper未变、逻辑保留；旧DOM定位失败不是产品缺失。重新适配原生select和portal窗格菜单，当前Web127项/build通过并冻结全部source hash/静态资产。旧资产包保留为历史，不外推到新UI。
- 最终代码完整CLI158 XCTest+1634 Swift Testing（1792项）零失败，本地local门禁通过（root7+401、release build/smoke/docs/diff，Xcode build跳过）。全量中的iOS native1与Bonjour2按开关跳过；另有显式开启的真实iOS native1项通过。待最终三端packaged、source Harmony重验及清理。

## 最终候选与逐端实测

候选v3来自当前主仓release CLI和Web127项测试后的生产资产，在仓库外按`triton + web/`发行布局压缩并重新解压，未发布。archive SHA-256为`8cd6c37336baa0de15b21c66fdf198f6ffcfae81a1adb62d30b1c442eabfab74`，binary为`26f575ca4e6ae7faeca3ca19d06a3dec86979616b75475d573d054589e2965c3`。私有`package-artifact.json`保存全部资产hash，`current-web-source-manifest.json`绑定78个源文件，`integrated-code-manifest.json`绑定本轮14个实现/测试文件及worktree一致性。

- 最终source Harmony：16阶段/19断言通过，真实帧1308×2880；11采集窗口全部通过。页面初始隐藏、后台、两窗格全隐藏、最后卸载与关闭页面均无采集观察；6个显示窗口有采集正对照。恢复保留5FPS/目标且新建请求，双预览可独立释放。
- 新Rhine菜单曾因验证脚本按`menu`的label定位超时，实际预览仍live；改用实际唯一打开的menuitem定位后完整通过。该轮失败保留为`menu-locator-*`，不记作采集缺陷。
- Android packaged v3首次浏览器16阶段/19断言通过，11采集窗口中仅3秒both-restored窗口正对照未命中。原始样本显示恢复初期真实screencap，随后有多个仅显示`(adb)`的不完整命令，未核实其进程状态；不能把命令缺失当无采集或通过。保留`short-observation-*`，将观察扩为8秒并对采样间隔加抖动，后续单独记录结果。

`ps`只提供采集进程数量下界，不是精确帧数；本轮不以此声称固定RAM回收量。

- Android packaged最终复验：16阶段/19断言及11采集窗口全部通过，真实1080×2400画面；保留首轮短窗口观察不足。Harmony packaged首轮浏览器通过，one-after-unmount稳态短窗口也缺正对照；保留原失败，扩为20秒后，最终16阶段/19断言和11采集窗口全部通过，真实1308×2880。两端HTTP各15项通过，所有停止窗口无采集观察；运行时SDK不在PATH，19421无独立服务。
- Harmony已通过Triton stop退出并读回离线；stop返回后进程退出有延迟，按PID消失再次确认，未把回执当即刻退出证明。测试用iOS重启后resize=inactive/display=primary。
- iOS首轮验证脚本初始5秒paused等待超时，而失败快照已是paused；退出时未处理route.fetch取消导致脚本未完成Chrome清理。已精确清理自有Chrome，保存`initial-readiness-*`，只将初次UI就绪等待改为30秒，后续隐藏暂停仍要求5秒；补路由关闭错误收尾，未修改产品代码。

### iOS目视反证：解码成功不等于主屏画面

第二次iOS浏览器16阶段/19断言虽通过，但截图目视为黑图，natural size是7680×4320；因此该轮视觉验收失败，不能称iOS已完成。真实`devicectl info displays`读回唯一active/primary/integrated LCD1206×2622，以及off/virtual Resizable7680×4320。旧native流按最大IOSurface面积选中了后者。默认Triton截图目视HOME正确1206×2622，说明不是手机黑屏。

保留`wrong-framebuffer-*`与`visual-acceptance.json`失败。原生单测此前只验证JPEG/lease，不验证选中主屏，必须补强；之前的“真实帧”仅指可解码，不构成视觉通过。显式`--primary-framebuffer`still因额外display严格拒绝，保持该契约不变；修复stream须绑定现有normal topology的主屏，禁止面积猜测或借用Resize unsupported豁免。native显示uniqueId与simctl framebuffer UUID实际不同，先取只读descriptor元信息确认映射，不能凭字段名拼接。

只读原生元信息证明：`SimScreen.screenProperties`为对象getter；其`SimScreenProperties.uniqueId`也是对象getter，真实返回NSString，与devicectl同一display uniqueId一致。`port.uuid`对应simctl framebuffer UUID，是另一套ID。ROCK动态代理通过protocol声明与转发提供getter，`class_getInstanceMethod`为空不能推定属性不存在。修复选择路径据此绑定唯一主屏descriptor，保留现有normal resize/display拒绝条件，不调用未验证标量ABI、不回退面积排序。

### 最终v4候选

iOS native精确主屏选择已完成：红测复现大副屏误选、主屏无surface回退等；两级动态代理、缺失/重复/无匹配、已出帧后身份/surface丢失清缓存均覆盖。完整CLI158 XCTest+1642 Swift Testing（1800项）零失败；全量仍按开关跳过native1与Bonjour2，随后显式owned native加强版1项实际通过（2.118秒），包含fresh主屏nativeSize与JPEG尺寸相等、双订阅/最后释放/迟到帧。main local再次通过。

打包前哈希检查发现并行SP-247已整合新版预览工具栏，保留其改动并重新通过Web142项和生产build，82个源文件在构建前后hash一致。验证脚本按真实Popover portal调整FPS入口，新增console error断言；不把v3界面的浏览器证明套到v4。v4 archive SHA-256 `a2186651c1884d6b26d95c4fb95e2de59ee3ffb8b318d1338b4aee31453c42e8`，binary `3ae41b3c328e7990db4ad407416c6ab7f5b068ba0df7ff5907fd0d95b88a3089`。三端packaged已按文末矩阵完成重验；v3源码Harmony与两端packaged成功、iOS视觉失败及采样不足均保留。

最终v4补充验证工具反证：Android浏览器16阶段/20断言通过，但整机ps观察发生11.207秒空洞，two-visible窗口0样本，原分析正确保持失败（`v4-ps-gap-*`）。将观察器改为原生`proc_listchildpids`仅查询实际服务子进程，再以`KERN_PROCARGS2`读取argv并保持server argv身份；自有子进程fixture验证PID计数/argv/清理通过。它不修改产品，也不把命令不完整或缺样本认定为无采集；之后重新采集完整窗口。

原生观察器离线审计后补强分析：静默窗口同时要求无未解析子进程，采样覆盖（含窗口首尾）最大间隙≤1秒；活动窗口只声称明确观察到采集，不声称持续帧率。Android最终4493条样本/133.2秒、16阶段/20断言通过；5个静默窗口capture=0/unknown=0，最大间隙<55ms。一次0.667秒间隙在活动窗口，保留该限制，不写“无任何间隙”。后续运行器检查观察器退出码，缺数据保持失败。

## 最终验收与交付

本机macOS arm64 / Xcode27.1上完成；没有发布、安装覆盖用户版本或提交。v4是仓库外重新解压、稀疏PATH、不依赖19421开发代理的真实候选包。

| 平台/模式 | 浏览器 | 真实画面 | 采集/释放证据 |
| --- | --- | --- | --- |
| Harmony source v3 | 16阶段/19断言，page errors0 | 1308×2880 | 11窗口全部通过 |
| iOS packaged v4 | 16阶段/21断言，page/console errors均0 | 1206×2622 | 原生几何/双lease/最后释放通过 |
| Android packaged v4 | 16阶段/20断言，page/console errors均0 | 1080×2400 | 11窗口全部通过 |
| Harmony packaged v4 | 16阶段/20断言，page/console errors均0 | 1308×2880 | 11窗口全部通过 |

全部覆盖初始隐藏不采集、后台/祖先隐藏/离屏/零尺寸/透明暂停、恢复新请求与原目标/FPS、双预览独立释放、最后卸载、重挂与重复事件。v4两端Android/Harmony分别通过15项HTTP检查；iOS通过实际平台适用检查。iOS截图已目视HOME，尺寸与独立Triton截图相等，修复前8K黑图失败不被脚本绿灯覆盖。进程采样（v3用ps，v4只查询绑定服务的子进程与argv）只能证明窗口内观察活动，不是持续帧率、精确帧数或RAM回收量；iOS使用进程内native生命周期测试，不套用外部截图进程采样。

代码验证：CLI1800项零失败（158 XCTest+1642 Swift Testing；全量native1/Bonjour2按开关跳过），加强的owned iOS native1项另行实测通过；Web142项/build及main local通过，Xcode App build未执行。最终docs门禁另记录在私有日志。5文件native checkpoint与14文件原实现checkpoint绑定main/worktree；Web82文件/静态资产与v4包hash绑定。

自有Chrome/profile、HTTP/Vite、观察器已清理；本轮启动的Harmony与iOS均停止并读回。外部Android及scrcpy保持运行。经验已回写Web、release、host-simulator三份skill、平台参考与EXPERIENCE；不新增未经验证的省内存百分比。
