# iCTRL v1.98.12：TritonKit 采用评估

日期：2026-10-16。上游固定 `d88bbf0b3a5addead31b4298d605d7ac7a87d6e7`，本地 `main@dd613a994abe45aa14e072c381662a0e3d868f03`；产品相关目录开工无未提交改动。本文评估当前源码，既有测试仅阅读，未在本轮执行。无性能量测、网络攻击复现或设备操作。

## 结论与排序

选择性借鉴安全原则，优先收敛已有发现链路；不引入上游完整 LAN/AWDL、配对管理或自制密码学。P1 表示建议下个实现批次，P2 表示后续强化，不是已证实可利用漏洞的严重性评级。

| 优先级 | 建议 | 当前事实与收益 | 复杂度与边界 |
| --- | --- | --- | --- |
| P1-A | 广播改为显式开启，发布状态反映实际结果 | serve 默认 loopback，仍无条件调用 Bonjour publish；对象非空就打印广播日志。收敛多余发现面和错误就绪解释 | 小到中；CLI 参数、schema/help、发布生命周期。显式 LAN bind 与显式 advertise 分开；不因此宣称 LAN API 已安全 |
| P1-B | SDK 发现改为显式策略，连接前区分候选与可信目标 | 无环境/bundle host 时自动 Bonjour，首个解析结果直接成为连接目标；TCP 可达不证明服务身份 | 中到大；bootstrap 默认值迁移、候选消歧、可信会话设计。先禁止静默首选，身份认证需独立设计，不能用公开 ID 代替 |
| P2-A | 默认日志只留元数据，限制长度并脱敏 | id=0 心跳已静默；未知 JSON、一般响应及 hierarchy 仍可直接输出原文。降低本地日志泄露与堆积 | 中；统一日志格式与输出策略，不改变返回给调用者的业务数据。错误/统计保留；敏感 payload 即使 verbose 也不能无条件放开 |
| P2-B | Runner 本机端口抢占威胁强化与真实鉴权负例 | 正常异会话已受 token/session/request 绑定；恶意本机监听器仍能先读 Bearer 并伪造 echo 回包 | 中到大；先做隔离负例与威胁模型，再选服务身份认证方案；若将来远端化则提升为前置门槛 |
| 已覆盖 | 配置完整预检、加锁、安全写入 | workspace 配置先验证，再加锁、备份与原子 rename；不是待新增整类功能 | 保留已有回归；文件持久化不等于监听器运行态事务 |
| 已覆盖 | Runner 目标与会话绑定 | 完整 target、唯一 USB Serial、每次新 token/session、回包 request/session 校验及 unknown 不重放 | 不改成按 host 保存长期密钥，不新增无认证 whoami 来替代这些保护 |
| 观察 | 配对指纹、冷却、发现恢复退避 | 对未来受控远端方案有价值，当前没有同类附近配对产品需求 | 另定范围；不先建 UI/管理 API、DDI 自动挂载或签名流程 |
| 不采用 | AWDL、nc 权限回退、纯 Python 密码学、明文远端屏幕流 | 扩大监听面、权限/依赖和审计成本，与当前本机入口边界不符 | 不复制上游代码，不新增远端控制产品面 |

## 本地证据与判断

### 发现与连接：优先处理既有边界

- [Serve](../../../../Sources/TritonKitCLI/CLIServeCommand.swift)：参数默认 `127.0.0.1:19421`；当前基线 1091 行仍无条件 `publishTritonBonjourService`，1135 行 helper 仅校验端口并 `service.publish()`，没有把发布成功回调作为状态依据。loopback bind 不等于广播关闭，广播也不等于 LAN 业务端口可达。
- [SDK bootstrap / resolver](../../../../Sources/TritonKit/TritonKit.swift)：39 行起，未指定 host 时执行 Bonjour；120 行起取首个解析结果并停止浏览；573 行起仅探测端口可达，随后连接 `ws://`，当前连接构造未附加服务身份认证。恶意或误配置发现服务造成误连是源码风险推断，本轮没有网络复现。
- [SP-129](../../SP-129-serve-loopback-default/README.md) 已明确保留 Bonjour 风险；本次是复核仍存在并提出下一切片，不是新发现一项已经被修复的问题。
- [ServeCommandTests](../../../../CLI/Tests/TritonKitCLITests/ServeCommandTests.swift) 保护默认 loopback 和显式非 loopback；[TKPlatformFallbackTests](../../../../Tests/TritonKitTests/TKPlatformFallbackTests.swift) 保护环境/bundle 配置覆盖 Bonjour。默认策略收紧会改变已有行为，必须给出显式 host/opt-in 迁移路径和 Release 说明，不能悄悄破坏真机开发连接。

明确 host 可避免发现歧义，但不构成密码学身份认证。建议第一切片只负责广播/自动发现默认策略、解释与迁移；需要远端信任时另设计双方认证及 secret 的安全交付，不能把 TXT、主机名、公开 device ID、TCP ready 或单候选当成认证。

### 配置：已有落地，不照搬上游运行态改配

[HostWorkspaceConfigStorage](../../../../Sources/TritonKitCLI/CLIHostWorkspaceConfigStorage.swift) 的 `save` 在写入前验证新配置/schema，锁内检查旧配置、保留原始字节备份、复核目录与文件身份、使用临时文件/fsync/rename 发布；读取限制大小，拒绝符号链接和未来 alias schema。[现有测试](../../../../CLI/Tests/TritonKitCLITests/WorkspaceConfigStorageTests.swift) 覆盖权限、旧配置损坏、symlink、未来版本及发布前失败保留原件。

本地 serve 的 host/port 为启动参数，当前不需要为借鉴而新增动态监听配置 API。上游 config 使用校验和串行执行、延迟 0.3 秒重启；重启失败只记日志，不能称作完整运行态事务。即便本地文件 rename 原子，目录 fsync 失败也不能推断文件仍是旧版本。将来动态切换须明确持久化/期望态/运行态和失败恢复，不借现有存储证明跨资源事务。

### Runner：既有保护与额外威胁分开

- [CLIIOSRunnerRuntime](../../../../Sources/TritonKitCLI/CLIIOSRunnerRuntime.swift) `boundSession/start` 绑定完整 target、准备资源摘要和进程归属，每次启动随机 32 字节 token、UUID session，有限 TTL。
- [CLIIOSRunnerTransport](../../../../Sources/TritonKitCLI/CLIIOSRunnerTransport.swift) 每次真机交换重列 usbmux 清单，以 USB Serial 精确唯一选择，不按旧序号/地址猜测；[Wire](../../../../Sources/TritonKitCLI/CLIIOSRunnerWire.swift) 关联 session/request，unknown 不重放。
- [随包 HTTPProtocol](../../../../Sources/TritonKitCLI/Resources/ios-runner/RunnerTests/HTTPProtocol.swift) 校验 Bearer/session；[IOSRunnerTransportTests](../../../../CLI/Tests/TritonKitCLITests/IOSRunnerTransportTests.swift) 与 [IOSRunnerLifecycleTests](../../../../CLI/Tests/TritonKitCLITests/IOSRunnerLifecycleTests.swift) 已有错误回包、旧绑定与身份歧义用例。它不同于 embedded SDK 自动发现链路，不能把两者的鉴权结论互相套用。
- Simulator 固定 `127.0.0.1:19439`；客户端先发送 Bearer，回包 session/request 是关联检查，不是 MAC。恶意本机监听器若先占端口，可以读到 token 并 echo 标识；这超出普通误连的既有保护。本轮未复现，也未把公开 whoami 当修复。
- 已读测试未找到对打包 Runner 实际鉴权调用链逐路由执行错 token/错 session 的完整负向证据；这是验证缺口，不能断言整个仓库绝无相关测试，打包成功也不能替代该证明。

### 日志：扩展已有降噪，不重复开发心跳静默

[CLIServerRuntime](../../../../Sources/TritonKitCLI/CLIServerRuntime.swift) 41 行起已跳过 id=0 ping，正常后台心跳不应列为未解决缺口。32–36 行未知 JSON pretty print、hierarchy/appInfo 与默认响应 payload 输出缺少统一脱敏/长度策略；[UI health probe](../../../../Sources/TritonKitCLI/CLIRuntimeUIHealthCommands.swift) 仍发起普通 ping，可针对高频只读成功收敛记录。没有证据证明本地存在与上游同样的 500 行日志环形缓冲淘汰问题，不能直接移植这个动机。

SP-192 的 alias、采集预算、settle、OCR、UI 健康五机制没有因本次上游更新而需要整体重做；诊断可借鉴静默成功、保留失败和计数的原则。

## 后续执行与验收门槛

本次主控负责文档整合，Runner 为只读子任务。未来按切片独立 space/worktree，由主控串行集成；不与 SP-201 或既有发布 WIP 混合。预期不新增外部依赖；若选认证方案需要依赖，先说明必要性。

| 顺序 / 文件面 | 先写失败场景，再实现的验收条件 |
| --- | --- |
| 1. serve 发布策略；ServeCommandTests、help/schema 与接入文档 | 默认 loopback 不发布；显式 LAN bind 也不隐式开启广播；显式 advertise 才进入发布流程；发布失败、停止、重试分别有真实状态，不能以对象非空报已发布；非法配置在 bind/publish 前失败 |
| 2. SDK bootstrap / resolver；TKPlatformFallbackTests | 默认不静默选首个服务；显式环境/bundle host 保持优先；多候选、超时、伪造 ID 不升级为可信；明确 opt-in 的发现候选也不等于认证；Debug 启用与 Release no-op 分别回归，文档给出兼容迁移 |
| 3. CLIServerRuntime 日志策略与独立输出测试 | id=0 心跳仍零常规日志；只读成功可静默但失败/计数保留；包含 token/私有字段或超长 JSON 的响应不原样泄漏；错误输出不二次包装，业务响应不被截断或改写 |
| 4. Runner 协议独立强化 / 验证 | 正常异会话占端口时不 ready、不动作；错 token、错 session、过期请求逐实际路由 UI 执行计数为零；USB 重排/缺失/多候选不漂移；针对恶意本机占端口，必须证明未向假服务发送可重用凭据且 echo 回包不能成功，未达到不能宣称双向认证 |

实现门禁：受影响的 CLI 解析/分发和 HTTP 测试、`swift test --package-path CLI --no-parallel`、`swift test`；SDK 变更另做 Debug/Release 编译和真实接入回归。按实际切片跑 `verify.sh --local` 及 public schema/skill 检查；Bonjour 状态和鉴权运行行为须有受控集成负例，不能仅 mock。此表是未来验收，不代表本轮已执行。

当前仅完成源码评估和规划。实际权限、设备、端口和隔离环境须在实现 space 再核对；本轮不启动服务、广播、Runner、签名或设备，也不修改长期自动化的只读边界。

## 原始来源与经验写回

- [正式 Release v1.98.12](https://github.com/OpenMinis/iCTRL/releases/tag/v1.98.12)、[完整增量](https://github.com/OpenMinis/iCTRL/compare/99dbfecdb39836ba26a0b2b0dcfde90f705a6835...d88bbf0b3a5addead31b4298d605d7ac7a87d6e7)。
- [固定 AuthManager](https://github.com/OpenMinis/iCTRL/blob/d88bbf0b3a5addead31b4298d605d7ac7a87d6e7/iCTRLKit/AuthManager.swift)、[固定 config 实现](https://github.com/OpenMinis/iCTRL/blob/d88bbf0b3a5addead31b4298d605d7ac7a87d6e7/iCTRLUITests/iCTRLUITests.swift)。完整上游读取与分页记录见 SP-193 检查摘要。
- 经验：上游采用优先级必须由当前源码重新计算；不要把“已有 Runner 身份绑定”“workspace 文件原子替换”和“默认心跳静默”继续列作整类缺失，也不要用它们证明 embedded 发现可信、运行态事务或日志全量安全。写回原参考档案；沿用现有治理流程，不新增重复 skill/AGENTS 规则。
