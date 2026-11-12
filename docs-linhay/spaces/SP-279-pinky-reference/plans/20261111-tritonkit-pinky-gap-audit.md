# TritonKit × Pinky 当前差距审计（2026-11-11）

## 结论

**主要差距已经从“缺动作原语”转为“常驻执行状态、人机协同和默认任务闭环没有贯通”。** SP-280/281 的 shared context、receipt 和 evidence 补上了基础，但不能等同 Pinky 全网关的审批、接管、Stop、resume 和逐动作观察链。

TritonKit 的开发诊断、embedded SDK、Harmony、WebView、构建/测试与可执行回归更广。Pinky 的优势集中在“把个人真实手机交给 Agent，同时让人观察、审批、随时接管”的完整产品体验。二者并非一条功能数量排行榜。

最先处理一个现有接线缺陷，然后整合已有机制；不建议立刻复制 Pinky 桌面、Companion 或远程控制面。

## 审计基线与证据等级

| 项目 | 本轮事实 |
| --- | --- |
| TritonKit | main `14574a7b26e2f69187d0ad21959cfcf3164f182d` + 当前工作区 WIP；SP-281 receipt/evidence 包含未提交实现，不能称为已发布能力 |
| Pinky | 恢复独立 clone，固定 `329f35ac2e240805e265a483fa2d3ff0f84780d3` / `v2026.1111.17`；该提交在上海时间 2026-11-11 18:19:57 生成 |
| 与历史研究的距离 | 从 `209aa9e4b2ff1fd81edec3c393a64b21b79162fb` 增加 324 个提交，旧结论不直接外推 |
| 静态核对 | 当前 handler/caller、状态模型、测试源码、README；两名只读子审计，主控复核关键调用链 |
| 实际运行 | 仅使用现有 Triton release CLI 做两次必定无法到达 provider 的参数解析探针；未编译/运行 Pinky、未安装依赖、未启动 server、未操作设备 |
| 许可证 | 恢复副本仍为 Apache-2.0；具体文件hash见[证据清单](./20261111-pinky-gap-evidence.json) |

本报告是**面向机制的源码差距审计**，不是 324 个提交的逐提交全量采用评估；不推进 SP-207 的成功检查点，不把上游测试源码或 README 中 checked 标记当作本地实测。

## 差距矩阵

“部分”表示存在明确代码和局部闭环，但覆盖范围/owner/状态机尚未统一；“范围差异”需要先确定产品方向，不自动列入实现清单。

| ID / 优先级 | 能力 | Pinky 当前实现 | TritonKit 当前事实 | 剩余差距与处理建议 |
| --- | --- | --- | --- | --- |
| G0 / P0 | CLI↔HTTP 参数一致性 | MCP tool直接进入统一 Session/Gateway | device parity HTTP 尾加 `--json`，typed device action parser未声明该参数；已有 parser-only 反例 | 已确认接线缺陷；补完整实际argv→parser→executor测试，先修接入链再扩能力 |
| G1 / P0 | 所有 mutation 共用执行owner | 常驻Gateway按device维护lease、action lock、inflight；锁前/锁后gate、provider前preflight | shared coordinator生产只有 typed device.action 与 specialized platform-control 两个caller；act/app/HID/WebView/管理动作使用各自专用合同 | 优先统一主入口act和关键provider的owner/receipt/generation，不只增加DTO字段；保留既有provider安全检查 |
| G2 / P0 | 人工审批与撤销 | Approval Center绑定session/device/lease/tool/args，单次消费/超时/撤销；Agent无Decide入口；批准后重新观察并拒stale | 有policyDecision/approval字段和非allow拒绝；生产两context工厂主动设allow；管理confirm/workspace allowlist是局部gate | 缺受信任issuer、可撤销binding与批准后snapshot重检的端到端控制面；先CLI/HTTP合同，UI不是前置条件 |
| G3 / P0 | TakeOver/HandBack/Stop屏障 | 用户操作接管、撤销pending approval、取消等待；交回带note；Stop继承到后续resume session | 有lease takeover、resident Runner stop、workspace stopped/paused；workspace stop本体主要落盘，无同一owner全局取消链 | 需要“停止→不再接收新动作→旧结果不推进新任务→显式恢复”的跨入口联合验收；不能把任何一个stop命令当全局屏障 |
| G4 / P1 | 动作前快照/动作后闭环 | 读取当前屏幕→解析ref→策略→输入→settle→diff；审批重读target/文本/位置；CallBudget贯穿锁/读取/等待 | @alias有30s+live fingerprint；UIKit selection有revision/window/identity guard；resident iOS有inspect/bundle/geometry校验；workspace有execute→observe/settle→business wait/assert | 能力不是空白；新typed device.action部分provider只携带/哈希observationID和geometry，尚未提交前重观察；将已有guard绑定同一receipt，而不是重写settle |
| G5 / P1 | 自动逐步历史与完整任务证据 | gateway默认逐动作记录状态、耗时、前后图，任务历史/录屏/导出；可配置NoScreenshots等 | evidence capture/redact/inspect、run events、workspace atlas/plan/test recorder已有；SP-281 evidence是两类caller显式opt-in | 缺跨入口默认任务日志与统一before/after关联；可先自动记录轻量metadata，图像按显式策略采集，保留我们的隐私/体积约束 |
| G6 / P1（本机）；P2（远程） | session/多会话/重连 | resume只接管空闲旧lease；同Agent新session可继续旧task，Stop保留；shared MCP session多task后强制显式device | serve lease有owner/TTL/takeover；resident iOS另有session/TTL/allowlist/ledger；没有将其与通用generation整合成同一任务身份 | 本机先明确run/session/task/lease owner关系；远程resume另立范围。不能复制User-Agent会话兼容方案作为强身份 |
| G7 / P1 | 语义隐私与危险操作策略 | 输入密码/OTP拒绝、默认屏蔽金融/密码管理App、Ask/deny优先、截图遮盖；录屏导出额外审批 | 有private input HMAC、private artifacts、evidence redact、app/session allowlist、risk/confirm和Debug隔离 | 工程脱敏较强，缺贯穿读取/图像/输入的“个人手机”语义策略。若仍只做开发工具，可先做字段/截图策略而非支付关键词引擎 |
| G8 / 范围差异 | Android后台工作/人工触摸事件 | Android13+可后台display运行Agent；Companion参与屏幕读取/输入与事件；人工触摸进入接管逻辑 | 已有AndroidBridge AccessibilityService、树/输入/多stroke手势、HTTP/auth；service明确按需pull，非事件驱动；已有录屏和预览入口 | 不能写成“没有Companion”；缺Pinky式后台display、服务事件→网关控制权和个人手机部署闭环。实现前先裁决是否扩真实手机场景 |
| G9 / 范围差异 | Agent接入与人用桌面 | 多Agent一键配置、自动安装/更新skill、审批卡片、镜像输入/接管、任务历史 | CLI/HTTP+public skills+DSH插件入口已有；Web当前以只读设备展示为边界，无该审批操作台 | 通用MCP/一键配置是易用性差距；桌面改造不是共享执行核心的前置需求，不能为对齐而开放Web写操作 |
| G10 / 范围差异 | 跨宿主/真实手机开箱体验 | 当前README声称macOS arm64/Intel、Windows/Linux及Android/iPhone，多后端与设置/权限向导 | 当前正式CLI发行macOS arm64；已有SDKless resident iOS Runner、Simulator/Android/Harmony能力，部分真机代码与独立scope | 不可说“无免SDK/无真机支持”；缺的是同等跨宿主、普通用户手机体验与相应验收矩阵。上游硬件/性能数字本轮未实测 |
| G11 / P1 | 一致deadline与batch恢复 | gateway全调用budget、动作锁等待预算、settleOwed、batch遇approval/budget停止 | host runner、wait/settle、workspace等已有局部deadline；并非一份预算贯穿所有provider与owner | 整合端到端budget并区分“未提交超时”和“已提交但未观察”；不将已送达输入当成可取消/可自动重试 |

## G0：已复现的具体接线缺陷

生产路径：

1. [serve注册device parity](../../../../Sources/TritonKitCLI/CLIServeCommand.swift#L53)。
2. [HTTP allowlist包含tap/double-tap/press/swipe，并强制追加--json](../../../../Sources/TritonKitCLI/CLIDeviceParityHTTP.swift#L43)。
3. [typed action common/parser不声明json或format](../../../../Sources/TritonKitCLI/CLIDeviceActionsCommands.swift#L7)。
4. [schema却声明这些选项](../../../../Sources/TritonKitCLI/CLISchemaHostCommands.swift#L446)。

本轮用现有release二进制执行：

```text
triton device press --device android:fixture --platform android --button __invalid_no_action__ --json
→ exit 64
→ action=cli.parse, error.code=unknown_option
```

所有必填已给出，button故意非法：即便parser日后接受json，也会在构建payload时拒绝，保证不能到provider。第一次缺少必填的探针只返回missing_argument，不作为json差异证据。

结论：**parser错误已运行复现；HTTP失败依据实际注册/argv拼接/子进程生产链静态推导。未发真实HTTP请求或设备输入。** 当前测试的注入executor/argv拼接覆盖不能替代完整实际parser链。此项本轮只记录，不修改产品代码。

## 最关键的源码证据

### Pinky：真正的网关状态机，不只是字段

- [gate](https://github.com/DIYgod/pinky/blob/329f35ac2e240805e265a483fa2d3ff0f84780d3/internal/gateway/pipeline.go#L301)：lease ended、setup、offline、person-in-control、approval busy、locked、scope联合判断。
- [act](https://github.com/DIYgod/pinky/blob/329f35ac2e240805e265a483fa2d3ff0f84780d3/internal/gateway/pipeline.go#L439)：action lock后再次gate、fresh screen、prepare、policy、审批或execute。
- [runApproved/preflight](https://github.com/DIYgod/pinky/blob/329f35ac2e240805e265a483fa2d3ff0f84780d3/internal/gateway/pipeline.go#L1581)：批准后重读screen/snapshot，provider前再次检查。
- [approval.Binding](https://github.com/DIYgod/pinky/blob/329f35ac2e240805e265a483fa2d3ff0f84780d3/internal/approval/approval.go#L59) 与 [TakeOver/HandBack/Stop](https://github.com/DIYgod/pinky/blob/329f35ac2e240805e265a483fa2d3ff0f84780d3/internal/gateway/client.go#L429)。
- [resume](https://github.com/DIYgod/pinky/blob/329f35ac2e240805e265a483fa2d3ff0f84780d3/internal/gateway/resume.go#L81)：inflight>0不adopt；同task/新session及Stop保护；[shared session](https://github.com/DIYgod/pinky/blob/329f35ac2e240805e265a483fa2d3ff0f84780d3/internal/gateway/shared.go#L9)处理多conversation无法区分的问题。
- [call budget](https://github.com/DIYgod/pinky/blob/329f35ac2e240805e265a483fa2d3ff0f84780d3/internal/gateway/budget.go#L10)、[refs](https://github.com/DIYgod/pinky/blob/329f35ac2e240805e265a483fa2d3ff0f84780d3/internal/screen/refs.go#L8)、[screen diff](https://github.com/DIYgod/pinky/blob/329f35ac2e240805e265a483fa2d3ff0f84780d3/internal/screen/diff.go#L3)。

### TritonKit：已有局部机制必须保留

- [shared receipt/coordinator](../../../../Sources/TritonKitShared/TKActionReceiptModels.swift#L147)、[typed device执行](../../../../Sources/TritonKitCLI/CLIDeviceActionExecutionRuntime.swift#L121)、[specialized Apple runner](../../../../Sources/TritonKitCLI/CLIHostApplePlatformRunnerRuntime.swift#L254)。production shared调用覆盖这两类，不能宣称所有mutation已接入。
- [lease HTTP gate](../../../../Sources/TritonKitCLI/CLITargetLeaseGate.swift#L13)与[serve lease store](../../../../Sources/TritonKitCLI/CLITargetLeaseStore.swift#L46)：check在store内原子，不等于check→外部provider原子。
- [resident iOS request](../../../../Sources/TritonKitCLI/CLIIOSRunnerRuntime.swift#L196)：host action lock、session ownership/TTL/allowedBundles；[device RequestLedger](../../../../Sources/TritonKitCLI/Resources/ios-runner/RunnerTests/HTTPProtocol.swift#L315)与[server claim](../../../../Sources/TritonKitCLI/Resources/ios-runner/RunnerTests/RunnerServer.swift#L154)已有same-session requestID+fingerprint去重。**不能用shared默认per-call store推导整个Triton没有跨进程保护。**
- [node alias freshness](../../../../Sources/TritonKitCLI/CLINodeAliasFreshness.swift#L43)：必须live observe、target/source/page fingerprint匹配、30s且唯一identity。
- [workspace action loop](../../../../Sources/TritonKitCLI/CLIWorkspaceActionLoopRuntime.swift#L113)：已有执行后观察与business wait/assert；[workspace stop](../../../../Sources/TritonKitCLI/CLIWorkspaceRuntime.swift#L812)目前是落盘状态，不是该loop的全局在途取消证明。
- [Android bridge service](../../../../Tools/AndroidBridge/app/src/main/java/jp/lycorp/tritonkit/bridge/service/TritonKitAccessibilityService.kt#L25)已有server生命周期；[GestureHandler](../../../../Tools/AndroidBridge/app/src/main/java/jp/lycorp/tritonkit/bridge/handler/GestureHandler.kt#L9)已有dispatch/multistroke，返回accepted后仍需观察验证。
- [SP-281动作证据writer](../../../../Sources/TritonKitCLI/CLIActionEvidenceRuntime.swift#L73)：排他新根、typed receipt、JSONL、hash、原子manifest，当前是显式opt-in，不是所有session默认记录。

## 不应被误报为差距的能力

| TritonKit已有或更广的方向 | 对比解释 |
| --- | --- |
| embedded SDK、UIKit语义/选择/revision、Lookin检查 | 面向App开发者的进程内可观测/可验证状态；Pinky主要是外部手机控制，不能用手机mirror替代这些能力 |
| Harmony/DevEco、ArkWeb/WebView、host诊断 | 本轮Pinky README及已读provider路径未显示同类Harmony链；不为模仿Pinky放弃现有产品宽度 |
| Xcode/SwiftPM/build/test、xcresult、host日志、容器/偏好等 | 是开发工作流资产；Pinky的app launch/install不是完整构建/测试/调试替代物 |
| .tritonplan可执行回归 | Pinky的Watch replay是逐步骤/截图回看（[UI实现](https://github.com/DIYgod/pinky/blob/329f35ac2e240805e265a483fa2d3ff0f84780d3/ui/activity.go#L417)），不能等价成重新执行动作；Triton[plan执行器](../../../../Sources/TritonKitCLI/CLIEvidenceReplayRuntime.swift#L96)确实调用步骤，但[test-recorder local-device](../../../../Sources/TritonKitCLI/CLITestRecorderReplayRuntime.swift#L84)仍返回not-run/deviceCommandExecuted=false，不能把全部replay产品线都算完成 |
| 强机器可读receipt、manifest内容hash、fail-closed恢复 | 不应为了更流畅的UI降低unknown/partial或把像素settle提升为业务成功 |

以上是已核对的产品机制差异，不是性能排名；本轮没有对同硬件/同任务测速度、内存、成功率或token消耗，不能给百分比领先/落后。

## Pinky自身的边界：不能原样照搬

1. **User-Agent不是强身份。** [sessionless兼容层](https://github.com/DIYgod/pinky/blob/329f35ac2e240805e265a483fa2d3ff0f84780d3/internal/mcp/sessionless.go#L14)按User-Agent维护sticky session；有Bearer token与[HTTP防护](https://github.com/DIYgod/pinky/blob/329f35ac2e240805e265a483fa2d3ff0f84780d3/internal/mcp/http.go#L66)，但会话兼容标签不是独立conversation授权身份。
2. **Stop/budget不保证撤回已送达输入。** call budget明确只限制gateway等待读取/settle/审批，不中断手机已经执行的输入；Triton应保留delivery unknown的事实。
3. **录屏不等于脱敏截图。** [save.go](https://github.com/DIYgod/pinky/blob/329f35ac2e240805e265a483fa2d3ff0f84780d3/internal/gateway/save.go#L22)明确录屏不遮OTP/blocked通知，因此每次导出另问人。不能把上游“有隐私策略”写成全部媒体自动脱敏。
4. **背景display和iOS后端有平台前提。** README当前宣称Android13+后台屏、iOS27新后端/旧系统helper，但本轮未在任何手机验证；旧ACCEPTANCE的Intel未完成等条目属于早期快照，不能覆盖较新README/实际CI。
5. **gateway不是OS权限沙箱。** 网关策略约束通过它的调用，不意味着同宿主的shell/其它adb工具被物理隔离；不能照搬“安全手机agent”的宣传作为严格安全证明。

6. **上游导出存在媒体缺失降级。** [exportTo](https://github.com/DIYgod/pinky/blob/329f35ac2e240805e265a483fa2d3ff0f84780d3/internal/gateway/export.go#L119)读取不到图像会略过，复制录屏失败记warning并移除Recording后继续写HTML/JSON。报告文件存在不等于媒体完整；我们应保留manifest/partial的机器判断优势。
7. **跨宿主包不等于全设备矩阵已测。** 当前README仍明确[iPhone on Windows未测](https://github.com/DIYgod/pinky/blob/329f35ac2e240805e265a483fa2d3ff0f84780d3/README.md#L361)、[Linux未测](https://github.com/DIYgod/pinky/blob/329f35ac2e240805e265a483fa2d3ff0f84780d3/README.md#L369)；其FFmpeg运行库也实际随包，不能从“Go二进制”推导零运行时依赖。

## 推荐的连续实施顺序与完成定义

| 顺序 | 交付 | 最小验收 |
| --- | --- | --- |
| 1 | 修G0及入口一致性 | schema宣称的完整argv实际parse；HTTP生产argv到executor，不只注入返回；失败单JSON，零provider副作用 |
| 2 | 统一执行owner与主入口action | 至少act与一个app动作接同owner；复用resident iOS ledger；两CLI竞争/lease takeover/旧result/取消/证据统一，mutation不重放 |
| 3 | 观察合同绑定receipt | 同action关联pre-observation/runtime epoch/geometry、provider前freshness、post-settle、business verify；rotation/ref复用/UI变化均负例拒绝 |
| 4 | 本机人机协同最小闭环 | CLI/HTTP approval request/decide/revoke、TakeOver/HandBack、Stop barrier；Agent不能自批准，批准后重读screen；不依赖新增Web写UI |
| 5 | 默认轻量任务历史与安装体验 | 可控metadata自动记录、图像显式策略；skill/Agent配置/doctor逐步整合；精确版本和实际制品验证 |
| 6 | 产品范围裁决后再做 | Android后台display、跨宿主桌面、远程MCP/resume、PIN/生物认证、个人真机部署；不从本报告自动授权或扩大范围 |

这些是调查后的建议，不是新实现完成声明。本轮没有改Sources/Tests/Web/Tools产品实现，没有创建提交或推送；保留既有main WIP。

## 验证与沉淀

本轮运行项：恢复clone并核对clean HEAD/tag/差异提交数；无provider的CLI parser反例；文档治理门禁与diff检查。测试源码只作覆盖线索，不复用SP-281历史测试计数宣称本轮跑绿。

新经验：外部项目比较必须同时检查“本地局部已有机制”和“跨入口统一程度”；Stop/lease takeover/历史replay/执行replay名称不能直接等价。共用schema/HTTP adapter必须进入实际argv parser；mock executor绿色不能证明入口可用。已写回本space和经验索引。
