# iCTRL 2026-10-20 增量评估（bounded complete）

影响层为参考追踪/CLI、HTTP、Runner安全契约评估；没有修改产品、共享space或检查点。对照真实 `main@f82872e2fa457431ee7cbc7df2bafecea7ca6f1c`（`../TritonKit-worktrees/main-integrated`），主目录 `codex/wip-main-before-sp209` 不冒充 main。

## 来源与完整性

[完整比较](https://github.com/OpenMinis/iCTRL/compare/d88bbf0b3a5addead31b4298d605d7ac7a87d6e7...874f528759b1b977971a06cc4a3594d169eb77b9)：3 commits/9 files。

- [认证硬化14d689b](https://github.com/OpenMinis/iCTRL/commit/14d689b006c6417f1d16451fa280ec02fc49f4e7)：8 files。
- [RemotePairing ca2d225](https://github.com/OpenMinis/iCTRL/commit/ca2d22548c777a957d3d071e1ddfa7f45fd407ed)：3 files。
- [merge 874f528](https://github.com/OpenMinis/iCTRL/commit/874f528759b1b977971a06cc4a3594d169eb77b9)：9 files。

每个 commit 用 `per_page=100&page=1` 读取，均小于100，未触及300文件上限；compare total=3与实际列表一致。全部patch的增删行数与API additions/deletions相符。9个固定HEAD变更源文件均获取完整UTF-8，并逐一核对Git blob SHA等于compare文件SHA；另读DDIMounter、LogBuffer全文，固定HEAD tree `truncated=false`。逐文件大小/行数/hash见 `completeness.json`。

**有界完整**：全部增量patch/文件清单及相关机制调用入口已完成语义审阅，包括URL/通知、RunnerAdmin与Settings stop、whoami/schema、PairingFileStore与DDIMounter、LogBuffer。9份固定HEAD全文保存并校验；未声称无关历史每行或全仓安全审计，下载/hash不单独替代语义审阅。满足此增量范围的读取检查点推进条件，检查点由主控统一更新。上游未执行、未构建、未安装或运行资产，没有真实iOS兼容性结论。

GitHub最新非draft [Release仍v1.98.12](https://github.com/OpenMinis/iCTRL/releases/tag/v1.98.12)；HEAD的serverVersion/skill_version已为1.98.13，不能报告1.98.13已发布。Apache-2.0完整license hash `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30` 不变，固定[许可证](https://github.com/OpenMinis/iCTRL/blob/874f528759b1b977971a06cc4a3594d169eb77b9/LICENSE)。如未来复制代码须保留Apache通知/归属；本轮仅机制研究。

## 变化与当前工程裁决

| 机制 | 裁决 | 实际收益与边界 |
| --- | --- | --- |
| 任意App可触发的stop深链改为设备解锁确认；已配对App走加密config | covered/observe | 本地没有iCTRL深链/锁屏通知入口。真实main `Resources/ios-runner/RunnerTests/RunnerServer.swift`先解密认证才进入router，`/stop`验证session与TTL，发送响应后stop；`ProtocolTests/RunnerServerTests.swift`对11条route覆盖错密钥/session/method/过期并断言不stop。SP205已交付，勿重复立项。 |
| Copy Logs要求解锁并使用dumpRedacted | covered | 本地没有此通知剪贴板出口。`CLIServerRuntime.swift`使用`CLIServerResponseLogger.swift`，仅本地枚举/计数/字节，512 UTF-8字节上限，未知键/文本不落日志，SP204已覆盖此响应日志范围；不将此结论夸大为全仓日志出口普查。上游正则仍主要遮UUID/引号文本/IPv4，不替代Triton白名单。 |
| whoami删除name，schema示例同步 | observe | [HTTP入口](https://github.com/OpenMinis/iCTRL/blob/874f528759b1b977971a06cc4a3594d169eb77b9/iCTRLKit/JSONRPCServer.swift#L512)与[registry](https://github.com/OpenMinis/iCTRL/blob/874f528759b1b977971a06cc4a3594d169eb77b9/iCTRLKit/RPCMethod.swift#L441)一致。对iCTRL客户端是字段收窄兼容提醒。本地无whoami/附近配对key选择器，不据此删除合法本机status字段。same-origin是浏览器读取限制，并非认证。 |
| callback仅向ictrl-app scheme添加地址 | reject直接照搬 | [URL处理](https://github.com/OpenMinis/iCTRL/blob/874f528759b1b977971a06cc4a3594d169eb77b9/iCTRLUITests/iCTRLUITests.swift#L642)减少任意callback泄露，但scheme字符串不能证明接收App身份；本地无同类入口，不新造控制面。 |
| RemotePairing import调用实际消费parser | observe | [PairingFileStore](https://github.com/OpenMinis/iCTRL/blob/874f528759b1b977971a06cc4a3594d169eb77b9/iCTRLApp/DDI/PairingFileStore.swift#L136)使用rp_pairing_file_from_bytes，释放错误和handle，拒绝lockdown并明确提示。实际[performMount](https://github.com/OpenMinis/iCTRL/blob/874f528759b1b977971a06cc4a3594d169eb77b9/iCTRLApp/DDI/DDIMounter.swift#L237)确为rp_pairing_file_read。但primeCryptoProvider仍读lockdown，影响未知，不能宣称全挂载兼容。Triton无配对文件导入/自行DDI挂载，收益不足以引入IDevice和新边界。 |

SP203的广播显式opt-in/发现信任边界已有交付，本轮未改AWDL/Bonjour。SP192的30秒alias、预算、视觉settle/OCR/UI health，以及SP196的geometry/evidence/完整性和SP200的Runner/设备诊断均未出现新增对应上游代码，不能把旧差距重新立项。

`CLIIOSRunnerTransport.swift`实际main维持单deadline、一次连接一次request、无redirect/retry/proxy，失败`ios_runner_transport_unknown`、`delivery=unknown`、`retryable=false`；本轮上游`stopRunner` catch后切到仅请求确认的深链不应被移植成Triton未知动作自动重放。

## 采用与后续验收

暂无 adopt 项，无新增space、文件所有权或执行会话。观察项仅在本地明确增加相应入口或出现可复现缺口时重新评估，届时需先写BDD与失败测试：未认证入口不得泄露身份或stop；callback不得凭scheme信任；预检与真实parser同输入一致；unknown不得重放。当前没有必要产品修改，故未跑Swift/设备测试，也不把既有交付的测试数冒称本轮通过。

经验检查命中现有参考采用流程，沿用“实际main与主目录分离、下载与完整阅读分离、成功检查点不随partial推进”，没有新可复用规则需扩写；本报告作为主控归档素材，未写共享memory。读取complete限定上述增量与相关机制；产品采用状态独立。
