# Runtime、网络与 iCTRL 上游更新报告

截至 2026-10-14 北京时间；各 GitHub 请求独立发生，非同一原子快照。该组原始 HEAD/compare 采集发生于证据整理前，最终证据整理时间为 `2026-10-14T17:45:08.244232+08:00`。本组影响评估涵盖 shared core、CLI/HTTP、host simulator、embedded runtime 与网络 evidence；仅研究，不修改 TritonKit 实现。报告相对已归档的具体 SHA 比较，而非统一的“最近一个月”。提交数含 merge/release/依赖提交，不代表功能数。

GitHub 官方 API 核实 5 个项目均未归档、未 disabled，`full_name` 与原路径一致，未发现重定向。HEAD 与 release 分开记录；发布日期见证据 JSON。表格采用北京时间，UTC 原始值保留在证据 JSON。

| 项目 | 最新正式 release / 发布时间（北京时间） | 默认分支 HEAD / 提交时间（北京时间） | 基线以来提交 / compare 文件数 | GitHub 识别许可证 |
|---|---|---|---|---|
| [heoblitz/Loupe](https://github.com/heoblitz/Loupe) | [v0.5.1](https://github.com/heoblitz/Loupe/releases/tag/v0.5.1) · 2026-10-14 16:42:28 北京时间 | `ff1351242e` · 2026-10-14 16:10:16 北京时间 | +59 / 132 | MIT |
| [jfarcand/mirroir-mcp](https://github.com/jfarcand/mirroir-mcp) | [v0.40.1](https://github.com/jfarcand/mirroir-mcp/releases/tag/v0.40.1) · 2026-10-05 06:50:07 北京时间 | `845a981163` · 2026-10-13 16:22:19 北京时间 | +131 / 300（达到 API 上限） | Apache-2.0 |
| [RockxyApp/Rockxy](https://github.com/RockxyApp/Rockxy) | [v0.41.0](https://github.com/RockxyApp/Rockxy/releases/tag/v0.41.0) · 2026-10-08 15:05:42 北京时间 | `de791b63e7` · 2026-10-08 15:05:15 北京时间 | +599 / 300（达到 API 上限） | AGPL-3.0 |
| [ProxymanApp/atlantis](https://github.com/ProxymanApp/atlantis) | [1.36.0](https://github.com/ProxymanApp/atlantis/releases/tag/1.36.0) · 2026-05-29 03:37:45 北京时间 | `cc059013de` · 2026-10-14 17:41:58 北京时间 | +1 / 22 | Apache-2.0 |
| [OpenMinis/iCTRL](https://github.com/OpenMinis/iCTRL) | [v1.97.1](https://github.com/OpenMinis/iCTRL/releases/tag/v1.97.1) · 2026-10-13 19:33:32 北京时间 | `99dbfecdb3` · 2026-10-13 19:32:57 北京时间 | +0 / 0 | Apache-2.0 |

## Loupe：优先复核 Xcode 兼容性与动作目标

基线 `5b89c9f51537a1c5ef7b8e9d42e274e2c1f04290`（2026-06-23 UTC）至 HEAD `ff1351242e6dbaba4a0b4de40d10350a668f03b8`，完整获取 59 个提交、132 个变更文件。[固定 compare](https://github.com/heoblitz/Loupe/compare/5b89c9f51537a1c5ef7b8e9d42e274e2c1f04290...ff1351242e6dbaba4a0b4de40d10350a668f03b8)。

- 今日发布 [v0.5.1](https://github.com/heoblitz/Loupe/releases/tag/v0.5.1)：兼容 Xcode 27 `Contents/SharedFrameworks` 中的 SimulatorKit，同时保留旧路径；不存在或无法加载的 bundle 会继续 fallback，失败携带尝试路径和错误。变更落实于 [LoupeHID.m](https://github.com/heoblitz/Loupe/blob/ff1351242e6dbaba4a0b4de40d10350a668f03b8/Sources/LoupeHID/LoupeHID.m)，附专门路径 fixture。
- [v0.5.0](https://github.com/heoblitz/Loupe/releases/tag/v0.5.0)：发现带实际手势的 UIKit/SwiftUI 目标，包括不在 accessibility 中的目标；增加双击 `tap --count 2`、按住拖动 `drag --hold-duration`，直接捕获 simulator framebuffer。
- [v0.4.0](https://github.com/heoblitz/Loupe/releases/tag/v0.4.0)：相同 CLI 自动选择 simulator HID 或 physical-device touch，真机要求签名 Debug app 嵌入 LoupeInjector；失败动作取消，不重试已部分派发的手势。
- 基线以来还包括 semantic accessibility actions、runtime 请求处理隔离、唯一 selector 及 wait 中 transient snapshot 重试；选择机制和传输加固可查 [动作发现 PR #15](https://github.com/heoblitz/Loupe/pull/15)、[CLI/runtime PR #18](https://github.com/heoblitz/Loupe/pull/18)。

**对 TritonKit 的判断（推断）**：优先检查我们的 framework discovery 是否有同类路径脆弱点，并借鉴 attempted paths 诊断、唯一选择器、可操作性与 AX 存在性分离、动作取消证据。真机部分只进入已批准的真机 space。**风险**：私有框架及 UIKit touch 有平台版本风险；v0.5.0 明确不再支持 Intel，不能照搬其分发矩阵到 TritonKit 双架构发布。上游真机与测试结果是其声明，本次未执行验证。

## mirroir-mcp：观察减少焦点副作用，验收拒绝虚假成功

基线 `7e97f0c813836ae07c69a9bb3565af8e82abdfd3`（2026-05-24 UTC）至 HEAD `845a981163aa6d40999d343fee26778df8627843`，完整获取 131 个提交；compare 只返回 300 个文件，达到 API 上限，文件清单不完整。[固定 compare](https://github.com/jfarcand/mirroir-mcp/compare/7e97f0c813836ae07c69a9bb3565af8e82abdfd3...845a981163aa6d40999d343fee26778df8627843)。

- [v0.40.0](https://github.com/jfarcand/mirroir-mcp/releases/tag/v0.40.0) 优先 ScreenCaptureKit 截图，减少激活窗口造成的焦点争用。[ScreenCapture.swift](https://github.com/jfarcand/mirroir-mcp/blob/845a981163aa6d40999d343fee26778df8627843/Sources/mirroir-mcp/ScreenCapture.swift) 确认先按 windowID 截图，再退回需要 activate 的 screencapture 途径；截图不是保证全程无焦点副作用。
- 新增跨调用 `touch`、`hold_keys`、`pinch`、`rotate`，每次调用从 live state 重新确定 PID/窗口；文档明示 iPhone Mirroring 只向 app 暴露一个独立 pointer touch，不能模拟两个独立手指的 touch-only 游戏。[当前 README](https://github.com/jfarcand/mirroir-mcp/blob/845a981163aa6d40999d343fee26778df8627843/README.md)。
- 跨 web/process/HTTP/iOS 的 mirroir-run runner、live capture parity、DRIFT verdict/accept 流程逐步成形；全部选中步骤跳过、未执行的 plan、孤立 baseline 都拒绝判为成功。[v0.40.0](https://github.com/jfarcand/mirroir-mcp/releases/tag/v0.40.0)、[DRIFT 文档](https://github.com/jfarcand/mirroir-mcp/blob/845a981163aa6d40999d343fee26778df8627843/runner/docs/drift-and-accept.md)。
- [v0.40.1](https://github.com/jfarcand/mirroir-mcp/releases/tag/v0.40.1) 禁止 AX-press 无标签 resume button；启动仍停在 Spotlight 或 home screen 会报错。HEAD 后续主要是依赖与 CI 更新，没有更新正式 MCP release。

**对 TritonKit 的判断（推断）**：借鉴只读观察的焦点预算、运行时重新解析目标、实际执行计数、全 skipped 拒绝成功、基线与实时证据的绑定。**风险**：iPhone Mirroring 受 macOS 版本、区域、权限和单 pointer 限制；嵌入 FFI 与跨表面 runner 增加打包/依赖复杂度。TritonKit 仍以 CLI/HTTP 为事实入口，不据此自动新增 MCP/Web 控制面。上游多点手势边界和表现未由我们实测。

## Rockxy：网络证据与脱敏能力增长，分发许可证需分开看

基线 `120a4428feb1a436677c7b8a9c7332f38ae6b0e0`（2026-06-09 UTC）至 HEAD `de791b63e7f9b5df49f127524a5c9320e675eb23`，compare `ahead_by=599`，6 页取得全部 599 个唯一提交；文件返回 300 个，达到上限，文件清单不完整。[固定 compare](https://github.com/RockxyApp/Rockxy/compare/120a4428feb1a436677c7b8a9c7332f38ae6b0e0...de791b63e7f9b5df49f127524a5c9320e675eb23)。

- [v0.41.0](https://github.com/RockxyApp/Rockxy/releases/tag/v0.41.0) 引入 Traffic Insights（慢请求、失败、时间对比与 Markdown 报告）与本地 Project 保存 traffic、布局和过滤条件；配置导入/导出不搬运 captured traffic。
- 导出 session/HAR/CSV/Postman 可选择遮盖凭据和敏感字段，原始 capture 保留；更新还覆盖 echoed secrets、无法检查的 encoded body、MCP export 和压缩响应检查的泄漏边界。
- SSE、NDJSON、WebSocket 活跃期间即出现并更新详情；HAR 更准确保留 content type、时间、可读 stream body 与 duration；导入不再按 live history 上限裁剪。
- 按 app 解密/tunnel rules、upstream proxy、booted simulator 根证书导入、Android emulator adb 路由以及控制运行中 app 的 rockxy-cli 陆续新增，规则与 capture 的 MCP 写操作仅在允许时开放。功能依据 [v0.41.0](https://github.com/RockxyApp/Rockxy/releases/tag/v0.41.0)、[v0.40.0](https://github.com/RockxyApp/Rockxy/releases/tag/v0.40.0) 与证据 JSON 中对应 commits；具体 Community/Pro 可用性须另核对，不据更新列表推定所有功能均属免费版。

**对 TritonKit 的判断（推断）**：优先把网络 evidence 中原始数据、脱敏导出、stream 生命周期、capture/import retention 区分开；参考系统代理恢复与 emulator localhost alias 的故障诊断。**风险**：当前 [README](https://github.com/RockxyApp/Rockxy/blob/de791b63e7f9b5df49f127524a5c9320e675eb23/README.md) 明示公共源码为 AGPL-3.0-or-later Community edition，官方 DMG 含非公开 downstream components 并按 [Binary EULA](https://github.com/RockxyApp/Rockxy/blob/de791b63e7f9b5df49f127524a5c9320e675eb23/legal/BINARY-EULA-v1.0.md) 分发。不能把源码 tag 当成完整 DMG build source；代码复用须单独审查义务。release 对大 capture 更流畅的描述只是上游声明，未测量。

## Atlantis：今天有代码增量，尚无对应正式 release

基线 `6427600ec87d516a43754e4eaa7762f3271ac77f`（2026-05-28 UTC）至 HEAD `cc059013de8778072b4fea6453b45e964e4202fe`，+1 提交、22 个文件，完整获取；最新 release 仍为 [1.36.0（2026-05-28）](https://github.com/ProxymanApp/atlantis/releases/tag/1.36.0)。[固定 compare](https://github.com/ProxymanApp/atlantis/compare/6427600ec87d516a43754e4eaa7762f3271ac77f...cc059013de8778072b4fea6453b45e964e4202fe)。

- 本组采集时（独立请求；整理时间见上方）观察到今日 [PR #195](https://github.com/ProxymanApp/atlantis/pull/195) 支持 iOS 26/27 的 Network.framework URLSession loader（NWURLSession）；提交说明提到 classic mode 关闭和 HTTP/3 Early Data 路径。
- 捕获 async upload 的内存与文件 request body，限制超过最大 package size 的文件读取；新增本地 HTTP/WebSocket fixture 覆盖两种 loader。
- 握手前 WebSocket message 先排队、在 handshake traffic 后发送；握手失败清理 pending 数据，避免乱序和泄漏；新 loader data chunk 在原 handler 之前报告。
- watchOS 10/11 resume hook 补齐，iOS 18/macOS 15 缺少特定完成 selector 时由 receive/send/ping hooks 补报失败握手。源码可核对 [NetworkInjector+NWURLSession.swift](https://github.com/ProxymanApp/atlantis/blob/cc059013de8778072b4fea6453b45e964e4202fe/Sources/NetworkInjector%2BNWURLSession.swift)。

**对 TritonKit 的判断（推断）**：网络 runtime capture 的新 loader 漏采风险值得建立回归矩阵，尤其 async upload、握手失败与流顺序。**风险**：此能力位于 main，尚不能称“1.36.0 已支持”；依赖私有运行时类型与 swizzling，系统变化可能再次失效。本次未运行上游测试，也未验证发布包。

## iCTRL：相对本日登记的基线没有变化

基线与 HEAD 均为 `99dbfecdb39836ba26a0b2b0dcfde90f705a6835`（2026-10-13 19:32:57 北京时间），compare `identical`、0 提交、0 文件；最新 [v1.97.1](https://github.com/OpenMinis/iCTRL/releases/tag/v1.97.1) 发布于 2026-10-13 19:33:32 北京时间。[固定 compare](https://github.com/OpenMinis/iCTRL/compare/99dbfecdb39836ba26a0b2b0dcfde90f705a6835...99dbfecdb39836ba26a0b2b0dcfde90f705a6835)。

本次没有可报告的新增能力。v1.97.1 修复 host app pairing-file import picker 不接受 XML plist；runner 没有功能变化。上一版 v1.97.0 的手机 Safari remote 页面、fullscreen、悬浮控件、截图文件类型修复是**已在基线内的背景**，不能作为本次新增。[v1.97.0](https://github.com/OpenMinis/iCTRL/releases/tag/v1.97.0)。

**对 TritonKit 的判断（推断）**：继续观察 refs/screen-state、bounded AX、settle-aware action 的既有参考方向，本次不生成新增实现任务。真机 wireless API、签名 IPA 与 Developer Disk Image 前置条件超出 emulator 默认边界。发行说明中关于 faster capture / 30 fps 的描述未实测。

## 建议排序与证据边界

1. **优先**：Loupe 的 SimulatorKit 路径 fallback/加载错误证据；Atlantis 新 loader 的漏采与 stream ordering 回归场景。
2. **其次**：mirroir 的只读截图焦点管理与全 skipped 拒绝成功；Rockxy 网络 evidence 脱敏及 retention/stream 生命周期。
3. **持续观察**：iCTRL 无增量，保持已有日追踪；不把历史亮点重报为新变化。

以上排序是研究建议，不意味着已修改代码或已验证 TritonKit 缺陷。证据结构已固定：顶层 `checked_at`、`method`、`repositories`；每仓包含 `metadata` 的平铺字段、`head`、`baseline`、`comparison`、`releases`、`focus_commits`、`changed_files`、`source_evidence`。原始 API 查询结果已精简为 [runtime-updates.json](runtime-updates.json)：保留固定 SHA、compare统计、release正文、关注提交、关键源码链接与有限摘录；删除完整 patch、用户身份、邮箱。Rockxy/mirroir 的变更文件清单触及 GitHub compare 300 上限，报告不声称已逐文件穷尽审阅。已完成 JSON 解析与本组文件 whitespace 检查；全仓文档门禁由主控集成后执行。
