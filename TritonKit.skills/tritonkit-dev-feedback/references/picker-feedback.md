# Optional highlight and picker feedback

## Optional view-highlight acceptance

`triton highlight capabilities/apply/status/clear` is optional; never require an embedded SDK for ordinary host screenshots. See [the highlight workflow](../../tritonkit-emulator-cli-takeover/references/view-highlight.md). Validate real properties, before/during/after images, exact session cleanup, TTL, business-write conflicts and reconnect. Screenshot success is not restoration success; preserve operationID/sessionID and incomplete cleanup evidence. This slice supports Debug UIKit ordinary views only.

## Optional floating-picker feedback (SP-201, unreleased)

The SP-201 UIKit floating picker is integrated into local main but is not a published release; the SP-209 SDK hub remains an isolated worktree candidate. Verify a matching candidate SDK/CLI and command schema before suggesting `triton inspect capabilities/selection/clear`. Preserve source/version, explicit runtime target, configuration, selection state and action outcome separately; never describe an HTML mock or a macOS-skipped UIKit test as native acceptance.

In the app's existing file-level `#if DEBUG` bootstrap, opt into both `config.features.insert(.inspector)` and `config.picker = .init(enabled: true, ttlSeconds: 300)`. The default is off and Release is no-op, with no added third-party dependency. `TRITON_PICKER_ENABLED=1` enables the default picker environment configuration only; it does not insert `.inspector` or replace the app's runtime startup gate. The fixture inserts the feature for convenience; ordinary apps must do so explicitly. Keep `.input` enabled when guarded taps are required.

Read `triton inspect selection --target '<runtime-target>' --json`, then use `triton act tap --target '<runtime-target>' --selection '<selection.id>' --selection-revision '<selection.revision>' --runtime-instance-id '<runtimeInstanceID>' --json` with fields from that same response. Selection does not trigger a business action. Only eligible UIKit buttons support guarded taps; labels/cells are `observeOnly`, with SwiftUI virtual nodes, DOM, Android and Harmony deferred. Re-selection, expiry or identity loss must reject the old guard without coordinate/OID fallback. Check `ok`, validity, supported actions and the business postcondition; record whether the defect is entry visibility, gesture leakage, target identity, delivery or business behavior. Clear deliberately with `triton inspect clear --target '<runtime-target>' --runtime-instance-id '<runtimeInstanceID>' --json` when cleanup is intended. Redact labels, identifiers and screenshots before public feedback.

### SDK hub 与选择器运行时开关

Debug App 预先授权 `.inspector` 后，在 MainActor 通过 `TritonKit.shared.setPickerEnabled(true/false)` 开关，读取 `isPickerEnabled` 判断会话状态；不重新 start SDK。接入代码放独立 Debug bootstrap。宿主负责自己的唤回入口，SDK 不实现宿主调试菜单。

圆球单击以系统 pageSheet 打开 SDK hub：首页真实连接摘要，连接、选择器、SDK 功能、应用、入口五路由。放大镜、辅助框、触感在选择器二级配置。SDK 功能是宿主配置的只读展示，不代表平台支持、provider 就绪或业务可执行；不展示未被消费的隐私配置或硬编码 SDK 版本，不为填充菜单添加无效按钮。

系统 modal 内部使用 UINavigationController 与 insetGrouped UITableViewController；iOS 15+ 使用 medium/large detents、grabber，iOS 13/14 降级系统 pageSheet，不承诺半屏。验收 modal 打开暂隐藏圆球、全部选择提示与罗盘，下拉或关闭恢复有效选择上下文；系统遮罩拦截整个窗口业务触摸，外围透传仅适用于 modal 关闭后。罗盘只保留节点导航和清除。隐藏操作仅在入口页经系统 UIAlertController 确认后执行，取消保持状态；确认后旧 selection guard 失效，宿主 API 恢复从空选择开始。分别核对隐藏/恢复前后连接与业务计数不变、Release 不能开启，以及浅深色、小屏滚动和子页面返回。SP-209 为未发布候选，使用前核对匹配源码/版本与实际验证记录；自绘卡片通过记录不能代替系统 modal 验收。
