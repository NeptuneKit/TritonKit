# SP-250 · v0.2.37 验收与发布

## 边界与状态

基线远端 main ca885cb6，目标发布已合入的 #237 WebView snapshot 与 #238 ArkWeb transport 修复。用户明确授权立即验收，通过后直接发版；尚未发布。隔离 worktree/branch 为 SP-250-release-v0-2-37 / feat/SP-250-release-v0-2-37，不包含主目录其他提交和 WIP。

## BDD 与验收

- Given 当前 SDK / CLI，When 自有 WKWebView fixture 运行 default / forms-only snapshot，Then 有界合法结果、特殊属性 selector/focus 往返；CLI和SDK身份分别记录。
- Given 真实 ArkWeb 或适用独立测试环境，When CDP evaluate / allowlist probe，Then text frame 得到结果或预期 allowlist 错误；传输错误不冒充页面错误。环境缺失须如实记录，不运行私有业务 handler。
- Given 精确发布候选，Then 完整 local preflight、版本/skills/Web/标准 CocoaPods/CI 必须通过。
- Given 新 tag 发布，Then 双架构CLI/checksum/skills/Web/SwiftPM/podspec一致，Homebrew安装与包外HTTP/浏览器验收通过。

## 证据与接替

原始日志归本 worktree .build/release-0.2.37；公开报告只保存脱敏结论。#214暂缓，#224/#237/#238保持开放；真实原用户App恢复与产品机制验收分开，不关闭issue。
