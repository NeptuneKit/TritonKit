# 高亮标记与还原契约 v1

> 2026-10-14；P0 UIKit契约已实现并验收；跨端扩展仍为设计。关联 [SP-197](../README.md)。本文件是标记身份、属性归属及还原冲突的详细事实源；第1–10节以iOS P0快照恢复为范围，跨端扩展按第12节；此前概要中“逐字段恢复”“对象相同即可恢复”等表述按这里收紧。

## 1. 目标与承诺

独立 apply 完成定位、保存原属性、应用高亮并返回会话；status/clear 可以跨 CLI 请求使用。截图、录屏、调试是消费者，不参与高亮状态机。

还原的承诺是：对仍属于本次高亮、身份未变的属性，恢复其应用前的值并回读。不能将“发过恢复请求”“等待 TTL 结束”或“当前看起来不红”当作还原成功。App 可并发写自己的属性，因此“绝不覆盖业务新值”和“无条件去掉一切残留”不能在通用属性覆盖模式下同时保证；默认优先保护业务新值，明确报告冲突和可能残留。

## 2. 如何做可识别的标记

### 视觉标记

- P0 仅支持 outline：实际修改目标 CALayer 的 borderColor/borderWidth，默认橙红色、3pt。不依赖图片后处理，不插入假业务节点，不修改 text、tag、accessibilityIdentifier/Label。
- 不修改 cornerRadius、masksToBounds、alpha、hidden、zPosition、frame 或点击能力。保留原圆角和裁剪语义；被父视图裁剪/弹层遮住时不通过改变布局强行显示。
- 多节点每个有独立 markID 和 label；颜色可从固定预设选择，但颜色和图上顺序都不是还原标识。没有图内编号也能通过 JSON/节点引用定位。
- 预设 border 与现值完全相同：记录 no_change，不保存虚假的“修改”或声称出现新视觉效果。全批均 no_change 时返回明确 no_change 结果，不创建活动覆盖会话。
- P0 不开放 background/alpha 等预设。后续每新增预设必须定义自己的属性组、强类型快照、值比较、动态属性和恢复测试，不能直接继承 generic patch 全字段。

### 五层身份

| 标识 | 用途 | 失效规则 |
| --- | --- | --- |
| runtimeInstanceID | 区分一次 runtime 生命周期，随机 UUID | App/runtime 重建改变；WebSocket 重连不改变 |
| operationID | apply 请求幂等键 | 绑定 runtimeInstanceID 与规范化请求 hash；重试不修改原值/延期 |
| sessionID | 一次多节点高亮会话 | clear/过期后保留终态记录，不能复用为新会话 |
| markID | 会话内一个节点标记，可由调用方命名 | 唯一且固定，重复 ID 拒绝；不等于 OID、颜色或 @N |
| objectToken + contentEpoch | 精确运行对象及其当前内容身份 | 弱引用 === 检查；cell/可复用子树要求可靠内容 epoch |

节点引用包含 runtimeInstanceID、viewOID/layerOID、window/scene、provider；OID 仅用于最初解析和审计。恢复使用原对象弱引用与 token，不重新按文字、位置、OID 去找一个相似对象。

`TKObjectRegistry` 当前进程内递增分配 UInt OID、反向引用为 weak；进程重启会重新计数。现有 transport generation 随重连递增，不能拿它充当本契约的 runtimeInstanceID。token 是 runtime 内部 ownership 表，不写业务 view.tag 或 AX 属性。

## 3. 保存什么，放在哪里

每个 mark 保存：对象弱引用/token、初始内容 epoch、节点路径摘要、原 window/scene、创建时间、deadline、preset/styleVersion、属性组快照、实际 applied 回读值、修改顺序及状态。

每个属性组保存：original（原始类型）、applied（setter 后实际回读类型）、changedKeys、guardKeys、ownershipState、restoreAttempt/最后回读。outline 组为 `{borderColor,borderWidth}`；即使只改其中一项，也保存并校验整组作为恢复前提。

- CGColor 保留原颜色对象/颜色空间和 nil；CGFloat 保留原数值；不能通过 hex/字符串往返还原，不借用“默认值”。
- P0 强类型快照只保存在 App runtime 内存；host receipt 是可脱敏摘要和恢复句柄，不含可跨进程重放的反向 patch。
- 对象弱引用避免 prolong 页面生命周期；颜色等 value snapshot 可以强持有。对象消失后不能把快照灌入另一个对象。
- 幂等重试永远返回首次快照，不能把已经高亮的红色当成新的 original。
- 不做 whole-view dump/restore；只恢复本次 changedKeys，guardKeys 用来发现属性组被业务整体接管。未修改属性绝不写回。

## 4. apply 的严格顺序

1. 校验 runtimeInstanceID、operationID、schema/TTL/上限；已接纳/可能写入的 operationID + 相同 payload 返回已有结果，不同 payload 拒绝；预检阶段validation/not-found/busy等零写拒绝尚不登记去重键，原因解除后同ID可以执行。MVP 一个 runtime 只允许一个活动或尚有残留待处理的高亮会话。
2. 只解析已存在的 UIView/CALayer，不接受通过 UIViewController.view 隐式加载页面；CALayer.delegate 映射回 view 时必须确认 view.layer === layer。解析所有节点，按实际 layer 去重。同对象通过 viewOID/layerOID 被重复选中：同预设合并、返回 requestID→canonical markID 映射；不同预设拒绝整批。多个 markID 不能争同一字段。
3. 检查可见性、对象/content 身份、属性 allowlist、值有限且有效、已知边框动画/未完成恢复；任一预检失败则零写入。
4. MainActor 同一不可挂起临界区再次核验，保存全部 original，再按固定顺序应用；局部禁用本次隐式动画。保存与应用之间无网络调用、截图或 await。
5. setter 后读取 applied 值，不采用未确认的请求值；值未接受或重入改变了上下文即中止。在 setter 前记录 writeAttempted、写后记录 readback，记录每个已尝试写入组，逆序尽力回滚；回滚也须遵守身份/归属规则，不能因此宣称绝对原子事务。
6. 给出有界渲染机会后再校验 applied、身份、期限；未就绪/已失效则清理并报告 apply failed + cleanup outcome。renderReady 仍不证明屏幕未遮挡。
7. 返回 active session、marks、deadline。CLI 正常退出和连接断开不清理；runtime 可独立到期清理。

多节点批次承诺“全量预检、失败时补偿”，不是无法失败的数据库原子性。个别恢复失败必须留下 receipt；不把部分 applied 当整批成功。

## 5. clear 不是反向 patch

clear 必须显式指定 sessionID；可选 markIDs 子集。无 markIDs 表示本会话全部，不支持无范围 clear-all；子集含不存在 ID 则零写入。清理范围绑定 runtimeInstanceID，不允许基于当前 selector 重新定位。

每个 mark 按属性组判定，组间及 mark 间可独立处理；组内所有恢复前提先检查，再恢复 changedKeys，回读整组。outline 的色与宽是一个视觉组合，禁止机械恢复一半，生成“业务新颜色 + 旧宽度”的未知样式。

| 情况 | 动作 | 精确结果 |
| --- | --- | --- |
| 同对象/内容 epoch 有效；guardKeys 均等于 applied；归属未失效 | 恢复 changedKeys → original，回读确认 | restored |
| 当前整组已等于 original | 不写值，释放归属；不能声称由我们恢复 | already_original |
| 任一 guardKey 与 applied/original 的整体条件不符，或已观察业务写入 | 整组不写，保留当前样式、撤销自动写回资格 | conflict，可能残留 |
| 对象已释放 | 不找替身，不写值 | target_gone，无存活对象上的高亮 |
| runtimeInstanceID 不同 | 不写新进程；返回旧实例失效信息 | stale_runtime；无法据此证明旧实例状态 |
| cell 内容 epoch 改变、未知，或对象跨 scene 上下文已不可信 | 不把旧 original 写到新内容；可确认的预失效清理另行处理 | identity_changed/unknown，可能残留 |
| MainActor 暂不可执行 | 保存待处理意图，禁止报告已恢复 | restore_pending |
| setter/回读未符合 original | 保留 snapshot 与失败组，不再次应用高亮 | restore_failed |

具体例子：原边框灰色/1pt，高亮红色/3pt，业务改为绿色/3pt。默认 clear 保留绿色/3pt、报 border 组 conflict；不擅自改为灰色/1pt，也不猜业务是否想要绿色/1pt。可能保留了高亮宽度，但这是有证据的冲突，必须明确展示。

已观察的冲突是单向失去所有权：之后值又变回红色也不自动恢复旧值，避免已知 ABA。默认不提供 force restore。用户/业务代码可重新渲染本组，status 验证整组回到 original 时记 already_original，或在所有 changedKeys 均可确认不再是 applied 时记 resolved_externally（不是 restored）；仍不确定则保持 residual/unknown。

对于始终未被观察到的同值写入/ABA，通用比较恢复无法发现。receipt 标明 `ownershipAssurance=value_guarded`；只有 provider 确实追踪了所有相关写入版本，才允许 `versioned`。P0 不通过全局 setter swizzling 声称万能可靠恢复，不把 ownership token 当业务写拦截器。

## 6. 重复、部分清理与结果聚合

- 同 operationID apply 重试：返回原 session/快照/期限，不叠层；同运行目标不同 operationID：有会话则 busy。MVP 不做嵌套高亮栈或会话间覆盖。
- clear 支持全部/markID 子集，无样式更新或延长 TTL；修改样式需先彻底清理，再新建会话。部分清理不延长其余 mark 的期限。
- 已 restored/already_original 的 mark 再 clear 返回原终态，不重新写旧值；TTL 与显式 clear 同时到达由同一 MainActor 管理器串行处理。
- clear 操作失败组不会阻止其他安全 mark 恢复；结果明确每个 mark 的 outcome。不能因为清了 9 个、冲突 1 个而整体 ok=true。
- 聚合字段：`state`（active/partially_active/restoring/closed/needs_attention）、`cleanupComplete`、`restorationVerified`、`residualState`（none/possible/unknown）、`marks[]`、`reason`、`errors[]`。无残留但节点已释放可 cleanupComplete=true、restorationVerified=false。
- clear ok=true 只在请求范围全部 restored/already_original；status ok=true 仅表示查询成功。整个会话其他 mark 可能仍 active，不能拿单次子集 clear.ok 当整会话结束。
- 普通 apply/status/clear receipt 不包含必需的截图字段。evidence 将 `capture` 与上述 `cleanup` 并列组合，只清理自己创建的 session。

## 7. 复用、离树与调试动作

仅 `weakRef === object` 不能证明 cell 内容未变；仅文本/路径 fingerprint 也不是可靠 contentEpoch。对于 UITableViewCell/UICollectionViewCell 及其子视图，P0 若没有可验证的 reuse/content hook，返回 `highlight_identity_unverifiable`，不能偷偷降级成“安全恢复已支持”。

可支持的接入方式是 provider 在 reuse/rebind 前通知 runtime：在旧内容仍有效时清理，再递增 contentEpoch，随后执行业务绑定。hook 必须覆盖异步 reconfigure 等路径；只挂 prepareForReuse 不足以证明全部内容变更都已覆盖。未知路径依然 fail closed。普通视图字段也可能被业务改写，因此仍受 value_guarded 限制。

离树/跨窗口不是对象销毁。能够在已知 will-detach/pre-navigation 时安全清理的，先清理再执行动作；如果发现时已经换内容/scene，则保守 identity_changed，不把旧样式写到新上下文。原对象消失不能重新 resolve 同名控件。

高亮 apply/clear 短临界区串行；活动高亮不长期封锁输入。Triton patch 修改重叠组时拒绝；无关属性/观察可继续。已知导航/复用动作前请求清理，若清理冲突则该自动流程停止并带回 receipt，不能因“动作更重要”偷偷释放归属。App 自己的异步导航无法全局阻止。

## 8. 超时、重连和恢复记录

- 默认 TTL 30s，范围1–300s，无永久会话/自动续期。runtime 使用覆盖设备休眠经过时间的单调时钟；期限到达后禁止继续报告 active，即使 UI 清理暂时排队。
- apply 正常结束/CLI 被杀/连接断开：保留 session 到显式 clear/期限，不依赖 host finally。WebSocket 重连保持 runtimeInstanceID、会话、快照及 operation 去重事实。
- 主线程卡住/挂起时，deadline 可以已到但样式仍在；状态 pending/unknown，恢复执行能力后先清理。恢复前的短暂可见窗口不能承诺完全消失，需真实验收。
- runtime stop 若进程仍活着，必须先清理再丢弃 manager；不能用“SDK 已停止”解释丢失快照。无法清理时保留 manager/pending 记录并返回不完整停止；Release no-op 不创建这些状态。
- App 进程退出后属性不存在，host 丢失回执时只能说明失联；只有重新连接或明确进程证据才能区分退出与暂时不可达。新 runtime 拒绝旧 session，绝不跨进程回灌 original。
- 去重：runtime 生命周期内保存紧凑 operationID + payloadHash + terminal/session 引用，不随详情过期删除“已使用”事实。详情可按上限淘汰后返回 receipt_expired，不能重放已使用 operationID。去重容量耗尽时拒绝新 apply，不淘汰旧键偷偷执行重试；上限与内存预算在实现阶段定量验证。
- 未清理快照不得因 TTL/普通 LRU 淘汰。仍有 possible residual 的 session 暂阻止新 apply，保留只读检查与恢复入口；明确 error/recovery，不创建无限后台重试。

## 9. 机器可读示例（拟议）

```json
{
  "ok": false,
  "runtimeInstanceID": "runtime-A",
  "sessionID": "highlight-7",
  "requestedMarkIDs": ["submit", "hint"],
  "state": "needs_attention",
  "cleanupComplete": false,
  "restorationVerified": false,
  "residualState": "possible",
  "ownershipAssurance": "value_guarded",
  "marks": [
    {"markID": "submit", "outcome": "restored", "group": "border"},
    {"markID": "hint", "outcome": "conflict", "group": "border",
     "changedKeys": ["borderColor", "borderWidth"],
     "restoreWritten": false}
  ],
  "error": {"code": "highlight_restore_conflict", "message": "App changed the border group; current values were preserved."}
}
```

所有命令 stdout 保持单一标准 envelope；raw original 对象不序列化。状态查询可携带单调 remainingMs 和展示用 expiresAt；用户机器墙钟变化不能改变真实期限。

## 10. 必须先写的失败场景

| 类别 | 场景与预期 |
| --- | --- |
| 身份 | 旧进程 OID 相同但 runtime 不同 → 不写；对象释放后内存复用 → 不写替身；layer 重绑 → invalid |
| 原值 | nil color、原边框宽度、颜色空间 → 原类型恢复；同 preset no-op 不误存新的 original |
| 去重 | 响应丢失重复 apply 不重新快照/延期；view/layer重复目标合并；同层不同preset拒绝 |
| 批次 | 第3节点预检失败零写；第3节点应用失败逆序补偿，补偿失败回执不能被覆盖 |
| 属性组 | 业务只改 color 时 width 不半还原；整组 already_original 不写；已知 ABA 不重新取得所有权 |
| 部分清理 | A clear 后 B 仍 active，session 未结束；未知markID零写；重复clear不再次写旧值 |
| 复用 | 缺内容generation的cell拒绝；pre-rebind清理；已rebind不恢复旧颜色；离树但活对象不当释放 |
| 超时 | apply退出不清理；TTL和clear竞争只一次写；挂起/卡主线程显示pending而非restored |
| SDK 生命周期 | transport重连不丢快照；SDK stop前清理，失败不丢manager；旧session不能恢复新runtime |
| 消费者 | screenshot失败不擅自clear；evidence只清自有会话；截图成功/还原冲突仍失败 |
| 外观 | 真实截图确认高亮可见，clear后属性与视觉分别验收；场景变化不能只靠像素差证明恢复 |
| 预算 | 节点/会话/去重上限达到时明确拒绝，不能淘汰待清理快照；无无限timer/retry |

逻辑比较/聚合可以纯单测；对象生命周期、显示提交、cell复用、MainActor恢复和动态外观需真实UIKit destination及可观测事件回执。无法完全控制的业务ABA和卡死期间的恢复时刻作为明确能力限制，不能通过放宽测试隐藏。

## 11. 跨平台节点 ID：查询身份与恢复句柄

2026-10-14 核对，平台 API 有 ID 不代表 Triton 已接通任意属性写入。统一对外恢复键建议为 `(runtimeInstanceID, provider, objectToken, contentEpoch)`；markID/sessionID 管理一次高亮，selector/nativeID 用于定位与审计，实际恢复仍需进程内有效对象/节点绑定。

| 平台 | 可用标识与现有代码 | 高亮恢复接入方案 |
| --- | --- | --- |
| iOS UIKit | 对象身份/内存地址仅对应存活对象；当前 TKObjectRegistry 以 ObjectIdentifier 为索引分配递增 OID，并保存弱引用 | 沿用 OID + runtimeInstanceID，内部使用原对象弱引用；不把地址整数转回对象，不跨重启恢复 |
| Android View | View.id/resource-id 是布局查找标识，允许重复；AccessibilityNodeInfo.uniqueId 从 API33 提供且可为 null | embedded provider 按真实 View 对象身份分配 runtime 内单调 token，并弱引用对象；resourceId 只用于初始定位，RecyclerView 内容复用仍需 epoch |
| Harmony ArkUI | FrameNode.getUniqueId()/UIContext.getFrameNodeByUniqueId() 自 API12 提供系统节点 ID 与查询；无对应节点返回 null | 在匹配 UIContext 中绑定原 FrameNode/provider handle，外加 runtimeInstanceID；节点重建/复用和可读写属性支持逐项验证，不只凭 uniqueId 宣称可恢复 |

当前项目事实：Android TreeHandler 提取 resourceId 和 API33+ uniqueId；CLI bridge nodeID 回退为 uniqueId/resourceId/path，UIAutomator nodeID 则使用遍历序号。因此当前 nodeID 并非统一的稳定 View 对象身份。Android AccessibilityService 节点可能是虚拟节点，不与真实 View 一一对应，也不提供通过此桥任意修改目标 App 边框的能力。

Harmony host layout 当前 nodeID 优先 hierarchy，随后 accessibilityId/hashcode/path；另保留业务 id/key。不能把这些 HDC dump 字段自动等同 App 内 FrameNode.uniqueId。后续 embedded adapter 要分别验收 ID→对象绑定、属性读取、修改及还原，未知即 unsupported。

官方依据：

- [Android View IDs](https://developer.android.com/reference/android/view/View.html)：ID 无需在整棵树唯一。
- [AccessibilityNodeInfo](https://developer.android.com/reference/android/view/accessibility/AccessibilityNodeInfo)：getUniqueId API33+，允许 null；无障碍树与 View 树不保证一一对应。
- [OpenHarmony FrameNode 官方源码文档](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkui/js-apis-arkui-frameNode.md)：getUniqueId API12+；同一节点可以复用，ID 不代表业务内容永久不变。
- [OpenHarmony UIContext 官方源码文档](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkui/arkts-apis-uicontext-uicontext.md)：getFrameNodeByUniqueId API12+、空值和自定义/Reusable 组件映射边界。具体 HarmonyOS SDK 接入仍需匹配本机版本校验。


## 12. 技术调研后的跨端恢复扩展

详见[跨平台技术调研](./20261014-cross-platform-research.md)。共享session/mark/TTL/幂等契约；provider须声明恢复机制，不把iOS边框快照推广为所有平台的通用能力。

- `snapshot_compare_restore`：iOS border组、Android受限foreground；保留original/applied强类型快照和guard，满足所有权条件才回写原值。Android按安装Drawable的引用身份判断，原Drawable不做mutate。
- `managed_override`：Harmony响应式AttributeModifier、未来显式Compose provider；保存原始业务样式/版本用于审计，同时持续维护当前业务基础样式。clear只撤销自己的overrideToken，并重算当前基础样式。业务版本变化时结果是current_base，不能称恢复历史original。
- receipt新增restorationMode、baselineVersionAtApply/current、restoredTo（original/current_base/already_original/none）。restorationVerified按照声明模式验证；只有逻辑ACK而无属性有效值证据时仍标unknown，不把显示机会当作截图证明。
- provider绕过写入、节点解绑或内容epoch改变时，停止旧值回写并按所有权/生命周期报告冲突；注册式provider必须在重绑定之前清理。不能用业务ID重新找到新节点后恢复旧快照。
- 统一outline是意图：iOS映射CALayer border，Android映射受限foreground drawable，Harmony优先原生outline；实际属性、单位和支持范围写入receipt/capabilities。Android API29 getUniqueDrawingId可辅助诊断，但不替代runtime token及弱引用。
- 新增BDD：高亮期间业务样式/主题升级V1→V2，clear必须显示V2且receipt为current_base；同provider绑定新组件前清理旧覆盖；Harmony主题变化不能依赖AttributeUpdater自动处理；未注册声明式节点明确unsupported。

本次只修订契约，尚无跨端实现或设备验证。iOS P0继续使用第1–10节约束。


## 13. 可选能力约束

高亮不强制用户接入内置SDK；原有查看、操作、截图能力的接入条件不变。provider可来自已有调试能力、自定义适配或自愿启用的独立Debug模块。仅resolve/截图能力不足以宣称可修改属性；不自动安装或注入。

显式highlight apply缺能力时返回unsupported；组合截图默认prefer，仅在零写入的unsupported场景继续普通截图，标明highlight=unsupported/imageAnnotated=false。显式required才使能力缺失阻断组合请求。已有写入、恢复失败或冲突必须返回相应失败/部分结果和清理证据，不能静默变成普通成功截图。上述策略不改变会话归属和finally清理义务。

## P0实现与验证补记

[模拟器验收](./20261014-p0-validation.md)记录当前可执行能力。main_queue_opportunity是下一MainActor队列机会，结束后校验deadline/identity/applied；不是帧已呈现或主线程卡死时可强制取消。sync stop安排清理且保留原值；async stopAndRestoreHighlights等待本批清理，被更新stop取代时可返回nil，不当作还原证明。节点原view到window弱祖先链重新绑定即失效。业务自己移除全部owned字段可resolved_externally，cleanupComplete=true而restorationVerified=false；已经original回读可already_original，但不能称由高亮器回写。
