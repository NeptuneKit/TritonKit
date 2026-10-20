# 可信执行系统：聚合、封装、消融与迁移验收

> 2026-10-08；实施候选，不是产品已实现功能。[ADR](../../../dev/20261008-trusted-execution-system-architecture.md)为设计事实源。当前只写文档；任何实现需独立space/worktree与失败测试。

## 1. 裁决不是“保留全部，再加一套”

聚合对象是一次Run，不是CLI命令列表；封装边界是adapter facts，不是未经解释的shell output；消融对象是重复决策与旁路编排，不是删除所有专家工具。

| 当前资产/入口 | 聚合/封装方式 | 必须消融的职责 | 保留边界 |
| --- | --- | --- | --- |
| [CLIActionCommands](../../../../Sources/TritonKitCLI/CLIActionCommands.swift) | act译为独立Operation，直接调用共同ExecutionCore，结果兼容投影 | 平台routing/策略/成功/预算/重试各自裁决 | 参数语法、格式、稳定legacy错误 |
| [workspace action loop](../../../../Sources/TritonKitCLI/CLIWorkspaceActionLoopRuntime.swift#L31-L170) | 提取共同ExecutionKernel；模型只生成候选 | 本地action→postobserve→business check编排与独立finalize | workspace配置、模型预算/决策artifact与app-map投影 |
| [workspace action provider](../../../../Sources/TritonKitCLI/CLIWorkspaceActionExecutionRuntime.swift#L110-L166) | 封装现有runtime primitive，过渡到adapter receipt | 直接选择/执行input及独立业务状态转换 | tap resolver/runtime call作为内部原语 |
| [replay runtime](../../../../Sources/TritonKitCLI/CLIEvidenceReplayRuntime.swift#L46-L154) | legacy plan importer→typed IR→同内核 | 第二套循环、失败/停止/恢复判断 | v1 plan读取、变量兼容、redacted preview |
| [plan models](../../../../Sources/TritonKitShared/TKReplayPlanModels.swift#L31-L130) | 保留v1 wire，归一化compiler | format模型中独立的runtime决策与执行argv责任 | 离线校验和导入错误；无隐式扩展proxy可执行性 |
| [verify/assert入口](../../../../Sources/TritonKitCLI/CLIEvidenceCommands.swift#L430-L499) | 共用VerificationEvaluator与Observation服务 | 各runner重复求值、模型done投影success | 独立只读verify工具仍可用 |
| [evidence capture](../../../../Sources/TritonKitCLI/CLIEvidenceCaptureRuntime.swift#L350-L524) | Artifact providers + Run evidence commit | 各入口自建manifest/来源解释/充分性判断 | ad-hoc capture合法；capture.ok不等于business pass |
| [TKInputResult](../../../../Sources/TritonKitShared/TKInputModels.swift#L199-L225) | wire保留，Receipt importer | primitive.ok直接变trusted；混用提交/验证 | source/strategy/geometry/verification boundary复用 |
| [lease gate](../../../../Sources/TritonKitCLI/CLITargetLeaseGate.swift#L4-L24) | writer coordinator吸收租约与owned资源ledger | 入队后不重校验、入口自认排他 | 旧opt-in行为兼容但标出保证范围 |
| [provider parser](../../../../Sources/TritonKitCLI/CLIActionProviderRuntime.swift#L67-L154) | 解析model格式为Candidate，不执行preview argv | model finished/status当run success；CLI字符串当IR | provider专属parse与normalized坐标声明 |
| [host发现](../../../../Sources/TritonKitCLI/CLIHostDeviceRuntime.swift#L27-L130) / [framework resolver](../../../../Sources/TritonKitCLI/CLIHostSimulatorFrameworkEnvironment.swift#L3-L40) | Binding/AdapterRegistry统一探测 | 各feature硬编码开发目录/重复kind/ready判断 | 公共工具优先、helper隔离、失败typed |
| Web/Wails | Run/Observation/Evidence只读DTO投影 | 前端selector/缩放业务输入/重试/调度决定 | 用户可见解释与timeline，不新增写控制面 |

设计期不删除旧函数。实施时每消融一项必须有调用方与测试证据，不能以文件更名/减少行数当完成。

## 2. M0：统一语义、契约与纯reducer先行

先落实 [多端统一语义契约](../../../dev/20261008-trusted-execution-semantics.md)：意图effect、字段unknown/coverage、input event约束、capability匹配、共同后置条件求值。schema不是各平台字段拼接，adapter不能把较弱效果投影成相同verified。

预期写面（proposal）：`Sources/TritonKitShared` 的typed RunSpec/Receipt/Verification/Outcome；`Sources/TritonKitCLI` 的compiler/result reducer与fake adapter测试。实际新文件名称在实施时确定，不先新建package。

失败测试：

1. `input.ok=true`、verification缺失 → executed-unverified，不是verified。
2. postcondition passed、必需evidence写失败 → 保留passed事实，trusted=false，最终uncertain。
3. compile/dry-run通过 → kind=compile-result；不创建“已执行成功”。
4. 旧capture partial=true/ok=true → 正确导入missing，不自动判业务通过。
5. model done没有verify proof → not-evaluated；不得结束为verified。
6. failure+cleanup partial → 同时保留原failure和恢复问题；不能用cleanup错误覆盖原错误。
7. 已满足read-only条件 → already-satisfied，不能伪造dispatch receipt。
8. 同意图经两种fake平台实现 → 相同required effects/后置条件/错误类别/outcome，不要求原始日志/ID相同。
9. partial/unknown观察与not-exists → inconclusive；无数据不能证明不存在。
10. required keyboard/IME事件、system scope或完整观察与backend不符 → semantic_gap/unsupported，零dispatch，不自动改义。

完成条件：同规范动作的Operation事实与验证规则在act/replay/workspace一致；高级RunOutcome额外聚合流程条件，不要求单点结果等同整体Run。legacy投影按旧schema保留，语义变化逐条说明。旧字段到新字段映射表完整；无真实设备写入。

## 3. M1：一个最小纵切，三个入口

唯一执行service串起bind/observe/resolve/guard/dispatch/verify/journal。选受控Debug App的一个确定性tap与明确后置条件；第一阶段runtime路径，不要求全部host/model功能。

- act译为独立OperationSpec，直接调用ExecutionCore；不强制run ID/session/model或整体业务postcondition。agent可随后独立observe/verify/capture。
- replay v1 importer译为RunSpec，由WorkflowEngine调用同ExecutionCore；原input/wait/evidence的既有语义继续兼容，没有显式postcondition的legacy步骤不自动升级为trusted。
- workspace proposal译为Intent；WorkflowEngine承载有界编排，通用原语委托ExecutionCore，模型driver只负责有界下一候选。
- 两路径BDD：无run ID的单点调用成功返回正确operation事实；单点不启动WorkflowEngine；高级调用相同原语时同backend/guard/verifier语义；同规范动作只发送一次。
- 混用BDD：高级流程中只读inspect可用，未经授权的manual mutation冲突；显式owner授权或暂停释放后可切单点，不接管/重放旧unknown动作。
- 可信性BDD：有效单点verify可证明相同声明条件，不因无Run判不可信；单点submission不冒充整体流程通过。

先用fake backend与fault injection实现CLI/HTTP及三个入口一致性，再有授权的真实项目回归。请求用typed IR，sourceCommand/preview只用于显示；secure值只在dispatch展开。

**不允许 shadow dispatch：** shadow仅跑compiler、策略/结果比较，只有一个writer路径真实发动作。不得让旧新runner同时点击“比较结果”。

切换门禁：三入口同意图fake结果一致；stdout单一envelope、JSONL单final；没有重复input调用；old-new差异ledger可解释；业务后置条件与evidence真实验收。旧实现若没有postcondition，仅作行为baseline，不被新系统误判trusted。

## 4. M2：写协调、失效与故障恢复

fake clock + controllable adapter + journal fault injection；同一target两个进程/客户端场景必须测试，actor级测试不足。

BDD：

- Given lease预检通过但dispatch前过期，Then拒绝新发送；不复用旧授权。
- Given target/runtime generation切换，Then旧frame/command/close不能作用于新target。
- Given observation后geometry/屏幕改变，Then stale observation被拒绝并重观察；不clamp到未知位置。
- Given request已发送且timeout，Then delivery-unknown；reconcile前发送次数保持1，不能fallback重复点击。
- Given backend明确not-dispatched，Then刷新绑定/观察/guard后才允许下一Attempt。
- Given journal记录dispatch意图后崩溃，Then恢复不假定已发/未发；不可辨识时uncertain/manual。
- Given cancel时有held keys/touch，Then只release本人输入，有界cleanup并保留失败；不stopAll/整机shutdown。
- Given外部Apple GUI/human改变状态，Then不声称lease约束外部；可检测的interference使观察失效。
- Given同operation ID不同RunSpec，Thenconflict，不复用旧结果或新动作。
- Given检查/执行分离，Then测试该窗口并说明无法锁定外部设备状态；不以测试通过宣称通用原子check-and-act。

完成条件：内核管理的写路径在统一协调域串行；取消/超时/崩溃不会导致盲重放；coordinator跨进程恢复与TTL行为有证据；对未迁移入口标记unmanaged，不宣称全仓覆盖。

## 5. M3：消融旧编排与接入第二平台

不把消融留到项目末尾。每个入口的迁移票据包含：旧决策函数、全部调用方、新owner、兼容映射、测试、已删除分支和回退开关。

顺序：workspace共同编排 → replay循环 → action平台routing → 通用verification/result → evidence finalize → 重复target/framework resolver。实际顺序以依赖与单片范围裁决，不能同时重写同一文件。

第二平台选择已有Android或Harmony emulator，不从真机/新协议开始。跑同一semantic conformance suite，比较相同Intent的effects/条件/结果与不同backend facts，不保证控件结构一致。支持矩阵逐端登记；某项unsupported不能以另一个平台成功掩盖。

**可回退的是入口routing，不是可信语义：** 已声明trusted模式如果内核不可用要typed unavailable，不能静默切回旧runner还声称trusted。legacy profile可保持原primitive行为，明确保证级别与deprecated状态。取消/unknown Run不能通过回退再发一次。

消融验收：

- 入口层不再有业务策略、retry、fallback或最终verification分支。
- 每种写意图仅一条权威dispatch路径；未迁移能力被明确列出。
- workspace/replay引用同reducer，不能独立重新算passed。
- preview argv不被执行；变量/secret源与执行IR隔离。
- `.tritonplan` v1可读；历史`.tritonevidence`只读保留，不重写或“认证”。
- schema/CLI/HTTP/public skills/examples一致；不把新命令列为已存在。
- 删除的旧代码由新focused + compatibility tests覆盖，不靠减少文件数宣称重构完成。

## 6. M4：环境与只读解释面

只有执行内核闭环可验收后，增加环境desired/read-back/restore ledger和只读Run timeline。逐字段能力矩阵；不支持恢复的字段明示manual，不能宣称整机快照。

环境写操作也进入同coordination/receipt/verification契约；可恢复资源归Run ledger。Web/Wails只展示“目标—策略—动作—验证—证据—限制”，不生成第二个服务控制面。

官方Apple agent backend研究、真机协议、live stream与高级resource管理另设space，作为adapter候选而非新系统前提。

## 7. 工程与验证门禁

所有implementation phases：BDD先行、失败测试→最小实现→重构；CLI解析/分发、HTTP handler、schema/DTO、并发/超时/cancel/fault测试，Swift根包与CLI适用完整回归、本地总门禁。设备动作必须Triton-first且串行；真实验收用evidence与独立verify，不以ACK过关。

交付指标：权威dispatch路径数、入口残留业务决策数、三入口结果一致性、假成功数、交付未知重发数、证据关联错误、恢复失败可见性。不能只统计命令数/功能数/通过一次demo。

停止条件：需要改未授权远端/设备、跨进程协调设计无法安全实现、旧wire变化无法保持、未知side effect需业务判断、同阶段写scope冲突。停在明确uncertain/unsupported，不放宽条件换绿。

## 8. 本轮设计验收

- [x] 新系统聚合与adapter边界明确，不是总CLI wrapper。
- [x] 当前已有workspace闭环与InputResult verification boundary被吸收。
- [x] 状态/可信gate/unknown delivery/恢复/证据各自定义。
- [x] 聚合、封装、消融裁决到具体入口与源码。
- [x] 渐进迁移、compatibility、无双发与回退安全有门禁。
- [x] docs-only门禁已通过并写回space/memory；产品TDD与真实设备未执行。

2026-10-20 后续：原 Baguette resolver 已由 [SP-218](../../SP-218-issue-222-device-hub-input/README.md) 的中性 framework resolver 接替；旧外部执行器/override/hook 已移除，本表保留历史调研语义。
