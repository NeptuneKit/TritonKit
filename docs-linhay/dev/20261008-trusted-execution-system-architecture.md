# ADR：TritonKit 新可信执行系统

> 2026-10-08；状态：设计基线，实施待立项。用户已明确要求从零散能力转为聚合、封装、消融的新系统。本文所有新类型/模块/命令面均为proposal，不是已实现schema或发布承诺。需求入口：[SP-182](../spaces/SP-182-trusted-execution-system/README.md)；[迁移与BDD](../spaces/SP-182-trusted-execution-system/plans/20261008-convergence-migration.md)。

## 架构总图

![TritonKit新可信执行系统架构：多端统一语义、唯一执行内核、平台适配、证据结果与只读投影](../spaces/SP-182-trusted-execution-system/screenshots/20261008-architecture-overview-proposal-v2.png)

[可编辑SVG](../spaces/SP-182-trusted-execution-system/20261008-trusted-execution-architecture-v2.svg)。蓝色线为请求与主流程，绿色线为事实/结果返回与只读投影，琥珀虚线为候选提议或conformance约束（不是绕过内核的写通道）。同图展示设计终态；首片仍按第9节分阶段实施。模型本身只提议，外部agent通过CLI/HTTP调用，不直接输入设备。

## 1. Decision

**Hybrid：保留“agent自由组合单点命令”与“TritonKit封装高级命令”两条一等操作路径；共用权威ExecutionCore，高级路径由WorkflowEngine编排。吸收现有workspace/embedded/host/verify/evidence资产，消融重复底层执行与事实裁决，不消融agent自主编排能力。**

不是在零散功能外包一层“万能session”；不是再建一个与workspace/replay平行的runner；不是重写全部设备后端。

- **聚合**：高级工作流把目标、意图、动作、验证、恢复、证据聚合成Run；单点命令独立返回OperationResult，不强制先建Run或完整session。
- **封装**：平台/传输差异只在adapter内，adapter返回事实和能力，不裁决业务成功。
- **消融**：入口层的平台选择、fallback、重试、成功归类、恢复优先级、证据充分性判断逐项退出，迁入唯一内核。
- **多端语义统一**：支持的平台统一意图、状态、前后置条件与结果含义；CLI/HTTP消费同一契约。相同命令名不等于相同效果，能力不足不得静默降级。详细字典、能力匹配与conformance见 [统一语义契约](20261008-trusted-execution-semantics.md)。

首期为本机iOS Simulator + 一个已有Android/Harmony emulator路径。CLI/HTTP为事实契约；Web/Wails只读投影；embedded继续Debug-only。真机私有远控、远端/云/多租户、窗口产品和模型托管不纳入首期。

## 2. Why：不是从零，但资产尚未成为同一系统

主控复核的当前源码：

| 证据 | 已有事实 | 新架构的处理 |
| --- | --- | --- |
| [workspace action loop](../../Sources/TritonKitCLI/CLIWorkspaceActionLoopRuntime.swift#L31-L170) | 有有界model decision→policy→action→observation→business checkpoint | 吸收流程；model decision做可选proposal provider；其余通用编排下沉 |
| [workspace action execution](../../Sources/TritonKitCLI/CLIWorkspaceActionExecutionRuntime.swift#L110-L166) | default provider支持tap text，直接调用runtime input | 变为Intent到执行adapter的过渡桥，不保留第二套动作主路径 |
| [transition status](../../Sources/TritonKitCLI/CLIWorkspaceActionExecutionRuntime.swift#L226-L235) | 已区分executed_unverified/verified | 复用语义，不另造互相矛盾的success枚举 |
| [workspace final state](../../Sources/TritonKitCLI/CLIWorkspaceRuntime.swift#L897-L958) | business checkpoint、provider/action影响run status | 提取独立结果reducer，不能只靠最后动作/模型状态判完整case |
| [replay](../../Sources/TritonKitCLI/CLIEvidenceReplayRuntime.swift#L46-L154) | 顺序执行、dry-run输出成功、首失败停止，独立恢复归类 | plan变输入格式；循环/停止/恢复裁决迁入内核 |
| [record/verify](../../Sources/TritonKitCLI/CLIEvidenceCommands.swift#L430-L569) | record仅模板；verify/assert共享文本求值入口 | 不误称真实录制；验证规则复用、入口转投影 |
| [TKInputResult](../../Sources/TritonKitShared/TKInputModels.swift#L199-L225) | 已带source/strategy/geometry/verification boundary | 保留wire兼容；编译为新的receipt事实，而不是直接升格业务成功 |
| [target lease gate](../../Sources/TritonKitCLI/CLITargetLeaseGate.swift#L4-L24) | opt-in独立check，不是全局原子执行 | 复用租约存储语义，新增run writer协调；旧不传lease不冒称排他 |
| [plan模型](../../Sources/TritonKitShared/TKReplayPlanModels.swift#L31-L130) | action、target、变量、wait/evidence混在一个step格式 | 作为legacy importer，不让schema模型继续承担独立执行裁决 |

只读subagent审计与主控关键文件复核一致：当前并非同一状态机。没有运行产品测试，本文不是现有实现缺陷的全面审计或安全认证。

## 3. 双操作路径，共享一个权威执行核心

```text
                    Agent / Scripts（CLI / HTTP）
                     /                         \
         A. 自行组合单点命令                 B. 封装高级命令
        observe / act / verify / evidence     replay / workspace / 新高级流程
                     │                         │
                 OperationSpec              RunSpec
                     └───── 统一语义契约 ───────┘
                     │                         │
                     │                    WorkflowEngine
                     │               有界编排 / Run裁决 / 资源恢复
                     │                         │
                     └───────────┬─────────────┘
                                 ▼
                           ExecutionCore
       目标绑定 / 观察 / 解析 / 能力与授权 / dispatch / verify / evidence
                                 │
                    Adapter Registry + platform providers
                       iOS / Android / Harmony

OperationResult ← 单点事实；RunResult ← 高级流程聚合
Web/Wails只读投影；内部LLM/VLM仅候选提议；外部agent可自行调CLI/HTTP
```

ExecutionKernel是整体执行子系统的统称，其内部明确区分WorkflowEngine与ExecutionCore，不再用“唯一内核”表示所有命令都被迫走完整工作流。单点路径直接调用共同service，不是绕过安全/语义门禁；高级路径复用同一service，不能另写一套device dispatch或验收实现。高级命令不是生成shell命令后多次启动CLI的黑盒串联。

单点调用按需使用observe、dispatch、verify或capture；无需自动执行全部八步或所有后置条件。高级流程负责声明的业务验收和证据链；agent自编流程的整体成功由agent或显式调用的共同验证器判断，不由一次act的ok冒充。

物理设备操作仍串行，平台adapter可以不同；平台能力不足返回typed unsupported，不假装意图等价。内核不包含模型品牌逻辑、GUI焦点逻辑、HTTP路由或各平台底层工具解析。

部署先是同进程服务调用，不以增加daemon为前提。有活跃serve时run coordinator可由它持有；离线CLI也必须使用同一共享writer协调域，不能各进程各自给自己发“独占权”。跨进程协调如何复用当前lease服务/本机存储锁须在第一实现space验证，不能只用actor宣称原子性。

## 4. 核心对象与权威归属

### 4.1 SessionContext：可复用绑定，不是结果容器

包含workspace/build/App绑定、target identity与能力快照、环境desired/observed、runtime来源和scope。SessionContext有revision；目标、App实例、能力前提变更使旧绑定失效。

不把会话当长期控制锁，不跨run继承不透明“当前窗口”；设备alias是选择提示，不能作为实际execution identity。日志/视频/调试等已有独立session通过resource handle引用，不强行塞进一个万能session。

### 4.2 Operation与Run：单点操作与工作流聚合分开

Operation是可独立调用的能力请求，至少绑定operation ID、目标/scope、参数语义与结果；动作有Attempt/Receipt，观察/验证/采集返回各自typed事实。无需run ID，context/session可选，不默认启动模型或完整流程。多个独立operation可由agent显式关联observation/evidence refs，但不会因同一target就自动组成受管理Run。

Run是高级命令的一次有预算、可留证的执行聚合根，不是单点操作的必需容器。Run拥有：不可变规范化RunSpec、context snapshot、步骤DAG/首期顺序列表、writer ownership、事件日志、step receipts、verification结果、资源ledger、最终判定。

Run只能修改自己的聚合。跨run共享的target writer归协调器；设备真实状态归设备；旧日志/画面不因run ID相同就变成新事实。

### 4.3 Step与Attempt：意图和实际发送分开

Step：一个规范化意图、前置条件、scope、后置条件、deadline与恢复规则。Attempt：某次backend dispatch的事实，绑定step ID、target/app instance、connection generation、observation与geometry revision、writer token。

模型提出新动作生成新的Step/候选版本；重试同一意图生成新的Attempt。不能把每次重试擦掉，不能让同一个operation ID不同payload继续执行。

### 4.4 Observation：带有效边界的快照

字段至少：observation ID、target/app身份、source、capture/receive time、generation、geometry revision、screen ID、coordinate space、freshness evidence、payload/artifact refs。

不同source可能无法同步；返回一致性窗口与skew/unknown，不能把异步AX与截图拼成“原子快照”。显示帧的新鲜度与guest状态新鲜度不同；不支持capture clock就unknown。OID/alias仅在相关runtime instance/observation范围内有效。

### 4.5 Receipt / Verification / Evidence：三种不同事实

- Receipt：请求是否未发出/已提交/明确拒绝/交付未知，原始adapter结果与来源。
- Verification：什么条件、什么新观察、何种范围/可靠性支持pass/fail/inconclusive/not-evaluated。
- Evidence：观察/动作/验收链是否完整、可读取、脱敏、持久化，缺什么。

可信不是confidence分数，也不是hash。内容hash证明完整性关联，不证明来源身份或业务真实性；本机事件日志不是远端可验证签名。首期不宣称密码学可信或tamper-proof。

## 5. 高级流程协议与单点操作保证

下面是高级命令的典型完整流程，不是每个单点命令的强制步骤。单点act可只绑定/校验/dispatch并返回submission事实，agent随后独立observe/verify/capture；显式带postcondition的单点操作可按同一验证规则验收，但仍不自动认证整个agent工作流。

```text
compile → bind → inspect/preflight → observe → resolve → authorize
   → persist dispatch intent → dispatch → receipt
   → fresh observe → verify → reconcile/compensate
   → evidence commit → finalize
```

### 5.1 准备阶段

- compiler做语法与纯语义校验，输出typed IR；dry-run仅compile/plan，不证明runtime能力、授权或业务结果。
- bind解析唯一target/App/runtime；多候选、未知kind、无法确认readiness返回blocked/unsupported，不按列表第一项猜。
- preflight检查工具/接口逐项能力、预算、artifact path/空间、敏感数据策略、验证支持与资源协调域。
- 高级trusted流程要求明确后置条件。单点mutation是一等能力，不必为没有业务postcondition另申请低级profile；返回submitted/unverified及验证边界，不自动过业务trusted gate。读取/验证/采集成功继续只证明所请求的operation完成。

### 5.2 分辨、授权和发送

- selector由resolver按新的Observation唯一解析；坐标必须注明空间/屏幕/方向与geometry revision，空白区拒绝。
- 策略resolver只在发送前选择一个backend，保留选择理由与被拒候选；public/embedded/host的偏好可按scope，不跨scope静默升级。
- writer token在队列入队与实际dispatch前校验；generation与geometry重新检查。不把lease预检等同于设备状态锁。
- 新体系中单点/高级写入口共用writer协调域；TTL到期/owner失效拒绝新发送。单点可使用operation-scoped所有权，不强制用户持有跨命令lease；高级Run可持有流程级所有权。旧opt-in wire行为兼容，但不宣称迁移前已覆盖。取消后的held-input cleanup有界且只针对本资源。
- 混用路径须显式：高级Run进行中可只读inspect；手动mutation须携带有效owner/context授权或先暂停/结束Run、释放写所有权。不因同一agent/target就自动接管，也不能暂停时重放交付未知动作。
- 外部Device Hub、裸工具、人手操作不受Triton租约约束；如可检测到interference，失效观察并reconcile，不能保证对外排他或原子check-and-act。

### 5.3 超时、fallback与幂等

设备点击不是数据库事务，不能承诺exactly-once或通用rollback。

- 已知未发送/被拒绝：允许按策略换backend，先刷新观察与授权。
- 已提交、超时、交付未知：禁止盲重发或切另backend重复点击；先reconcile目标状态。
- 确认幂等的动作（例如明确值的setting）也要由adapter能力与后置条件支持，不由命令名猜。
- 非幂等动作只有明确补偿/重试策略才可新增Attempt；付款/删除等无法辨识的side effect停为uncertain/manual，不重复触发。
- 相同operation ID与相同spec可返回已有Run；不同spec拒绝。持久journal不消除“记录后/发送前或发送后/receipt前崩溃”的窗口；恢复时unknown delivery仍需reconcile。

### 5.4 验证与恢复

VerificationEvaluator不依赖model说done，也不把窗口变化当任意业务完成。verify用target/app/generation正确、晚于动作且有足够freshness的观察；必要时稳定多次采样。read-only条件已满足时可报告already-satisfied/skipped，不伪造一次执行。

恢复是资源补偿，不是撤销所有业务：release touches/keys、停自己媒体、释放writer、恢复明确拥有的环境变更。每项都有read-back/失败/unsupported状态；不能重置整机、杀别人App或stopAll。cleanup失败保留原始错误，不覆盖业务结果。

## 6. 状态与结果：不能压缩为一个ok

### 6.1 Run阶段（处理位置）

```text
created → preparing → ready → running → reconciling? → finalizing → completed
                   ↘ rejected
running/reconciling → cancelling → finalizing → completed
```

阶段与最终结果独立；completed只是没有继续执行，不代表成功。Step内部允许prepared/dispatched/observed/evaluated，最终执行事实immutable。恢复后的新观察与评估作为新event/evaluation revision追加，不改写历史receipt。

### 6.2 四维结果（建议枚举）

| 维度 | 建议值 | 意义 |
| --- | --- | --- |
| execution | not-dispatched / submitted / rejected / delivery-unknown | adapter交付事实，不等于业务 |
| verification | passed / failed / inconclusive / not-evaluated | 注册后置条件的证据结论 |
| recovery | not-needed / completed / partial / manual | 本run拥有资源的恢复状况 |
| evidence | complete / partial / unavailable | 必需证据契约是否落盘 |

最终outcome：verified / failed / uncertain / blocked / cancelled / executed-unverified。**verified只指已声明后置条件，不认证未声明业务。** 同时单独计算trusted gate：后置条件passed、目标/授权/观察有效、所有required证据已commit、required恢复完成。业务passed但证据丢失可保留verification=passed，trusted=false/outcome=uncertain，不抹去已观察事实。

新run API的`ok`仅是严格gate投影；旧primitive/capture/replay的`ok`继续按原schema兼容投影，不强改含义，也不凭旧ok升级trusted。compile/status等只读operation的`ok`仅表示该operation完成，必须用不同kind，不能与run判定混淆。

### 6.3 示例（proposal，非现有CLI输出）

```json
{
  "kind": "triton.execution.run-result",
  "schemaVersion": 1,
  "runId": "run-example",
  "phase": "completed",
  "outcome": "uncertain",
  "ok": false,
  "trusted": false,
  "execution": { "state": "submitted", "attemptId": "attempt-1" },
  "verification": { "state": "inconclusive", "reason": "postcondition_observation_stale" },
  "recovery": { "state": "completed" },
  "evidence": { "state": "complete", "manifestRef": "<manifest-ref>" },
  "error": { "code": "execution_uncertain", "message": "Input was submitted; the postcondition could not be established." }
}
```

deadline/cancel/unknown不能静默变success。长任务用同一event schema JSONL，只有一个final result；stdout不混工具日志。新高级可信流程同步调用的non-verified终态非零退出；单点调用按自身operation契约给退出状态，不把缺少整体业务验收一律当命令失败，具体码在实现schema登记。HTTP accepted只代表接收，不能投影成verified。

## 7. 模块边界与“谁可以决定什么”

| 组件（建议逻辑模块，暂不拆Swift package） | 拥有 | 明确不拥有 |
| --- | --- | --- |
| Contracts + Compiler | typed意图/约束/输入格式版本，兼容导入 | target实时可用、平台工具调用、secret日志 |
| ExecutionCore + OperationReducer | 共同目标/能力/授权/dispatch、事实归一化、验证和证据服务 | 强制Run、自动认证agent整体工作流、独立高层循环 |
| WorkflowEngine + RunReducer | 高级命令的阶段/预算/编排/停止/恢复与聚合门禁 | 另一套底层dispatch/verify、接管agent所有手动编排 |
| Binding/Observation服务 | identity、source、失效与几何转换 | 最终业务success |
| Coordination/ResourceLedger | 写所有权、队列、owned资源、cleanup请求 | 对外工具或人类排他保证 |
| VerificationEvaluator | 声明条件与观察的求值 | model done即通过、再次发动作 |
| AdapterRegistry | 实时能力、dispatch事实与不可重试边界 | 自己另开fallback/重试循环或生成trusted |
| Journal/EvidenceStore | append事件、artifact refs、manifest原子提交/索引 | 根据截图存在推断业务完成 |
| CLI/HTTP/Compatibility projections | 解析/格式/版本/稳定error envelope | 重选target、执行shell argv、独立retry/success |
| Workspace proposal provider | 候选意图与决策理由，有界模型预算 | 直接发input、宣布verified |

SecretRef从受控变量/environment读取，仅在dispatch边界展开；真实payload不写journal。展示argv/nextActions仅是审计投影，永远不能当执行IR回灌。保留secure redaction与proxy等现有unsupported/plan-only边界。

## 8. 对外面收敛，不新增一串重复命令

两条一等主路径：**A单点能力自由组合，B高级命令封装执行**。prepare/inspect、execute、observe result、cancel/reconcile是高级生命周期，不是替代单点命令的唯一入口。名字与HTTP路径在实现时由schema裁决，不声称 `triton run/session/...` 已存在。

单点observe/act/verify/evidence保持独立可用；agent决定顺序、分支、何时验收。优先演进已有workspace/replay的高级编排底座；replay是确定性流程输入，workspace可用模型候选，高级命令使用WorkflowEngine并委托ExecutionCore。单次act是Operation，不强制包装为一step Run；两条路径不要求长期session或模型。

高级封装是可选便利而非唯一可信来源。手动组合若使用同样有效目标、所需验证与充分证据，可以证明同样的声明条件；没有高级Run只是没有系统托管的流程级预算/资源ledger/自动聚合，不能将单点称为天然不可信。

底层sim/device/app/xcode命令可以保留为专家工具与诊断原语，但业务写操作最终也进入协调/审计服务，不能成为绕过新系统的“隐形trusted入口”。不迁移支持的命令明确primitive/unmanaged，不宣称整仓已统一。

独立observe/verify/evidence继续有用：可观察已经发生的状态、做手动验收、收集故障资料；它们不是另一套写runner。Web只看Run DTO、环境差异和证据timeline，不持有selector/策略/重试逻辑。

## 9. 首个实现切片与拒绝项

首片不是“全平台Session重构”，而是：**一条iOS runtime tap-with-postcondition纵切，三种入口共用一个fake/real adapter与ResultReducer。** 无模型、无新daemon、无live video、无真实录制、无环境全量恢复。随后补已有host与第二平台，再消融旧路径。

拒绝：把旧命令串拼成新run；全量重写Swift包；新增第二个runner；维护新旧双裁决到无限期；把同进程actor当跨进程锁；承诺exactly-once/全局排他/任意业务rollback；把hash当真实性；把模型done当验证。

下一步实施需先登记新implementation space与worktree，按 [迁移计划](../spaces/SP-182-trusted-execution-system/plans/20261008-convergence-migration.md) 的失败测试和淘汰门禁推进。本轮只确认设计，没有执行实现或设备验收。
