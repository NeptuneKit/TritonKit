# SP-216 — Harmony 转发清理归属

## 状态与范围

2026-10-20 参考增量评估为可纳入；等待 `gpt-6.1-sol` 会话分派，当前同接口真实创建失败，不冒称开发启动。影响层仅为 macOS CLI/HTTP 现有 Harmony ArkWeb 临时 HDC forward 生命周期；不扩展 VM 管理、设备云、真机或新 Web 控制面。

基线 `main@f82872e2fa457431ee7cbc7df2bafecea7ca6f1c`；branch `feat/SP-216-harmony-forward-cleanup`；worktree `../TritonKit-worktrees/SP-216-harmony-forward-cleanup/`；独立主控 [SP-217](../SP-217-harmony-forward-integration/README.md)。按 SP-207 用户授权直接进入开发流程，必要本地提交/主控本地合并允许；未授权 push/tag/release、安装依赖、设备或第三方代码执行。

## 固定来源与缺口

来源 [ai-phone d339057](https://github.com/dongxinsuperman/ai-phone/commit/d339057bc64aa85002570765e2a20d45e0391bae) 的 [清理归属复核](https://github.com/dongxinsuperman/ai-phone/blob/d339057bc64aa85002570765e2a20d45e0391bae/backend/ai_phone/agent/harmony_vm/manager.py#L2438) 与 [隔离测试](https://github.com/dongxinsuperman/ai-phone/blob/d339057bc64aa85002570765e2a20d45e0391bae/backend/tests/test_harmony_fport_cleanup_isolation.py)。6 个增量提交/23 个最终文件及相关机制全文已读取，MIT 许可全文/hash 保存于 `.build/reference-monitor/20261020/agents-revyl/dongxinsuperman__ai-phone/`。独立 Swift 实现，若复制须保留许可通知。

main `CLIHostHarmonyArkWebRuntime.swift` 的 `harmonyArkWebWithForward` 在 body 后直接按缓存 localPort/remoteNode 构造 `hdc -t target fport rm`，未在删除前确认当前 listing 的 target/local/remote/direction。上游指出 `-t` 不保证 list/rm 的目标隔离，缓存端口也可被重分配；这属于上游源码与 fixture 主张，未在本机设备验证。[OpenHarmony 官方文档](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/dfx/hdc.md#查询端口转发任务列表)列出所有正反向映射，示例含 connect-key，并建议先 list 再删除，但不提供跨进程原子删除保证。

本期只保护既有 ArkWeb 清理：当前归属不确定时不删；进程内分配/归属确认/删除使用一致互斥范围，不声称能阻止其他进程的 HDC 竞态。不能因异常而重放已执行的 CDP body。

## BDD 与验收

- Given 新鲜完整 listing 唯一匹配 target/local/remote 且方向 Forward，When 清理自建映射，Then 只删除已证明的 tuple；创建前已存在的他人映射不得认领为本次创建。
- Given target/remote 已变、Reverse、重复/歧义/畸形/截断/null-like 输出、list 失败/超时或 unknown，Then rm 调用计数 0，返回稳定 cleanup uncertainty 与可脱敏的审计事实，不把资源已清理伪装为成功。
- Given 主 CDP 请求已失败且清理也不确定，Then 保留主失败，附加清理证据，不静默丢弃或自动重放；body 成功但清理不确定不得宣称完整交付。
- Given 本进程并发分配与清理，Then ownership-sensitive 区间串行且在 deadline 内，确定性测试证明不会删除被本进程重新分配的端口；明确跨进程竞态残余边界。
- Given 合法原行为，Then listing 成本、错误/schema/hint、敏感 target/socket/log 脱敏和单一 JSON envelope 保持有界；不依赖真实设备验证本期离线 parser/DI 契约。

## 文件面与交付

执行会话拥有本 space、`CLIHostHarmonyArkWebRuntime.swift`、必要新增 `CLIHostHarmony*Forward*.swift`、对应 Harmony ArkWeb/fake-HDC 测试，以及真实契约所需的最小错误/schema 接线。不得修改 SP-214 Simulator 文件或 SP-207 共享追踪状态；共享入口/索引/memory 归主控。超长源文件按现有规范拆分。

先失败测试，再最小实现；独立 scratch 跑 focused 和完整 CLI，按受影响层跑根包/local/docs 门禁。保留候选清单、SHA、红绿日志、确定性副作用计数和未验真实 HDC 语义。主控复核后必要本地合并，执行不自行合 main。后续新会话显式 `model="gpt-6.1-sol"`，不回退；你不是唯一开发者，不覆盖他人变更。

## 2026-10-21 实现与离线验收

- `harmonyArkWebWithForward` 创建 forward 后，在清理前通过同一 HDC target 执行 `fport ls`，解析当前映射，仅当 local/remote 精确匹配且方向为 forward、唯一归属时执行 `fport rm`；缺失、反向、重复、畸形、list 失败或 unknown 均返回 cleanup uncertainty 并保持 rm 计数为 0。
- 进程内 cleanup 由 actor 串行；跨进程 HDC 仍可能存在 list/rm 之间的竞态，报告保留该边界。主 CDP 失败优先保留，清理不确定性作为附加失败事实，不重放 body。
- `swift test --package-path CLI --scratch-path .build/sp216-cli --no-parallel --filter HarmonyArkWebBridgeCallTests`：37 tests passed；覆盖精确 tuple、reverse、unknown、list failure、cleanup failure 和单一错误 envelope。未执行真实 HDC/DevEco Emulator。
