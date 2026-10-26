# SP-221 — Simulator资源状态只读重试

## 边界与来源

2026-10-26由SP-207日检评估采用；来源[simslim 2c68da93](https://github.com/MobAI-App/simslim/commit/2c68da93700aa1a1c45ce31a7ea9f7cac2174ddc)，固定MIT许可全文hash `8b65667572b02a584c03c2977372eeb5fe8de0e228211b6f83033c458cc10b4e`。独立实现，不复制Go源码。基线main@24e7d0f2。影响CLI/host资源状态reader，HTTP/shared/Web无新契约；不扩大SP-177已归档资源管理范围。

本地readOverrides对明确launchd boot/teardown拒绝只读一次就失败；apply/restore/verify的状态读取可受影响。这是静态可复现可靠性差异，未在本机设备重现。只重试同一精确UDID的print-disabled；不重放enable/disable/boot、动作未知或全局runner。

## BDD与验收

- Given同一有效UDID，首次明确launchd_sim124或Domain is tearing down，When读override，Then有限次数/总预算内只读重试，第二次严格有效结果才成功；argv/目标不变。
- Given真实runner抛HostCommandRunError.nonZeroExit（而非fixture只返回result），When可识别暂态，Then同一生产reader路径重试；错误命令目标/argv不匹配不重试。
- Given权限/永久错误、截断stdout/stderr、畸形/重复payload、超时/cancel/任意throw，Then立即保留原失败语义，不将它们作为暂态重试。
- Given持续暂态或耗尽预算，Then有界失败；不无限等待、不输出成功map；无mutation命令。
- Givenapply/restore处于查询失败或mutation错误，Then有副作用命令从不自动重放，保持现有拒绝和三方恢复语义。

文件面：Sources/TritonKitCLI/CLISimulatorResourceState.swift、CLI/Tests/TritonKitCLITests/SimulatorResourceStateTests.swift；需要其他实现文件先交主控。先失败测试，再最小实现；保留真实非零throw和返回result两路径、预算/不可重试反例。focused/full CLI与适用root/docs门禁串行。真实Simulator/跨进程竞态不执行；离线通过不证明设备恢复概率。

状态：执行中；真实执行thread `01a175fc-c9c4-7053-b91e-74c209d3f0ca`，branch `feat/SP-221-simulator-resource-read-retry`，worktree `../TritonKit-worktrees/SP-221-simulator-resource-read-retry`。主控[SP-222](../SP-222-simulator-resource-retry-integration/README.md)真实thread `01a175fd-5c91-7b52-bc7c-683468efff9f`。两会话create_thread均显式gpt-6.1-sol且创建成功；不再沿用旧模型校验失败作为本批阻塞。当前未形成通过验收候选；通过后继续必要本地提交并合main，不push/tag/release。
