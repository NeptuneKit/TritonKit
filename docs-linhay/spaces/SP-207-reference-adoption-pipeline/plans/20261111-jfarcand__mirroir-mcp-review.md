# mirroir-mcp 2026-11-11 固定增量部分复核

结论：**partial / revise-first；complete_review=false；不推进成功检查点，不登记新 adopt。** 本轮完成固定提交清单与关键协议、安全、本机可用性源码复核；采集不等于审完。

- repository：`jfarcand/mirroir-mcp`
- checkpoint base：`1166ac1517263d773703c08ceae762a20432d3a2`，来自仓内 `SP-207/plans/20261102-observations.json`。
- head：`5a3f93d86fdd40aad7d1a6267223146e110870dd`，固定于本目录 `result.json`。
- actual main：`607410fb3d44bfe02274c13822170c3015c63a99`，产品比较只用该 SHA 的 git blob，不取 SP-281 WIP。
- 最新非 draft Release：v0.45.0；前检查点 v0.42.0。Release 正文已读；输入前台/指针保持、flick 改动及键输入已知限制只是上游声明，未在本机执行验证。
- Apache-2.0 许可证全文 10771 bytes，SHA256 `52327c57e955a3e63f872960938e814acc19eb1b77c501999f5fd1e543b21346`，与既有记录相同。

原始来源：[固定 head](https://github.com/jfarcand/mirroir-mcp/commit/5a3f93d86fdd40aad7d1a6267223146e110870dd)、[固定增量](https://github.com/jfarcand/mirroir-mcp/compare/1166ac1517263d773703c08ceae762a20432d3a2...5a3f93d86fdd40aad7d1a6267223146e110870dd)、[Release v0.45.0](https://github.com/jfarcand/mirroir-mcp/releases/tag/v0.45.0)。比较网页只是导航；实际采集用固定 SHA 的 GitHub API tree / commits 和 raw 文本。

## 覆盖与缺口

- commit pagination：第一页面 100 条已找到精确 base，base→head 共 **52 提交**，包括一条 merge，共 **53 parent edges**。完整提交元数据和消息在 `review-commit-inventory.json`；全读提交消息不等于审完所有改动。
- 每 parent 树差异完整采集 **4 edges**：`5a3f93d86f`、`006e61d62f`、`cff7e0b12d`、`5a3ff6114e` 各自与 parent。对应 changed path 数 5 / 30 / 1 / 20。它们仍未逐文件全部语义复核，**没有提交被标为全文件审完**。
- 需要 54 个不同 revision 树，实际保存 **6 个**，均 `truncated=false`；缺 **48 树**，尚有 **49 edges** 未完整采集。第五条 `9984cf8f4e` 的大量文件只采集部分。缺树名单见 `review-manifest.json`。
- **352 个不同 path+blob 文本版本**已取得，UTF-8 解码、无 NUL、Git blob SHA1 与 SHA256 校验；其中本轮完整语义复核的 head 文件 **14 个**，如下。其余 **338 版本**仅可称采集校验，不能称已审；未采集的额外版本数量未知。未覆盖范围始终是相对 11/02 checkpoint 的完整 52 提交增量，不以新 head 重设基线。
- 普通 strict TLS 官方连接；请求前按源码/测试/文档用途与文本扩展白名单筛选，拒取 binary、identity、credential、secrets、key/certificate。未关闭证书验证。没有运行上游代码、依赖、设备或签名。
- 为按主控限定范围收口，在部分第五 edge 期间停止自己 collector，`review-collect.log` 保存 KeyboardInterrupt；不是上游“无变化”，也不是完整检查成功。后续 focused 固定 head 文本请求成功。
- 11/03 未提交 archive 已缺失，原因 unknown。本目录属于 **11/11 新取的固定 SHA 副本**，不是恢复的历史 API 响应或复现日志。

## 实际完整阅读的 head 源码与测试

以下全文阅读与 `review.json.sources_reviewed`、`review-text-coverage.json` 对应；测试仅静态阅读，没有执行。

- `Sources/mirroir-mcp/MCPHTTPEndpoint.swift`，blob `119df4c2b5a74059a7f91c81000e34d8e4221776`。
- `Sources/mirroir-mcp/NetworkHTTPServer.swift`，blob `7a62fb15d592c1ef4cc5cf0686a7e4018308f29b`。
- `Sources/mirroir-mcp/HTTPMessage.swift`，blob `20fcfd435046b2f74d7f171fc0637cd2483b763a`。
- `Sources/mirroir-mcp/ScreenCapture.swift`，blob `6f7e17e58a66208bea55616f337d78527d6ef64d`。
- `Sources/mirroir-mcp/ScreenCaptureKitShot.swift`，blob `d7a323c158bc488d633a19cb94523b60d7b54d9f`。
- `Tests/MCPServerTests/MCPHTTPEndpointTests.swift`，blob `e5d8fed1a206b2370f7b810801dfc86d85617074`。
- `Tests/MCPServerTests/NetworkHTTPServerTests.swift`，blob `0cf989fc85c9182b94c864a67a32f568f31849ef`。
- `Tests/MCPServerTests/ScreenCaptureKitShotTests.swift`，blob `66895048880b1aa7b59286aaaec1e0920c21f4e0`。
- `runner/src/target/process_port.rs`，blob `a18cf2a23945568ad108d0c88e7cccc5cb016581`。
- `Sources/mirroir-mcp/ServeAppBundle.swift`，blob `b9624e7b384d955603b1db0bd68532c0cd2b773c`。
- `Sources/mirroir-mcp/ServeToken.swift`，blob `b9c5dc18d27af6f0fe22f51bdad291b2046e9c40`。
- `Sources/mirroir-mcp/ServeCommand.swift`，blob `b00bca813f89282fdf373b6e66c845b708be8b5b`。
- `Sources/mirroir-mcp/SessionBlock.swift`，blob `81be96b137f0d6bd05a830207e22af3a2a0030a2`。
- `Sources/mirroir-mcp/AgentNotes.swift`，blob `bdd4c564637c4beaf97584b6652787fcffd5cd27`。

主线固定副本见 `review-local-main-manifest.json`：`CLIWebRuntime.swift`、`CLIHostNativeHIDRuntime.swift`、`CLITestImportRuntime.swift`、`WebCommandTests.swift`、`TestImportTests.swift`。本轮重点重读 WebRuntime 225–229、593–649 与 WebCommandTests 371–432；后者通过注入 Bool 断言 idle/occupied DTO，没有证明 socket 总 deadline。TestImportTests 仅保存比较上下文，未声称全文审查。

## 机制判断

1. **本机 Web 端口探测：revise-first。** 上游 `runner/src/target/process_port.rs` 用一个 monotonic deadline 覆盖 v4/v6；open 等待通过有界重叠连接避免一个挂起 attempt 阻断后续，drop 取消任务；closed 探测不把挂起/超时直接当作 refused。主线 `CLIWebRuntime.swift:225` 先同步 `isTCPPortListening`，`:599–628` 仍裸 blocking connect；失败统一 false。后置 `URLRequest.timeoutInterval=1.0` 无法保护先前 connect。这是本轮独立静态证据，**未新增真实挂起复现，不断言 bind-but-not-listening 必然挂起，不宣称旧候选已采用**。需主控先裁决 Bool 兼容性、unknown 与启动 fail-closed 契约和确定性测试，不能照搬 Rust 并发实现。
2. **HTTP 协议/安全/预算：observe。** 上游 fixed loopback、强制 Bearer、默认拒 Origin、读 body 前鉴权、拒绝重复安全 header；header 16KiB/body 4MiB/nesting64/16 连接/绝对30秒读 deadline；工具串行执行，client 离开时 dispatch 前跳过。这些机制在源码与针对性测试中一致。尚未完整对照 Triton 当前 HTTP 内部鉴权与队列，未建立新的主线缺口；不扩展 MCP/SSE/对外 HTTP 面。上游声称支持的 MCP 版本未独立对照规范，本轮不认证其规范合规性。
3. **采集完成与图像真实性：observe。** SCK latch 首次结果获胜；completion 被释放可报告 handlerDropped，保留不回调可超时，只有 brief error/dropped handler 最多重试3次。截图 fallback 对已知 window ID 不夺前台，非前台时拒取易被遮挡的 region。静态读到这些边界；没有本机 SCK/TCC/跨 Space 验证，没有证明 Triton 相同 provider 存在缺口。上游 replayd 成因解释未本地验证。
4. **Agent notes：observe。** 500 字/条、50条/topic、明确替换，注释区分历史观测与用户指令。未证明 Triton 缺少对应公开需求，不自动新增持久写面。
5. **签名 bundle、iPhone Mirroring、Maestro/run_steps/game/input：不分派。** 前两者超出本轮自动采用动作边界；其余在提交 inventory 可见但尚未完整审相关增量，不能从标题推断采用。当前 Triton 编译 testcase 导入与 Maestro importer 不是同一能力；本轮不提出替换。

## 端口候选若继续的 BDD 与验收边界

- Given connect pending，When status 检查，Then 所有地址共同受一个总 deadline 约束，返回可区分 unknown/error，不能当 idle/free。
- Given v6 pending、v4 listening，When 检查，Then 总预算内可报告 live 且关闭所有 fd/task。
- Given timeout/DNS/socket 资源错误，When start 检查，Then 单一稳定 JSON failure、未知 fail-closed、不启动子进程。
- Given 本机真实 refused，When 检查，Then 保持既有 idle/start 行为；兼容性由主控先定，不能静默改 Bool 语义。

拟文件面仅 `CLIWebRuntime.swift`（现有 error/DTO/runtime）、`WebCommandTests.swift` 以及按实际 schema owner 与公开契约决定的 schema/docs。应先失败测试再最小实现，focused/full tests 由主控串行执行；没有创建 space/branch/worktree，没有写产品或采用登记。

## 验证与沉淀

已验证固定主线 SHA、352 文本 blob hash、6 无截断树、52 提交 inventory 到 base、许可证全文 hash；未执行上游/Swift/Rust 测试、live socket 复现、采集/设备/签名。仅归档资料，没有仓内文档改动，因此不由本子任务运行共享 docs 门禁。

经验核对结论：现行治理已覆盖 partial 不推进、fresh copy 不冒充历史证据、子任务完成不等于采用完成。本轮没有新增规则；SP-207/memory/检查点由主控统一写回。本次 review 的缺口和状态已先落盘，避免只留会话。
