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
