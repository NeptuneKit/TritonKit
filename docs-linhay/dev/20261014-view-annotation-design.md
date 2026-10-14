# 独立 App 高亮会话与临时属性恢复

关联：[SP-197](../spaces/SP-197-view-annotation/README.md)。本设计按用户明确的独立高亮能力修订：定位/保存/应用独立交付，截图只是消费者。P0独立UIKit能力已实现，验收见[报告](../spaces/SP-197-view-annotation/plans/20261014-p0-validation.md)；截图组合/跨端仍未实现。执行顺序见[执行清单](../spaces/SP-197-view-annotation/plans/20261014-execution-checklist.md)。

详细约束以 [高亮标记与还原契约 v1](../spaces/SP-197-view-annotation/plans/20261014-mark-restore-contract.md) 为准，尤其是属性组恢复、内容复用、幂等记录与部分清理。

## 已有基础

- `Sources/TritonKitShared/TKNodePropertyPatchModels.swift`：存在 frame/view/layer/style patch DTO，支持 backgroundColor、alpha 等；尚无 borderColor/borderWidth、保存原值或恢复事务。
- `Sources/TritonKitCLI/CLIInspectionCommands.swift`：`triton debug patch-node` 向 runtime 发送 `node.patch`。
- `Sources/TritonKit/TritonKitRequestHandler+LegacyInspection.swift`：MainActor 上解析 registry 对象、修改 UIView/CALayer；任一字段应用即 ok，允许部分 applied/skipped。这个成功语义不能直接用于多节点全量高亮。
- `Tests/TritonKitTests/TKNodePropertyPatchTests.swift`：已有 UIKit 属性修改用例，可补临时修改和恢复 tests；macOS 不执行 UIKit 条件内测试。
- `CLIEvidenceCaptureRuntime.swift`：可保留 host 全屏与 runtime app-layer 截图两条来源；截图链路可复用，增加前后状态与高亮事务记录。

现有 node.patch 是持久的调试修改，缺事务、TTL、并发互斥与可靠回滚。复用对象解析和受支持属性 setter，新增独立 HighlightSession 管理器，不把 agent 手工发两条 patch 当作临时高亮。

## 架构和接口

shared 新增 HighlightSpec、HighlightSessionReceipt、HighlightRestoreResult；embedded 新增 @MainActor HighlightSessionManager；公开 CLI highlight apply/status/clear 直接驱动。evidence orchestrator 作为独立 adapter 组合这些能力，不是高亮实现的所属模块。现有本地 HTTP request transport 转发新增 typed runtime 消息，需更新 transport enum、capabilities、schema 和单一失败 envelope；不臆造已有 `/evidence/capture` HTTP handler。

公开 CLI 与 typed HTTP 请求契约统一为 `highlight.apply`（幂等 operationID）、`highlight.status`、`highlight.clear`。apply 返回 sessionID、runtimeInstanceID、bound target、单调 deadline、applied nodes、render-ready 状态；重复同 operationID 返回原会话，不重新应用或延长 deadline，payload 不同则冲突。status 可用 sessionID 或 operationID 查询，不依赖创建它的 CLI 连接。

runtimeInstanceID 是 runtime 生命周期 UUID，不能复用随 WebSocket 重连变化的 transport generation。operationID 去重事实在同 runtime 生命周期保留；详情可有界淘汰，但已用键不可变成可重新执行的请求。容量达到上限拒绝新 apply，不淘汰待清理快照。clear 幂等并检查原 runtimeInstanceID，不能修改重启后的同 OID 对象。

P0 allowlist 仅 CALayer.borderColor/borderWidth，构成一个 border 属性组；背景色后置。高亮 resolver 只接收已存在 UIView/CALayer，不通过 UIViewController.view 加载页面；CALayer.delegate 不自动等价于其宿主 backing layer，必须验证 view.layer === layer。以实际写入 layer + property group 去重，不以请求 OID 去重。

## 独立生命周期

内部phase：`validated → originals_saved → applied → render_ready → restoring → restored`。对外session state固定为active/partially_active/restoring/closed/needs_attention，逐节点outcome另列。

状态机不包含 captured；可以从 active 被 clear、到期或身份失效触发清理。异常状态包括 rejected、restore_pending、restore_conflict、restore_failed、target_gone、unknown。apply 成功表示当前高亮 active 并已得到有界渲染机会；status.ok 仅表示查询成功，state 可能已过期/恢复；clear 成功要求恢复回读通过。

1. 解析全部真实对象，核对同一 runtimeInstanceID/session、window/scene、唯一身份、可见性和 allowlist；全量预检通过才进入短暂写临界区。MVP 同 runtime 只允许一个会话，第二个 apply 返回 busy。
2. MainActor 同一 turn 保存原始强类型属性并应用整批修改。CGColor 保留 nil 与颜色空间；以后背景色预设还须保留 UIColor 动态 provider；保存对象身份/语义指纹，弱引用对象，不延长页面生命周期。保存与应用之间不插入截图或网络等待。
3. 局部 CATransaction 禁止本次修改的隐式动画，不全局禁止 App 动画；中途失败清理已改字段。属性原值及恢复表由 runtime 持有。
4. 等待有界提交/显示刷新机会并检查 applied 值；超时清理并失败。render-ready 只说明渲染机会已到，不证明未被其他窗口遮挡，不要求为此内部截图。
5. 返回 sessionID/operationID、active、deadline 和修改摘要。apply 的 CLI 进程正常退出或 HTTP 连接关闭均不清理；会话独立存在。
6. 调用方可执行 status、观察、截图、录屏或不冲突动作，直到显式 clear/到期。clear 按 markID/属性组恢复回读并返回独立恢复结果；普通 screenshot/observe 不偷偷 clear。

TTL 默认建议 30s，范围 1–300s；apply 前登记单调 deadline 与 runtime 清理，不自动续期，重复请求不延长。断连保留会话至 deadline；客户端丢响应通过 operationID 查询，不能盲目重放。未完成 apply 的取消应尽力清理，其结果不确定时仍保留可查询 ID。

清理属性必须由 MainActor 执行；卡住或挂起时报告 pending/unknown，恢复可运行后优先清理过期会话，不承诺硬实时恢复。App 退出则属性随内存消失，记录 target_gone，不伪装回读成功。运行时不可达也不能仅凭 deadline 推断已恢复。

## 截图 adapter（独立消费者）

1. evidence 解析 target 并保存未高亮图；原图采集失败不创建会话。随后调用公开 apply；高亮 runtime 不依赖原图存在。
2. 记录本 adapter 创建的 sessionID。截图前后查询会话 active、节点身份/布局、属性和期限；TTL 到期或被覆盖不标为成功高亮图。host/embedded 截图必须绑定同一 target，不因 setter 成功推断全屏无遮挡。
3. 字节取得后，或失败/取消时，finally clear 自己创建的 session；不等归档完成。MVP 遇到他人活动 session 返回 busy，不擅自复用/清理。
4. 将原图、高亮图与独立 session/restore receipt 关联，capture 状态只属于 adapter。已高亮路径的完整成功要求截图成功及 clear 已验证；prefer在零写入unsupported时可以普通截图成功，并明确未高亮；apply 独立成功不等待后续截图或 clear。

手动调用 screenshot 失败不会改变高亮生命周期；需要自动恢复的工作流显式负责 finally clear。业务断言/视觉基准使用未高亮状态，不能将高亮像素当业务变化。

## 恢复与并发

每个 session 包含多个 markID，分别绑定 runtimeInstanceID、weak object/token、contentEpoch 与属性组账本。账本直接保存 original/applied 强类型值与 changedKeys/guardKeys，不经 JSON hex 或 node.patch 反向恢复。

clear 支持整个 session 或 markID 子集；未知 ID 在写入前拒绝。borderColor/borderWidth 是耦合组，先校验整组身份与归属，再仅写回 changedKeys 并回读。整组已是 original 时只记 already_original；任一 guardKey 被业务覆盖则整组不写并标 conflict，不恢复半个边框。不同 mark/独立组仍可安全恢复，最终返回逐项结果。

同 operationID apply 返回首次快照和期限，不能把已高亮值变成 original。同对象 viewOID/layerOID 重复命中先按物理 layer 合并；不同 preset 冲突拒绝。MVP 同 runtime 一个 active/残留会话，不支持嵌套覆盖栈、永久高亮或 force restore。

apply/clear 的短临界区串行；活动会话保护覆盖属性组，不长期禁用输入。重叠 patch 拒绝，无关查询/动作允许。已知页面身份改变的 Triton 动作前请求清理，失败则停止该自动流程；不能阻止 App 自身异步更新。

对象身份不等于内容身份。缺少可靠 content/reuse epoch 的 cell 及其子树在 P0 拒绝；provider 须有覆盖 reuse/reconfigure 的预失效协作才能开放。离树但仍存活不当成对象释放；已知旧上下文有效时清理，已经换内容/scene 则不把旧 original 写入新上下文，不按 selector 重找对象。

字段值比较仅为 value_guarded；token 不能观察业务同值写或未观测 ABA，不能宣称绝对无损。已观察冲突不可因值再次相同就自动重获恢复资格。保留业务现值与可能残留、停止自动重试；详细判定和恢复后的聚合见契约。

会话聚合使用 state、cleanupComplete、restorationVerified、residualState。target_gone 可以无残留但不能称回读恢复成功。TTL/主线程挂起只能产生 pending/unknown，不能凭过期时间自动判 restored；runtime stop 前也必须先清理或保留 manager。

## 可选provider与能力探测

本能力不强制用户接入内置SDK。CLI/HTTP按目标探测可写provider；官方embedded实现是可选适配之一，也允许已有调试provider或用户自定义适配。原有节点查看/操作/普通截图无需新增接入。无provider不自动安装/注入，显式apply返回unsupported。截图组合默认prefer，仅零写入的unsupported可继续普通截图且标明未高亮；显式required要求该能力。部分写入、恢复失败不能按缺能力静默降级。

## 跨端调研补充

[跨平台技术调研与裁决](../spaces/SP-197-view-annotation/plans/20261014-cross-platform-research.md)固定共用会话、独立provider路线。以上直接快照流程限定iOS P0；Android需要App内Debug provider并先验证空foreground替换，现有无障碍桥不具备目标View写权限。Harmony采用注册响应式AttributeModifier控制真实outline，不能仅凭FrameNode UniqueID写任意声明式节点。

恢复模式分snapshot_compare_restore与managed_override：前者条件写回历史原值；后者撤销本次覆盖并应用当前业务基础样式。必须在receipt披露restorationMode、baselineVersionAtApply/current及restoredTo；具体规范以契约第12节为准。SDK stop现同步安排清理，stopAndRestoreHighlights等待本批回执；清理generation、TaskLocal接纳epoch阻断旧排队请求/旧清理污染新会话；CATransaction completion不单独作为帧已显示证明。

## Evidence 和错误契约

保存三类产物：未高亮 `screenshot`、`screenshot.highlighted`、`highlight.receipt`。现有原图 primary 语义保持，新增可选 reportArtifact 指向高亮图。

独立 session receipt 字段：schemaVersion、operationID/sessionID、runtimeInstanceID/target、state、nodeRefs、modifiedProperties、appliedAt、renderReady、deadline、restore status/time、marks/group outcomes、cleanupComplete/restorationVerified/residualState、errors、recovery。不含必填 screenshot/path/hash。capture interval/status/path/hash/source/scope 属于 evidence 的引用记录，按 sessionID 关联，缺截图不影响高亮 DTO 编解码。原值/应用值仅做脱敏可读摘要；恢复用的强类型快照只存 runtime 内存。报告必须标明 temporaryAppMutation=true；不同时间原图不包装成单一原子快照。

错误建议：highlight_unsupported、highlight_target_ambiguous/not_found、highlight_busy、highlight_identity_changed、highlight_render_timeout、highlight_expired、highlight_restore_conflict/failed。输入格式复用 validation_failed，alias 复用 stale_node_alias。capture --highlight 的部分失败沿用 evidence_capture_partial 并在 skipped/error detail 保存独立 capture/restore 状态；stdout 只有一个 manifest。

失联后 CLI 不重放 apply，不假设恢复；优先查询 operationID/sessionID。recovery 为重新连接并查询/clear 同一会话；不自动重启 App、覆盖冲突字段或继续业务动作。

Debug-only：沿用 TRITONKIT_RUNTIME_ENABLED 与独立 #if DEBUG bootstrap；Release 不注册高亮响应，根 SwiftPM 不引 CLI 依赖。不新增任意 KVC、脚本 eval 或跨 App 注入。host AX/OCR 无可写对象时返回 unsupported，不静默换成图片框选。

## 验证

- UIKit：原有边框、nil/颜色空间（动态 UIColor 在背景色预设引入时补测）、全量预检、部分应用异常、多个节点、窗口/scene/对象替换、复用、边框动画拒绝、属性组 conflict、重复 clear。
- 生命周期：无截图独立 apply、跨 CLI status/clear、正常退出连接仍 active、响应丢失按 operationID 查询、TTL、主线程卡住后恢复、App 挂起后恢复；无法证明的场景保留 unknown，不用 timer unit test 代替真实 UI 清理。
- 集成：同对象属性组 patch 冲突/无关 action 可继续、多目标隔离、正确 target、host 与 embedded screenshot、生成图确有高亮、恢复后属性回读一致。cell 拒绝边界和接入复用 hook 后的安全清理需真实 Simulator destination。
- CLI/schema：独立 apply/status/clear 完整 argv、单一 JSON、旧命令兼容、无 runtime/Release unsupported、operationID 幂等、无截图字段的 session receipt round-trip；status.ok 与 state 分离。evidence 另测图成功而恢复失败必须非零、下游失败仅清理自有 session。
- 性能目标仅建议：≤10 节点，属性保存/应用/恢复不阻塞正常帧；测量 MainActor 花费和总事务时长，host 截图慢时按 deadline 退出，不能无限加大 TTL。

本轮仅文档检查；功能、可靠恢复和截图视觉效果待实现，尤其不能把现有 patch tests 通过当成临时事务能力已有。

## P0落地差异

DTO/预算/入口以实际schema和shared模型为准，capabilities按目标provider返回。原型只支持OID/identifier/withinOID；text/role拒绝。幂等只覆盖预检后接纳的操作，零写拒绝可重试。原值边框强类型、弱祖先链、MainActor事务和整组条件恢复已实现；同值ABA仍value_guarded。渲染观测是main_queue_opportunity，返回后再次校验TTL/身份/applied；主线程卡死不提供墙钟deadline保证。capture参数与managed_override描述属于后续设计，不代表已实现。
