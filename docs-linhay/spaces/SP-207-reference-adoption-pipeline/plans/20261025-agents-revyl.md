# 2026-10-25 agents / Revyl 官方参考日检

影响层为CLI/HTTP/shared core静态对照，实际main固定24e7d0f21017c8ca7104b6f8e3912fc2c44be892，与昨日一致。12仓官方默认分支HEAD、完整Release分页（含prerelease、非draft完整body）、固定HEAD许可证全文/hash查询完成，5 complete / 7 partial。无网络失败或重试。7仓许可404与历史来源缺口保留，不推进成功点。当前WIP只读保留。

| 仓库 | HEAD | Release | 覆盖 | 相对昨日 |
|---|---|---|---|---|
| getsentry/MobileBuildMCP | `2998ac77ebbca59544e88a27f34bfb830db9d924` | v2.7.1 | complete | 未变 |
| awizemann/harness | `3f58c077ded131cca71d75efb05c5d325f0ed18f` | v0.8.4 | complete | 未变 |
| dongxinsuperman/ai-phone | `d339057bc64aa85002570765e2a20d45e0391bae` | v0.8.0 | complete | 未变 |
| karminski/eyes-on-my-phone | `eef71926e613c3242643923bb21c92beab439990` | 无 | partial | 未变 |
| RevylAI/revyl-cli | `4238272acc9d4fc020f92645e29cb9acc4df967c` | v0.1.188 | partial | 变化 |
| RevylAI/app-explorer | `b3edc443dbfbd8fe84b0fb0bc7c3190cb233c41e` | 无 | partial | 未变 |
| RevylAI/greenlight | `fcb36e395bd4ae20448f2535382baecba9396fd9` | v0.2.0 | complete | 未变 |
| RevylAI/mobile-devtools | `efc1dae5da089ec08108a39f1ead39324c11b410` | 无 | partial | 未变 |
| RevylAI/mobile-pr-reviewer | `ba1250c72f56a08f3718aefc82dc911c1b3a2f23` | 无 | partial | 未变 |
| RevylAI/visual-regression | `2758e8a88f4efb3a251b675e0984c091bf8abeb8` | 无 | partial | 未变 |
| RevylAI/figma-design-checker | `8b4e5cea045dcff5c30aa723b923e514d2cdc07a` | 无 | partial | 未变 |
| RevylAI/CogniSim | `3d8902e011981b93cb0ebfafba1794eab93b053e` | 无 | complete | 未变 |

## 新增量与完整性

[Revyl CLI固定HEAD](https://github.com/RevylAI/revyl-cli/tree/4238272acc9d4fc020f92645e29cb9acc4df967c)相比昨日8fe715c3为2 commits/5最终路径。两提交明细与完整Markdown全文已读；4个pyc仅登记路径，不请求二进制。允许请求前已保存语义用途白名单source-request-allowlist.json。历史generated/openapi/hosted来源缺口和许可404未闭合，保持partial，不把局部文本审阅视为整体恢复。

唯一文本变化[device-infrastructure.md](https://github.com/RevylAI/revyl-cli/blob/4238272acc9d4fc020f92645e29cb9acc4df967c/docs/device-infrastructure.md)：澄清Web swipe用页面方向、原生iOS/Android用手指方向；桌面Web原生HTML select及页面日期下拉临时使用in-page picker，关闭后恢复。两提交均无本机移动控制实现变更。[v0.1.188](https://github.com/RevylAI/revyl-cli/releases/tag/v0.1.188)取代昨日v0.1.185为最新非draft Release；全部分页及body已保存，body仅安装、分发、skill与checksum说明，无新增功能差距依据。未执行安装指令。

其余11仓身份/发布/许可全文hash相对昨日一致，保留已有固定源审阅和partial限制。对成功检查点/import与昨日观察独立比较，不将历史未闭合差异当作今日新变更。

## 本地差距与采用裁决

无新增可执行采用项，不生成推测BDD。当前Web是React/Vite mock，WebView表单在CLIWebViewCommands.swift提供opt-in显式入口；上游托管桌面Web的in-page picker说明不能推导本机iOS/Android缺陷。CLIAction/host swipe已有坐标或原生方向语义，文本澄清没有指出本地可重现问题。

已对照SP-192/196/200/203～205/216与采用登记：alias/预算/unknown、设备能力、发现/日志/Runner鉴权、HDC归属均为既有机制，不重复分派。main的CLIDeviceEnvironmentRuntime.swift:106仍对iOS Duo fold安全unsupported；上游今日没有新增本机transport。SP-218/219于2026-10-24独立完成本机Xcode27.1/iOS27.0普通native HID、Device Hub占用拒绝恢复、普通→Resize→普通录制并发布v0.2.33；本巡检只核对已有证据，未执行设备，不再沿用旧未验断言。Resize AX/HID仍unsupported，其他工具链和用户项目另验。

## 边界与治理

仅官方只读取证；未执行第三方代码、二进制、安装、build/test、设备、远端写入、线程或subagent。只写本任务.build/reference-monitor/20261025/agents-revyl/。已读AGENTS、ops-governance、subagent-supervision、经验索引参考路由和参考采用流程；复用现有白名单/许可/partial规则，无新可复用经验，主控统一回写。
