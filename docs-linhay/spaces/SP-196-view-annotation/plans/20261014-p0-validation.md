# SP-196 P0 实现与模拟器验收

日期：2026-10-14。源码位于 `feat/SP-194-view-annotation` 独立同级worktree，基线 `8aaf6c31`，本次源码尚未提交、合并或发布。主工作区和原默认服务保持原有状态。验证设备是本次新建的 Triton-SP194-Highlight / iPhone-Duo / iOS 27.1 Simulator（arm64），仅测试fixture，不操作用户App。

## 实现范围

独立 `highlight capabilities/apply/status/clear` 已实现，经既有本地 HTTP `/request` 转发；direct embedded HTTP 有 `/v2/runtime/highlight/apply|status|clear` 的 POST 和 capabilities 的 GET。共用shared强类型DTO，截图不是高亮请求的必填字段。

首个provider是可选Debug UIKit：普通UIView/CALayer，OID或唯一identifier，可选withinOID；真实修改borderColor/borderWidth，默认#FF453A/3pt。保存CGColor?（包括nil）/CGFloat原值和弱对象/祖先链；不靠地址整数反向构造对象。cell子树没有可信content epoch时拒绝，text/role保留字段此provider不支持。没有新增SDK安装、自动注入、Web写入入口或外部依赖。

最多10节点/1个活动或待处理会话；TTL默认30秒、范围1–300；operation tombstone上限1024、终态详情128。紧凑SHA256去重，只对已通过预检、登记为可能写入的操作幂等；validation/not-found/busy等零写拒绝不登记，条件变化后同operation可以重新尝试。对已接纳operation重试不重新应用、不续期，详情淘汰后receipt_expired，不重新执行。

原值只留在App。clear整组比较original/applied和对象身份，不覆盖业务新值；发生一个字段冲突也不自动恢复组内另一个字段。响应丢失保留operationID/runtimeInstanceID和unknown residue。会话跨CLI退出/transport重连保留；到期及App前台恢复时检查。stop每次切换清理generation，TaskLocal保存请求接纳epoch，过期排队请求/清理不得写入新会话。同步stop安排清理，async stopAndRestoreHighlights等待本批结果；被更新stop取代的旧async调用可返回nil，不能以nil证明已还原。

## 验收结果

| 证据 | 结果 |
| --- | --- |
| shared契约/路由 focused | 13项通过；先有缺类型编译失败，后完成DTO |
| CLI高亮 focused | 22项通过（后续能力分类测试另计）；旧能力零新wire、参数、HTTP、非2xx保留回执、丢响应保留恢复键 |
| 真实iOS Debug UIKit | 19项通过（15会话/provider、4 lifecycle，按最终xcresult计数）；nil/原色、冲突、cell拒绝、去重、补偿、祖先迁移、partial-clear期间apply失效、setter重入、stop代际隔离 |
| fixture CLI→HTTP→WebSocket→UIKit | 37步脚本通过，并分别用App层截图及宿主实际display=1复跑 |
| transport断连/重连 | 仅停止自建测试服务；失联查询非零，重连后runtime/session不变；按operation找回并clear，restorationVerified=true |
| 无SDK普通截图 | 启动系统com.apple.Preferences，Triton host截图成功并人工看图；不接入/注入SDK |
| 完整本地门禁 | verify.sh --local通过：根包SDK50项+shared277项、边界/Debug隔离、release CLI build/smoke、Harmony smoke、iOS observe smoke、Simulator build、docs/diff |
| 最终完整CLI/Release | CLI1219项/112 suites通过；macOS及iOS Release各3项availability通过；初期失败轮保留 |

37步包括：两处同名文案分别唯一identifier定位；批量真实红框及MainActor处理；同operation保持session和deadline；属性回读frame/bounds不变，高亮期间按钮点击成功；未知mark零写拒绝、第二apply busy；只清primary留下nil节点；全部clear恢复灰色1pt与nil/0pt；重放closed operation不重新高亮；真实2秒TTL后还原；业务仅改green导致clear非零、整组保留green/3pt、needs_attention/possible；业务自身reset后状态清理；后续新apply可用。

## 画面证据

| 状态 | 图像 |
| --- | --- |
| 原始 | [original](../screenshots/20261014-highlight-original-verified-v1.png) |
| 真实App红框 | [active](../screenshots/20261014-highlight-active-verified-v1.png) |
| 部分clear | [partial](../screenshots/20261014-highlight-partial-verified-v1.png) |
| 还原并回读原值 | [restored](../screenshots/20261014-highlight-restored-verified-v1.png) |
| 业务变green，保护整组不回写 | [conflict](../screenshots/20261014-highlight-conflict-verified-v1.png) |
| 未接SDK的系统设置 | [no-sdk](../screenshots/20261014-highlight-no-sdk-verified-v1.png) |

图像是真实Simulator截图，未后期绘制高亮。App层466×678与宿主1398×2034的保真边界分别记录；归档画面使用宿主实际display=1。

## 复跑入口与失败证据

1. 先保存Triton status/doctor/capabilities/schema/plan事实，再用triton sim创建/boot专用Simulator。默认19421已有用户App连接，故本轮使用隔离测试服务的临时端口，不改产品默认端口，也不停止原服务。
2. `triton xcode test --package . --scheme TritonKit-Package --configuration Debug --destination 'platform=iOS Simulator,id=<owned-simulator>' --only-testing TritonKitTests/TKHighlightSessionTests --only-testing TritonKitTests/TKHighlightLifecycleTests --result-bundle <new.xcresult> --timeout 600 --jsonl`。
3. `triton xcode run --project Examples/TritonKitTestFixture/TritonKitTestFixture.xcodeproj --scheme TritonKitTestFixture --configuration Debug --simulator <owned-simulator> --env TRITON_PORT=<test-port> --env TRITON_HOST=127.0.0.1 --build-setting CODE_SIGNING_ALLOWED=NO --jsonl`；用list取得对应target，点fixture.login.highlight。
4. 使用[可复跑fixture脚本](../../../scripts/verify-ios-highlight-fixture.py)验证属性和截图。仅接受本仓fixture显式target和Simulator，不能用于用户App。service重启验证由主控单独串行完成。

原始日志、JSON/xcresult位于worktree的gitignored `.build/sp194-evidence/`。初轮CLI因schema编译快照/新taxonomy未同步失败；UIKit nil断言曾误以为CALayer默认nil，改为保存真实原色，nil专测仍保留；首次provider签名跨编译快照link错误经冻结重跑通过。Release的默认SwiftPM Xcode scheme测试因@testable/非testable Release模块不兼容取消，重新使用显式ENABLE_TESTABILITY=YES测试设置（不启用runtimeflag），不将编译取消计作行为失败。

首次host截图默认LCD-1/screen3得到黑屏：保留失败事实，没有把文件生成当视觉通过。Triton schema没有显示枚举，按fallback规则只读执行 `xcrun simctl io <owned-simulator> enumerate`，确认App实际LCD/screen1，再回到 `triton sim screenshot --display 1`。完整enum包含宿主元数据，仅放gitignored日志，不公开。归档6张图均已人工查看。

## 明确限制与后续

`main_queue_opportunity`只代表响应主线程获得下一次队列机会，不是独立帧提交/呈现证明。deadline在此机会返回后再校验；主线程卡死/进程挂起期间不能承诺按墙钟强制恢复。真实挂起、卡死、外部修改后回到同值的未观察ABA没有本轮实机证据；value_guarded不会伪称versioned。节点脱树/身份变化保留待处理记录，释放对象不等于已回写原值。

P0范围不包含截图自动finally组合、prefer/required capture参数、Android foreground provider、Harmony注册outline provider、Compose/SwiftUI虚拟节点专用适配、动态第三方插件加载或真机验收。上述仍属P1/S4与后续S5，不能以本次UIKit成功宣称跨端支持。

## 最终门禁记录

- 完整CLI：1219项/112 suites通过（final日志）；初期18/5/1个schema metadata遗漏逐项修复，独立能力probe不抢普通primary recovery入口。
- 最终根包：TritonKit 53项/11 suites、TritonKitShared 277项/36 suites通过；macOS下UIKit不会运行，真实UIKit证据单列19项。
- Release：macOS Release 3项availability通过；真实iOS Release最终3项通过（AvailabilityTests）；Release测试只显式ENABLE_TESTABILITY=YES使@testable可用，未定义TRITONKIT_RUNTIME_ENABLED；保持no-op。
- 最终release CLI实际复跑fixture：37步全部通过，原值/布局/交互/截图/TTL/冲突和显式清理同一provider链路。
- verify.sh --local、verify.sh --ci-docs、独立check-docs.sh、相对链接与git diff --check通过；最终只增测试/文档后按对应focused与docs门禁重新检查。
