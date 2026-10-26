# 2026-10-26 agents / Revyl 官方参考日检

影响层：CLI/HTTP/shared core静态对照；实际main固定24e7d0f21017c8ca7104b6f8e3912fc2c44be892，与昨日相同。12仓官方默认HEAD、完整Release分页（含prerelease、全部非draft body）与固定HEAD许可证全文/hash已查询，5 complete / 7 partial，无网络失败或重试。7仓许可404、generated/pyc及历史来源缺口保持partial，不推进成功点；现有共享WIP只读保留。

| 仓库 | HEAD | Release | 覆盖 | 相对昨日 |
|---|---|---|---|---|
| getsentry/MobileBuildMCP | `2998ac77ebbca59544e88a27f34bfb830db9d924` | v2.7.1 | complete | 未变 |
| awizemann/harness | `3f58c077ded131cca71d75efb05c5d325f0ed18f` | v0.8.4 | complete | 未变 |
| dongxinsuperman/ai-phone | `d339057bc64aa85002570765e2a20d45e0391bae` | v0.8.0 | complete | 未变 |
| karminski/eyes-on-my-phone | `eef71926e613c3242643923bb21c92beab439990` | 无 | partial | 未变 |
| RevylAI/revyl-cli | `ecbe45690fe4605acf7faa62dac7afcccd3690a9` | v0.1.188 | partial | 变化 |
| RevylAI/app-explorer | `b3edc443dbfbd8fe84b0fb0bc7c3190cb233c41e` | 无 | partial | 未变 |
| RevylAI/greenlight | `fcb36e395bd4ae20448f2535382baecba9396fd9` | v0.2.0 | complete | 未变 |
| RevylAI/mobile-devtools | `efc1dae5da089ec08108a39f1ead39324c11b410` | 无 | partial | 未变 |
| RevylAI/mobile-pr-reviewer | `ba1250c72f56a08f3718aefc82dc911c1b3a2f23` | 无 | partial | 未变 |
| RevylAI/visual-regression | `2758e8a88f4efb3a251b675e0984c091bf8abeb8` | 无 | partial | 未变 |
| RevylAI/figma-design-checker | `8b4e5cea045dcff5c30aa723b923e514d2cdc07a` | 无 | partial | 未变 |
| RevylAI/CogniSim | `3d8902e011981b93cb0ebfafba1794eab93b053e` | 无 | complete | 未变 |

## 新增量与来源边界

[Revyl CLI固定HEAD](https://github.com/RevylAI/revyl-cli/tree/ecbe45690fe4605acf7faa62dac7afcccd3690a9)相对昨日4238272a新增3 commits/17最终路径，13项允许文本固定HEAD全文均保存；两生产改动和测试补丁、三提交文件面已检查。4个pyc未请求，历史generated/openapi来源缺口与许可404未闭合。请求前用途白名单见source-request-allowlist.json，文本全文hash/行数见source-read-manifest.json。无新增/消失的中间路径未覆盖。

[托管MCP轮询](https://github.com/RevylAI/revyl-cli/blob/ecbe45690fe4605acf7faa62dac7afcccd3690a9/internal/mcp/device_session.go)将step_status只读轮询间隔上限5s降至1s，瞬时网络/408/429/502/503/504允许15s连续失败，成功响应重置时钟；429/503透传Retry-After，受总timeout限制。其它4xx/5xx快速失败，测试覆盖取消、持续失败与delay上界。它重复的是GET状态读取，没有重放execute_step动作，不能把此策略迁移为本机动作自动重放许可。[API客户端](https://github.com/RevylAI/revyl-cli/blob/ecbe45690fe4605acf7faa62dac7afcccd3690a9/internal/api/client.go)的402提示优先保留服务器原因，已有原因时缩短generic billing建议。

[computer说明](https://github.com/RevylAI/revyl-cli/blob/ecbe45690fe4605acf7faa62dac7afcccd3690a9/docs/computer-runs.md)将Linux从contract-only改为仅allowlisted组织+配置Linux host，仍无Linux app hosting。版本文件0.1.188→0.1.190；公开最新非draft Release仍[v0.1.188](https://github.com/RevylAI/revyl-cli/releases/tag/v0.1.188)，不把源码版本当已发布产物。Python锁文件为版本/依赖marker和wheel集合整理，无执行或安装。README MIT声明不能替代固定HEAD完整LICENSE，仍404。

## 实际main差距与裁决

无新增可纳入的具体本地缺口，不生成推测BDD。当前无Revyl式托管accepted step_id/step_status协议、billing配额或云computer provider；本机waitForIOSHostText（CLIIOSHostWaitRuntime.swift）直接观察AX并保留失败，录制start/stop（CLIDeviceRecordingRuntime.swift）基于本机记录存储/worker及独立deadline，失败保留state。上游降低托管HTTP延迟或容忍瞬时状态读取失败不能证明本机入口存在相同缺陷；不为通用优化新增云控制面或自动重放。CLIHostDeviceProxyServer.swift现有Retry-After输出也不构成相同客户端协议。

已对照SP-192/196/200/203～205/216及采用登记，alias/预算/unknown、设备能力、发现/日志/Runner鉴权、HDC归属为已交付机制，不重复分派。SP-218/219于2026-10-24本机Xcode27.1/iOS27.0独立证明普通native HID、Device Hub占用拒绝恢复、普通→Resize→普通录制并发布v0.2.33；当前main已含displays真实接口修复。本巡检未执行设备，不沿用旧未验断言；Resize AX/HID仍unsupported，其他工具链和用户项目另验。CLIDeviceEnvironmentRuntime.swift:106的iOS Duo fold仍安全unsupported，今日上游无本机transport新证据。

其余11仓HEAD/Release/许可hash与昨日一致，沿用固定源审阅及partial限制。成功点/import和20261025观察分别比较，旧未闭合差异不重复计今日变化。

## 执行与治理

只读官方取证；未执行第三方代码、二进制、设备、安装、build/test、远端写入、线程或subagent。仅写.build/reference-monitor/20261026/agents-revyl/，不改共享docs/state/git。已核对AGENTS、ops-governance/subagent-supervision、经验参考路由与workflow；复用现有许可/文本白名单/partial规则，无新增可复用经验，主控统一回写。
