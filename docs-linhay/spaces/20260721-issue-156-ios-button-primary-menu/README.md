# GitHub Issue #156：iOS UIButton Primary-Action Menu Activation

> 状态：待集成
>
> GitHub：[NeptuneKit/TritonKit#156](https://github.com/NeptuneKit/TritonKit/issues/156)
>
> Branch：`feat/20260721-issue-156-ios-button-primary-menu`
>
> Worktree：`../TritonKit-worktrees/20260721-issue-156-ios-button-primary-menu/`

## 背景

标准 UIKit `UIButton` 可以只配置 `menu` 与 `showsMenuAsPrimaryAction=true`，不注册 `.primaryActionTriggered` / `.touchUpInside` target。当前 embedded runtime 在 `accessibilityActivate()` 失败后只检查 target/action pair，因此把可由 UIKit public primary-action API 激活的菜单误报为普通 UIControl 无动作失败，并在 CLI 外层表现为泛化 `request_failed`。

## 范围

- 在 iOS embedded runtime 的 `act tap` 既有高层入口内识别 primary-action menu button。
- iOS 17.4+ 优先使用 UIKit public `performPrimaryAction()`，不引入私有 selector、HID、Web/Wails 或新业务 root command。
- 返回明确 activation strategy/message，并继续要求 agent 用可见菜单标题或业务后置条件验证。
- 为低版本或 public API 无法安全执行的路径返回 menu-specific failure/unsupported 语义，不伪报成功。
- 更新 fixture、单元测试、agent-facing 文档/skill 与 memory。

## BDD 场景

### 场景 1：primary-action menu button 使用 UIKit public path

- Given 一个 enabled、可交互、`menu != nil` 且 `showsMenuAsPrimaryAction == true` 的 `UIButton`
- When embedded runtime 执行 `act tap`
- Then iOS 17.4+ 调用 public `performPrimaryAction()`
- And result 返回 `ok=true`、UIButton activation identity 与独立 menu strategy
- And 不要求业务 App 为菜单额外注册 touchUpInside target

### 场景 2：普通 UIButton 行为不回归

- Given UIButton 只有 primary/touchUpInside target 或 accessibility activation
- When 执行 tap
- Then 继续使用既有 action/accessibility 策略
- And primary menu 检测不吞掉普通 control action

### 场景 3：菜单出现由后置观察证明

- Given TestFixture primary-action menu 包含稳定 action title
- When 通过 Triton 打开菜单
- Then 后续 `verify text-exists` 能观察到 action title
- And 只有后置条件成立才在 issue 验收中宣称菜单已打开

### 场景 4：public API 不可用时不泛化假成功

- Given 系统低于 public `performPrimaryAction()` availability 或按钮不满足 primary menu 条件
- When embedded runtime 无安全路径
- Then 返回 `ok=false` 与 menu-specific message/strategy
- And 不回退私有 API 或伪造 touchUpInside 成功

## 验收门禁

- 先补 primary menu detector/dispatch 测试并确认红灯。
- focused `TKRuntimeInputActionsTests`、根包 `swift test` 与 release/local gate 通过。
- Triton-first 保存 status/doctor/capabilities/schema 事实，真实 Simulator App 通过 `triton xcode run` 启动；菜单打开与 action title 必须由 Triton observe/verify 证明。
- README、agent control 文档、real-project/dev-feedback skill 与 memory 写回。

## 停止条件

四个场景、自动化门禁、真实 Simulator 证据、文档/memory 写回、main 集成与线上 CI 全部满足后关闭 #156。若需发布，创建 `v0.2.14` 或当时下一 patch，不移动 `v0.2.13`。

## 实现与验收记录

- embedded runtime 在 iOS 17.4+ 对 primary-action menu button 调用 public `performPrimaryAction()`，成功结果为 `button-primary-menu-action`；低版本返回 `button-primary-menu-action-unsupported`。
- 可见菜单项标题若来自当前可见 primary menu 的 public `UIMenu` / `UIAction` 树，embedded 选择返回 `button-primary-menu-item-unsupported` 与 `unsupported_capability`，不依赖 UIKit 私有 class 名或 selector。
- CLI 已修复“先输出 `TKInputResult`、再泛化输出 `request_failed`”的双 JSON 问题；运行时失败对象只输出一次并以非零退出。
- TestFixture 的 `Open Fixture Menu` 通过 Triton 打开，返回 `ok=true`、`strategy=button-primary-menu-action`；`verify text-exists "Fixture Menu Action"` 返回 `ok=true,count=1`。
- 再点击 `Fixture Menu Action` 返回退出码 1，stdout 经 `jq -s` 证明只有 1 个对象，且 `error.code=unsupported_capability`、`strategy=button-primary-menu-item-unsupported`。
- iOS Simulator focused tests：primary menu、nested menu titles、普通 UIControl accessibility fallback 共 3 项通过；根包 `swift test` 226 项通过；CLI `InputOutputTests` 聚焦用例与 `WebViewRouteTests` 18 项通过。
- Triton-first baseline 保存于 `/private/tmp/triton-issue-156-baseline/`；`triton xcode` schema 缺少 `only-testing`，因此聚焦 iOS test 在保存缺口证据后回退 raw `xcodebuild`。
