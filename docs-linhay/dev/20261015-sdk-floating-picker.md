# SDK 悬浮圆点控件选择：当前契约、调研与经验

当前版本：2026-10-16。需求、BDD与交付阶段见 [SP-201](../spaces/SP-201-sdk-floating-picker/README.md)。源码已实现并验证，仍为未发布候选；下文初版调研/契约草案保留历史，不能覆盖本节与“已实施契约”的实际字段。

## 当前交互与机器契约

直接拖动圆球变准星，实时线框/名称/局部放大；长按0.4秒拖动只移位。密集辅助框延迟0.25秒显示，松手/取消清理；有效松手保留标记并自动展开罗盘。上父级、下子级、左右同级，连续导航保持展开；父子往返记忆与稳定位置是当前体验契约。中心收起、清除独立，左右不是屏幕几何方向。

实际接口为 `inspect capabilities|selection|clear`，选择结果 `TKSelectionResponse` 的核心字段为 `runtimeInstanceID/revision/state/selection`，selection内含 `id/revision/target/validity/supportedActions`。动作使用 `act tap --selection <id> --selection-revision <revision> --runtime-instance-id <id>`；三项必须来自同一响应，实际执行处同步检查，不自动降级裸OID或坐标。启用方式与命令示例见[接入指南](20260519-ios-integration-guide.md)。

状态 `none/valid/observeOnly/stale` 与浮层显示分离。可执行首版是明确UIButton；文字/cell/身份无法证明的对象保持observeOnly。Debug双重显式启用，Release no-op。完整交互参数、迟滞和渲染边界见文末“连续选取体验优化”；[最终整理](../spaces/SP-201-sdk-floating-picker/plans/20261016-recap-v01.md)汇总源码和验证。

## 历史调研（2026-10-15）

## GitHub 调研

| 项目 | 已核实机制 | 对本需求的借鉴 | 差距 / 取舍 |
| --- | --- | --- | --- |
| [react-debug-inspector](https://github.com/linhay/react-debug-inspector) | 悬浮按钮进入检查模式；高亮元素，复制组件、源文件位置和上下文；构建期注入 data-debug | 入口简洁、目标可见、上下文可交接 | React 构建期源码映射不等于原生 UIView 源码定位；不直接移植 Babel 方案 |
| [FLEX](https://github.com/FLEXTool/FLEX) | App 内浮层工具条；遍历可见视图；排除自身窗口；支持候选层级切换 | 原生视图多层消歧、业务窗口和调试层分离 | 不是 agent 交接协议；不整体引入框架和私有 API |
| [DoKit](https://github.com/didi/DoKit) | iOS ViewCheck 准星在 touchesMoved 中查找目标并更新轮廓框，排除自身与边框；Android 也有 ViewCheck 模块 | 与“直接拖动圆点选控件”最接近，优先借鉴交互 | iOS touchesEnded 移除轮廓；没有本需求所需的持久 selection/agent 动作闭环；坐标处理需按本项目重新设计 |
| [React Grab](https://github.com/aidenybai/react-grab) | 将元素与组件调用栈、源码位置交给 agent；primitives 支持命中测试、排除检查器本身、限定容器 | 将“可视选择”与“结构化上下文”分层；不把交接限制在剪贴板 | 服务于 Web/React；原生实现应提供 runtime 目标身份，源码位置只能可选 |

补充轻量参照：[petite-react-grab](https://github.com/aidenybai/petite-react-grab) 将浮层与工具条隔离在 shadow root，适合后续 WebView provider 的隔离思路；不新增为 SDK 依赖。

### 来源固定点

使用 GitHub API 核对本次默认分支，以下为源码研究基线，不代表发布版本：

- react-debug-inspector `main@98de1cad6737c006af2567ea328f710a557deafe`：[README](https://github.com/linhay/react-debug-inspector/blob/98de1cad6737c006af2567ea328f710a557deafe/README.md)，MIT。
- FLEX `master@63a6f588841e94e4c3adaa045ff16eb8163f0bb4`：[FLEXExplorerViewController.m](https://github.com/FLEXTool/FLEX/blob/63a6f588841e94e4c3adaa045ff16eb8163f0bb4/Classes/ExplorerInterface/FLEXExplorerViewController.m)。重点 `viewsAtPoint`、`viewForSelectionAtPoint`、`recursiveSubviewsAtPoint`、`handleChangeViewAtPointGesture`。[LICENSE](https://github.com/FLEXTool/FLEX/blob/63a6f588841e94e4c3adaa045ff16eb8163f0bb4/LICENSE) 含禁止将该项目放入 App Store 提交 App 的附加条件；API 返回 NOASSERTION，不能简单标成普通 BSD。首版只参考机制，不复制或引入其代码。
- DoKit `master@626827cddb2feb2f3aee87a52a064b4e5ca2bed4`：[iOS ViewCheck](https://github.com/didi/DoKit/blob/626827cddb2feb2f3aee87a52a064b4e5ca2bed4/iOS/DoraemonKit/Src/Core/Plugin/UI/ViewCheck/Function/DoraemonViewCheckView.m)、[Android ViewCheck](https://github.com/didi/DoKit/blob/626827cddb2feb2f3aee87a52a064b4e5ca2bed4/Android/dokit/src/main/java/com/didichuxing/doraemonkit/kit/viewcheck/ViewCheckDoKitView.java)，Apache-2.0；本轮深入核对 iOS 触摸路径，Android 仅模块入口核查。
- React Grab `main@ea4bbec9e80f4802e8ae19ad18431edb9ddbb670`：[README](https://github.com/aidenybai/react-grab/blob/ea4bbec9e80f4802e8ae19ad18431edb9ddbb670/README.md)、[类型契约](https://github.com/aidenybai/react-grab/blob/ea4bbec9e80f4802e8ae19ad18431edb9ddbb670/packages/react-grab/src/types.ts)，MIT。

结论：自研轻量 picker，组合 DoKit 拖动方式、FLEX 层级消歧、React Grab 上下文交接的思路。使用 TritonKit 现有传输和动作引擎，不引入以上依赖，不承诺原生源码文件/行号自动恢复。

## 初版源码复用分析（历史基线）

基线：主仓 `dd613a99`，只读分析，未运行产品测试。

| 入口 | 现有能力 | 新增工作 |
| --- | --- | --- |
| `Sources/TritonKit/TKRuntimeAXBuilder.swift` / `performHitTest` | 坐标命中、AX-safe 祖先转换 | 同 scene 候选栈、原始命中与最终语义目标分离、排除自有浮层 |
| `Sources/TritonKit/Util/TKObjectRegistry.swift` | 单调 OID 与弱引用 | selection 绑定 runtime 实例和内容身份；不把 OID 当跨进程 ID |
| `Sources/TritonKitShared/TKObservationModels.swift` / `TKAXNode` | role/label/identifier/frame、view/target/layer OID | 复用节点快照，新增选择状态与版本 |
| `Sources/TritonKit/TKRuntimeForegroundTargets.swift` | 活动窗口、模态、可见性与 stale 保护 | 统一 SDK-owned overlay 排除；已有业务遮挡规则仍保留 |
| `Sources/TritonKit/TKRuntimeInputActions.swift` | tap、focus、setText 等已有动作 | selection guard 在实际执行处验证，避免读完后目标改变的竞态 |
| `Sources/TritonKit/Highlight/` | SP-197 属性高亮、恢复与冲突收据 | 仅作为选中后的可选消费者；不改现有语义 |
| `Sources/TritonKit/TritonKit.swift` | Feature、Configuration、Debug gate | 可选 inspector 配置、启动停止、scene 生命周期 |
| `Sources/TritonKitCLI/CLIActionCommands.swift` / `Hit` | 现有 hitTest 传输入口 | selection 查询与原有 act 参数接线；schema/capabilities 同步 |

Android 当前本仓 `Tools/AndroidBridge/` 为 AccessibilityService 外部辅助桥，不持有目标 App 的 View 对象；系统悬浮 Accessibility overlay 属于不同 provider 与权限边界。Harmony SDK 位于独立仓库，只有 [SP-197 跨端调研](../spaces/SP-197-view-annotation/plans/20261014-cross-platform-research.md) 的历史线索，本轮未核对当前源码或获得跨仓实现范围；不声明现已具备 picker。

## 初版模块与交互（历史，后续修订见文末）

建议四层：`PickerOverlayCoordinator` 管浮层与 scene 生命周期；`PickerTargetResolver` 解析命中及候选层级；`SelectionStore` 保存单个有界快照和弱引用；shared/CLI/HTTP 暴露只读选择状态，现有 action 执行器消费选择保护条件。

状态区分 UI 与目标：UI 为 hidden/idle/picking/selected；目标为 valid/stale/observeOnly/none。取消 picking 不隐式清空旧 selection。用户每次提交目标、切换父级或清除均递增 revision；失效原因可查询。

- 圆点视觉直径可先试 24–28 pt，触摸区域先试 44 pt；最终以真实设备操作验证为准。仅圆点/菜单接收触摸，其余区域透传。
- 直接拖动圆球实时预览控件；长按 0.4 秒后拖动仅移动圆球并停留。选取时松手固定标记并恢复圆球停靠位置；轻点打开父级/清除菜单。使用 UIKit 原生 pan/long-press recognizer 区分手势，取消菜单内的移动模式。
- 拖动期间圆球自身变为透明底十字准星并跟随手指，准星中心就是命中位置；松手恢复圆球。线框和紧凑标签预览候选。选中后显示编号和控件类型。
- 用户可向父级调整选择，UI 明示实际层级；保留 rawHitOID、targetOID 与解析原因。任何自动语义祖先归并都应能被理解。
- 拾取过程中不发送业务点击、滚动或合成触摸；手势取消不把结束事件透传给控件。
- overlay 不抢 key window，不改变业务 first responder。首次仅支持绑定 scene；多窗口切换清晰取消/重建当前 picking。
- 固定标记跟随当前视图几何；无可靠身份或被遮挡时转 stale。禁止只保留旧矩形继续声称有效。

## 初版机器契约草案（历史，非当前wire字段）

建议命令形状为 `triton inspect selection --json`、`triton inspect clear --json`，通过现有本地 HTTP/runtime 通道传输；具体命名实施前对照 parser/schema 冻结。agent 动作扩展现有 `act` 的 selection 引用，不创建另一套点击执行器。

最少字段：

| 字段 | 含义 |
| --- | --- |
| schemaVersion / runtimeInstanceID | 协议版本、进程实例；不复用进程退出前身份 |
| selectionID / revision / selectedAt | 标记与单调变更版本；明确本次动作针对哪个选择 |
| sceneID / windowID | 目标场景/窗口；不使用全局第一窗口替代 |
| rawHitOID / target: TKAXNode / resolutionReason | 命中视图、语义目标及归并依据 |
| coordinateSpace / rect | 目标窗口逻辑 point；仅定位证据，动作前重新验证 |
| validity / invalidReason / supportedActions | 能否观察/操作及限制，不以“有 OID”推断可点击 |
| identitySnapshot / contentEpoch | 目标、祖先、窗口、业务内容代次证据；无可靠 epoch 则复用容器只观察 |
| deliveryState | 本地可读/连接状态；不显示未经确认的“已发送 agent” |

运行时持有权威 selection；CLI 退出不清空，同进程断连可保留一个有界标记，重连时重新验证。默认 TTL 建议 5 分钟，配置必须有范围校验，挂起时不承诺准时清理；读取与动作时同步判断超时。敏感输入不返回明文 value，label/text 使用现有脱敏策略，文本长度有上限。首版不默认截图、上传源码或调用云模型。

动作路径必须将 `runtimeInstanceID + selectionID + revision` 一起送到 runtime，在执行该动作的 MainActor 临界段校验弱目标、场景、窗口、当前模态、内容身份及支持动作，再调用现有 action。不能只在 CLI 先查 OID，再无保护地发出动作；重选、导航、复用可能发生在两次请求之间。拒绝失效目标后不自动按旧坐标兜底。

成功仍由现有动作 receipt 和业务后置条件判断；selection 被读取、传输 ACK、轮廓出现都不是业务动作完成证据。只提供上下文，不在 SDK 内内置某个 agent 产品或自动发起外部会话。

建议稳定失败类别：unsupported、selection_missing、selection_stale、selection_revision_mismatch、selection_identity_unverifiable；实施时与现有 envelope/failureCodes 命名对齐，保持单一合法 JSON。

## 接入风险与下次检查

1. **浮层污染前台窗口。** `keyWindows()` 按 level 排序，而 `runtimeForegroundTargetFailure` 要求目标在第一业务窗。独立高层 UIWindow 若不统一排除，会改变 hitTest、action、AX 和截图路径。新增测试必须在浮层可见时仍能命中并操作下方按钮，且业务树/普通截图不只剩浮层。自有浮层用明确类型/注册身份标记，不能宽泛跳过所有高层窗，系统告警仍应阻断背后操作。`TKHierarchyBuilder.buildHierarchyWithBudget` 直接枚举 scene windows，不经 `keyWindows()`，因此必须另接同一排除策略，不能只修改前台窗口函数。
2. **选择预览与属性高亮不同。** SP-197 修改真实 border 且只有一个活动事务；逐帧 apply/clear 会冲突，并不能覆盖 cell。预览独立绘制；对外术语和 capability 分开，既有属性高亮测试保持通过。
3. **对象存活不证明业务内容相同。** OID 弱引用防释放对象，但 cell 可以同对象复用。可靠 content epoch 不存在时仅观察或重新选择，不能只比较文案与 frame 就宣称身份稳定。
4. **坐标、模态和平台边界。** 统一窗口 point 与坐标转换，覆盖滚动、transform、clipping、旋转、键盘、多 scene；不可选择系统 App UI 或未接入 App。SwiftUI/DOM 单独探测能力。
5. **证据范围。** 设计阶段证明源码存在上述耦合，当时未实跑新增浮层；实施验证见下文，不能把设计阶段与运行证据混写。下次先构建失败夹具再实现；不得将 macOS 条件编译跳过的 UIKit 测试当通过。

## 实施切片与验证顺序

1. S1 身份与浮层隔离：先失败测试覆盖前台窗口规则、自命中、普通截图/AX 排除；实现纯选择状态和 shared 编解码。建立独立 worktree。
2. S2 iOS UI：先宿主 fixture 验证无业务事件泄漏、可见预览、松手固定、父级调整、取消与安全区域；接入 feature/scene/Release gating。
3. S3 agent 闭环：接 CLI/HTTP/status/clear 和带 selection guard 的 act；测试重选竞态、离树、cell 复用、进程重启、断连、过期和非法配置；更新 schema 和公开调用说明。
4. S4 集成验收：根包 `swift test`、CLI `swift test --package-path CLI --no-parallel`、iOS App-hosted UIKit suites、Release 编译/no-op 验证、`verify.sh --local`。真实设备操作先保存 Triton status/doctor/capabilities/schema/plan 事实，再走现有测试/证据链。

真实验收至少包含两段证据：用户拖动选中按钮但按钮计数不变；agent 读取该 selection 后执行一次点击，业务计数准确加一。补浮层可见时原有定位/操作、列表复用拒绝、模态遮挡、横竖屏、键盘和 Release 无浮层截图。截图归本 space 的 screenshots；模拟交互、fixture 和真实验收分别报告。

后续 Android/Harmony/WebView provider 先明确维护权限与目标 SDK，按同一 selection 契约适配，不能借 iOS 验收声明跨端完成。


## 2026-10-15 已实施契约与经验

用户同意后已在 SP-201 独立 worktree 实现 iOS UIKit 首版，具体测试与环境限制见[实施验证](../spaces/SP-201-sdk-floating-picker/plans/20261015-implementation-validation.md)。上文建议字段不是全部 wire 字段：实际响应为 `TKSelectionResponse{ok,schemaVersion,runtimeInstanceID,revision,state,selection?,error?,outcome?,uiHealth?}`；`selection.id` 是 opaque selectionID，frame 位于 `selection.target.frame`。identity snapshot 留在 runtime 内存；没有公开 contentEpoch/deliveryState，也不宣称已发送给某个 agent。

- `state` 为 `none/valid/observeOnly/stale`，能力探测为 `available/unsupported`，UI admission 拒绝为 `unavailable`。`outcome=unknown` 不可自动重试。
- `inspect selection|clear|capabilities` 走原本地 CLI/HTTP 转发。新增子命令时父命令不能再重复声明连接选项；本轮已通过隐藏默认摘要子命令保留 `inspect --json` 语法，完整根 argv 测试验证自定义端口，不只 parse 叶子命令。
- 两层显式启用：`.inspector` feature 加 `picker.enabled`。环境只控制 picker.enabled/TTL，不能代替业务 App feature opt-in；fixture 自动插入feature是测试接入。TTL 1–300秒，非法值回退300。
- manager selection weak refs + scene/window/祖先链/版本/TTL，检查与 `performTap` 在同一个同步 MainActor turn；仅支持明确UIButton，不自动晋升文字到父级，cell 子树无可靠内容代次时仅观察。
- 所有 SDK 自有窗口通过具体protocol标记；同时检查统一窗口入口和直接枚举scene.windows的hierarchy路径，未知高层业务窗不豁免。轮廓不改原view属性。
- 生命周期还需generation fence：重新启用的配置已发布、MainActor configure 尚未执行时不能暴露旧manager；停止立即禁用动作，异步清理方法返回前等待浮层清理。
- UIKit 测试用前台轻量宿主，避免hostless connectedScenes为空；宿主不链接SDK，避免静态SDK同时进入App/tests导致重复类型。嵌套Swift Testing suite过滤必须确认实际命中数量。Release测试仅ENABLE_TESTABILITY不代表启用runtime。
- UIHealth拒绝必须匹配每条请求的typed DTO，保留原错误码和unknown/not_started；不能让CLI仅得到JSON解析失败。旧JSON无新增可选字段仍可解码。

未增加外部运行依赖。跨端、SwiftUI虚拟节点、DOM provider与多场景真实设备矩阵保留后续范围；本次不以单Simulator结果推断全部平台可用。


### 用户试用后的手势修订

旧版采用“固定圆球 + 移动准星 + 菜单切换移动模式”，用户试用指出不符合拖球预期。当前以直接拖动实时预览并选取、长按拖动移位替代该方案。验证必须覆盖原生 recognizer 的真实触摸顺序、实际圆球位置变化、选取后归位和业务零点击；直接调用 controller helper 的测试只能证明状态逻辑，不能证明手势体验。初版 HTML 原型仅保留历史设计，不能作为当前原生手势验收证据。

用户进一步指出拖动中必须明确看到命中控件。交互以直接拖动实时预览为主路径，长按拖动负责入口移位；候选框、类型/名称和“松手选中”同步更新，移出目标立即清除候选框，松手才提交selection。前一轮“普通拖动只移动”已被替代，不能让默认拖动路径缺少目标反馈。


### 样式与反馈位置（初版菜单样式已由罗盘替代）

采用深色表面与单一青色强调，44pt圆形入口使用取景图标和轻阴影；候选框8pt圆角，提示12pt圆角，控件名称独立第二行。菜单保持父级/清除两项，图标与文字同层级。拖动提示与圆球至少留出间距；顶部空间不足时翻到下方，窄屏约束于安全区域。真实UIKit窗口测试同时验证上缘、中央和下缘不与圆球相交。样式不改变直接拖选/长按移位和CLI契约。


### 十字准星与密集区域辅助轮廓

拖选时同一个44pt触摸载体去掉圆底、边框和图标，显示十字与中心小环；取消/松手恢复原样，长按移位保持圆球。命中对象向上最多5级寻找至少4个可见控件的区域，最多绘制48个控件框；每级遍历预算240、深度8。辅助CAShapeLayer放在SDK浮层，使用低对比虚线，当前目标仍用实线高亮；裁剪到可见祖先/窗口，过滤隐藏对象，不修改业务layer。离开目标、松手、取消、停用均清空辅助path；这不是给业务控件永久添加调试边框。


节点菜单支持连续向父级遍历：点击“选择父级”只更新selection和轮廓，菜单保持展开；再次轻点圆球或开始拖动收起。清除标记仍收起菜单。避免每选一层都重新打开菜单。


### 四向层级导航（层级语义保留，布局与子级策略由后续优化替代）

菜单增加父级、子级、前一同级、后一同级，切换后保持展开。子级选第一个可见可选子视图，同级按subviews顺序前后查找，跳过不可见/被遮挡节点，不循环；左右不是屏幕几何方向。无selection或stale时禁用导航，无对应候选时单独禁用。每次成功导航经过既有可见性/身份校验并生成新revision；失败不改变标记。菜单为48pt高横向工具条，按选中框/名称提示/圆球的位置挑选低遮挡区域。


用户指出五行菜单遮挡目标。当前改为横向五按钮工具条，默认靠屏幕底边，目标靠底时避到顶部或目标上下空区；切换节点即时重算。选中标签同时显示类型与名称。无法完全避让的全屏容器采用最小重叠区域，不能承诺所有满屏目标零遮挡。


### 方向罗盘（2026-10-16，替代横向工具条）

用户确认四向操作使用空间一致的罗盘。布局上父级、下子级、左前同级、右后同级；中心仅收起导航，清除标记放在罗盘下方独立按钮，避免把清除当确认。各触摸区最少44pt；未选/不可达方向置灰，导航保持打开。148×196pt面板只给按钮绘制背景，透明角落透传；根据目标、名称提示和浮球在四角及目标上下挑选低遮挡位置。全屏目标无法保证零遮挡。横向工具条的验证作为历史保留。


### 连续选取体验优化（2026-10-16，已实施）

罗盘展开后保留位置；当前区域无重叠时不重新寻找“最佳角落”，发生重叠且新位置减少至少 968pt² 遮挡时才避让，旋转越界时重新放置。这一迟滞避免微小标签变化或全屏父级导致按钮来回跳动。成功拖选松手自动展开，中心收起保留标记，清除独立；左右标题改为前同级/后同级。

父级导航成功后记录弱父子关系及身份快照，向下优先返回刚才节点；记忆上限128条，不持有业务UIView。隐藏、遮挡、离树、换父级或身份变化均回退首个有效子节点；直接重新选择或clear清空路径。最初rawHit离开窗口时，后续显式导航使用当前有效节点作为rawHit，不放宽guarded action校验。

拖动时显示128×96pt、2倍的局部放大镜，带命中点十字和目标边界；仅渲染权威业务窗口，避免浮层递归，非目标变化刷新上限15Hz。镜头优先位于手指上方，顶部不足则下翻；名称放镜头外并避开手指，极短窗口优先保留文字。松手、取消、失去候选、场景失活时清空图像，不持久缓存或上传。当前CALayer截图只承诺普通UIKit内容，视频、Metal、远程WebView渲染内容未实测，不承诺放大镜完整还原这些表面。

密集区域在候选稳定且停留0.25秒、位移不超过12pt后才出现辅助线；移动超过阈值立即清除并重新计时。候选变更触发UISelectionFeedbackGenerator，最短间隔80ms，同候选刷新不重复触发。模拟器验证触发条件，触感强度仍需真机体验。

经验：连续操作时布局稳定性本身属于交互契约，不能每次节点更新都重排；父子导航需保留用户刚走过的路径，弱引用仍须结合父子关系、身份和可见性验证。拖动中的放大反馈须实际抓取中间态，松手截图不能证明拖动体验。测试与截图见[验证记录](../spaces/SP-201-sdk-floating-picker/plans/20261015-implementation-validation.md)。


### 完整回看检查点（2026-10-16）

| 触发场景 | 根因/边界 | 下次可执行检查 | 本轮证据 |
| --- | --- | --- | --- |
| 拖动看不出选中、圆球不跟手 | 固定入口与独立准星割裂手势预期 | 用真实pan检查圆球位置/候选反馈，松手后计数仍0；另抓拖动中截图 | UIKit85、XCTest1、拖动hold截图 |
| 连续导航需反复开菜单、挡住控件、按钮跳位 | 导航被当一次性菜单且每次重排 | 菜单保持、目标可见、无遮挡位置不变，父子往返恢复原节点 | stableCompass与真实父子往返 |
| 弱节点仍存在却指向变化内容 | 对象身份不等同业务身份 | identity/父子/window/可见性复核，cell无epoch仅观察 | session tests及CLI guard拒绝 |
| 选择后CLI先于零点击断言执行 | selection有效不是跨进程交接信号 | 等XCTest ready attachment再执行CLI动作，业务后置独立确认 | verify-ios-picker-fixture.py 7步 |
| 测试结束后构建看似卡住 | Xcode失败后simctl诊断仍占执行通道 | xcode status核对PID和日志，原进程退出后才跑下一构建 | 行为红测诊断清理后绿测 |
| 后续文档仍写旧交互、截图链接无法随提交复现 | 只追加过程记录且screenshots被忽略 | 当前入口归一、旧方案标历史，核对staged截图与最终源码摘要 | 本轮整理提交与closeout-summary |

以上经验更新原入口并由治理skill/public回归skill链接复用，不新增repo-wide AGENTS规则。最新体验仍待用户验收，真机触感/特殊渲染/多scene矩阵保留明确边界。
