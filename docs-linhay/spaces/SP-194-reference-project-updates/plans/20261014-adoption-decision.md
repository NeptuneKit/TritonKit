# 上游更新接入裁决

## Decision

Hybrid：从 simslim、sim-use、Loupe 选取三个兼容与正确性切片先接入；从 Harness、Maestro、Revyl 提取回归和后续候选。用户当前询问适合接入哪些，范围是筛选建议，本次未授权实现，不修改产品源码。

## Why

| 顺序 | 适合更新的能力 | 当前工程事实 | 影响与价值 |
| --- | --- | --- | --- |
| 第一批1 | simslim 服务保留规则 | `CLISimulatorResourceCatalog.swift` 仍pin4ae1659a，alwaysEnabled只有sharingd，assistantd/gamed仍在slimmable，widgets exception未关联navd | 补assistantd/gamed保护和widgets→navd条件，避免瘦身触发上游报告的内存泄漏、启动等待/日志洪泛 |
| 第一批2 | sim-use Resize Mode 识别和动作拒绝 | CLI源码搜索未发现appResize/resizable_app_session保护；只是静态检索，非设备失败复现 | host观察携带display/scene事实；错误display上的触摸显式拒绝，逐动作检查，不报已送达；截图与视频区分能力 |
| 第一批3 | Loupe Xcode27 framework加载兼容 | HID probe已支持selected Xcode SharedFrameworks；但`CLIHostSimulatorFramebufferService.loadPrivateFrameworks`硬编码Xcode.app，只找Developer/Library/PrivateFrameworks | 针对画面流补selected toolchain候选路径/加载失败诊断，复用已有resolver，避免把已有HID支持重复实现 |
| 第二批 | Harness/Maestro输入验证、证据与回归 | workspace已有executed_unverified/verified、业务checkpoint、unknown停止；replay已有空plan拒绝；不能推断全skipped漏洞 | 增加输入读回、前景sheet目标一致性、stale tree/WebView超时、视频开始时间和产物路径安全的差距审计/失败场景；保留已实现契约 |
| 后续独立切片 | Baguette typed defaults | 当前host-defaults是工具配置，不等于App偏好准备 | 增加App配置场景准备：presence+type、限定键导入、App Group/普通suite及重启后读回 |
| 后续独立切片 | Revyl skill update与config migration | public skill已有整体打包/版本信息，需审计CLI安装更新面 | 更新保留本地修改、冲突账本，配置迁移预演/备份/原子替换 |
| 后续独立切片 | MobileBuildMCP prepared test产物 | 与triton xcode测试工作流对照后再定实现 | 复用编译产物但每次新结果包，降低重复构建；先验证配置/目标一致和缓存失效 |

上游事实和链接见[更新报告](../../../dev/20261014-reference-project-updates.md)及其分组来源。本地源码核对于2026-10-14完成，只读，未执行设备动作。

## Execution Plan

1. 第一批按独立功能建立实现space，先失败场景再改产品；资源catalog优先，接着Resize Mode与画面流兼容。不要把三个不同作用面混成未经分项验证的大更新。
2. 第二批先审计现有workspace/replay/evidence/WebView验证契约，再只补真实差距；已经实现的alias freshness、预算、OCR、视觉settle和UI健康不重做。
3. 新功能各自定CLI/HTTP schema、状态流和验收；Atlas、defaults、skill updater/prepared tests不直接塞进兼容补丁。

## Borrowed

上游规则与失败场景保留到Triton-owned CLI/HTTP：服务例外、display门禁、selected Xcode加载、read-back和证据完整性。只借鉴能力，不引入额外npm/MCP或云账户作为依赖。

## Rejected

- iCTRL与OpenDeviceHub本期无增量；iCTRL五机制已实现，不生成重复任务。
- Atlantis NWURLSession embedded swizzling属于替代网络路线，当前宿主代理不直接接入。
- Rockxy以证据/脱敏模式为研究对象，源码AGPL及DMG分发条款分开，不直接复制未审阅授权代码。
- remote adb、云设备/Computer/SSH、手机Web控制页、私有Runner/DDI与模型自主点击不属于本轮默认接入。
- XcodeBuildMCP更名仅先修正参考入口；不能因此更改Triton自有命令/schema。

## Verification

- 资源规则：default/except/keep/alwaysEnabled、旧receipt恢复、未知label与runtime能力边界；独立Simulator上检查XCUITest启动、日志/内存趋势与restore。性能需实测，不沿用上游数字。
- Resize Mode：无法查询、状态切换/缓存、batch每步、键盘与触摸分离、不同display截图、unsupported视频；Triton-first真实证据，不发送错误display动作。
- 加载路径：selected Xcode、SharedFrameworks/legacy/Versions、存在但加载失败、失败候选摘要；CLI stdout单一envelope，真实只读画面流验收。
- 每切片focused/完整CLI及本地总门禁、schema/HTTP按影响补齐；文档/skills/memory写回。

## Executor

后续授权实施时，主控负责集成和最终验收；独立实现space/worktree按文件责任拆分。此次单agent完成筛选，不创建实现任务、不提交或推送。

## 追加可纳入的优化

用户继续询问除第一批三项外的优化。2026-10-14再次只读核对源码，建议如下；仅推荐与验收设计，不实现。

| 顺序 | 优化 | 已核对事实与借鉴来源 | 验收重点 |
| --- | --- | --- | --- |
| 高 | WebView受控表单输入与读回 | `TKRuntimeWebViewProvider.swift` 的form input直接`element.value = oldValue`，返回ok:true与长度；已派发input/change但未在该脚本验证目标值保持。Harness0.8.4给native prototype setter/blur/read-back场景 | React受控输入、datetime/number不支持selection API、select值/文案、只读/无变化、异步回退、secure只返回验证布尔和长度；精确postcondition不代替业务提交成功 |
| 高 | 前景目标与可操作性一致 | Harness0.8.3与Loupe0.5.0：sheet/popover/menu限制、label provenance、gesture target | 模态出现后不选底层同名控件；AX可见不等于可点击；命中候选保持来源与歧义。先审计现有实现再补差距 |
| 高 | helper/进程/流取消可靠性 | serve-sim shutdown等待in-flight、sim-use interruptible sink、device-hub-ios operation-owned process session | 阻塞消费者、断开pipe、SIGPIPE、取消/超时、重复stop、不能杀其他工程进程；诊断与stdout契约不被日志破坏 |
| 中 | prepared test产物复用 | `runXcodeTest`目前调用普通test；Apple platform专门runner已有xctestrun，不能当通用xcode test reuse已覆盖 | 源码/SDK/toolchain/scheme/config/destination指纹失效，测试编译与执行分离，每次新xcresult，节省时间必须量测 |
| 中 | 证据时间线与失败报告 | `CLITestRunRuntime.swift`已有before/after截图；workspace已有unknown/business checkpoint；Maestro2.7–2.11提示补时序和导出安全 | 审计视频真正开始时间与步骤对齐、失败仍保留截图/树、产物路径不得越界、dry-run/simulated/skipped不算真实执行；已实现部分不重做 |
| 中 | 配置/skill更新治理 | Revylskill update与config migrate ledger；Tritonpublic skill已有版本包而非完整CLI updater证据 | dry-run、字节备份、原子替换、保留用户本地修改、冲突退出、版本及checksum、回滚；内部managed文件权限/符号链接边界独立验证 |
| 中 | 网络证据与App Map完整性 | proxy已有header names-only脱敏；App Map已有evidenceRefs/coverage/health，不从零新造Atlas | 网络不扩采敏感body默认值；审计stream结束/截断/无法检查状态。App Map补build/device/runtime范围、完整性与证据回溯；未知不等于不存在 |

建议在原第一批之后先做WebView输入可靠性和helper取消治理，再优化测试构建复用。前景命中与证据完整性可作为横向回归项持续补齐；配置/skill/App Map各自独立立项。不是把上游工具整体引入工程。

来源：[Harness0.8.4](https://github.com/awizemann/harness/releases/tag/v0.8.4)、[Harness0.8.3](https://github.com/awizemann/harness/releases/tag/v0.8.3)、[Maestro2.11.0固定changelog](https://github.com/mobile-dev-inc/Maestro/blob/cli-2.11.0/CHANGELOG.md)、[Revyl内部文件约束](https://github.com/RevylAI/revyl-cli/blob/ac35cd88e6f122b9e956069d6f170380a419d3d1/docs/local-runtime-files.md)，其他固定来源见分组报告。Maestro网页读取timeout，但前轮官方contents API读取成功；本轮不据网页失败推断无变化。
