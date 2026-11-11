# v0.2.44 发布前验收

日期：2026-11-11（Asia/Shanghai）。当前 main 基线 `224578b9` 加本次未提交发布候选；完成提交后以提交 SHA 和下方 manifest 共同绑定。

## 修复与反证

- `device.action`：iOS `ok:false/result:null` 与仅 `submitted=true` 不再提升为 executed true；保留原 envelope，失败 stdout 单 JSON 且退出非零，nested postcondition 正确读取。
- coordinator：非 allow 策略与非法 TTL 在 generation 更新前拒绝；issue/consume 成功后才推进 generation。
- receipt uncertain 校验要求 delivery unknown 且 executed nil。
- type 文本在 admission 前一次读取，随机 key HMAC 内容摘要进入 argsDigest，派发复用内存文本；测试固定 key 校验相同/不同内容，不用随机 key 差异伪证内容绑定。
- 完整 CLI 抓到 Harmony verified-input 参数、输出、错误与 recovery 缺少父 schema 定义；补齐真实 parser/已有 contract，保留 compact/fact-source 严格校验。

shared 新负例在旧实现产生实际断言失败；CLI 新负例编译执行后产生 7 项断言失败；修复后 focused 和完整回归均通过。red/green 原始日志已归档，未把编译失败当行为反证。

## 本轮验证

| 项目 | 结果 |
| --- | --- |
| 完整 CLI XCTest | 166 项通过 |
| 完整 CLI Swift Testing | 1839 项 / 202 suites 通过；2 项需要自有 Simulator 的 live test 显式跳过 |
| root 两个 Swift Testing 目标 | 130 项 / 26 suites、313 项 / 45 suites 通过 |
| `TRITON_VERIFY_XCODE=0 verify.sh --local` | 通过；release CLI build、CLI/Harmony/iOS offline smoke 通过，真实 Simulator build 显式跳过 |
| Web 完整清单，Node 24、单并发、绑定本候选 CLI | 174 项通过 |
| Web TypeScript/Vite build | 通过 |
| 版本 0.2.44、release automation、skills、docs/ci-docs | 通过 |

Web 首次使用 DSH bundled Node 24 时因 macOS Team ID library validation 拒绝 Rollup 原生模块，保留失败日志；改用已安装 Homebrew Node 24.21.0 后同一锁文件/完整测试和构建通过，没有重签 runtime 或删除 lock。依赖 audit 返回 7 项（5 high/1 moderate/1 low），集中于 Vite/构建工具链；保留报告，未自动改依赖。本次 portable 制品只含编译后的静态 Web，不包含 node_modules；这不代表源码开发依赖已完成漏洞修复。

## 候选与证据

持久本地日志目录：`../TritonKit-release-evidence/20261111-v0.2.44/`。`manifest.json` 保存日志 bytes/SHA-256；`candidate-files.json` 保存 Sources/Tests/CLI/Web/public skills/workflows/验证脚本的实际文件摘要。

candidate manifest SHA-256：`a4e79198c591086671038f96dcc094c11f3371ab01030b4f982aaafd42448ac2`。

发布前还须完成精确 main SHA 的完整 CI、tag/Release、公开资产 checksum/Runner/skills、Homebrew 和仓库外 packaged Web 验证；这些步骤此时未宣称完成。

## 未覆盖边界

本轮未执行真实设备、guest tap/业务后置验收、审批/远端 admission、跨 CLI generation 或统一 receipt 的生产投影迁移。DTUHID 私有 ABI 在不同 Xcode/SDK 的兼容仍需各环境验收。当前发布遵循 arm64-only、SwiftPM iOS16+，CocoaPods/x86_64 已退休。
