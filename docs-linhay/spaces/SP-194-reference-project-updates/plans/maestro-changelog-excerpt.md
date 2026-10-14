# Maestro 2.6.1 → 2.11.0 变更摘要

来源：[固定版本 CHANGELOG](https://github.com/mobile-dev-inc/Maestro/blob/cli-2.11.0/CHANGELOG.md)。读取于 2026-10-14；以下为摘要，不代表本地运行验收。

- 2.7：逐步骤截图和结构化产物 manifest，故障附 UI 树；Android Unicode 输入、WebView 超时、native crash 收集；iOS AX 失效恢复与生命周期超时修复。
- 2.8：防止产物路径逃逸、失败 hook 丢证据；修复 stale childOf 树及启动等待；上传结果 unknown 时不自动重试。
- 2.9：主题控制/断言，Android WebView socket 有界、序列化深树与循环 DOM 修复。
- 2.10：支持 Android system image 完整路径。
- 2.11：Android 17/API37 system image，物理 iOS 目标提前拒绝；记录视频真实开始时间，拒绝被误用并静默忽略的选择器参数。

对 TritonKit 的直接借鉴是证据时间线、路径安全、unknown 不重试、陈旧树与 WebView 超时回归；不引入其 Cloud 服务。
