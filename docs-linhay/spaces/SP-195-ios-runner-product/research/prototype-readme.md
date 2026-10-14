# Resident Runner Research

独立 iOS 17+ 研究工程；不接入 TritonKit 生产 CLI 或 root SwiftPM。仅使用公开 XCTest、Network、SwiftUI API，控制专用计数器 fixture。

`xcodegen generate` 生成共享 `ResidentRunnerResearch` scheme。主控串行负责构建、签名和设备测试，避免与其它工作抢占。

UITest `ResidentRunnerTests.testServe` 启动 fixture，将 counter 初始化为 0，开启 loopback `127.0.0.1:19439` 服务，在主 RunLoop 等待直到 `/stop` 或 TTL。真实设备访问需要 host 建立精确设备的 USB 转发；应用 HTTP endpoint 另以 Bearer/session 鉴权，转发本身不提供应用层加密。此代码没有后台 entitlement、保活保证、解锁、重启自动拉起或私有 bootstrap。

运行测试前在 XCTest 测试环境配置：

| 环境变量 | 约束 |
| --- | --- |
| `TRITON_RESEARCH_TOKEN` | 必填，16...256 bytes；不可归档真实 token |
| `TRITON_RESEARCH_SESSION` | 必填，1...128 bytes |
| `TRITON_RESEARCH_PORT` | 默认 19439 |
| `TRITON_RESEARCH_TTL` | 默认 300 秒，范围 10...3600 |

所有请求必须携带 `Authorization: Bearer <token>`、`X-Session-ID`、唯一 `X-Request-ID`。响应 JSON 固定为 `{ok,sessionID,requestID,result,error}`，HTTP header echo request ID。一个连接一个请求、Connection close；header 上限 16 KiB，body 上限 64 KiB，最多 8 个连接，每连接最多 20 秒；不支持 chunked 或流水线请求。

| Route | Method / body | 验证范围 |
| --- | --- | --- |
| `/health` | GET | 独立网络队列；仅 listener 活着，不证明 XCTest 可用 |
| `/probe` | POST `{}` | fixture 状态 + 已知元素，`automationReady` |
| `/snapshot` | POST `{}` | 两个已知 identifier；不承诺全树采集预算 |
| `/screenshot` | POST `{}` | 公开 XCUIScreen PNG，上限 8 MiB |
| `/tap` | POST `{"expectedCounter":0}` | 单次 tap；counter 前置和 +1 后置条件 |
| `/receipt` | POST `{"actionRequestID":"..."}` | 查询原请求结果，不重复执行动作 |
| `/home` | POST `{}` | 公开 XCUIDevice Home，仅 submitted；后置状态另行验证 |
| `/activateFixture` | POST `{}` | 公开 activate，用于恢复前台实验 |
| `/stop` | POST `{}` | 停止服务并返回自己的测试方法 |

UI 请求按主线程串行；health、receipt、stop 不等待 UI。tap/home/activateFixture/crossApp 使用进程内、session 绑定的 request-ID ledger（最多 256 条，耗尽时拒绝）；同 ID 同 payload 返回原结果或 pending，不再执行；不同 payload 冲突。连接取消不能取消已发出的 XCTest 操作，超时必须查 receipt，不能盲重试。XCTest 自身可能阻塞或结束进程，此研究不提供硬取消保证。

`RunnerProtocolTests` 覆盖分片读取、认证、session/request-ID 绑定、字节预算、拒绝 method/path/chunked、重复 tap ledger 和 payload 冲突。测试先写后实现；是否通过以主控实际构建测试证据为准。

本目录独立 `Package.swift` 只编译 Foundation 协议模块和这 9 个测试，可在本目录运行 `swift test`，不改变仓库根 SwiftPM。它验证解析和账本，不验证设备 XCTest 运行。

当前队列限制：8 个待处理 UI 项和 20 秒连接超时控制资源，但队列项尚无独立失效 deadline；连接断开后的排队项可能在前项恢复后执行。实验 host 必须串行动作并查 receipt。正式化前应增加执行前过期拒绝；已执行 XCTest 动作仍无法硬取消。


本轮 Simulator/有线 iPhone 的实际结果见 [实验报告](./plans/20261014-lab-results.md)。每次 Runner 启动必须由 host 提供新 session；复用环境中的旧 session 不能保证跨进程去重。testServe PASS 必须同时结合服务与 UI 实测，不能单独证明 listener 成功。


追加 `/crossApp` POST 研究端点：app 白名单 fixture/settings/calculator/safari、expectedBundle绑定、operation指定；activate/probe可用于就绪判断，inspect最多40条返回（底层XCTest采集预算未知）。tap/typeText/back/navigateExample必须来自最新30秒inspect并在执行前唯一匹配/可点击，动作后清除观察。所有crossApp请求均进ledger，host要求allow_write；跨进程重启须新session。typeText仅固定测试短句，navigateExample仅Safari固定example.com；Home/scroll返回submitted，业务后置另验。原始系统UI和未知截图私有保存。场景见 [跨App计划](./plans/20261014-cross-app-validation.md)。

本轮多 App 实验结果见 [报告](./plans/20261014-cross-app-results.md)。截图使用 `XCUIScreen.main`，是设备全屏而非目标 App 专属画面；请求中的 app、前台 state 不能替代视觉归属核对。Safari 导航焦点校验未通过，不能将 testServe PASS 理解为所有业务场景通过。
