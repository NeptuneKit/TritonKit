# 2026-10-19 参考项目更新、采用与分派报告

## 结论与阶段

33 个登记仓完成官方默认分支 HEAD、最新非 draft Release（含 prerelease）和固定 HEAD 许可证读取；本轮完整 28 个、partial 5 个，成功检查点推进只覆盖完整仓。观察到 5 个相对记录点有变化，其中 4 个完整仓、1 个 partial 仓。iCTRL 仍按 SP-193 独立检查点保存。

本轮仍不运行上游代码、安装依赖、签名、DDI、设备或远端动作；不 push/tag/release。SP-212 的两个 mobile-mcp 候选已进入评估/待分派，但桌面接口拒绝显式 `gpt-6.1-sol`，没有伪造 thread ID。

## 有价值变化与采用边界

- [mobile-mcp `1.0.12`](https://github.com/mobile-next/mobile-mcp/releases/tag/1.0.12)：新增 Android focused activity / iOS view controller 输出，以及 legacy adb 对 `#`/`~` 的转义。实际 main 复核确认 Triton 当前前台观察缺 activity 字段、`TKAndroidADBCommand.inputText` 直接传原文；两项纳入 [SP-212](../SP-212-mobile-mcp-android-contracts/README.md)，仅限 CLI/HTTP DTO 与 fake-adb/离线契约测试，不升级 mobilewright 或做设备验证。
- [JaviSoto/device-hub-ios `58caf76`](https://github.com/JaviSoto/device-hub-ios/compare/b5994ff72d8c75d68370ae80aa3efaa4e590686d...58caf76c199457e33af1b44956016f73c302df7d)：iOS 27/Xcode 27.1 floor、SDK guard、runtime device type 与 debug fixture；属于上游 app/build tooling，SP-196/SP-200 已覆盖相关 Triton 边界，保持 observe。
- [dongxinsuperman/ai-phone `4cac05b`](https://github.com/dongxinsuperman/ai-phone/commits/main) 与 [RevylAI/revyl-cli `53a9e8`](https://github.com/RevylAI/revyl-cli/commits/main) 的 API 限流已恢复并完成完整增量阅读；未发现当前 Triton 可直接采用的新独立机制，保留 observe。
- [tddworks/baguette `v0.2.7`](https://github.com/tddworks/baguette/releases/tag/v0.2.7) 的 APK 关联构建源码/manifest provenance 仍缺，保持 partial，不推进检查点。
- [iCTRL `main@d88bbf0`](https://github.com/OpenMinis/iCTRL/commits/main) 与 [`v1.98.12`](https://github.com/OpenMinis/iCTRL/releases/tag/v1.98.12) 未变。首次 `gh api` 因本机 TLS 证书失败，随后使用官方 GitHub API 的系统 curl 完整恢复；恢复证据已保存，SP-193 检查点只在完整摘要写入后推进。
- RevylAI/visual-regression、figma-design-checker、CogniSim 本轮 GitHub API rate limit，保持旧 checkpoint 和 partial；不能报告无变化。

所有上游性能、测试数量和兼容性数字若未在 TritonKit 本地验证，只作为上游自述。评估绑定实际 main `d51403a69afbafd9426bd5ed6bfe3eb81a0ff0ec`，并核对 SP-192/196/200 与 SP-203–211。

## 逐仓库结果

| 仓库 | HEAD（短） | 变化 | 完整 | Release | 裁决 |
| --- | --- | --- | --- | --- | --- |
| [EvanBacon/serve-sim](https://github.com/EvanBacon/serve-sim) | `a30d70a55e05` | 否 | 是 | — | observe |
| [JaviSoto/device-hub-ios](https://github.com/JaviSoto/device-hub-ios) | `58caf76c1994` | 是 | 是 | — | observe |
| [Mastersam07/OpenDeviceHub](https://github.com/Mastersam07/OpenDeviceHub) | `e50f07f1f448` | 否 | 是 | v0.2.0 | observe |
| [MobAI-App/simslim](https://github.com/MobAI-App/simslim) | `6518ba7eab11` | 否 | 是 | v0.12.2 | observe |
| [OSU-NLP-Group/UGround](https://github.com/OSU-NLP-Group/UGround) | `8974f95b0685` | 否 | 是 | — | observe |
| [OpenBMB/AgentCPM-GUI](https://github.com/OpenBMB/AgentCPM-GUI) | `2168ae21b1be` | 否 | 是 | — | observe |
| [OpenMinis/iCTRL](https://github.com/OpenMinis/iCTRL) | `d88bbf0b3a5a` | 否 | 是 | v1.98.12 | observe |
| [ProxymanApp/atlantis](https://github.com/ProxymanApp/atlantis) | `cc059013de87` | 否 | 是 | 2.0.0 | observe |
| [RevylAI/CogniSim](https://github.com/RevylAI/CogniSim) | `3d8902e01198` | 未知 | partial | — | reject |
| [RevylAI/app-explorer](https://github.com/RevylAI/app-explorer) | `b3edc443dbfb` | 否 | 是 | — | reject |
| [RevylAI/figma-design-checker](https://github.com/RevylAI/figma-design-checker) | `8b4e5cea045d` | 未知 | partial | — | reject |
| [RevylAI/greenlight](https://github.com/RevylAI/greenlight) | `fcb36e395bd4` | 否 | 是 | v0.2.0 | reject |
| [RevylAI/mobile-devtools](https://github.com/RevylAI/mobile-devtools) | `efc1dae5da08` | 否 | 是 | — | reject |
| [RevylAI/mobile-pr-reviewer](https://github.com/RevylAI/mobile-pr-reviewer) | `ba1250c72f56` | 否 | 是 | — | reject |
| [RevylAI/revyl-cli](https://github.com/RevylAI/revyl-cli) | `53a9e876207b` | 是 | 是 | v0.1.174 | observe |
| [RevylAI/visual-regression](https://github.com/RevylAI/visual-regression) | `2758e8a88f4e` | 未知 | partial | — | reject |
| [RockxyApp/Rockxy](https://github.com/RockxyApp/Rockxy) | `de791b63e7f9` | 否 | 是 | v0.41.0 | observe |
| [X-PLUG/MobileAgent](https://github.com/X-PLUG/MobileAgent) | `11cea575561f` | 否 | 是 | — | observe |
| [awizemann/harness](https://github.com/awizemann/harness) | `3f58c077ded1` | 否 | 是 | v0.8.4 | covered |
| [bytedance/UI-TARS](https://github.com/bytedance/UI-TARS) | `582f3a7ea5d2` | 否 | 是 | — | observe |
| [dongxinsuperman/ai-phone](https://github.com/dongxinsuperman/ai-phone) | `4cac05b50b6a` | 是 | 是 | v0.8.0 | observe |
| [getsentry/MobileBuildMCP](https://github.com/getsentry/MobileBuildMCP) | `d13ff0c707b0` | 否 | 是 | v2.7.1 | covered |
| [google-research/android_world](https://github.com/google-research/android_world) | `30583e22b9fb` | 否 | 是 | — | reject |
| [heoblitz/Loupe](https://github.com/heoblitz/Loupe) | `ff1351242e6d` | 否 | 是 | v0.5.1 | observe |
| [hughkli/Lookin](https://github.com/hughkli/Lookin) | `95e30fdcc815` | 否 | 是 | 1.0.7 | observe |
| [jfarcand/mirroir-mcp](https://github.com/jfarcand/mirroir-mcp) | `845a981163aa` | 否 | 是 | v0.40.1 | observe |
| [karminski/eyes-on-my-phone](https://github.com/karminski/eyes-on-my-phone) | `eef71926e613` | 否 | 是 | — | covered |
| [linhay/SKProcessRunner](https://github.com/linhay/SKProcessRunner) | `24e036604b9e` | 否 | partial | 0.0.17 | reject |
| [lycorp-jp/sim-use](https://github.com/lycorp-jp/sim-use) | `81c3089331aa` | 否 | 是 | v0.15.0 | observe |
| [mobile-dev-inc/Maestro](https://github.com/mobile-dev-inc/Maestro) | `028c18b9ce74` | 否 | 是 | cli-2.11.0 | covered |
| [mobile-next/mobile-mcp](https://github.com/mobile-next/mobile-mcp) | `c659f8ee3487` | 是 | 是 | 1.0.12 | observe |
| [njucckevin/SeeClick](https://github.com/njucckevin/SeeClick) | `0ef37ac4d7aa` | 否 | 是 | — | observe |
| [tddworks/baguette](https://github.com/tddworks/baguette) | `14b39834fef6` | 是 | partial | v0.2.7 | observe |

## 不完整项与恢复条件

- Baguette：固定 APK 可读，但关联源码/manifest provenance 未建立；后续需补齐来源证据。
- RevylAI/visual-regression、figma-design-checker、CogniSim：GitHub API rate limit 导致 Release/增量未闭合；后续 API 恢复后重读。
- linhay/SKProcessRunner：许可证 API 404 且固定树无 LICENSE/COPYING/NOTICE；保持历史点但不推进当前完整 checkpoint。

## 分派与开发状态

- [SP-212](../SP-212-mobile-mcp-android-contracts/README.md)：已记录 focused activity 身份与 ADB `#`/`~` 转义两个 adopt 机制，执行 worktree 已建立。
- [SP-213](../SP-213-mobile-mcp-contracts-integration/README.md)：独立主控 worktree 已建立，负责冻结候选、联合门禁和本地 main 合并。
- 2026-10-19 两次执行 `create_thread` 均显式传 `model="gpt-6.1-sol"`；一次因 reasoning 组合无效、随后无 thinking 仍因模型校验失败，执行与主控均无 thread ID。状态保留 `dispatch_blocked_model`，不回退、不冒称开发完成。

## 证据与验证

[机器观察](20261019-observations.json)、[sim-runtime](20261019-sim-runtime.md)、[agents/Revyl](20261019-agents-revyl.md)、[research](20261019-research.md)、[分派记录](20261019-dispatch.json) 及 [iCTRL SP-193 摘要](../../SP-193-ictrl-reference-tracking/plans/20261019-check-summary.json) 均在本轮完整结果保存后生成。原始 API、Release、许可证全文和变更源码位于 `.build/reference-monitor/20261019/`。

本轮没有产品代码提交、推送或发布；docs-only 门禁见收口记录。
