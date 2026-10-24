# 2026-10-24 真实验收与历史 space 收口

用户已授权先完成 SP-218 真实验收、顺带验证 SP-219，再按本聊天裁决收尾与归档 SP-126/134/177/179/183，更新索引和 memory。影响 CLI/host adapter、机器可读契约及治理文档；用户在验收后追加授权仅提交并推送本轮差异；该验收与源码提交阶段不创建远端发布或关闭 GitHub issue。随后用户另行授权的v0.2.33发布见[发布验收](20261024-v0.2.33-release.md)。

基线 `main@409670ef`。实现隔离在同级 `SP-218-issue-222-device-hub-input` worktree；主目录已有参考追踪 WIP 必须逐文件保留。主控独占设备、服务和共享构建动作。

## BDD / 验收边界

1. 创建本任务专用 Simulator，保存操作前设备清单、工具链、CLI 版本与 Triton status/doctor/capabilities/schema/plan 事实；不选择现有业务设备作为测试对象。
2. 原生 fixture 上通过 `--hid-only` tap 验证 UIKit touch 业务计数变化，通过 `sim swipe` 验证滚动后置。AX/截图仅用于观察，不能替代待测 HID 动作；ACK 不能算送达。
3. Device Hub 未占用时验证动作；占用时稳定拒绝；解除本任务占用后复验恢复。未知/失败保留真实原因，不绕过 guard、重启 SpringBoard 或伪造业务成功。
4. SP-219 只验已绑定 Resizable display 的录制：Resize on/off、目标画面、可解码与实际样本时长；AX/HID 继续安全拒绝。Triton 缺少设置入口时保存 schema 证据后使用官方/UI fallback。
5. 结束时关闭本任务创建的进程/窗口并恢复或删除自有 Simulator，保留私有原始证据；仅脱敏摘要和安全 fixture 截图进入 space。
6. 归档口径：SP-126/134 本期已完成，真实可靠性为条件触发待办；SP-177 单设备能力已交付、取消当前 fleet/编排扩张；SP-179 保留检查/预览、取消通用自动删除并修正文案；SP-183 缩小平台范围、明确历史操作遗留交接。实现、运行验收与取消分别记录。

## 结果

真实运行验收通过；当前代码联合回归与最终文档门禁结果见本页末尾。

### 真实运行

工具链 Xcode 27.1 / iOS 27.0，任务专用 iPhone 17 Simulator（402×874 pt，1206×2622 px）。Triton v0.2.32 安装版原生 HID 与录制实现和 main@409670ef 一致；本轮显示查询修复用独立 Debug CLI 候选真实验证，没有替换安装版或运行中的 server。

Release TritonKitDemo 经 `triton xcode build` 构建并通过 `triton app install/launch` 安装启动；状态为 Disabled，业务触控不依赖 embedded runtime。服务未运行时 status/doctor 的 server_unavailable 保留为实际事实，不能解释为 HID 不可用。

| 场景 | 实际命令/观察 | 结果 |
| --- | --- | --- |
| 未占用 tap | `act tap --platform ios --device sim:<owned> --at 192,366 --hid-only --json` | source=host-hid；Complex harness 0→1，passed |
| Device Hub attach | 本轮启动官方 Hub，选中专用设备；guest notify=1；同一 tap | `ios_host_hid_device_hub_attached`；计数仍1，passed |
| 离开窗口/仅重启 | Hub仍运行但切回原选择；仅重启专用 Simulator | 所有权仍1，未错误宣称恢复 |
| 显式退出/恢复 | 正常退出本轮启动的 Hub，随后仅启动专用 Simulator；fresh guest notify=0 | cold-query unknown 曾安全拒绝；稳定后 tap 0→1，passed |
| 原生 swipe | `sim swipe --simulator <owned> --start-x 340 --start-y 628 --end-x 60 --end-y 628 --duration 0.5 --json` | source=host-hid；轮播 item 1–4→item 7–10，passed |
| 截图兼容修复 | 同目标候选 `sim screenshot` | 旧版 topology queryFailed；候选通过 fresh displays gate 并输出1206×2622截图，passed |
| Resize on/off录制 | 普通→Resize→普通 | 三段实际解码通过，详见[SP-219报告](../../SP-219-simulator-resizable-routing/plans/20261024-live-recording-validation.md) |

[初态](../screenshots/20261024-hid-before-ready-v1.png) · [首次点击](../screenshots/20261024-hid-tap-passed-v1.png) · [恢复点击](../screenshots/20261024-hid-recovery-passed-v1.png) · [滑动后置](../screenshots/20261024-hid-swipe-passed-v1.png)

HID receipt 始终保留 verification.required=true / not-verified；业务完成由本次截图后置另证，不改成自动保证。观察截图在安装版失败后使用官方 simctl fallback；候选修复后真实 Triton screenshot 已通过。没有用 AX activation 或 GUI 点击代替待测业务触控。

### 发现与修复

SP-214 原实现调用本机不存在的 `devicectl device info displayTopology`，测试亦使用自拟字段。真实接口为 `displays`，含 displayId/uniqueId/primary/backlightState/type，result没有设备UUID；现在精确核对 info.arguments 和实际命令，使用正确字段，只允许一个 active primary integrated，未知/重复/多个active仍拒绝。用真实响应形状建立失败回归，5项显示安全测试通过，候选真实截图通过；不能据此宣称全部AX树或跨Xcode版本兼容。

SP-177 resource replay 现在在任何runtime解析/前序步骤前整体拒绝，保留dry-run；SP-179取消通用自动删除，保留inspect/preview及兼容错误码；sim.record schema/public skill与SP-219实际视频路由同步。

### 失败与未覆盖

- 冷启动及高主机负载时出现 Resize queryTimedOut、attachment_unknown、display_unsupported 等发送前拒绝，已保留原始输出；未放宽deadline/未知状态保护，没有在delivery unknown后自动重放。
- 误用 `act swipe --device sim:…` 进入embedded/server路由失败，不是host swipe证据；实际公共入口为 `sim swipe`，已完成业务后置。
- 正常退出Hub时专用Simulator实际进入Shutdown；随后显式启动后才验证恢复，不能把退出请求当成“模拟器保持运行”。没有杀SpringBoard、业务App或全局dtuhidd。
- 首次5s视频时长不足被正确拒绝；Resize AX/HID保持unsupported。不同Xcode/OS、其他设备类型、多击/长按、用户项目与全面DeviceHub控制未验收。

### 收尾与证据

私有原始证据保留在主目录 `.build/sp218-live-20261024/`（包括CLI hash、原始JSON、视频、设备前后清单），不提交原始设备身份或用户设备名。space只保存安全Demo截图、脱敏摘要。验收阶段未操作远端issue、push、release、计划任务或Git提交；后续源码提交与推送由用户另行授权。

环境恢复：本次专用 Simulator 已通过 Triton shutdown 后由官方 simctl delete 删除（Triton无delete入口，schema失败事实已保留）；自有Resize进程和Hub已退出。原18个Simulator身份仍全部存在。终态有1个原设备由Shutdown变为Booted，本任务没有向它发送显式设备命令，也没有为“恢复快照”擅自关闭它；因此不宣称全机状态逐字恢复。私有对照为 environment-restoration.json。

回归已通过：显示安全focused 5 tests；完整CLI `swift test --package-path CLI --no-parallel` 1515 tests / 153 suites。首次focused含冷构建1387.8s；CLI完整运行177.7s，未将编译时间当测试性能。最终候选整合回原main工作目录前逐文件核对已有WIP基线，未覆盖参考追踪资料。`verify.sh --ci-docs`、独立 `check-docs.sh`、`git diff --check` 通过：220 spaces、经验路由28项、public skills打包13项等门禁无失败。主目录 `TRITON_VERIFY_XCODE=0 verify.sh --local` 已退出0：根包XCTest及Swift Testing 108+293、Release CLI构建（925.72s）、Release CLI smoke、Harmony host smoke、iOS runtime observe smoke、文档结构与diff检查全部通过。此env仅跳过总门禁的重复Xcode构建，本轮此前已完成真实Release Demo build/install/launch；不把跳过项记为本次总门禁执行。

运行跟踪经验已写回ops skill及EXPERIENCE：长构建进度必须绑定本任务session、cwd/scratch与父子PID，不能将另一并行构建的同名进程当作本任务状态；本次成功以该verify命令退出码和日志为准。原始门禁日志保存在私有证据目录的 `validation/`。

临时worktree收口：全部51份候选源码/文档/安全证据与main逐字节一致；私有 `worktree-closeout.tar.gz` 及 `worktree-final.patch` 已生成并读回校验。随后仅还原该工作树的本轮修改，普通移除干净worktree及无新提交的基线分支；该阶段main保留未提交最终差异，未使用stash/强制删除/重置用户main。原参考追踪6份非共享WIP的patch逐字节不变。

### 源码提交边界

验收后用户授权提交并推送本轮52份修复、测试、文档和安全截图。5份共享文档按开工前快照分离段落；10月22/23参考日检、SP-193/SP-207追踪、SP-219既有许可证纠正及其他原有WIP保留在工作区，不纳入本次提交。源码与测试保持已通过完整CLI和本地门禁的候选，分离后的文档树另跑门禁；该阶段由`c0ce0cc2`提交推送且CI通过，不包含tag、Release或issue关闭。后续v0.2.33发布按用户追加授权单独验收，不改写本页历史证据。

提交前验证：精确暂存树导出副本的独立 `check-docs.sh` 通过；纯导出副本运行 `--ci-docs` 在skill打包读取Git元数据时退出（无Git仓库），不是源码/文档断言失败。主仓完整 `--ci-docs` 随后通过，public skills与验证脚本与暂存候选一致；暂存差异空白检查通过。代码/测试仍与此前完整回归候选逐字节一致。
