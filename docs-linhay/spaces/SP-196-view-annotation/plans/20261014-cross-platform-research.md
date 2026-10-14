# 独立视图高亮：跨平台技术调研与裁决

> 2026-10-14。范围：定位节点、保存原值、修改 App 内真实外观、独立查询/还原。状态：源码/官方文档/本机 SDK 声明核查完成；未编译或运行高亮 PoC，未启动设备，不能称产品能力已验证。

## 0. 可选能力与接入边界

用户明确：高亮是可选增强，不能强制用户接入内置SDK。此约束优先于下文各端候选实现。

- Triton的节点查看、既有操作和普通截图沿用各自现有能力，不新增embedded SDK前提。目标不支持属性高亮，只影响该可选能力。
- 属性高亮按目标探测provider能力：可使用已经存在的App内调试能力、用户自行提供的provider，或用户自愿接入的Debug适配模块。官方embedded SDK只是可选实现，不能作为唯一产品接入方式。
- 无可写provider时返回typed unsupported及原因；不得自动安装、注入或要求用户修改App。现有host/无障碍通道仍可用于其原有功能，但不伪装具有任意属性写入能力。
- 用户显式调用highlight apply，不支持则明确失败。截图/evidence的可选高亮采用prefer/required策略：默认prefer，unsupported时继续普通截图并标记highlight=unsupported、imageAnnotated=false；仅显式required时使该组合请求失败。出现部分写入或恢复冲突不能按unsupported静默降级，必须保留清理结果并显式报告。
- CLI/HTTP先呈现是否支持及原因，不把“请接入SDK”变成必经流程。平台provider只在实际使用和具备条件时加载/调用；Release/no-runtime不影响其他能力。

## 1. 裁决

**Decision：Hybrid — 共用会话契约，各端使用独立属性 provider。**

- iOS UIKit：采用实际 CALayer 的 borderColor/borderWidth 强类型快照与条件恢复，作为首个实现切片。
- Android 原生 View：对自愿启用属性高亮的目标，提供可选 App 内 Debug provider；API23+ 从受限 foreground 属性替换开始，初版只接受空 foreground 与兼容 tint/gravity 的普通 View，新增自有零 padding 描边 Drawable。
- Harmony 声明式 ArkUI：对自愿启用属性高亮的目标，采用 App 显式注册的响应式 attributeModifier 样式 provider（AttributeUpdater 为受限可选实现），保存类型完整的业务样式和版本，通过撤销本会话临时覆盖恢复。不能把 FrameNode UniqueID 当通用写权限。
- Compose/纯 SwiftUI：仅支持明确注册的节点/provider；不能把虚拟语义节点自动转换成原生可写 View。
- 外部无障碍、UIAutomator、HDC dump、XCTest/host AX：保留查找/截图角色，不声明高亮属性修改能力。

**Why：**三端身份、属性存储与可写边界不同。iOS边框可以直接读回，Android的Drawable有对象状态/共享副作用，Harmony声明式节点没有被确认的通用原声明无损快照。统一命令不应假设统一的 border setter。

**Borrowed：**保留现有 observe/node resolve、iOS registry、node.patch transport 分发思路、Harmony 独立 SDK 的注册 provider 入口；复用 session、TTL、幂等、markID、冲突/部分还原设计。

**Rejected：**截图后画框、全屏 overlay 作为默认替代；裸内存地址反解；跨进程无障碍ID→View强转；对业务 Drawable 原位 mutate；Harmony resetAttribute 代替还原；全局 setter/reuse swizzling；不分 provider 的万能 patch。

**Executor：**主控先固定契约与 iOS 原型；Android/Harmony仅在各自App内provider文件面隔离后并行实现。当前授权是调研，源码实现与设备验收尚未开展。

## 2. 身份不是同一种 ID

| 平台 | 原生标识 | 只能证明什么 | 恢复句柄设计 |
| --- | --- | --- | --- |
| iOS UIKit | ObjectIdentifier、现有递增OID | 当前存活对象身份 | runtimeInstanceID + OID/token + 原对象弱引用 + 内容epoch |
| Android View | resourceId、API29 getUniqueDrawingId | 前者是可重复查找键，后者是绘制系统ID | runtime内单调token + WeakReference<View>，引用比较而非hash唯一性 |
| Android Accessibility | API33 uniqueId，可为null | 无障碍节点身份，不保证一对一View | 只作selector/观察来源，无直接属性恢复能力 |
| Harmony ArkUI | API12 FrameNode UniqueID + UIContext | 当前UI上下文的实体节点查询 | runtimeInstanceID + provider token + native uniqueId + 内容epoch/生命周期 |
| Compose/SwiftUI | semantics/testTag/业务key等 | 语义或业务定位，不等价于可写原生对象 | 显式provider注册token，并绑定重组/复用生命周期 |

iOS [ObjectIdentifier 文档](https://developer.apple.com/documentation/swift/objectidentifier)明确对象比较有效期局限于实例生命周期。Android [View文档](https://developer.android.com/reference/android/view/View.html)允许ID重复，[API29变更表](https://developer.android.com/sdk/api_diff/29/changes/android.view.View)列出 getUniqueDrawingId；Android [AccessibilityNodeInfo](https://developer.android.com/reference/android/view/accessibility/AccessibilityNodeInfo)说明 uniqueId API33+可空，且无障碍树不一定与View树一一对应。Harmony UniqueID边界见 [UIContext官方文档](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkui/arkts-apis-uicontext-uicontext.md)。

因此 raw ID/地址只做查找和诊断；还原要有原生对象绑定、应用实例、生命周期版本。相同对象仍可呈现新业务内容，不能省略contentEpoch。

## 3. iOS：最先可落地的受限属性事务

### 已证实

- 主仓 `Sources/TritonKit/Util/TKObjectRegistry.swift` 已按 ObjectIdentifier登记递增OID，反向持有弱引用；不同App启动编号可能重合。
- `TritonKitRequestHandler+LegacyInspection.swift` 已在MainActor写真实 UIView/CALayer；目前允许部分applied，不能直接当高亮事务。
- [borderColor](https://developer.apple.com/documentation/quartzcore/calayer/bordercolor) 是可读写 CGColor?；[borderWidth](https://developer.apple.com/documentation/quartzcore/calayer/borderwidth) 是可读写 CGFloat，边框在bounds内侧且位于内容/子层之上。两者均可动画；本机iOS SDK的CALayer.h同样声明这两个字段。
- [CATransaction.setDisableActions](https://developer.apple.com/documentation/quartzcore/catransaction/setdisableactions(_:))支持局部禁用属性动作。SDK CATransaction.h 明确没有动画时 completionBlock 可以立即调用，因此它不能单独作为“已显示到屏幕”的证据。
- [prepareForReuse](https://developer.apple.com/documentation/uikit/uitableviewcell/prepareforreuse())不在reconfigureRows时调用，单一reuse hook无法覆盖内容变化。

### 推荐实现

新增 MainActor HighlightSessionManager，隶属runtime生命周期而非某条WebSocket；apply验证实际backing layer，保存CGColor?/CGFloat与guard组，使用局部CATransaction应用。等待显示机会、再检查属性与身份；presentation/model之间有未完成动画时明确拒绝或标render unknown，不删除业务动画。

基础API不要求截图；截图消费方另验证画面。clear按照[标记/还原契约](./20261014-mark-restore-contract.md)执行属性组条件恢复。背景色、透明度、布局、文本不进入首期。

### 需要先修订的集成假设

当前 `TritonKit.stop()` 为同步Void，直接stop连接并close；disconnect也复用它。不能在网络断线时创建新runtimeInstanceID或丢失原值。建议 manager 独立持有，transport重连只变transport generation；显式SDK shutdown通过异步清理路径返回结果，现有stop保持兼容并安排清理，未完成时不得销毁manager。最终API选择需先写失败测试，不能假定已有stop能等待UI回滚。

cell子树无可靠content epoch时拒绝；先对普通UIView演示完整闭环，再引入业务绑定前的cleanup/rebind hook。UIKit相关测试必须在iOS destination执行，macOS条件跳过不能算通过。

## 4. Android：现有桥与 App 内 provider 分开

### 已证实

`Tools/AndroidBridge` 是独立AccessibilityService；TreeHandler序列化AccessibilityNodeInfo，ActionRouter处理受支持动作。它没有目标App的View引用。官方说明服务获得的节点信息不可直接变更；可以执行动作或显示无障碍overlay，不代表获得目标View属性写权限。[官方节点契约](https://developer.android.com/reference/android/view/accessibility/AccessibilityNodeInfo)

Android不存在一个覆盖所有View的iOS式 borderWidth/borderColor 属性组。[View.foreground](https://developer.android.com/reference/android/view/View.html#setForeground(android.graphics.drawable.Drawable))从API23成为通用View接口，适合作为受限候选，但foreground可能影响padding且已有ripple/tint/gravity必须考虑。

[Drawable.mutate](https://developer.android.com/reference/android/graphics/drawable/Drawable#mutate())会改变共享状态关系，并非克隆且不可逆；ConstantState可为null。直接修改原background、再写回同一引用不能证明还原。

### 推荐实现（工程方案，待PoC）

- 可提供独立、可选的目标App Debug AAR/provider，不要求接入整个内置SDK；现有AccessibilityBridge仍只读/动作，不注入或反射绕过其他App。
- 主线程以对象身份注册单调token、WeakReference<View>；API29 drawingId仅诊断，不用identityHashCode当唯一ID。
- 第一批要求foreground为空、tint无冲突、gravity可兼容、标准View绘制路径；已有复杂foreground/custom view/Surface特例返回unsupported，避免覆盖ripple或动画。
- 每个mark创建独占BorderDrawable：透明内部、只描边、零padding、无固有尺寸，不共享可变实例。实际修改View.foreground属性，保持它在App绘制流程内。
- 记录foreground原引用及gravity/tint/布局guard；clear仅在当前foreground仍为安装的同一Drawable且guard未变化时恢复。若业务替换foreground，保留新值并报告ownership_lost。
- 必须测布局/padding/触摸/焦点前后无变化，不能因设计为“零padding”就宣称无副作用。

RecyclerView需在每次onBind/rebind前清理并递增generation，onViewRecycled不足。Compose独立注册Modifier.Node/业务key：其semantics可能合并，不等同View；onReset/onRelease等生命周期覆盖后才开放复用。[RecyclerView.Adapter](https://developer.android.com/reference/androidx/recyclerview/widget/RecyclerView.Adapter)、[Compose语义](https://developer.android.com/develop/ui/compose/accessibility/semantics)、[Modifier.Node](https://developer.android.com/reference/kotlin/androidx/compose/ui/Modifier.Node)。

## 5. Harmony：有实体节点 ID，仍须能力门禁

### 已证实边界

API12+ `FrameNode.getUniqueId()`与`UIContext.getFrameNodeByUniqueId()`支持实体查询；无对应节点返回null，自定义/Reusable组件可能映射到根或首个子组件，不能把业务组件ID与物理写入节点直接等同。

官方FrameNode文档和本机SDK声明需分别核对：commonAttribute/typeNode属性接口对创建方式有约束；代理节点getRenderNode可为空。`isModifiable`只约束其列出的操作，不是“所有属性都可写/不可写”的万能判断。某个SDK存在方法也不证明某类节点可调用。

[FrameNode官方文档](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkui/js-apis-arkui-frameNode.md)、[UIContext官方文档](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkui/arkts-apis-uicontext-uicontext.md)。

### 推荐路线

App显式注册可高亮目标和响应式 AttributeModifier，实现受控样式provider。优先修改原生 outline 属性：API11+支持，绘制在组件外侧，不占组件布局；仍需验证父节点裁剪、滚动和遮挡。provider持有原声明的强类型outline style、业务styleVersion、内容epoch；高亮向同一节点的真实outline属性加入临时覆盖。clear撤销自己的覆盖，再应用当前业务样式；业务期间改变样式时应用新业务值，不回退旧值。

AttributeUpdater（API12+）可作可选直通实现，但官方明确一个实例只能同时关联一个组件、后写属性生效，且不支持深浅色切换等状态管理操作。因此主题/状态变化必须由provider显式接管并实测；首选接入响应式业务样式来源，不宣称Updater自动保存或还原。API18的outline(undefined)重置到无描边，也不是恢复原业务outline。

官方依据：[outline](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts/ts-universal-attributes-outline.md)、[AttributeModifier](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts/ts-universal-attributes-attribute-modifier.md)、[AttributeUpdater](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkui/js-apis-arkui-AttributeUpdater.md)。

这一路线需要接入业务样式来源，不能只从Inspector结果读一个颜色字符串，再称恢复原始Resource/单位/主题状态。开发者直接写属性或更换modifier绕开provider时，返回ownership未知/冲突。

Native/TypedFrameNode可作为第二条受限路线；NativeNodeAPI的get/set必须逐属性验证数据/单位/引用有效期，reset返回默认值不能当成撤销本次操作。跨语言属性写入受节点来源和SDK版本限制，必须先锁定实际SDK/OS矩阵。

### 独立 SDK 与本机声明证据

- 只读核查同级独立仓库 `harmony-tritonkit`，HEAD `0c7a7525d61069098395b4719170b70934d81fcb`，已有未提交改动，未修改或集成该仓。`library/src/main/ets/ui-tree/ArkUIViewTreeCollector.ets` 已调用 getFrameNodeByUniqueId，Inspector样式仍以字符串读取；normalizeNodeId优先业务ID、其次node-uniqueId。因此协议应新增独立nativeUniqueID字段，不把现有nodeID一概当实体ID。
- `library/src/main/ets/server/ExportServer.ets` 已有runtime action provider注册入口；无provider返回unsupported_runtime_scope。可复用接入机制，但当前没有高亮快照/还原事务。
- 本机DevEco默认SDK的 `ets/oh-uni-package.json` 为API24、6.1.1.125 Release；`FrameNode.d.ts` 明确commonAttribute限定自定义节点，typeNode.getAttribute不支持声明式创建的节点，不能从UniqueID推导通用读写权限。
- 本机声明的跨语言节点范围与官方master后续版本不同；例如API24相关声明列出Scroll，master较新API增加范围，必须按实际SDK与OS做能力探测，不能照搬新文档。
- Native getAttribute返回缓冲的有效期也有约束，后续调用可覆盖内容；需要立即复制。即使读到ARGB/尺寸，也没有证明拿到原Resource表达式或动态绑定。resetAttribute是默认值重置；引擎ResetBorderColor/ResetBorderWidth还会清理资源关联，不能作为undo。

证据入口：[NativeNodeAPI getAttribute](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkui/capi-arkui-nativemodule-arkui-nativenodeapi-1.md#getattribute)、[引擎属性reset实现](https://github.com/openharmony/arkui_ace_engine/blob/master/frameworks/core/interfaces/native/node/node_common_modifier.cpp)、[NAPI句柄转换](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkui/capi-native-node-napi-h.md#oh_arkui_getnodehandlefromnapivalue)。以上均是调研证据，不等于主仓已交付高亮。

## 6. 统一协议，两种恢复机制

统一命令保持 `highlight apply/status/clear`；scope由runtimeInstanceID/provider/window-or-context/objectToken/contentEpoch确定，markID/sessionID负责这次操作。

provider能力必须拆分：`resolve`、`snapshot`、`apply`、`restore`、`renderObservation`；每项还要记录支持的preset和节点类型。只会resolve的provider不允许进入apply。capabilities声明不替代每次节点预检。

| 恢复机制 | 适用 | clear语义 | 必须保留的证据 |
| --- | --- | --- | --- |
| snapshot_compare_restore | iOS边框、Android受限foreground | 当前对象/属性组仍属于本会话时写回original | original/applied/readback、identity、guard/conflict |
| managed_override | Harmony/Compose显式注册样式provider | 去掉自己拥有的覆盖，重新应用当前业务基础样式 | overrideToken、baseStyleVersion、contentEpoch、去覆盖及有效样式回读 |

第二种机制属于本次调研新增建议，不把“应用当前业务值”伪装成“写回历史原值”。receipt需新增 `restorationMode`、`baselineVersionAtApply/current`、`restoredTo=original|current_base|already_original|none`，restorationVerified指按声明的模式已验证；没有readback/render证据仅标acknowledged/unknown。

统一preset `outline`表达产品意图，各provider映射原生属性组；width使用logical unit，报告实际pt/dp/vp及scale，不将各端值直接当截图像素。SDK不支持某属性组就返回typed unsupported，不回退到图片框选或overlay冒充成功。

## 7. 最小实验与实施顺序

| 次序 | 原型 | 必须证明 | 不通过时如何收口 |
| --- | --- | --- | --- |
| A | iOS普通UIView，两节点同label | apply/status/部分clear；原边框/nil恢复；截图确实改变；没有布局/点击变化 | 保留失败receipt，修runtime再继续 |
| B | iOS异常与生命周期 | CLI断连/TTL、stop/reconnect、业务写冲突、cell拒绝；恢复回读 | 不以计时器触发代替恢复证明 |
| C | Android目标App Debug provider | API23+空foreground View真实高亮，padding/焦点/触摸不变，旧token重启无效 | 限制节点范围或停用foreground路线 |
| D | Android复杂状态 | 已有ripple/tint拒绝、同resourceId去重、rebind清理、业务换foreground | 不顺手覆盖业务Drawable |
| E | Harmony modifier/provider | 普通声明式Button注册后修改outline，清除恢复Resource/多边单位/主题当前值 | 若只能读resolved字符串，不开放通用快照模式 |
| F | Harmony可复用/原生节点 | @Reusable/binding epoch；Native get/set/reset差异；SDK/OS一致 | 按节点类型与版本报告unsupported |

先统一契约和iOS A/B，再以独立SDK适配Android C/D和Harmony E/F；截图adapter最后组合已验证能力。设备动作、构建scratch和生命周期测试串行，原始截图脱敏，按Triton-first保存事实；本轮没有执行上述实验。

测试包括单元状态机/幂等/组冲突，真实UI生命周期和显示测试，CLI schema及HTTP透传单一envelope。UIKit/macOS、Android纯JVM/设备、ArkTS类型检查/设备各自分开报告，不把静态检查当运行成功。

## 8. 本轮证据等级与交付边界

- 已做：官方文档核对、现有代码读查、iOS/Harmony本机SDK声明核对、独立Harmony SDK入口只读核查、各端方案比较与细化。
- 未做：高亮代码实现、SDK编译、真实节点修改/还原、截图视觉证明、性能测量和发布。
- 技术可行性判断：iOS原生路线证据最完整；Android受限View需可写App内provider（可选接入，现有外部桥不支持）；Harmony显式provider可设计，但任意声明式节点通用快照还原不成立为当前承诺。
- 本轮research与plan不要求确认即可完成；后续实现按独立feature切片和各端门禁推进，不把本报告当已支持能力。
