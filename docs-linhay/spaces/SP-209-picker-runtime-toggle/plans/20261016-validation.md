# SP-209 验证记录

> 开关/宿主菜单、选择器专用设置、自绘 SDK hub 均为历史阶段。当前方案为系统半屏 Modal，Red 记录与最终验收见文末；旧通过数不代表新 modal 验收。

## 历史候选与边界

基线main@35356c9c，独立worktree实现。未新增CLI/HTTP命令或依赖；Debug SDK API、UIKit浮层和公开fixture调试菜单。

## 测试

- Red：`swift test --filter TKSelectionAvailabilityTests`因缺少`setPickerEnabled/isPickerEnabled`编译失败，原始日志`.build/sp209-evidence/api-red.log`。
- Debug根包：291项通过，macOS不执行UIKit条件用例。
- Release选择契约：5项通过，不能开启SDK/picker。
- 真实App-hosted UIKit：89项通过，包括独立开关、重复开启不清标记、关闭立即清理、旧guard失效、不重新探测endpoint/改变delegate，以及排队start与同步开关竞态。
- 真实XCTest手势：3项通过（原拖选、初始隐藏后开启、隐藏/恢复且连接回调数及业务计数不变）。后补截图附件的两条开关用例单独复跑，数量不重复累计。
- 本地总门禁首次与非法TTL修正后复跑均通过。通用Xcode步骤使用`TRITON_VERIFY_XCODE=0`跳过，由上述真实iOS宿主/手势测试覆盖本轮UIKit改动。

## 工具与证据

先保存triton status/doctor/capabilities/schema/plan与sim/xcode状态至`.build/sp209-evidence`，构建测试通过`triton xcode test`。Triton的xcresult schema目前仅summary/failures，附件导出未覆盖，因此只读回退`xcrun xcresulttool export attachments --path <xcresult> --output-path <evidence>`。XcodeGen仅生成包目录外的fixture宿主工程。

外部工程、DerivedData与xcresult保存在同级`.sp209-validation-host`；这些产物不提交。触感、全设备/多scene矩阵和用户体验验收仍未完成，不将单模拟器证明扩大到这些范围。

## 审查发现与修复

公开TTL字段可在初始化后改成非法值。初次启动回退300秒，但运行时开启原先直接传入manager，-1被manager裁成1秒。新增真实UIKit失败用例已复现，开关路径统一回退300秒，已保留红灯日志，最终89项绿灯通过。

TTL红灯的Swift Testing已输出89项中1个预期失败，但Xcode27未结束汇总。先保存triton xcode status确认唯一属于本任务的PID63153且xctestCount=0；SIGINT未退出后SIGTERM结束该进程，保留原日志，确认idle再启动新绿灯结果目录。该次仅作为断言失败证据，不作为完整xcresult成功报告。

## 历史阶段：选择器专用 SDK 设置

撤除App.swift新增宿主菜单和连接计数，SDK设置只属于自有浮层。新增3个可配置展示开关，圆球单击打开设置，拖选松手仍罗盘；隐藏后的恢复由宿主调用API负责。

UIKit首跑因Swift Testing宏对allSatisfy keypath编译失败，改为先计算布尔值后断言；90项通过。真实UI3项通过，覆盖三开关关闭/重开保持、关闭辅助仍拖选、SDK设置隐藏后连接/业务计数不变。补审查修正长按触感与动态配置即时刷新，最终UIKit90项与本地门禁通过。

该历史阶段截图：[SDK设置](../screenshots/20261016-picker-settings-v01.png)、[关闭辅助](../screenshots/20261016-picker-settings-disabled-v01.png)、[隐藏态](../screenshots/20261016-picker-sdk-hidden-v01.png)。旧宿主菜单截图仅为历史，不代表交付。

## 历史阶段：自绘 SDK hub

用户纠正了此前仅围绕选择器堆叠菜单的设计。当前首页展示真实连接摘要，并提供连接、选择器、SDK 功能、应用、入口五路由；辅助开关放入选择器二级页面。SDK 功能仅反映宿主配置，不等同于实际平台支持或 provider 就绪；未消费的隐私配置与硬编码 SDK 版本不展示。宿主菜单仍由宿主负责。

面板打开时暂隐藏全部选择提示和罗盘，关闭恢复仍有效的选择上下文；罗盘只保留节点导航与清除。隐藏入口只从入口页经确认执行，取消不改变状态，接受后旧 selection guard 失效；宿主 API 唤回保持独立，不重启 SDK 连接。

### 已完成的候选验证

- 本地门禁通过：`TRITON_VERIFY_XCODE=0 docs-linhay/scripts/verify.sh --local`；`hub-local.log` 中根包为 TritonKit 108 + Shared 291 项 Swift Testing，另 XCTest 2 + 5 项。通用 Xcode 步骤显式跳过，另行验证 UIKit 与真实 UI。
- 早期 focused App-hosted UIKit 91 项通过；最终全套 `hub-uikit-final.jsonl` 为 231 项通过、1 项跳过，跳过项为 `TKDiscoveryTests` 中由 `TRITON_TEST_BONJOUR=1` 控制的真实 Bonjour 测试，本轮未显式启用。focused 数量不与最终全套累加。
- SDK settings snapshot 7 项通过。
- Release 定向回归 5 项通过。
- 模拟器真实 UI 3 项通过。

以上由主控提供，不累计历史重复运行数量。最终 UIKit 候选已包含罗盘遗留隐藏按钮移除、首页 480pt 防末行裁切、44pt 返回触区、主副文案色阶与 teal 图标修正。最终真实 UI 3 项通过（`hub-real-final.jsonl`），包含上述全部最终差异。原始日志位于 `.build/sp209-evidence/`。

### 自绘卡片阶段最终回归

- 最终真实 UI 已核对五路由、返回/滚动、确认取消/接受、选择上下文恢复和业务动作不泄漏，3/3 通过。
- `verify.sh --ci-docs` 通过；独立 `check-docs.sh` 与 `git diff --check` 通过。

整理提交 `afbe3077` 已创建；用户体验已在 iOS27 模拟器验收，触感实机感受与完整多设备/多 scene 矩阵仍未覆盖。

补充工具边界：最终截图导出仍使用上文已记录的 xcresulttool 只读回退。尝试通过 host HID 打开圆球时，`triton act tap --target sim:<udid> --x 360 --y 155` 返回 `host_action_failed`（no chrome bundle covers udid）。`triton sim` 无 open 子命令，`open -a Simulator` 与已配置 Xcode 下 Simulator.app 路径均不存在；未以点击派发替代成功证据。深色面板改由已有 XCTest 手势流程验证，Triton sim ui 负责切换外观，完成后恢复 light。

深色模式定向真实 UI 1/1 通过（`hub-dark.jsonl`），已人工检查浅/深色首页截图，五路由完整可见。测试后恢复 light，重新启动最终构建并进入 Picker Fixture，供用户试用。

## 当前修订：系统半屏 Modal

用户要求菜单直接采用系统 modal 半屏样式。当前设计为 SDK 自有窗口呈现系统 `pageSheet`；iOS 15+ 设置 medium/large detents 与 grabber，下拉或关闭按钮均恢复圆球及仍有效的选择。iOS 13/14 降级系统 pageSheet，不承诺半屏。内容由 `UINavigationController` + `.insetGrouped` 的 `UITableViewController` 承载，五路由和真实数据边界保留；隐藏入口改用系统 `UIAlertController` 确认。

Modal 展示期间圆球、选择提示与罗盘全部暂隐藏；系统遮罩拦截整个窗口的业务触摸，不能沿用自绘卡片外围透传。外围透传仅适用于 modal 关闭后的普通浮层。关闭与下拉不清 selection；确认隐藏才使旧 guard 失效，仍不重启连接。

### Red 与最终验收

- `.build/sp209-evidence/modal-red.jsonl` 已证明旧实现不呈现 `UINavigationController`：presented navigation controller 为 nil 的预期断言失败。该日志仅为失败测试证据。
- 最终 modal 已由 `modal-uikit-final.jsonl`、`modal-real-final.jsonl`、`modal-release.log` 与 `modal-local.log` 证明；不能复用自绘卡片 231/3/1 等通过数字作为新实现通过。
- 已验证真实 presentation 完成、系统 sheet/detents、分组表单与导航、背景整窗拦截、圆球暂隐藏、关闭/下拉恢复、系统隐藏确认取消/接受及连接与业务计数不变。
- iOS 13/14 pageSheet 降级与完整设备/多 scene 矩阵需分别声明实际覆盖；编译可用不替代真实运行验收。

### Modal 当前验证进度

- 首次 UIKit 发现弹出动画未结束时关闭不能可靠完成。增加 pending dismissal，在 present completion 后执行关闭；由 presenting root dismiss 整层，避免确认 alert 独占 dismiss。测试使用有界等待真实关闭状态，而非固定100ms等待。
- 修复后 `modal-uikit-final.jsonl`：231通过、1跳过（Bonjour opt-in未启用）。覆盖真实系统sheet、medium/large、遮罩触摸与关闭恢复。
- `modal-local.log` 本地门禁通过（通用Xcode显式跳过，由独立真iOS验证）；`modal-release.log` Release定向5通过。
- 系统 API 参考：[UISheetPresentationController](https://developer.apple.com/documentation/uikit/uisheetpresentationcontroller)。真实 UI 最终证据为 `modal-real-final.jsonl`。

真实 UI 首跑4项中2项通过（原拖选、modal背景/下拉关闭），2项测试查询失败：原生只读行在AX树中为StaticText而非Cell，已用identifier不限定类型；iOS27系统Alert按钮同时有同identifier父子元素，使用firstMatch明确选取。失败AX记录证明已进入连接页，并非页面跳转失败。查询修正后已重跑全套并通过。

### Modal最终验收

`modal-real-final.jsonl` 4/4通过：五路由/设置保持、原始拖选、背景遮罩/下拉恢复、隐藏确认取消与接受。`modal-uikit-final` 231通过/1 Bonjour opt-in跳过；Release定向5、本地门禁、ci-docs/check-docs/diff检查通过。最终截图归档sdk-modal系列；已重新启动最终App供试用。当前iOS27模拟器通过，iOS13/14降级与深色矩阵未运行；本轮尚未合入 main 或发布。
