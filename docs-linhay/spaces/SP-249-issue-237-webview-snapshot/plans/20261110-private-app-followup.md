# #237 私有 App 现场边界复核（2026-11-10）

## 新评论与当前证据

2026-11-09 的 [issue 评论](https://github.com/NeptuneKit/TritonKit/issues/237#issuecomment-6731858527) 说明原私有 App 仍嵌入 SDK `0.2.29`（revision `dd613a…`）。CLI `0.2.42` 的 `webview current` 可用，但 `webview snapshot --include dom,text --max-dom-nodes 100` 在 App 内仍以 `WKErrorDomain 4` 报告生成脚本第 105 行错误；重试不能改变结果，App 与 SDK 没有升级。

这条证据无法归因到当前主线实现：它运行的是旧嵌入 SDK，且没有提供可核对的当前 App 二进制、日志或匹配现场。按范围规则，私有 App 的升级和人工现场验收不纳入本轮独立交付，issue 保持开放。

## 当前主线独立回归

在当前远端 main `ca91c2da36ee5127eb9035009c26a41e65eddb78` 上复跑：

```text
swift test --package-path . --filter TKRuntimeWebViewSnapshotExecutionTests
1 test / 1 suite passed
```

该测试执行当前生成的 JavaScriptCore snapshot 脚本，默认 includes 与 forms-only 场景均通过。主线源码测试同时覆盖 `getElementsByTagName("label")`、`getAttribute("for") === element.id`，并拒绝旧的 `querySelector('label[for="…"]')` 插值方式；因此仓库内可独立验证的脚本生成和解析路径仍保持通过。

## 结论与接替

- 当前主线机制回归通过；没有新的、可由 agent 独立修复的代码失败。
- 旧 SDK 私有 App 的运行时失败保留为未验证边界，不能用本地 fixture 代替，也不宣称 #237 整体恢复。
- 后续若出现与当前 SDK/CLI 匹配的可脱敏失败样本，再按同一 BDD 场景复核；在此之前不重复发版或关闭 issue。
