# SDK统一入口：设计与功能消融

## 判断与取舍

| 原方案 | 决策 | 当前设计与依据 |
| --- | --- | --- |
| 首页铺满选择器开关 | 下沉 | 首页是SDK功能入口；辅助开关仅在控件选择器页 |
| 设置内节点导航 | 移除 | 方向罗盘只属于拖选结果，避免跨场景混合 |
| 圆球/选择提示与设置叠加 | 暂藏 | Modal 打开隐藏圆球和选择提示，下拉/关闭恢复有效选择；不清 selection |
| 隐藏为直接按钮 | 系统确认 | 入口管理→UIAlertController 确认隐藏，说明宿主唤回，取消保留 |
| 连接编辑/断开 | 只读 | 现有disconnect会stop SDK；改endpoint会重置配置，不能冒充安全设置 |
| 功能权限开关 | 只读 | 展示宿主feature配置，不扩大授权，不宣称provider就绪 |
| 隐私开关 | 移除 | RedactionPolicy当前没有消费实现，不能假装设置生效 |
| SDK版本 | 移除 | 已有version值硬编码，不当作可信发布版本 |
| 宿主调试菜单 | 不实现 | 宿主自行提供入口，SDK保留显隐API |
| 自绘定高卡片与导航 | 移除 | 使用系统 pageSheet、导航控制器和 insetGrouped 列表 |
| 打开菜单时外围透传 | 移除 | Modal 的系统遮罩拦截整个窗口；普通浮层只在 modal 关闭后透传 |

## 信息架构

首页：连接摘要；连接与会话、控件选择器、SDK功能、应用与环境、悬浮入口。

- 连接与会话：真实state、host:port、autoReconnect配置；不读取含凭据dataURL。
- 控件选择器：放大镜、密集辅助、触感，即时生效且保持当前selection。
- SDK功能：实际Feature枚举及宿主配置，标注不等于当前界面能力可用。
- 应用与环境：真实Bundle名称/version/build/id及系统，缺失省略。
- 悬浮入口：长按移动说明；隐藏确认，保持SDK连接。

## 视觉与交互（当前：系统半屏 Modal）

用户明确采用系统 modal 半屏样式。SDK 自有窗口以 `.pageSheet` 呈现 `UINavigationController`，内部为 `.insetGrouped` 的 `UITableViewController`，由系统提供导航栏、返回、分组、开关、滚动和浅深色样式。iOS 15+ 配置 medium/large detents 与系统 grabber；iOS 13/14 使用系统 pageSheet 降级，不伪造半屏或宣称同样 detent 行为。首页和子页面沿用系统 sheet 尺寸，不再使用自绘 480pt 卡片。

打开 modal 暂藏圆球、选择框、名称、罗盘，保持 selection 本身；通过关闭按钮或系统下拉结束后恢复圆球及仍有效的选择上下文。系统遮罩覆盖整个窗口并拦截业务触摸，不允许点击外围触发业务。普通浮层外围透传仅在 modal 关闭后适用。入口页使用系统 `UIAlertController` 确认隐藏，取消保持 modal 与 selection，确认才真正停用入口、清除旧 guard，SDK 连接不重启。

## 验证边界

`.build/sp209-evidence/modal-red.jsonl` 已得到旧实现 presented UINavigationController 为 nil 的预期失败。最终 modal 已验证真实 presentation 完成、系统 sheet 类型及 detents、列表导航/滚动、整窗背景拦截、dot 暂隐藏、关闭/下拉恢复及系统确认取消/接受。iOS 13/14 降级单独记录覆盖，不以 iOS 15+ 验收推定。

此前 snapshot 7、UIKit、浅深色真实 UI 与截图为自绘卡片阶段证据；即使信息架构未改，也不能将其当作系统 modal 已通过。原始拖选与不触发业务动作的契约仍需保留回归。

实现检查点：系统转场是异步生命周期，present尚未完成时收到close需排队，在present completion执行；dismiss必须从presenting root关闭整层，避免UIAlert只被单独关闭而遗留sheet。自动化断言按实际AX identifier/type核对，原生value1只读cell可被系统暴露为StaticText，系统alert在iOS27可有同identifier父子节点；使用firstMatch明确目标，不把查询差异误判为业务失败。
