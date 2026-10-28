# SP-236 — #223 系统导航按钮语义边界

当前状态：本地实现/联合验收完成；汇入 `feat/SP-241-open-issues-validation`，未合main、未发布、远端仍开放。[联合验收与风险](../SP-241-open-issues-validation/plans/20261028-validation.md)为当前事实源；独立分支冻结记录保留为历史。
## 范围

影响 embedded UIKit runtime 的 tap 失败契约。系统生成的 UIBarButtonItem 视图没有公开的 view → item 绑定；不凭相同标题猜测 target/action，不遍历后台页面寻找候选，不使用私有 KVC。

## BDD 与验收

- Given 导航栏/工具栏内无公开 UIControl action 且 accessibilityActivate 返回 false，When tap，Then 返回 `unsupported_capability`、`bar-button-action-unsupported` 与指定目标的 host/Runner 恢复建议。
- Given 可用公开 control action 或 accessibilityActivate，When tap，Then 保留既有语义激活。
- Given pageSheet 盖住背景控件，Then 不因导航按钮失败而激活背景。

实现及 App-hosted iOS Simulator 4 项测试通过；旧实现 typed refusal 反证失败。macOS 测试不作为 UIKit 场景验收。关联 [issue #223](https://github.com/NeptuneKit/TritonKit/issues/223)。

验证见 [4项真实 UIKit 测试记录](plans/20261028-validation.json)。修复同时限定既有 Android shell Process 测试仅在 macOS 编译，避免 iOS package tests 编译失败。
