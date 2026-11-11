# SP-282 — v0.2.44 发布

## 范围与状态

2026-11-11 用户授权整理、沉淀、提交及发版，已在 main 串行完成 v0.2.44 发布，未创建分支或 worktree。发布候选 `4d32a545` 的 main/tag CI 与 Release 全部成功；公开资产、Homebrew 和仓库外 packaged Web 验收通过。前一公开版本为 v0.2.43。

发布范围：已合入的 DTUHID modern transport、host 日志独占创建、ActionContext/admission 接线，以及 main 开发治理。发布前审计发现 device.action 失败投影、coordinator policy/TTL、uncertain 不变量与 type 文本绑定缺口，已补 red/green 并修复；完整 CLI 另发现 Harmony verified schema 缺口，也已修复并回归。

## BDD 与门禁

- iOS provider 返回失败或仅 submitted 时，不得宣称 executed=true 或业务 settled；保留原 envelope。
- 非 allow 策略和非法 TTL 在 admission/generation 变化前拒绝。
- uncertain 必须保持 delivery unknown 和 executed unknown。
- type 文本在 admission 前冻结，HMAC 内容摘要参与参数绑定；执行复用内存快照。
- root、CLI 全量、本地 release build/smoke、Web tests/build、docs/contracts 和精确 main CI 通过后才能创建 tag。
- Release 包含 arm64 CLI、bundled Web、unsigned iOS Runner、public skills 和 checksum；SwiftPM iOS 16+ 跟随 tag。当前 workflow 为 arm64-only，不要求 x86_64 回填。
- 发布后核对资产摘要、Runner/skills 版本、Homebrew、仓库外 packaged Web HTTP/浏览器。

## 证据边界

共享 TKActionReceipt 目前是合同及 fixture，生产路径复用 coordinator.admit，尚未完成全部 receipt 投影迁移。generation/admission 默认 store 属单次执行范围，不宣称跨 CLI 进程排他或远端审批。真实设备、guest 触摸及业务后置条件未在本轮验收。

发布结果、精确 SHA、CI URL、资产与安装验证见[发布验收](./plans/20261111-release.md)，red/green 和本地门禁见[发布前验收](./plans/20261111-preflight.md)。原始截图/日志只保存在私有仓外证据目录。
