# 2026-10-19 simulator/runtime 上游只读检查

范围为 `reference-state` indices 0..9（不含 iCTRL）：tddworks/baguette、serve-sim、sim-use、simslim、OpenDeviceHub、device-hub-ios、Loupe、mirroir-mcp、Rockxy、Atlantis。严格只读查询官方 GitHub 默认分支 HEAD、最新非-draft Release（含 prerelease，分页至末页）和固定 HEAD 许可证全文/hash；未运行上游代码、安装依赖、设备/签名/DDI。TritonKit 评估基线为真实 `main@d51403a69afbafd9426bd5ed6bfe3eb81a0ff0ec`，证据见 `main-source-check.json`。

| 仓库 | HEAD 相对 checkpoint | 完整性 | 新提交数 | 最新非-draft Release | SPDX | 裁决 |
|---|---|---|---:|---|---|---|
| EvanBacon/serve-sim | `a30d70a55e05` (无变) | 完整 | 0 | 无 | Apache-2.0 | observe |
| JaviSoto/device-hub-ios | `58caf76c1994` (变) | 完整 | 6 | 无 | MIT | observe |
| Mastersam07/OpenDeviceHub | `e50f07f1f448` (无变) | 完整 | 0 | v0.2.0 | MIT | observe |
| MobAI-App/simslim | `6518ba7eab11` (无变) | 完整 | 0 | v0.12.2 | MIT | observe |
| ProxymanApp/atlantis | `cc059013de87` (无变) | 完整 | 0 | 2.0.0 | Apache-2.0 | observe |
| RockxyApp/Rockxy | `de791b63e7f9` (无变) | 完整 | 0 | v0.41.0 | NOASSERTION | observe |
| heoblitz/Loupe | `ff1351242e6d` (无变) | 完整 | 0 | v0.5.1 | NOASSERTION | observe |
| jfarcand/mirroir-mcp | `845a981163aa` (无变) | 完整 | 0 | v0.40.1 | Apache-2.0 | observe |
| lycorp-jp/sim-use | `81c3089331aa` (无变) | 完整 | 0 | v0.15.0 | NOASSERTION | observe |
| tddworks/baguette | `14b39834fef6` (变) | partial | 9 | v0.2.7 | Apache-2.0 | observe |

## 变化与评估

- **JaviSoto/device-hub-ios**：相对 checkpoint `b5994ff72d8c75d68370ae80aa3efaa4e590686d` 前进 6 个提交至 `58caf76c199457e33af1b44956016f73c302df7d`。完整阅读提交详情、36 个变更文件及固定源码；变化集中在 Xcode 27.1/iOS SDK 27.1 toolchain guard、iOS 27.0 deployment floor、按 runtime 支持的 simulator device type 选择、Device Hub debug fixture、测试/构建脚本与 1.0.4/1.0.5 release notes。它是上游 app/build pipeline 的兼容性工作；SP-196 已覆盖 TritonKit 的 resize/framebuffer/helper 边界，SP-200 已覆盖 simulator 环境/动作契约，当前没有可独立采用的 Triton 缺口，裁决 **observe**。
- **tddworks/baguette**：仍从 imported observation `8930ac...` 追到 `14b39834fef663c2eca868db98422e4eaa8e2bb3`，9 commits/67 files，最新 Release `v0.2.7`。提交、Release notes、可读取源码和固定 HEAD `LICENSE` 已保存；`docs/features/companion-screens/DiPlay.apk` 仅返回官方 metadata（`source-57.json`），没有源码全文，因此按既有 APK source provenance **partial** 保持，裁决 **observe**，不作二进制行为/来源完整性断言。
- **其余 8 个仓库**：HEAD、Release、许可证与 2026-10-18 成功 checkpoint 均未变化（Atlantis 的 imported release 显示旧 `1.36.0`，但 checkpoint 已是 `2.0.0`，本轮按 checkpoint 判定无变化），均无新增采用动作，裁决 **observe**。

本轮没有 `adopt`、`reject` 或需新建 space/thread 的结论；`covered` 仅作为评估依据使用（SP-192/SP-196/SP-200 已覆盖相关本机模拟器/runtime 边界），不把上游声明当作本地产品验收。结果机器可读汇总见 `results.json`；每仓库原始 API、分页 Release、提交详情、变更文件源码、许可证全文位于对应子目录。错误/限制：仅 baguette 的 APK 源码 provenance 缺失导致 partial；其余仓库 complete=true。
