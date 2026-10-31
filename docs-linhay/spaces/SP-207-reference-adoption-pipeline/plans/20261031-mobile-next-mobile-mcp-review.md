# Mobile MCP 2026-10-31 固定增量评估

结论：adopt_candidate，仅host detached日志独占创建进入本轮安全开发候选，静态同源风险须先由失败夹具证实。App数据清理按主控裁决列observe，能力名空缺不等于当前产品缺陷。下文保留初次评估建议及上游事实，不代表两个建议均获本轮开发批准。

## 固定来源与读取覆盖

base `6c945971b6b16832f7fa2a69ae23d33e8b9beb71` → head `1025dd070fc934986dec9ea25458b0ab03bc54c7`；官方https://github.com/mobile-next/mobile-mcp/commit/1025dd070fc934986dec9ea25458b0ab03bc54c7 。commits?sha=head&per_page=100&page=1找到base，8提交。所有8条提交父边涉及的9个树均recursive、truncated=false；未下载compare或commit patch。父边路径并集20项；18项安全文本路径的37个唯一版本均按用途+文本扩展白名单后读取固定blob（包括README、CHANGELOG、workflow中间版本），本地diff由这些文本生成。新增2张docs/screenshots PNG仅记录树路径/SHA，不请求内容；属文档截图，不支撑本次执行代码机制，不将其视作已审二进制。

证据：review-inventory.json含各父边、提交和跳过路径；review-text-coverage.json映射路径→固定blob；text-manifest.json保存全文size/hash；main-text保存git show main固定blob。许可Apache-2.0，固定HEAD LICENSE全文由主控已采集，sha256 `c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4`。官方release已完整1页，最新1.0.15；不运行其mobilecli或MCP依赖。

## 变更裁决

1. `af6cef12859cc6fd46c6c128e0549ad5685866f7`新增mobile_clear_app_data：直接委托mobilecli apps clear，声明Android设备/Emulator及iOS Simulator，real iOS报不支持、legacy缺方法拒绝；tool destructiveHint=true。上游测试仅校验argv/annotation，源码没有暴露mobilecli内部iOS清理算法；不能由wrapper断言全平台清理完整性。
2. `b619543f9c1682a2b67050cddea817ee62db3256`将输出O_NOFOLLOW|O_TRUNC改为随机同级O_EXCL partial，写完rename，避免通过hardlink改动外部inode；新0600、旧regular mode继承，并测symlink/hardlink及失败清理。这是安全机制借鉴，不能原样改变Triton既有“不覆盖任何现存输出”的契约。
3. CI从CHANGELOG生成GitHub release、只在package变化时audit、@modelcontextprotocol/node2.1.2和Mobilewright云CI指南：不直接采用。Triton无该Node MCP runtime，不新增云设备租赁/MCP server，不执行上游workflow或安装依赖。

## 实际main与既有交付去重

绑定main `1139db7712d485c0927282a4415ac45765567332`。SP-192观察/输入新鲜度、SP-196安全原子写入原则、SP-200设备环境/App lifecycle、SP-212前台activity和ADB输入转义已交付，adoption-state未登记以下两个具体机制。SP-212不能当作已经支持pm clear。

### observe：Android Emulator App数据清理（初评建议保留）

静态能力差异（不等同现有缺陷）：CLIHostAppCommands.swift:517的HostApp仅list/info/inspect/install/uninstall/launch/terminate/go/open-url/container/pull/prefs；TKAndroidADBSupport无pm clear builder。CLIHostSimCommands.swift:789 SimPrivacyReset只重置privacy permission，不能当App cache/documents/preferences/databases清理。保留安装的清理不能以uninstall/reinstall冒充。

主控裁决：本轮observe，不批准该新增破坏性操作进入开发。须先设计并验证reset覆盖的数据范围（cache/documents/preferences/databases、keychain及权限是否清除）、默认/显式Android user、多用户边界、精确本机Emulator目标、真机/其他平台拒绝规则，以及机器可读plan/confirm绑定、拒绝/unknown/部分失败语义。上游工具名或包装器声明不能代替这些契约。以下最小边界、BDD和文件面为初次评估历史建议，未来立项时须按上述设计重审。

初评最小边界：先Android Emulator；CLI/HTTP共享命令契约，显式target与confirm，destructive风险。real device排除，iOS/Harmony诚实unsupported，直到另有原生安全方案。上游wrapper不提供iOS实现证据，不能复制其宣传作为Triton支持证明。

BDD：Given明确本机Android Emulator与合法package且确认，When app clear-data，Then一次adb -s SERIAL shell pm clear PACKAGE，无uninstall/install/launch，不改变其他App；JSON标出scope/target和submitted/verified边界。Given未confirm、real target、非法包名、未知/多目标，Then执行前拒绝且零mutation。Givenexit0但stdout Failure或nonzero，Then单一failure envelope；timeout结果unknown且不重放。Givenprovider unsupported，Thentyped unsupported而非成功stub。

建议文件面：新CLIHostAppClearDataCommands.swift、相应runtime/model/schema（由主控分配唯一owner）；TKAndroidADBSupport.swift添加builder；CLIHostAppCommands.swift注册入口；schema/capabilities/HTTP使用既有路由；fake-adb参数、分发、确认与Failure/timeout focused测试。禁止通过本次评估直接运行设备清理。

### adopt_candidate：host detached日志独占创建

固定上游来源：[b619543f完整提交](https://github.com/mobile-next/mobile-mcp/commit/b619543f9c1682a2b67050cddea817ee62db3256)、[固定src/utils.ts](https://github.com/mobile-next/mobile-mcp/blob/b619543f9c1682a2b67050cddea817ee62db3256/src/utils.ts)、[固定test/utils.ts](https://github.com/mobile-next/mobile-mcp/blob/b619543f9c1682a2b67050cddea817ee62db3256/test/utils.ts)。对应父边安全blob全文已保存在review-text-coverage.json索引；上游采用rename替换，而本机必须保持no-overwrite。

主控复核采用裁决：创建独立安全space，优先原子创建0600、O_EXCL/O_NOFOLLOW/O_CLOEXEC并直接使用所得FD；stderr打开失败须释放已打开stdout FD。该项仍是待红测证明的adopt_candidate，不是已实现或已验收。

同源静态证据：CLIHostProcessRuntime.swift:168 hostDetachedOutputHandle先prepareHostArtifactOutputPath，再FileManager.createFile，再FileHandle(forWritingTo:)。prepare在100行只检查当时路径不存在；createFile与后续open不是独占绑定，两个检查后窗口容许输出项替换。对照同文件drainPipeToFile第39行与bounded版本第62行已经O_EXCL|O_NOFOLLOW，primary framebuffer也独占临时创建+无覆盖发布；workspace config有descriptor/inode/nlink校验，不能重复改这些已覆盖入口。

此处没有运行本地夹具，现阶段是具体源码支持的race候选，不是已复现利用。开发切片第一步必须用受控注入点在prepare后植入symlink/hardlink，并在create/open之间替换，证明当前实现失败；若不能复现则记录反证、修订范围。

BDD：Given路径已存在regular/symlink/hardlink，Then拒绝、victim内容不变；Given预检后并发植入任一种文件，Then独占open拒绝且不启动child；Given成功，Then返回的fd就是独占创建的0600文件，不通过路径重新open；Givenstderr创建失败，Then关闭已获stdout且不得启动child，不删除非自有输出。保持现有no-overwrite契约，不能迁入上游rename替换现存输出。

建议文件面：CLIHostProcessRuntime.swift中hostDetachedOutputHandle及最小独占helper、对应HostProcess/Detached fake-process测试；若private函数需要测试注入，限制在内部同步hook/adapter，不新增生产控制面。与App clear-data文件面隔离、共享构建串行。

## 验证边界

本次仅官方只读网络、固定树/blob及实际main源码/既有space审阅；未运行上游、依赖、测试或设备，不进行Git写入。complete_review=true表示本次全部安全文本机制评估闭合；两张文档截图明确不读取，不等于上游资产或全史安全审计。安全候选未实现、未测试、未合并，由主控建立独立space并验收；App数据清理仅观察，不属于本轮已批准开发。
