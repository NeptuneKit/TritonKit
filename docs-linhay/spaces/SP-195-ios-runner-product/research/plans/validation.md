# 常驻 Runner 分阶段验证计划

状态：标准 XCTest 的 Simulator/有线 iPhone 最小实验已完成；完整生命周期矩阵仍待执行。实际结果见 [20261014 实验报告](./20261014-lab-results.md)。技术事实与 proposed 契约见 [研究报告](../mechanism.md)。用户已授权展开调研与测试并选择有线 iPhone；后续不同风险的设备设置/发布仍按实际授权判断。

## 最小可执行研究切片

建立独立 XCUITest 工程，只包含一条 `testServe`：输出有限生命周期日志、启动已认证 listener、串行提供一次 SpringBoard state probe、正常 stop 返回。P0A 再加入有界 AX 和截图，不先引入私有触摸、shim 或手机端 DDI 代码。

优先标准 `build-for-testing / test-without-building` 流程；host 管理测试会话与转发进程的生命周期。Triton 当前 xcode schema 没有完整 resident-runner 工作流，不将 proposed 命令伪装为现有能力。后续执行先保存 `triton status/doctor/capabilities/schema/plan --json`，现有能力 unsupported 后才按精确参数回退，并记录原因与命令。

## 设备实验记录

每次实验固定：Runner IPA/app hash、bundle ID、插件 ID、Xcode/SDK build、iOS build、匿名 target、DDI 状态及准备方式、首次/已有授权、launch mode、Mac/Xcode/test process/USB/network 状态。不要公开签名证书、pairing file、密码或 raw UDID。

记录时间点：`+load → didFinishLaunching → setUp → test entry → listener ready → automation probe passed → background confirmed → stop/exit`。记录 PID、sessionID 和失败阶段；日志中出现 server started 不等于 UI 可用。

| 序号 | 实验 | 单独判断什么 |
| --- | --- | --- |
| E01 | 标准 Xcode 测试启动并保持会话 | 工程可编译/签名、测试服务和 UI probe 可用 |
| E02 | 健康、AX、截图连续 30 分钟，最终正常 stop | 连续服务、资源增长、测试 timeout 配置及可回收性 |
| E03 | 后台 30 分钟；锁屏 5 分钟；人工解锁 | health/AX/screenshot/action 分项能力，不以 wake 代替解锁 |
| E04 | 分别关闭 Xcode UI、停止 host test process、断 USB | 三种状态各自对旧 session 的影响 |
| E05 | 预装后终止旧 Runner，按图标/URL/RemoteXPC 分别冷启动 | 排除 warm session 残留；验证 Apple bootstrap 黑盒 |
| E06 | 只准备 DDI、不安装管理 App，再做 E05 | 管理 App 是否仅为准备辅助 |
| E07 | 首次授权延迟超过 30 秒、取消、完成后重启 | 等待授权与真实 crash 的区别，禁用进程内重复 bootstrap |
| E08 | 图标/URL/RemoteXPC/devicectl 分开，至少现代和最低拟支持 OS | launch mode × OS × Xcode 矩阵；已知不支持路径 fail fast |
| E09 | 崩溃后外部重启；设备重启后重新 preflight | refs/receipt/token 失效；DDI/授权重新检查，不承诺开机自启 |
| E10 | 同 ID/原插件 ID、设备/嵌入 XCTest、shim/无 shim 各自 A/B | 每次仅改一个打包变量，区分签名、dyld与 bootstrap 因果 |

E04–E10 属 P1 的设备准备/脱离宿主研究，不是 P0A 的常规功能门禁。关闭 Mac 后若没有可达通信路径，只能判断进程/日志，不能把不可达直接认定崩溃；提前安排独立受控探测并记录通道，不临时开放无认证 LAN。

## P0A 的 BDD 与失败测试

1. Given 两个可选设备，When 缺精确目标，Then 返回 ambiguous，launch 次数为零。
2. Given 设备管理层 ready，When XCTest session 不存在，Then manifest 不广告 UI 动作。
3. Given listener 有响应，When automation probe 未通过，Then transport ready 与 automation unavailable 分开。
4. Given handshake 的 device/build/nonce/protocol 不匹配，When 注册 provider，Then fail closed，不派发 UI 请求。
5. Given 缺 forwarding 工具或转发进程启动失败，Then 返回 transport 错误，不偷偷改走 LAN。
6. Given 无 token/错误 token/旧 session token，Then 拒绝请求，输出和 artifacts 不含 secret。
7. Given AX 超 nodes/depth/deadline/payload 预算，Then 收集停止，结果有 partial 与真实原因。
8. Given UI queue 卡住，Then health 仍有界响应，automation 为 degraded；不能虚报 underlying XCTest 已取消。
9. Given stop 请求，Then 正常返回长测试，只回收 owner 的 Runner/test/forwarder 进程。
10. Given snapshot/screenshot 证据缺失，Then 明确 skipped/failed，不合成可用 artifact。

先用 fake supervisor/transport 验证参数、身份、鉴权、状态机、预算和进程 ownership；有真实设备后再证明 XCTest/USB 及长测试，不用 fake 成功代替设备能力。

## P0B 的 BDD 与失败测试

1. Given 一个设备已有 session owner，When 第二 owner 申请写操作，Then 返回冲突且 Runner 收到写请求数为零。
2. Given App/scene/snapshot generation 变化或 Runner 重启，When 使用旧 ref，Then stale/target mismatch，不能沿用旧坐标。
3. Given tap 已发送但响应丢失，Then 返回 outcome unknown，不自动补点；只允许查询同 session/request receipt 或观察后置状态。
4. Given XCTest tap 已返回，When 期望文本未出现，Then delivered 但 postcondition failed，不能报告业务成功。
5. Given 同 requestID 重复写请求，Then 有界去重，receipt 对应同 session 和原 action digest。
6. Given read-only AX 与 tap 同时到达，Then UI 队列串行，不以观察豁免绕过 XCTest 互斥。
7. Given Release embedded SDK，Then 不连接、不采集、不响应；根 SwiftPM 不依赖 Runner/XCTest。

先做公共 API tap；私有 event injection 单独 capability/兼容测试，不作为 fallback 隐式加入。

## 分层证明与停止条件

| 证明层 | 必须提供 | 不能推出 |
| --- | --- | --- |
| 文档/static | 固定源码、引用、接入方案、BDD | 编译或设备可用 |
| SDK build | build/test bundle、hash、签名检查 | XCTest session 与后台存活 |
| transport | forwarding process、认证握手、target/session binding | UI automation 可用 |
| automation | SpringBoard/目标 App 有界 AX及截图 | 写动作和业务成功 |
| action | request receipt + UI interaction proof | 业务后置条件 |
| business | 显式预期状态 + freshness/evidence | 所有 App/OS 支持 |
| longevity | 持续探测、资源、背景/锁屏/断线矩阵 | 永久存活、自启或跨版本保证 |

启动失败三次且同一阶段无新增证据时，停止重复设备启动，收集有界日志与诊断；不要用进程内重复 XCTest bootstrap 或无限重装解决。被测设备由其他任务使用时不抢占。暂停/终止仅处理本实验拥有的进程和 session。

## 本轮门禁

本轮仅文档变更，执行 `verify.sh --ci-docs`、`check-docs.sh`、`git diff --check`。结果写回 space/memory。未进行设备实验，E01–E10 和 P0A/P0B 均为待执行计划。
