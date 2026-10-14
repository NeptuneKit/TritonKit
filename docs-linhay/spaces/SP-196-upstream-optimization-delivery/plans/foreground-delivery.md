# Foreground action target 正确性

状态：实现、独立窗口策略与真实应用宿主验收完成。主控Hosted第6轮56项 / 8 suites全部通过，0失败、0跳过，xcodebuild退出0且xcresult解析为Passed；Foreground 5项全部进入场景并通过。

影响层：iOS embedded runtime 的 input / semantic target resolution 与现有 WebView mutation provider。没有更改公开模型、CLI、HTTP 或 Web 控制面。

## BDD 与实现

1. Given app 已有 UIWindowScene，When 所有 scene 为 background / foregroundInactive，Then 不从 UIApplication 或 registry 的无scene窗口回退。只有 foregroundActive 的真实窗口进入候选。
2. Given 完全无 UIWindowScene 的 hostless runner，Then 可使用可见、无scene的 UIApplication / registry 窗口；带后台scene的registry对象不借此重返动作面。
3. Given 同时有可见业务窗口，When 较高 windowLevel 的非key业务窗口出现，Then 优先绑定该窗口；同level优先key，再按稳定来源顺序排序。只排除下述已实测、UIKit定义的精确输入overlay组合。
4. Given 模态完成真实 presentation 且底层旧OID仍挂在同一窗口，When input / semantic / collection coordinate fallback，Then 底层OID/控件不能被操作。只允许当前最上层presented root的子树；dismiss completion且挂载关系消失后恢复原目标。
5. Given detached/hidden/后台窗口OID，When text / semantic 直接解析或nearestSuperview路径，Then 使用同一个前景helper拒绝。
6. Given 真实UITextField focus且高层keyboard window出现，When 连续OID clear，Then 该系统输入overlay不抢业务action root，原字段可清空；未知overlay继续保守阻断。
7. Given 实际 provider 可枚举的 WKWebView 仍在模态底层，When tap / focus / formInput / allowlisted bridge mutation，Then 现有错误码静态拒绝且 DOM 无副作用；read-only list 保持可观察，真实 dismiss 后 formInput 恢复。

新 `TKRuntimeForegroundTargets.swift` 承接 `keyWindows()` / `resolveView()`，提供内部 `runtimeForegroundTargetFailure(for:)` 与 `runtimeForegroundActionRoot(in:)`。场景判断与稳定排序抽成不依赖 UIKit 的事实策略；不新增 transport schema。

InputActions 的以下路径接入同一约束：OID/坐标view、OID文本responder、坐标文本ancestor、隐式firstResponder、semantic control、tabBar/table/menu搜索。原直接读取control的OID绕过分支已去除。主控授权的 CollectionActions 改动仅限 collectionCellContaining 循环的一行前景过滤，selection状态/回调逻辑不变。

仅有modal时约束为presented子树；无modal时保留正常window层的navigation/tab chrome及原UIKit窗口夹具。pending presentation/dismissal不强行load view，也不提前解锁底层。

## 验证事实

红测：基于旧窗口策略的事实适配初版运行5项场景，5项失败（后台/回退/高层nonkey/hostless/稳定次序）。正确策略及生产hooks完成后：

```sh
swift test --scratch-path .build/sp196-webview --no-parallel --filter 'TKRuntimeForegroundWindowPolicyTests|TKRuntimeInputActionTargetSafetyTests'
```

窗口策略独立复跑通过6项 / 2 suites。完成 WebView 写入口接入后的联合 focused 回归为：

```sh
swift test --scratch-path .build/sp196-webview --no-parallel --filter 'TKRuntimeForegroundWindowPolicyTests|TKRuntimeWebView(FormInput|ControlledInput|Snapshot)Tests|TKRuntimeInputActionTargetSafetyTests'
```

通过33项 / 5 suites；`git diff --check`通过。随后仅完成下述 UIKit observation fallback 与夹具断言收紧，macOS 无法编译/执行此条件代码；这些是当时的macOS结果，不计为UIKit通过；最终真实结果见下述Hosted6。

UIKit suite为同一个 process-wide 串行父suite `TKUIKitWindowTests` 下的 `TKRuntimeForegroundTargetTests`，共5项：detached文本/semantic绕过、真实keyboard出现后的连续focus→clear、真实高层nonkey窗口、真实overFullScreen模态+collection fallback+dismiss恢复，以及真实WKWebView modal下四条producer mutation拒绝/dismiss恢复。模态fixture等待 UIKit 真实completion，并断言modal实际window挂载、旧目标仍同window；超时失败，绝不以等待时长当验收。collection fixture先证明真实cell可匹配，再验证modal后拒绝。WebView fixture强制要求实际 provider candidate存在，随后无条件调用tap/focus/formInput/bridge producer并断言静态前景拒绝，验证字段及点击计数不变，dismiss后真实formInput和DOM读回成功。

主控授权对 `TKRuntimeStateSnapshot.swift` 的 `allRuntimeWindows()` 只作窄改动：没有任何 UIWindowScene 时使用 UIApplication.shared.windows；有scene时保持原有全scene观察枚举。registry仅用于既有hostless动作fixture fallback，不扩展观察枚举。mutation eligibility另由严格前景helper判断。

这些UIKit项未在本agent的macOS运行中执行；真实foregroundActive/background生命周期也未通过操作宿主app做端到端转换。主控已使用owned iOS destination完成Hosted6，真实通过不替代后台scene生命周期端到端转换。

## 明确边界

- `keyWindows()`影响既有观察入口的排序/候选，前景root约束主要用于上述input/semantic动作。下层internal dispatch helpers仍要求调用方先完成target解析，不声称每个低层函数都独立防护。
- WebView的focused text insertion、focused delete、tap/click、focus、formInput、allowlisted bridge共6处写入口已复用同一helper；bridge在安装页面bridge前校验。失败仅返回静态错误，不泄露文本或页面信息。WebView枚举、current/metadata、snapshot/wait/events等只读入口保留既有观察范围。
- LegacyInspection的属性patch是独立编辑面，本分片未更改。
- 不宣称完整应用生命周期、任意多scene物理显示屏或客户工程的前景策略已真实验收。

没有操作设备/服务，没有提交或推送；InputActions由1496行降至1449行附近。


## 真实 iOS 第一轮诊断

主控实际包测试的55项中，真实WKWebView表单5项全部通过；窗口suite的43项在创建夹具后的`keyWindows().first === window`前置要求失败，runtime返回nil，尚未进入模态或高层窗口行为断言。证据位于`.triton/sp196-validation/ios-runtime-1.jsonl`及`ios-runtime-1.xcresult`。现有日志未记录activationState，不能把推断写成已证实原因。

主控授权仅改fixture support：移除foregroundInactive fallback，要求真实foregroundActive；若完全无scene，仍构造实际UIWindow，并在注册后重新检查runtime前景候选。失败诊断包含appState、scene数量与activation rawValue、visible window数量以及fixture所属scene/hidden/alpha/interaction/key/windowLevel，均不含私有identifier。没有waiting、activation mock、测试专用生产override或生产策略放宽。

主控已生成独立 `.triton/sp196-validation/hosted/SP196RuntimeHost.xcodeproj` / `RuntimeValidation` scheme，将由真实UIApplication+SceneDelegate前景宿主加载实际测试文件并串行复验。这是当前推荐实测方式；本agent不操作设备。最终验收已迁移到worktree同级的独立host工程，详见Hosted6结果。


Hosted首次编译暴露fixture诊断的Swift Testing类型错误：字符串字面量可隐式成为Comment，但动态String拼接不能直接传给`#require`。已核对当前iPhoneSimulator `Testing.swiftinterface` 的 `Comment.init(rawValue: String)`，两处诊断使用显式Comment包装，predicate不变。该轮编译失败不计入行为验证；后续hosted需重新执行。


## Hosted 第二轮：键盘 overlay 回归

真实宿主已确认 `appState=0`、一个 `activationState=0` 的scene；第一项深层collection观察通过，第二项coordinate UIKeyInput focus通过并显示键盘，紧接smart tap的夹具失败：实际最高窗口为 `UITextEffectsWindow`。同轮窗口suite41项失败不是scene生命周期问题，也不是后续modal fixture导致。旧level排序把系统输入overlay当作业务动作root，存在连续focus→input被堵的生产风险。

新增真实UITextField keyboard窗口场景，要求更高可见窗口真实存在后验证连续OID clear；当时生产策略预期红；最终Hosted6已进入该场景并通过，不能用夹具清理替代此场景。fixture候选诊断补充window/root class、level/key/hidden/interaction、iOS15+公开Swift `canBecomeKey` 与fixture匹配布尔值，随后主控已取得实际组合并完成最小修复验收。所有共享window夹具通过RuntimeTestWindow在原有hide teardown前调用公开endEditing(true)，避免跨测试保留first responder；不修改测试期间政策。当时生产暂不改；最终仅按精确实测组合修复，未知窗口不按substring盲排。

Hosted第三轮仅编译失败：ObjC header中的canBecomeKeyWindow导入Swift时名称为canBecomeKey，diagnostic已按实际Swift编译诊断修正；该编译失败不计行为红测。


## 键盘窗口的最小生产修复

Hosted第四轮实测公开事实：`UITextEffectsWindow` 的root为 `UITrackingElementWindowController`、level=1、key=false、interaction=true、canBecomeKey=true。因此不能用root=nil、不可key或所有非key窗口过滤；这些条件也会误伤业务window。新keyboard测试仍被遗留overlay挡在fixture创建处，未进入自身focus→clear，不将其后续断言记为已执行红测。

主控授权后仅识别这个精确window/root名称组合，同时要求两者的类定义Bundle URL与UIKit `UIWindow`定义Bundle一致。读取类名及Bundle元数据，不实例化/调用私有类；不同名称、不同root、缺失root、非UIKit来源或未知高层窗口继续作为保守候选。未知高层窗口仍可拒绝底层动作，custom非key alert保留优先级，sceneactive要求未放宽。这一系统组合只在本机Xcode27/iOS27确认；其他OS的新组合需实际证据，不能substring扩张。

macOS pure策略新增2项：身份/来源严格匹配，以及known overlay不抢业务root但unknown/business高层继续优先。先录得7 tests中3 issues红测，随后7 tests全通过：`.build/sp196-keyboard-red.log` / `.build/sp196-keyboard-green.log`；diff检查通过。真实foreground UIKit suite现5项（新增keyboard连续动作），最终行为已由主控Hosted6确认。


Hosted第五轮编译/链接完成后在Xcode调度阶段超时：日志无`Test run started`，最后为Resolve Package Graph，HTTP/CLI返回`host_command_timeout`（240秒），stderr为BUILD INTERRUPTED。此轮既不算行为通过，也不算行为失败；真实suite需要主控串行重试。源码保持冻结。


## 最终真实验收：Hosted6

主控将测试工程移至worktree同级的独立 `.sp196-validation-host/`，避免嵌套local package的Xcode graph反馈；使用 `RuntimeValidation` scheme、真实UIApplication/SceneDelegate、专用 `Triton-SP196-Validation` iPhone 17 / iOS27.0 Simulator（arm64）。证据：worktree同级 `.sp196-validation-host/ios-hosted-6.jsonl` 与 fresh `ios-hosted-6.xcresult`。

- xcodebuild退出0，xcresult解析Passed：56 tests / 8 suites，0失败、0跳过。Swift Testing运行12.332秒（xcresult调度区间32.021秒，两个口径不同）。
- `TKRuntimeForegroundTargetTests` 5项通过，suite 2.170秒：detached OID、实际keyboard高层window出现后的focus→clear（0.228秒）、真实高层非key业务window、真实overFullScreen modal+collection fallback+dismiss恢复、实际WebView四条producer拒绝及dismiss恢复（1.849秒）。
- `TKRuntimeWebViewControlledInputUIKitTests` 5项同步全通过，其余window suites回归通过。
- Hosted1与Hosted3仅编译失败；Hosted4采集到实际窗口诊断/失败后被取消，无完整green；Hosted5编译后调度超时。它们均不计为成功，仅Hosted6作为最终真实验收。

精确UIKit输入overlay组合的OS确认仍限定本机Xcode27/iOS27。没有据此宣称未知系统overlay、其他OS的新内部组合、客户工程多scene/物理屏幕或完整后台生命周期已经验收。未知组合保持保守阻断；LegacyInspection属性patch仍为未改边界。主控负责统一README/报告/memory，本agent只写两份delivery plans，最终结果后没有继续测试、设备或源码操作。
