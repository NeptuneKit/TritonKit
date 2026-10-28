# SP-236 — #223 系统导航按钮语义边界

## 范围

影响 embedded UIKit runtime 的 tap 失败契约。系统生成的 UIBarButtonItem 视图没有公开的 view → item 绑定；不凭相同标题猜测 target/action，不遍历后台页面寻找候选，不使用私有 KVC。

## BDD 与验收

- Given 导航栏/工具栏内无公开 UIControl action 且 accessibilityActivate 返回 false，When tap，Then 返回 `unsupported_capability`、`bar-button-action-unsupported` 与指定目标的 host/Runner 恢复建议。
- Given 可用公开 control action 或 accessibilityActivate，When tap，Then 保留既有语义激活。
- Given pageSheet 盖住背景控件，Then 不因导航按钮失败而激活背景。

实现与验证进行中；macOS 测试不作为 UIKit 场景验收。关联 [issue #223](https://github.com/NeptuneKit/TritonKit/issues/223)。
