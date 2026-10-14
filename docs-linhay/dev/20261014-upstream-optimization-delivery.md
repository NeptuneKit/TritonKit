# TritonKit 上游优化工程交付说明 — 2026-10-14

**状态：实现与本地验证完成；独立工作区待集成。** 本文描述 SP-196 当前代码行为、采用依据与能力边界，能力边界与验收以报告为准，本轮未发布。完整结果以 [验收报告](../spaces/SP-196-upstream-optimization-delivery/plans/20261014-validation-report.md) 为准，需求入口为 [SP-196](../spaces/SP-196-upstream-optimization-delivery/README.md)。

## 采用原则与来源

用户已授权规划、开发与验证；实现放在 SP-196 独立 worktree，保留主工程 SP-195 Runner 的已有工作。影响面是 CLI、现有 host HTTP/stream、shared Xcode builder 与 iOS embedded runtime；没有借本轮扩大 Web 写控制面、云设备或远端 agent 产品。

依据来自 [参考更新报告](20261014-reference-project-updates.md) 及 [接入裁决](../spaces/SP-194-reference-project-updates/plans/20261014-adoption-decision.md)。下表的“借鉴”表示吸收规则或失败场景，不能解释为复制上游全部实现、依赖或许可授权。

| 来源 | 采用的内容 | 在 TritonKit 的落点 |
| --- | --- | --- |
| [simslim 固定 profiles.go](https://github.com/MobAI-App/simslim/blob/6518ba7eab1123d7e1d7797b0e05f51043b42a5b/profiles.go) | 服务保留例外，沿用 MIT notice 与固定 catalog SHA | Resource 的 plan/apply/verify/restore 一致性与 receipt 防误恢复 |
| [sim-use v0.15.0](https://github.com/lycorp-jp/sim-use/blob/v0.15.0/Sources/iOSSimBackend/Sim/ResizableAppSession.swift) | Resize 状态、display-bound screenshot 与不可路由动作拒绝 | fresh target-bound 查询；unknown fail closed；不采用 unknown→inactive 或关闭保护 fallback |
| [Loupe v0.5.1](https://github.com/heoblitz/Loupe/releases/tag/v0.5.1)、[serve-sim 参考快照](https://github.com/EvanBacon/serve-sim/commit/6d009686ed08f7d8bd19bca9f9f67a9237931f44) | Xcode 新 framework 布局、helper shutdown/cancellation 的差距审计 | 复用已有 HID resolver，修 framebuffer 硬编码；只修实际发现的助手生命周期缺口 |
| [Harness v0.8.4](https://github.com/awizemann/harness/releases/tag/v0.8.4)、[Maestro cli-2.11.0](https://github.com/mobile-dev-inc/Maestro/releases/tag/cli-2.11.0) | 输入读回、前景范围、未知结果不冒充成功 | WebView native setter/readback、统一前景动作范围；已有 checkpoint/unknown 契约继续复用 |
| [MobileBuildMCP v2.7.1](https://github.com/getsentry/MobileBuildMCP/releases/tag/v2.7.1)、[Apple TN2339](https://developer.apple.com/library/archive/technotes/tn2339/_index.html) | prepared test 产物复用与 Apple build-for-testing/test-without-building 流程 | Triton-owned manifest、完整身份校验、每次 fresh result bundle；不改原 Runner 的 xctestrun 动作 |
| [Baguette v0.2.6](https://github.com/tddworks/baguette/releases/tag/v0.2.6) | typed defaults 的 presence、类型和限定键导入 | bundle app-data 的 prefs get/set/import；不扩 App Group/suite |
| [Revyl CLI v0.1.153](https://github.com/RevylAI/revyl-cli/releases/tag/v0.1.153) | 更新冲突保护、备份、范围与完整性 | public skill 安装基线、workspace config 私有存储、AppMap 分页；未新增 Atlas/迁移 ledger |
| [mirroir v0.40.1](https://github.com/jfarcand/mirroir-mcp/releases/tag/v0.40.1)、[Rockxy 参考快照](https://github.com/RockxyApp/Rockxy/blob/de791b63e7f9b5df49f127524a5c9320e675eb23/README.md) | 未实际执行拒绝通过、证据完整性与脱敏模式 | 零成功 primitive 门禁；header-only 网络 capture 验证与 URL 脱敏；未复制 Rockxy AGPL 代码 |

iCTRL 和 OpenDeviceHub 在归档比较基线内没有本期增量；没有生成重复能力。Atlantis 的 embedded swizzling、远端设备、私有 Runner/DDI、手机 Web 控制页与模型自主点击均不属于本轮交付。参考项目长期追踪与本期采用决策分开，以 SP-193/SP-194 为原事实源。

## 1. Host Simulator 正确性

Resource 主实现位于 `CLISimulatorResourceCatalog/Runtime/State/OfflineStore/Receipt.swift`。catalog 更新到完整固定 SHA；assistantd、gamed、sharingd 只能启用，widgets category/feature 都保留 navd。plan 解析实际 profile，apply/verify 复用相同规则；offline 只合并 managed delta，保留用户非管理 label。restore 校验目标与 allowlist，并且只撤回仍等于 receipt.applied 的条目；保护服务不会恢复到禁用。

Receipt/profile/offline 文件均有读取上限与 nofollow/regular/owner 检查。旧 receipt 信息不足时保守 no-op，不能从 category 猜测恢复；同一 Bool 的用户重复写入无法由现有 receipt 完全区分。这里交付的是规则与恢复安全，内存、启动速度和日志下降仍须独立 Simulator 实测，不能沿用上游数字。详情见 [Resource plan](../spaces/SP-196-upstream-optimization-delivery/plans/resource-delivery.md)。

Resize 主实现位于 `CLIHostSimulatorResizeRuntime.swift` 与 `CLIHostSimulatorResizeCapture.swift`。active、inactive、unknown 三态来自 selected Xcode 的新鲜查询；请求 argv 和返回 identity 必须绑定同一个精确 Simulator UUID。CoreDeviceError 24004 可证明无会话，单独 exit code 或工具链版本不能证明 inactive。查询有 native 5 秒/host 6 秒 deadline，stdout/stderr 16 KiB、file JSON 1 MiB 接受预算。

Host touch 与连续 gesture 在动作开始前调用统一 guard：active 为 `ios_simulator_resize_touch_unroutable`，unknown 为 `ios_simulator_resize_state_unknown`。键盘沿用自身 capability。Screenshot active 时添加本次 boot 的 `--display=<UUID>`；video、现有 HTTP framebuffer 与 stream active/unknown 拒绝，错误分别为 `ios_simulator_resize_capture_unroutable` / `ios_simulator_resize_capture_state_unknown`。AX/observe 输出 `resizeAdvisory` 并标识主屏 hit testing 不可靠；没有将主屏事实当作 Resize App 几何证明。query 到 dispatch 的状态变化仍有竞态，完整消除需要未来 display-aware digitizer 路由。详情见 [Resize plan](../spaces/SP-196-upstream-optimization-delivery/plans/resize-delivery.md)。

Framebuffer 主实现位于 `CLIFramebufferHelper.swift` 和原两套 framebuffer service。加载候选复用 HID 的 selected Xcode resolver，SharedFrameworks 优先，保留 legacy 与已安装 CoreSimulator 路径；不遍历别的 Xcode bundle。CoreSimulator 成功后即使 SimulatorKit 失败也 pin 本次工具链，避免后续混用 private ObjC 类。`SimServiceContext` 显式传同一 Developer；start 成功才增加 lease，stdout debug 已去除。

Android/Harmony helper 同时非阻塞读取双 pipe，默认 5 秒/16 MiB 总输出预算；stop/timeout 禁止新帧并停止自有直接子进程，未知完成状态不自动重试。Harmony 远端文件带 session UUID，本地目录 0700、regular file 16 MiB；cleanup 另设 2 秒/64 KiB 上限。取消不终止共享 adb/hdc 服务，也不承诺所有未知子孙退出。iOS 停止立即禁止发布；实际live测试已验证JPEG、双订阅与停止后不可读，未量化底层callback注销耗时。详情见 [Framebuffer plan](../spaces/SP-196-upstream-optimization-delivery/plans/framebuffer-delivery.md)。

## 2. Embedded runtime 的动作与输入

`TKRuntimeForegroundTargets.swift` 抽出真实 foregroundActive/windowLevel/key 的统一选择策略。App 已存在 scene 时不允许后台/非活跃 scene 通过 UIApplication/registry 重新进入动作范围；真正无 scene 的 hostless 环境才保留可见无scene窗口 fallback。modal 真实挂载后只允许最上层 presented root 子树；dismiss 未完成不提前解锁底层。

OID/坐标解析、text responder/ancestor、semantic、table/tab/menu 与 collection coordinate fallback 使用相同过滤。真实键盘回归后，只豁免exact UITextEffectsWindow/UITrackingElementWindowController且两者均由UIKit定义的输入浮层；未知窗口仍保守进入候选。当前 WebView mutation 入口也调用同一 helper；观察枚举仍可看到后台或底层对象，不等于授予它们写能力。LegacyInspection 属性 patch 和低层 internal dispatch 的所有调用链没有在本轮全部重构。详情见 [Foreground plan](../spaces/SP-196-upstream-optimization-delivery/plans/foreground-delivery.md)。

`TKRuntimeWebViewFormScripts.swift` 从原 provider 拆出输入脚本。文本输入用目标 document realm 的原生 prototype setter，发送 input/change、完成 blur；date/number/select 不依赖可用 caret API 才能成功。disabled/readonly/非文本 input 在写入前拒绝；contenteditable 保留原行为。

Provider 50 ms 后消费一次性页面内 readback closure，确认同一节点仍连接且值精确匹配；closure 消费后删除并设 2 秒过期兜底。初次返回和验证结果不暴露文本，secure 异常不泄漏值；导航变化/回滚/原生拒值不能报告成功。这个读回证明观测时值保持，后续业务提交仍需既有显式断言。未增加公开任意 JS 执行面或把 DOM 合成事件变成 trusted HID。详情见 [WebView plan](../spaces/SP-196-upstream-optimization-delivery/plans/webview-delivery.md)。

## 3. 测试复用与结果完整性

Prepared tests 在 `CLIXcodePreparedTestsModels/Runtime.swift` 和 shared `TKXcodePreparedTestCommand.swift` 实现。入口为 `xcode build --for-testing --test-artifact --source-root --prepared-tests-manifest` 与 `xcode test --prepared-tests-manifest`。Manifest 绑定 container/scheme/configuration/destination、selected Developer/version、build settings、源树与实际测试产物；执行前后再次校验，漂移返回 `prepared_tests_identity_mismatch`。

哈希含稳定相对路径、文件类型、权限、大小和完整内容，源/产物集合分别限 20,000 节点/1 GiB；xctestrun 4 MiB，解析实际 bundle/host/UI target 与已知 macros。source/.xctestrun 拒绝用户链接；.xctestproducts只接受经固定physical root逐组件验证的包内相对链接，并哈希链接字节与目标实体内容、拒绝循环；特殊文件、未知 macro 或读取时变化拒绝；只兼容固定系统 `/tmp`、`/var` 路径别名。`.xctestproducts` 由当前 xcodebuild help 能力确定，不只按版本号推断。源树排除 `.git/.build/.triton/DerivedData/node_modules`，项目外依赖和放在排除目录的源码不在自动保证范围内。

Manifest 独占新建，result path 必须 fresh；未显式给路径时分配本次 `.triton/prepared-tests/<UUID>.xcresult`。进程 exit 0 但结果无法解析、没有测试、全部 skipped 或零通过均为 `prepared_tests_result_incomplete`。未用旧 xcresult 充当本次测试证据。详情见 [Prepared plan](../spaces/SP-196-upstream-optimization-delivery/plans/prepared-tests-delivery.md)。

AppMap 列表新增 `--offset` 默认 0 与 `--limit` 默认 100、最大 1000；非法参数在 map 发现前返回 `invalid_app_map_page`。原 screen/transition/path count 保持总数，新增 `totalCount/returnedCount/truncated/nextOffset`，实体按 stable ID 排序并保留 `evidenceRefs`。`truncated = returnedCount < totalCount` 包含 offset 已略过的前缀；`nextOffset` 独立表示后续页，无后续时省略。静态 viewer 内部仍读取全量，不因默认页大小丢图。分页只限制返回量，没有声称有界读取全 map 或跨请求事务快照。

Empty suite 在创建 flow/evidence 前返回 `empty_app_map_suite`。TestRun 只有至少一个 primitive.status=passed 才能最终 passed；全部 optional failed/blocked 或 empty normalized override 为 blocked/`no_successful_steps`。Mandatory failure 保留原类型，已有通过 primitive + optional failure 保留原 passed 语义。`run.finished` 保存 final failure，report 优先它、再兼容 first failure.recorded。没有另造 replay executor 或把探索图当作业务验收。详情见 [AppMap plan](../spaces/SP-196-upstream-optimization-delivery/plans/appmap-completeness-delivery.md)。

## 4. 场景准备与本地更新安全

Prefs 从原大文件拆入 `CLIHostPreferencesCommands/Models/Runtime.swift`，限 bundle app-data plist。get 的 `present` 与值分离：false、0、空字符串仍存在，缺文件/键为 false。import 接受 json/plist，整包严格校验后只合并重复 `--key` 白名单；null/Date/非法数字、超 32 层/1 MiB 或缺选中键均在写入前失败，其它键保留。

set/import 的 `--relaunch` 默认 false，磁盘原子写后 readback；显式要求才 terminate→launch。失败 receipt 保留 `diskWriteVerified:true` 与失败阶段、`preferences_relaunch_failed`，退出非零且保持单 envelope。import 不输出值；`runtimeConsumptionVerified:false` 不因 launch exit 0 自动升级。App Group/suite 与真实运行中 App 消费仍待独立需求。详情见 [Prefs plan](../spaces/SP-196-upstream-optimization-delivery/plans/preferences-delivery.md)。

`CLIHostWorkspaceConfigStorage.swift` 仅管理固定 host-defaults/host-targets 配置，不改变既有 JSON 格式。逐级 openat/nofollow、owner/regular/nlink=1、目录 0700/文件 0600/1 MiB；缺失只读 load 不创建目录。新旧模型都校验，坏旧字节、future schema 拒绝覆盖；有效旧配置先保存 exact raw backup，再复核目录/inode/旧字节、fsync staging、renameat 和目录 fsync。用户 symlink 不通过自动 canonicalize 放行；raw backup 无自动清理。目录 fsync 在 publication 后失败可能已产生更新，不能把非零退出解释为必定零副作用。详情见 [Config plan](../spaces/SP-196-upstream-optimization-delivery/plans/config-storage-delivery.md)。

Public skill 的 CLI installer 与 `install-public-skills.py` 均保留本地修改，记录文件 hash 基线。Archive 先验证 checksum（适用远端更新/提供 checksum 的入口）、路径、type、重复项和预算，拒绝链接/特殊文件/逃逸；上限 10,000 条目与 100 MiB。已有基线与现文件不同，或无基线且不同于 incoming 时拒绝 `skills_update_conflict`；锁冲突为 `skills_update_busy`。通过验证才 stage、再次核对、原子交换整包并保留旧包；legacy 独立目录仅无改动时归档，不盲删。

脚本 dry-run 完成源包/当前安装校验而不修改安装文件；CLI update dry-run 是行动计划，不能当作下载包实际验证。交换后的 backup/legacy rename 失败可能已经更新，新旧包仍保留，需要按阶段恢复；没有冲突自动合并、自动 retention 或全新配置 migration ledger。Swift/Python 各自门禁由主控补记，不能只验证一个入口就宣布两者等价。

## 5. 网络 evidence 的范围

`CLIHostNetworkCaptureIntegrity.swift` 按块验证 capture：64 MiB 总量、256 KiB 单行、100,000 条，已知 schema、合法 UTF-8/JSON/newline、regular/nofollow source。空、坏、半条、超限输入不能成为完整证据，已有输出保持原字节。Append 达硬限时保留前缀并写 `.incomplete` marker，后续导出 fail closed，不能以预算内前缀替代完整流。

Proxy export/HAR 的统计从同一次验证数据计算；session export 与 generic evidence 接入同 reader。URL userinfo/query/fragment 在落盘、event writer 和导出均清除，转发和 mock policy 仍保留原请求语义。旧零计数空 placeholder 是 not-observed，混合来源是 partial-source。

仍是 headers names-only，TLS 不解密、body 不采集；URL path 与设备身份可能敏感，generic evidence 继续标 sensitive。文件锁不证明对不协作外部生产者的原子快照，无 retention sweep。旧 Evidence/Replay tests 改为真实 event parser/newline 夹具，不放宽 reader 以兼容坏数据。详情见 [Network plan](../spaces/SP-196-upstream-optimization-delivery/plans/network-delivery.md)。

## 最终验证与集成边界

完整CLI：XCTest41项、Swift Testing1323项/128组通过（1项live默认禁用，另单独实际通过）。根包：SDK XCTest2/Swift77与shared XCTest5/Swift274全部通过。真实iOS56项/8组、0失败/0跳过；foreground5与WebKit5实际执行通过。Private framebuffer双订阅实测通过，资源apply/restore、typed prefs import/relaunch、prepared两次复用与源码漂移拒绝均已完成。

本地门禁、release CLI、CLI/host/runtime smoke、依赖边界、Debug隔离与docs检查通过；真实Debug应用宿主与Release SDK构建补充平台编译证明。详见[验收报告](../spaces/SP-196-upstream-optimization-delivery/plans/20261014-validation-report.md)与[结构化摘要](../spaces/SP-196-upstream-optimization-delivery/plans/20261014-validation-summary.json)，原失败与超时记录保留，不算通过。

实现仍在独立worktree，未提交/合入/推送/发布；主线后来增加的Runner/highlight需在集成时保留并重跑门禁。active Resize、多OS私有ABI、App业务消费与客户React提交不是本轮证据覆盖范围。没有测资源/编译性能收益。代码按Commands/Runtime/Models边界拆分，根包保持SDK依赖边界，没有新增第三方runtime依赖。
