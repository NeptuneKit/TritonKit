# SP-201 实施与验收记录

## 候选与范围

- 用户明确授权“实现并测试”；候选在同级 `TritonKit-worktrees/SP-201-sdk-floating-picker`，分支 `feat/SP-201-sdk-floating-picker`，基线 `dd613a99`。未提交、合并、推送、发布或替换用户已安装 CLI。
- 实现层：iOS embedded UIKit、shared DTO、CLI、现有 HTTP/WebSocket 转发；Web 仅原设计稿。
- 首版：单个有界标记、拖选/取消/父级/清除/移动入口、精确 UIButton tap、进程/版本/可见性校验。文字和复用 cell 仅观察；SwiftUI 虚拟节点、WKWebView DOM、Android、Harmony 未实现。
- 普通业务观察排除 SDK 自有浮层，真实系统/业务高层窗仍参与遮挡保护；轮廓独立绘制，不修改目标属性。

## 测试结果

最终候选已冻结，门禁与截图结果如下。原始本机日志在工作区 `.build/sp201-evidence/`；失败记录不计为通过。

- 根包 `swift test`：runtime 88项 + shared 291项 = 379项通过；macOS不含条件编译掉的UIKit tests。
- CLI：最终候选全量1437项通过，含8组选择器CLI、完整argv和schema/public command snapshot。
- iOS App-hosted：最终78项通过，包含实际UIKit前台窗口、既有属性高亮回归、选择/命中/overlay隔离、generation快速启停与健康错误响应。
- Release：7项通过（包括显式启用仍start=false、disconnected、无manager）；仅开启ENABLE_TESTABILITY，不定义runtime compile flag。健康handler忙碌测试在Release提前返回，不宣称该路径执行。
- 真实触摸：iPhone 17e / iOS 27.0 专用 Simulator，XCTest 从浮点拖到按钮；实际选中 UILabel 时，通过可见菜单显式选父级 UIButton。拖选计数 0；独立候选 CLI 读取 selection 并执行 guarded tap，XCTest 确认计数 1 且保持 1。不是直接调用 UI controller 代替触摸。
- CocoaPods：原始 `pod lib lint --allow-warnings --skip-tests` 失败，原因是本机 Xcode 27.1 不接受 podspec 原有 iOS 13 部署目标。保留 lint workspace 后用 `triton xcode build` 一次性 `IPHONEOS_DEPLOYMENT_TARGET=15.0` 编译同一单模块源码成功；不等价于原 lint 通过，不修改产品最低版本。

截图：[拖选后0次](../screenshots/20261015-picker-ios-selected-v02.png)、[CLI点击后1次](../screenshots/20261015-picker-ios-clicked-v02.png)。截图来自最终通过的XCTest附件；另有[普通截图不含浮层](../screenshots/20261015-picker-ios-business-only-v01.png)，已打开核对。

## 可复跑入口

先构建候选 CLI，使用独立测试服务端口 19422，避免替换已运行的 19421 服务；该端口只用于本轮验证，产品默认仍为 19421。明确准备并绑定自己的 Simulator。设备操作前保存 Triton status/doctor/capabilities/schema/plan 事实。

从仓库根目录生成包外测试工程（需要 XcodeGen）：

```sh
TRITON_PICKER_REPO="$PWD" SP201_WAIT_FOR_AGENT=1 xcodegen generate \
  --spec Examples/TritonKitTestFixture/picker-validation.json \
  --project ../.sp201-validation-host
```

`RuntimeValidation` scheme 是不链接 SDK 的轻量宿主加 SDK tests；`PickerGesture` scheme 是真实 fixture App 加 XCTest UI 触摸测试。前者避免 app/test 双份静态 SDK 类型互相影响。需要 Release 时使用 `ENABLE_TESTABILITY=YES ONLY_ACTIVE_ARCH=YES`，不增加 runtime compile flag。

真实闭环时，先启动候选 `triton serve --port 19422`，运行 `PickerGesture` scheme。另一个进程执行：

```sh
python3 docs-linhay/scripts/verify-ios-picker-fixture.py \
  --triton <本候选triton绝对路径> --simulator <专用UDID> \
  --port 19422 --xcode-events <当前测试JSONL路径> --output .build/sp201-evidence/fixture-contract
```

该脚本只接受明确 Simulator 上的公开测试 App，等待 XCTest 选中增量按钮，检查零次点击、普通 AX/截图排除浮层、错误版本和错误进程拒绝，再执行一次 guarded tap。业务成功以 XCTest 后置断言为准。默认无 `SP201_WAIT_FOR_AGENT=1` 时只验拖选，不等待外部 agent。

## 失败、修复与证据边界

1. hostless SwiftPM UIKit tests 没有前台 App，出现窗口为空，不能算 UIKit 通过；切换真实前台宿主后通过。嵌套 Swift Testing suite 过滤需使用外层 `TKUIKitWindowTests`，零命中不算通过。
2. Inspect 父子命令重名连接参数被父层消费，子命令访问默认端口；改为无参数分发组和默认摘要子命令，补完整根 argv 测试。现 `inspect selection --port 19422` 已实测到正确服务。
3. 新 TKRequestType 路由、throwing 测试宏、schema usage/recovery taxonomy/public command snapshot 的失败均已按契约修正，保留原通用断言。
4. queued start-stop-start 曾可在 configure 前读到旧 manager；新增 generation 绑定与4项测试。异步停止入口等待 picker MainActor 清理。
5. UIHealth admission 原通用错误无法解码成 selection DTO；三种 selection 请求改为 typed error，保留 unknown/not_started 与健康信息，禁止因超时自动重复动作。
6. 宿主更换曾把 SDK 同时链接进 App 与 tests，触发重复类型和挂起；回到不链接 SDK 的轻量宿主。可复跑 spec 固化这一结构。
7. `triton sim swipe` 返回 `host_action_failed: no chrome bundle covers udid`，本机没有可开启的 Simulator.app。Triton boot/schema 不覆盖 UI chrome 修复，尝试 `open` 失败后，改由 `triton xcode test` 驱动 XCTest 真触摸；未绕过为模拟调用。
8. `triton xcresult` 目前仅 summary/failures，不导出附件；记录此未覆盖后使用 `xcrun xcresulttool export attachments` 提取通过测试的截图。
9. XCTest 结束会终止 App；事后 CLI verify 得到 target_not_found，不能算业务验证失败或成功。后置业务断言在 App 仍运行时由 XCTest 完成，复跑脚本在测试等待期间执行。
10. 门禁期间曾发生源码修改使编译读到旧 shared module 与新 runtime；该次失败废弃，冻结实现后重新运行，不把混合候选构建算通过。

## 未覆盖与限制

- 真机、多 scene 实机切换、键盘覆盖及横竖屏真实手势矩阵尚未做；安全区域/旋转取消有 UIKit 测试，不能替代以上设备验收。
- 中心点被遮挡即保守拒绝；无业务内容代次的复用 cell 永远仅观察。UIControl callback 是请求已分发，业务成功仍要后置验证。
- 本轮在独立 worktree 完成实现/验证，尚未主线集成或发布；原主仓 SP-193 未动。


## 最终交付检查

- 最终XCTest触摸1项通过，独立CLI脚本7步通过：零次业务点击、AX排除、普通截图、错误revision拒绝、错误runtime拒绝、拒绝后仍零次、有效guarded tap。业务后置由XCTest确认准确1次。
- 本地总门禁 `TRITON_VERIFY_XCODE=0 verify.sh --local` 通过：根包、Release CLI构建与smoke、Harmony fake host smoke、iOS runtime observe smoke、文档结构、差异检查。只关闭门禁内未指定专用设备的重复Xcode步骤，替代证据为本轮显式设备78项+Release7项+真实手势1项。
- [候选文件摘要与结果](./20261015-runtime-evidence/candidate-summary.json)、[CLI脚本结果](./20261015-runtime-evidence/summary.json)。原始xcresult和日志保留在本机独立测试目录及`.build/sp201-evidence`；不提交庞大临时构建产物。
- 经验/接入说明已写回设计、iOS指南、public skills、经验索引、space索引及memory。未提交/合并/发布；主仓只同步本space文档进展，产品代码保留独立worktree。


### 用户试用交接

用户随后要求安装体验。已重新启动专用 `Triton-SP201-Picker`、安装最终Debug PickerFixture.app并启用picker，候选服务保留127.0.0.1:19422。已进入Picker Fixture，界面显示Connected、计数0与圆点。新Xcode使用 **Device Hub（com.apple.dt.Devices）** 展示模拟器，已通过其侧栏选中设备并截图核对；此前找不到传统Simulator.app仅说明旧入口不可用，不能推断没有可见交互窗口。用户正在试用期间保留服务与设备运行，不自动关闭。


## 用户反馈修订：原生手势与圆球跟手

- 用户反馈原版圆球固定、只有准星移动，菜单再切移动模式不自然。改为普通 pan 移位并停留，长按 0.4 秒拖动选取、圆球半透明跟手，松手标记并回到停靠位置；轻点菜单仅保留父级/清除。取消独立准星，缩小提示标签。影响仅 embedded UIKit 交互与对应测试/文档，selection CLI/HTTP 契约不变。
- TDD：新增移位/取消/跟手/归位断言先编译失败；实现后真实 App-hosted `TKUIKitWindowTests` 73 项全过（`picker-gesture-revision-green-v2.xcresult`）。
- 更新后的真实 XCTest 验证快速拖动确实移动球、长按拖动选取、松手归位、父级菜单与业务计数保持0；CLI执行一次后计数1且保持。最终 `picker-gesture-revision-real-v2.xcresult` 1/1通过，独立CLI脚本7步通过。
- 首次重跑遇到测试交接竞态：selection有效后CLI立即执行，早于XCTest最后一个零点击断言。原始日志证明CLI动作先发生；等待XCTest的 ready attachment 后重跑通过。复跑脚本新增 `--xcode-events`，只在对应测试发出ready后开始动作；不得将首次失败解释为手势误触，也不得删除原零点击断言。
- 本轮 `TRITON_VERIFY_XCODE=0 verify.sh --local` 通过；Xcode重复步骤由明确专用模拟器的73项及真实手势1项替代。Release no-op 沿用首版7项证据，本次未重跑Release测试。原型HTML标注为历史设计，不能用初版14项浏览器测试证明当前手势。
- 新Debug产物已重新安装并启动，Device Hub可见Connected、Picker Clicks: 0、新手势提示和圆球；保留设备及127.0.0.1:19422服务供用户试用。仍待用户体验验收，未提交、集成或发布。


## 实时预览修订（替代上一轮手势映射）

用户要求拖动中实时看到是否命中。当前直接 pan 拖动实时预览并松手选中；long press 0.4秒后拖动仅移位。圆球跟手；候选框、类型/名称、“松手选中”即时更新，移出目标清框，松手前不发布selection。前一轮普通拖动只移位的映射已退出当前交互。

新增断言覆盖拖动中边框可见、包含命中点、预览提示、未提交selection、移出清框及再次移入恢复。失败测试72通过/1失败；实现后UIKit73项全过。真实XCTest改为长按移位、快速拖选；1项及CLI7步闭环通过。本轮本地总门禁通过；未重复Release测试，原有Release no-op证据不变。预览中间态由真实UIKit窗口测试验证，XCTest验证真实手势映射及松手后结果。

证据：本机 `.build/sp201-evidence/picker-live-preview-{red,green,real}.jsonl`、`live-preview-contract/summary.json`、`live-preview-local-gate.log`；相应xcresult在同级`.sp201-validation-host`。重新安装Debug fixture供用户继续体验，待用户验收，未提交或发布。


## 样式优化

深色圆球配青色取景图标和轻阴影；统一圆角边框、两行控件提示、带图标菜单。保持44pt触摸区域与既定手势。新增上缘/中央/下缘提示避让测试，旧版73通过/1失败；修复后UIKit74项全过，真实手势1项及CLI7步闭环通过，本地总门禁通过。

截图已导出并目视检查：[已选样式](../screenshots/20261015-picker-style-selected-v01.png)。Triton xcresult未覆盖附件导出，沿用已记录的xcresulttool fallback。证据为 `.build/sp201-evidence/picker-style-{red,green,real}.jsonl`、`style-contract/summary.json` 和 `style-local-gate.log`。覆盖安装后继续用户试用；未做新的Release/真机/完整深色外观矩阵，未提交或发布。


## 十字准星与密集控件辅助层

拖选时圆球切为透明底十字准星，结束恢复；密集区域使用SDK浮层的临时CAShapeLayer虚线描边，当前目标仍实线高亮，最多48框。业务layer不变，结束/取消清空path。新增测试覆盖准星外观切换、密集区域辅助path存在及清理、业务layer不变、移位模式不显示辅助层。

失败测试实际报告75项中2个issues，但xcode诊断采集未及时退出；误在诊断进程仍存活时开启首轮green，该轮不作为最终证据。已终止本任务残留进程，随后严格串行重跑 `picker-crosshair-serial.xcresult` 75项全过；真实 `picker-crosshair-real.xcresult` 1项和CLI7步闭环通过；local gate通过。中间态由UIKit测试验证，尚无拖动中截图证据；用户试用为体验验收。

经验：测试输出结束不代表xcodebuild进程结束，同一DerivedData及设备必须确认原进程退出后再构建。临时辅助层放SDK浮层，既能清理又不污染业务截图/层级。新Debug已覆盖安装，保持专用服务供试用；未提交/集成/发布。


## 选择节点后菜单保持展开

按用户反馈，选择父级仅更新目标与轮廓，不再关闭菜单；允许连续逐级选择，再次点圆球主动关闭。新增真实UIKit两次向上选择及菜单显隐断言，先75通过/1失败，修复后76项通过；XCTest补选择父级后菜单仍可点、点圆球关闭，真实手势1项及CLI7步闭环通过。本地门禁通过，新Debug覆盖安装。证据 `.build/sp201-evidence/picker-menu-{red,green,real}.jsonl`、`menu-contract/summary.json`、`menu-local-gate.log`。当前仍未提交/集成/发布。


## 四向节点导航

新增父级、子级、前一同级、后一同级，菜单保持打开，无候选按钮置灰。同级按subviews顺序，跳过隐藏/遮挡节点且不循环，子级取首个可见可选节点；每次成功导航重新提交selection/revision，失败保持原标记。新增方向/边界/隐藏跳过/清除后不可导航测试先编译失败，再77项UIKit通过。真实XCTest验证父→子→父及菜单持续可点，1项与CLI7步闭环通过；local gate通过，Debug覆盖安装。左右同级的精确目标切换由UIKit测试覆盖，XCTest验证菜单呈现和父子切换。证据 `.build/sp201-evidence/picker-navigation-{red,green,real}.jsonl`、`navigation-contract/summary.json`、`navigation-local-gate.log`。未提交/集成/发布。


## 菜单遮挡修复

五行竖向菜单改为48pt横向工具条（父级/子级/前项/后项/清除），仍保持完整accessibility名称。按选框、名称提示、圆球选择重叠最少位置，默认底部；切换目标立即重算。标签显示控件名称，便于识别当前目标。满屏容器不能保证零重叠。

新增上/中/下目标不与菜单相交、工具条高度、边界及保持展开断言；失败测试78项4issues，诊断采集迟迟不退出后停止本任务进程；修复后UIKit78项通过。真实XCTest前几轮由于新增多行标签的正则误将UIButtonLabel当UIButton或无法匹配换行而失败；改用caption标识符读取完整label并按空白分词验证精确类名，未放宽实际目标。最终 `picker-toolbar-real-v4.xcresult` 1项通过，CLI7步闭环通过；截图目视验证工具条与目标分离。

[工具条避让截图](../screenshots/20261015-picker-toolbar-avoids-selection-v01.png)。local gate在工具条布局改动后通过；后续仅caption accessibility标识与XCTest匹配改动由最终真实测试验证。原始证据 `.build/sp201-evidence/picker-toolbar-green.jsonl`、`picker-toolbar-real-v4.jsonl`、`toolbar-contract-v4/summary.json`。Debug已覆盖安装；未提交/集成/发布。


## 2026-10-16 方向罗盘

用户确认后，将横向按钮排列改成方向罗盘：上父级/下子级/左前项/右后项，中心收起，清除独立。菜单保持展开/禁用不可达方向，44pt最小触摸区，透明角落透传。四角及目标上下选最小遮挡位置。

新增空间方向、触摸尺寸、透明角落和中心收起测试，并保留目标避让/连续导航断言；red 3项失败，green UIKit79项通过。真实手势1项和CLI7步闭环通过，本地总门禁通过。[罗盘截图](../screenshots/20261016-picker-compass-selected-v01.png)已目视核对。测试过程中发现昨日专用server已退出，确认19422无监听后恢复本任务服务，未触碰其他服务。Debug已覆盖安装供用户体验，未提交/集成/发布。

证据 `.build/sp201-evidence/picker-compass-{red,green,real}.jsonl`、`compass-contract/summary.json`、`compass-local-gate.log`。空间映射比横排文案更直接；方向代表节点关系，不能推断屏幕几何方向。


## 2026-10-16 连续交互优化

- 实现：罗盘位置迟滞、父子路径记忆、局部放大镜、停留辅助框、候选变更触感触发、松手自动展开、前后同级标题。selection wire协议与业务动作保护不变。
- TDD：首次编译红测证明时钟/反馈注入尚不存在；加入测试接口后行为红测85项中6项失败、10 issues，覆盖路径回返、离树回退、立即辅助框、罗盘跳位、放大镜缺失。Xcode随后停在失败诊断，保存xcode status后停止本次simctl diagnose进程，确认原任务退出再启动绿测。没有并发写同一DerivedData。
- UIKit：`picker-ux-green.xcresult` 85/85通过，无跳过。覆盖放大镜安全区/手指避让/触摸透传/取消清图、稳定罗盘及遮挡避让、辅助框延迟、重复刷新不触发触感、父子记忆与隐藏/离树/身份变化/遮挡回退及弱引用释放。
- 真正触摸：`picker-ux-real.xcresult` 1/1通过；为补拖动中截图，加入3秒hold并重跑 `picker-ux-capture.xcresult` 1/1通过。验证快速拖选、长按移动、松手自动罗盘、父→子返回原节点、罗盘位置稳定、业务零点击。两个执行是同一场景复跑，不累加为两个独立验收场景。
- CLI：最终 `ux-capture-contract/summary.json` 7步通过，旧版本/错误runtime拒绝，单次guarded tap后计数恰好1。
- 截图：通过 `triton sim screenshot --simulator <专用UDID> --output ... --json` 在真实拖动hold期间采集[放大镜](../screenshots/20261016-picker-magnifier-drag-v01.png)；[稳定罗盘](../screenshots/20261016-picker-stable-compass-selected-v01.png)来自XCTest附件。两图均已目视检查。当前 `triton xcresult` schema仅summary/failures，附件导出沿用 `xcrun xcresulttool export attachments --path ../.sp201-validation-host/picker-ux-capture.xcresult --output-path .build/sp201-evidence/ux-attachments` 的已记录fallback。
- 本地门禁：`TRITON_VERIFY_XCODE=0 docs-linhay/scripts/verify.sh --local`通过；通用Xcode构建由专用UIKit与手势测试覆盖。当前轮未重复Release或真机验证，触感强度和视频/Metal/WebView镜头渲染未验收。
- 运行：原127.0.0.1:19422服务不可达，检查监听后仅启动本任务loopback服务（另一地址监听保持不变）；最终Debug安装/启动成功，再进入Picker Fixture，runtime确认Connected、Picker Clicks: 0，保持服务供试用。
- 证据前缀 `.build/sp201-evidence/picker-ux-*.jsonl`、`ux-*.json`、`ux-local-gate.log`；xcresult在同级`.sp201-validation-host`。经验已更新原设计；未提交/集成/发布，待用户体验验收。
