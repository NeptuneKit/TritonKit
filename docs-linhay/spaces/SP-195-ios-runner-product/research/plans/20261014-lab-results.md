# 2026-10-14：常驻 XCUITest Runner 最小实测

## 结论与适用范围

Mac 管理标准 XCTest 会话的独立 Runner 路径已在专用 Simulator 和有线 iPhone 通过。公开 XCTest + Network 足以提供认证 HTTP、已知 UI 查询、截图、单次点击后置断言和正常停止，无需本期引入私有触摸、shim 或手机端 DDI 挂载。这个结果支持继续开发独立可选 host provider；不证明脱离 Mac、任意 App、锁屏或永久常驻。

研究代码：[ResidentRunnerResearch](../prototype-readme.md)。机器可读结果：[lab-summary.json](./20261014-lab-summary.json)。机制与接入建议：[技术研究](../mechanism.md)。产品 CLI/HTTP/embedded SDK 未改变；未提交、未合并、未远端写入。

## 环境与隔离

- 基线 `main@8aaf6c31d308194b489e10ed83362cee91f549d5`；Triton 0.2.26；Xcode 27.1 / 27A9275。
- 自建专用 iOS 27.1 Simulator；真机为用户选择的有线 iPhone 13 Pro Max，iOS 26.6.2 / 23G90，Developer Mode 与 DDI services 原已可用。
- 只控制独立 RunnerFixture，bundle `dev.tritonkit.research.runnerfixture`；测试插件 `dev.tritonkit.research.resident.tests`；Runner app `dev.tritonkit.research.resident.tests.xctrunner`。未控制用户业务 App。
- 自有 DerivedData 用于跨目标产物及私有 `.xctestrun` 隔离，避免混入主工作区/其他会话。真实身份、签名团队、token、完整日志、xcresult 均保存在 ignored `.build/sp193-*`；不归档签名 app、profile、配对文件或私钥。
- 保存 `triton status/doctor/capabilities/schema/plan --json` 与实际目标列表后才回退。Triton schema 尚无 `build-for-testing`、`test-without-building -xctestrun` 及精确测试环境注入。native 命令和回退理由在私有收据中保存。

## 实验结果

| 验收项 | Simulator | 有线 iPhone |
| --- | --- | --- |
| build-for-testing | exit 0 | 签名构建 exit 0 |
| 标准 XCTest `testServe` | 1 test / 0 failures，231.804 秒，exit 0 | 第二会话 1 test / 0 failures，195.316 秒，exit 0 |
| 认证 transport + automation probe | 通过 | USB 精确选中设备，每连接重新验证 inventory/Connect，认证 health 与 probe 通过 |
| Runner / fixture 状态 | UIKit Runner state 2；fixture state 4 | UIKit Runner state 2；fixture state 4 |
| 已知元素读取 | counter=0，button exists | counter=0，button exists |
| 错误 token | unauthorized | unauthorized |
| 点击与后置状态 | 0→1，postconditionVerified=true | 0→1，postconditionVerified=true |
| 相同 requestID 与 payload | 返回原 receipt，counter 仍 1 | 返回原 receipt，counter 仍 1 |
| 相同 ID 不同 payload | request_id_conflict | request_id_conflict |
| 前置 counter=99 | precondition_failed，无点击 | precondition_failed，无点击 |
| PNG 截图 | 99,700 bytes，目视 counter=1 | 干净截图 67,184 bytes，目视 counter=1 |
| 连续 health 观测 | 13/13，约 60 秒 | 25/25，120.306 秒 |
| 查询动作 receipt | found / 原结果 | found / 原结果 |
| stop 与最终退出 | stop ack，测试正常返回，exit 0 | stop ack，测试正常返回，exit 0 |
| Home 后置条件 | submitted 后 fixture 仍 state 4，未证明切回主屏 | submitted 后 fixture 仍 state 4，未证明切回主屏 |
| 普通 App 冷启动 | app_launch_failed，NSPOSIX 3；16 次/30 秒无 health | host launch exit 0；16 次/30 秒无 health；其后单次进程 inventory 未见 Runner |

`state 2` 为 `UIApplication.State.background`；`state 4` 为 `XCUIApplication.State.runningForeground`。它们证明本次有宿主会话下 Runner 自报后台、fixture 前台，并在该条件下提供服务；Home 的 submitted 回包不证明主屏切换。activateFixture 后 probe/counter 仍正常，不代表从已确认后台恢复。

XCTest 总时长包含 fixture 启动与结束；不能充当服务连续存活时长。连续 health 样本才是对应时间窗口的直接证据。`testServe` PASS 自身也不充分：listener 失败当前只是 stop，不记录 test failure；这里的成功结论同时依赖真实 health/probe/tap/screenshot 与结束结果。

## 失败与恢复经过

1. 初始协议 XCTest 6 条中 5 通过、1 失败；测试 helper 用 XCTUnwrap 先记录了预期 parser rejection，已修正为直接 assert throws。该 Xcode 会话随后在结束阶段达到 Triton 300 秒超时；保留失败日志，不计通过。独立 SwiftPM 重跑 6/6 通过。
2. 首次签名尝试把证书 CN 尾部当 Team ID，得到 No Account/No Profile，exit 65。依据本机有效 identity 指纹匹配公开证书，改取 OU 后构建 exit 0；未读取/导出私钥。
3. 真机第一会话先遇到 Unlock iPhone，再在 Runner 启动后的 UI automation 初始化阶段 60 秒超时，exit 65，尚未进入 `testServe`。用户解锁后生成新 session/token，第二会话成功。不能仅凭该先后关系断言超时完全由锁屏造成。
4. 普通冷启动仅使用已安装原始 Runner 和业务 session 环境。Simulator launch 失败；真机 host launch 成功但未建立服务。没有执行图标、URL、DVT ActivateSuspended 或 RemoteXPC 完整 bootstrap；不把此实验当所有预装启动路径不可行。
5. Home postcondition 未成立。Simulator 额外 host framebuffer 为黑屏，AX 输出有限，无法独立证明 SpringBoard 状态；不猜測失效原因。

## 能力限制与下一轮门禁

- snapshot 仅两个固定 identifier，不是 generic AX tree。公开 `.exists/.label` 仍可能触发 XCTest 内部 snapshot，无法据此保证树采集耗时/内存上界。
- 8 MiB PNG 上限在截图和编码后判断，只约束返回大小；不保证采集阶段预算。
- UI 排队最多 8 项但尚无逐项过期拒绝；连接超时不会取消已提交操作。TTL、stop 和 XCTest execution allowance 不提供底层硬取消。
- 账本只覆盖 tap/home/activateFixture，最多 256 条、耗尽拒绝；只证明本次进程内已完成请求去重，不是持久化 exactly-once。每次启动必须分配新 session；复用旧环境 session 会让 host 误认新进程，并在已清空账本上重复动作。
- 本期客户端仅绑定 session/request 与精确 USB 设备；尚未实现生产 provider 的 buildID/nonce/完整 manifest、强制 owner/ref generation、generic tree、资源监测。
- 尚未验证 30 分钟存活及内存曲线、锁屏/熄屏服务、断 USB 重连、关闭 host test、设备重启、任意第三方 App、无宿主启动和 RemoteXPC 路径。

后续优先级：先正式化 host supervisor、分层 readiness、执行前 deadline、receipt/owner 与受限 AX 采集；再用固定 WDA/RemoteXPC 在同设备做冷启动 A/B，最后做锁屏/断线/重启和长时资源矩阵。完整场景见 [validation](./validation.md)。

## 测试、证据与清理

独立单测 41 条通过：Swift protocol 6、Python client/USB 32、session preparation 3。它们证明解析/预算/鉴权/去重/host transport 边界，不替代真实设备测试。

公开截图仅保存干净 fixture：Simulator counter1（原实验私有截图，未纳入本次提交）、iPhone counter1（原实验私有截图，未纳入本次提交）。第一次真机截图包含到达的私人通知，因此保留私有且不作为公开产物；后续截图确认通知消失后才归档。

两次成功 testServe 均通过正常 stop 退出，所属 xcodebuild 已结束；研究 USB 转发器已停止；自建 Simulator 已 shutdown（未删除）。真机普通冷启动后进程查询未见 Runner；Triton bundle-ID terminate 因无法核实 PID fail closed，没有提交终止命令，也没有猜测 PID。研究 app 保留安装，未卸载或改设备配置。

仓库 `verify.sh --local` 已通过：根 Swift tests（264 tests / 34 suites）、release CLI build/smoke、Harmony host smoke、iOS runtime observe smoke、可用 Simulator 的根工程编译、文档结构与 diff。编译日志出现既有 transport capture warning，未修改生产源码。此门禁不包含独立 PoC，故前述 41 条及两次真实 testServe 单独记录。文档 `--ci-docs`、独立 `check-docs.sh` 与 `git diff --check` 已通过；精确私有值扫描零泄露，公开两张 fixture PNG 已目视复核，所属测试/转发进程检查为空。
