# SP-209 — SDK 统一面板与选择器运行时开关

## 状态与范围

2026-10-16 SDK hub 已改为系统半屏 Modal，最终 UIKit/真实交互与门禁通过。自绘卡片已退出当前方案，其通过记录只保留为历史。基线 main@35356c9c；独立 worktree `../TritonKit-worktrees/SP-209-picker-runtime-toggle`，分支 `feat/SP-209-picker-runtime-toggle`。延续 SP-201，影响 embedded SDK 自有浮层、运行时显隐 API 与示例测试；无新增 CLI/HTTP 写入口，宿主调试菜单不属于 SDK 范围。整理提交已由 `0e296783` 合入 main；用户已授权随main全量发布v0.2.30。

## 当前设计与功能边界

圆球单击以系统 `pageSheet` 打开 TritonKit SDK hub，首页展示真实连接摘要，并提供「连接」「选择器」「SDK 功能」「应用」「入口」五个路由。选择器只占其中一个二级页面，放大镜、密集控件辅助框、触感开关均在该页；配置仅对本次运行生效。

- 连接页展示当前实例的连接状态、服务地址和自动重连配置，不提供会重启 SDK 的伪装连接开关。
- SDK 功能页展示宿主配置是否允许对应能力，属于只读配置，不声称平台支持、provider 就绪或业务可执行。
- 应用页使用真实 Bundle 信息；未被消费的隐私配置和硬编码 SDK 版本不展示，不填充虚假数据或无效按钮。
- 入口页管理悬浮入口；隐藏只从该页发起，并经系统 `UIAlertController` 二次确认。取消保留原状态，确认清除浮层、选择和旧 guard。宿主自行通过 `setPickerEnabled` / `isPickerEnabled` 恢复，SDK 不实现宿主调试菜单。
- Modal 展示期间暂时隐藏圆球、选择框、名称与罗盘；点击关闭或下拉关闭后恢复圆球及仍有效的选择上下文，不把暂隐藏等同于清除选择。系统遮罩覆盖并拦截整个窗口的业务触摸；外围透传仅适用于 modal 关闭后的普通浮层。
- 拖选仍实时预览，松手打开方向罗盘；罗盘只承担节点导航与清除选择，不承载 SDK 设置或隐藏入口。

采用系统 `UINavigationController` + `.insetGrouped` 的 `UITableViewController`，由系统负责导航、分组、浅深色与内容滚动。iOS 15+ 使用 medium/large detents、系统 grabber 和下拉关闭；iOS 13/14 使用系统 pageSheet 降级，不承诺半屏。取消自绘卡片的固定高度和自绘返回/关闭布局。

## BDD

- Debug runtime 已启动且授权 inspector 时，运行时显隐立即生效，不改变 transport、delegate、endpoint 或其它功能；重复开启保留当前标记。
- 点球进入首页；五路由可进入、返回及滚动，显示当前实例真实状态，SDK 功能与宿主 config 一致。
- 修改选择器辅助不重连、不清 selection；modal 打开暂隐藏圆球和全部选择提示，整个窗口的业务触摸由系统遮罩拦截，关闭/下拉恢复有效上下文。
- iOS 15+ 实际呈现系统 pageSheet 与 medium/large detents；导航控制器承载 insetGrouped 列表。iOS 13/14 验收系统 pageSheet 降级，不套用半屏断言。
- 入口页确认隐藏才清除 selection 和 guard；取消不隐藏；宿主 API 恢复后从空 selection 开始。收起罗盘、清除标记与隐藏入口明确区分。
- SDK 未启动、已 stop、未授权 inspector 或 Release/不支持平台时不得开启；停用总是可安全清理。
- 环境变量只用于启动初值；显式重新 start 按新配置重置。

## 验证状态

系统 modal Red 已记录于 `.build/sp209-evidence/modal-red.jsonl`：旧实现的 presented UINavigationController 为 nil，出现预期失败。最终 modal：UIKit 231通过/1跳过（Bonjour opt-in未启用），模拟器真实UI 4/4通过，Release定向5通过，本地门禁与文档检查通过。以下旧记录均属于自绘卡片历史。

### 历史：自绘 SDK hub

统一面板本地门禁通过（`TRITON_VERIFY_XCODE=0`，Xcode 单独验证）：TritonKit 108 + Shared 291 项 Swift Testing，另 XCTest 2 + 5 项。snapshot 7 项与最终模拟器真实 UI 3 项通过。清理罗盘遗留隐藏按钮、首页高度与触区/色阶修正后的最终 UIKit 全套 231 项通过、1 项跳过；跳过项是 `TKDiscoveryTests` 中需 `TRITON_TEST_BONJOUR=1` 显式启用的真实 Bonjour 测试，本轮未启用。Release 定向 5 项通过；最终真实 UI 3 项通过（hub-real-final）。历史 focused UIKit 91 项不与全套重复累计。

历史 89/90 项 UIKit、旧宿主菜单与选择器专用设置截图只证明各自阶段。触感实机感受、全设备/多 scene 矩阵和用户体验验收仍未完成。

## 链接

- [原功能](../SP-201-sdk-floating-picker/README.md)
- [接入说明](../../dev/20260519-ios-integration-guide.md)
- [实现与经验](../../dev/20261015-sdk-floating-picker.md)
- [验证记录与历史阶段](plans/20261016-validation.md)

- [历史自绘浅色首页](screenshots/20261016-sdk-hub-home-v01.png)
- [历史自绘功能页](screenshots/20261016-sdk-hub-capabilities-v01.png)
- [历史自绘隐藏确认](screenshots/20261016-sdk-hub-hide-confirmation-v01.png)
- [历史自绘深色首页](screenshots/20261016-sdk-hub-home-dark-v01.png)

自绘卡片阶段浅色完整 UI 3/3 与深色定向 UI 1/1 通过，截图已检查，并曾安装到模拟器；这不代表系统 modal 已安装或通过。


当前系统半屏已安装到测试模拟器。[原生首页](screenshots/20261016-sdk-modal-home-v01.png) · [选择器设置](screenshots/20261016-sdk-modal-picker-v01.png) · [系统隐藏确认](screenshots/20261016-sdk-modal-confirmation-v01.png)。当前仅真实验证iOS27模拟器；旧iOS降级、深色/多设备矩阵未重新实测。
