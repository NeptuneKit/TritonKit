# SP-292-open-issues-release-046 — 八项issue整合与v0.2.46发布

状态：候选验证中（2026-11-16）。初始八项中 #277 已关闭，GitHub 复查仍开放七项。最新公开版本 v0.2.45。

## 范围与BDD

当前 main 串行实现和验证。初始八项为 #224/#237/#238/#246/#274/#277/#282/#283。2026-11-16 续接指令明确剩余七项一起处理，先修 #283 的重启旧值，再发 v0.2.46，并逐条回帖关闭验收通过的 issue。

- Given 当前main与初始线上需求，When 完成代码、测试与契约后集中验收，Then 每项分别记录实现、fixture、真实运行和发布证据，不以发行成功替代行为验收。
- Given 失败或未知结果，Then 保留原错误和部分效果，不自动重放写操作。

## 验收

续接候选完整 CLI 1898 项、#283 专项 9 项及真实 Simulator 重启通过。Web 构建、文档结构、public skills 与版本/发布自动化检查通过。发布前还需完成本地 Release 门禁和精确 main CI。公开候选从线上 main 套用本轮 issue 差异，证据路径所在的本地研究提交单独保管。

## 当前版本报告（持续更新）

本文件是v0.2.46唯一当前报告；各issue space记录边界，原始日志/截图独立归档。

| issue | 本轮交付 | 验收状态 |
| --- | --- | --- |
| #283 | app-container 原生单键 remove、旁键类型保留、无键 no-op、可选 relaunch | 候选在自有 iPhone 重启 App 后，界面从临时值变为 `Preference: absent`。原生偏好域和磁盘均缺键，旁键保持布尔 `false`。9 项专项测试通过，待发布包复验。见 [SP-290](../SP-290-issue-283-preference-remove/README.md) |
| #282 | 显式完整 Release 新目录安装，核验 checksum、归档、CLI、Web、Runner 与 bundle | 候选 CLI 旁路安装公开 v0.2.45，原安装执行文件 SHA 一致。补充 Vite JS/CSS 缺失拒绝和独立包禁止只替换二进制。v0.2.46 安装与原 Homebrew 环境待验证。见 [SP-291](../SP-291-issue-282-homebrew-recovery/README.md) |
| #224 | 当次失败 `probeDiagnostic` 与原始 JSON/log/process 本地引用；doctor 独立快照 | 自有 iPad 返回当次 CoreDevice 1001 并保存三个引用，显式 LCD 成功。自有 iPhone 滑动后轮播从 item1–4 到 item4–7，续接候选 8 次只读截图均成功。`queryFailed` 有注入覆盖，原瞬态根因未知 |
| #277 | 精确 target-bound `unsupportedDevice` 继续独立 HID/display 守卫 | [已关闭](../SP-274-issue-277-resize-host-input/README.md)。v0.2.45 原调用形态返回 `host-hid`，自有 iPad 计数 0→1，主 LCD 截图通过；原 iOS 26.5 iPhone 未复跑 |
| #237 | 现有 WKWebView 脚本修复 | 当前 SDK 在自有 iPhone 真实 WKWebView 默认／forms-only 快照和 `wait --text` 通过，含引号和反斜杠的字段原值保留；原私有 App 同版 SDK 待复验 |
| #238 | 已有ArkWeb text-frame与transport/protocol/page错误分型沿用 | SP-250旧真实证据保留；本轮受DevEco首次许可拦截 |
| #246 | selector-bound verified 输入沿用，公开 fixture 明确断言原始空串基线，并独立验证普通文本、空白与密码遮掩 | 本轮受 DevEco 首次许可拦截，正向待运行 |
| #274 | 默认无本地/远端 inference，显式 opt-in，不因配置开启，不在失败后 fallback | 当前候选受控 CLI/HTTP 16 项通过；原 `llama-server` 进程归属和低内存场景待验证 |

### 环境与证据界限

本轮使用自有 iPhone 17 和 iPad Air、iOS 27.0 Simulator；公开 iOS fixture 连接隔离端口 19422。Harmony 专用 HVD 启动返回 `emulator_license_agreement_required`。#238 仍需原 `pageInit` 场景证据。#246 还需真实 IME 正向输入、空串对照及 clear 控制；当前 host `act clear` 返回 unsupported。

本地原始验收文件位于 `.build/issue-batch-20261116/`，本轮新增 `takeover-*`。（[本轮结束时的 GitHub open 快照](plans/20261116-issues-after-takeover.json)）

测试开始前按发布skill先证明0.2.45 manifests拒绝0.2.46目标，再同时更新Web manifests。未手改CLIBuildInfo；最终版本由Release CI stamp。
