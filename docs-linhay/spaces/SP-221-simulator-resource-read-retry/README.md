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

状态：已验收合本地main；真实执行thread `01a175fc-c9c4-7053-b91e-74c209d3f0ca`，branch `feat/SP-221-simulator-resource-read-retry`，worktree `../TritonKit-worktrees/SP-221-simulator-resource-read-retry`。主控[SP-222](../SP-222-simulator-resource-retry-integration/README.md)真实thread `01a175fd-5c91-7b52-bc7c-683468efff9f`。两会话create_thread均显式gpt-6.1-sol且创建成功；不再沿用旧模型校验失败作为本批阻塞。已形成离线通过候选并合入main a0eebff0；合后CLI/root通过，合后local/docs门禁已通过，现标local_merged，不push/tag/release。

2026-10-26候选冻结：`eb9539f48df4ea6a0e1cf3de6828b8d8177c8017`，生产reader与State测试、Mutation测试来源fixture对齐共3文件；先红10项/3失败，最后focused37/37通过。主控先后拒绝substring诊断、成功来源未绑定及tracked patch证据不一致，已修复，产品hash与最终日志绑定。完整CLI与合main尚待SP-222；候选完成不等同验收合并。


## 冻结执行证据与后续主控

# SP-221 — Simulator资源状态只读重试

## 边界与来源

2026-10-26由SP-207日检评估采用；来源[simslim 2c68da93](https://github.com/MobAI-App/simslim/commit/2c68da93700aa1a1c45ce31a7ea9f7cac2174ddc)，固定MIT许可全文hash `8b65667572b02a584c03c2977372eeb5fe8de0e228211b6f83033c458cc10b4e`。独立实现，不复制Go源码。基线main@24e7d0f2。影响CLI/host资源状态reader，HTTP/shared/Web无新契约；不扩大SP-177已归档资源管理范围。

基线readOverrides对明确launchd boot/teardown拒绝只读一次就失败；apply/restore/verify的状态读取可受影响。这是静态可复现可靠性差异，未在本机设备重现。只重试同一精确UDID的print-disabled；不重放enable/disable/boot、动作未知或全局runner。

## BDD与验收

- Given同一有效UDID，首次明确launchd_sim124或Domain is tearing down，When读override，Then有限次数/总预算内只读重试，第二次严格有效结果才成功；argv/目标不变。
- Given真实runner抛HostCommandRunError.nonZeroExit（而非fixture只返回result），When可识别暂态，Then同一生产reader路径重试；错误命令目标/argv不匹配不重试。
- Given权限/永久错误、截断stdout/stderr、畸形/重复payload、超时/cancel/任意throw，Then立即保留原失败语义，不将它们作为暂态重试。
- Given持续暂态或耗尽预算，Then有界失败；不无限等待、不输出成功map；无mutation命令。
- Givenapply/restore处于查询失败或mutation错误，Then有副作用命令从不自动重放，保持现有拒绝和三方恢复语义。

文件面：Sources/TritonKitCLI/CLISimulatorResourceState.swift、CLI/Tests/TritonKitCLITests/SimulatorResourceStateTests.swift；主控追加授权 SimulatorResourceMutationTests.swift 仅对齐一处 fixture sourceCommand，不改断言。需要其他实现文件先交主控。先失败测试，再最小实现；保留真实非零throw和返回result两路径、预算/不可重试反例。focused/full CLI与适用root/docs门禁串行。真实Simulator/跨进程竞态不执行；离线通过不证明设备恢复概率。

## 实现与候选边界（2026-10-26）

已完成局部 reader 实现，待 SP-222 主控审查、完整门禁与 main 整合。执行 worktree 为 `/Users/linhey/Desktop/linhay-open-sources/TritonKit-worktrees/SP-221-simulator-resource-read-retry`，分支 `feat/SP-221-simulator-resource-read-retry`。本会话不合 main、不写共享索引/memory/adoption-state、不做远端写入。

- 最多三次相同 executable/argv/精确 UDID 的 `launchctl print-disabled system`；单调时钟覆盖命令耗时与 0.1/0.2 秒退避，30 秒配置执行预算，每次 timeout 收敛到剩余预算。
- 只接受完整诊断行：exit124 的 `Failed to start launchd_sim: could not bind to session, launchd_sim may have crashed or quit responding` 或非零退出的 `Domain is tearing down`。可带唯一、同 code 的 `An error was encountered processing the command (domain=NSPOSIXErrorDomain, code=<exitCode>):` 前导行；多余/未知上下文不重试。普通124、字符串子串、永久错误混入暂态文字均拒绝。
- 重试要求空白 stdout、有效 UTF-8、stdout/stderr 都未截断，以及匹配的 sourceCommand。抛错路径还要求 error.command 完整等于本次 issued command（含 timeout、环境等字段）。成功也校验 sourceCommand 与严格 payload；合法成功允许非空 stderr。
- 成功/错误 envelope 和 parser 不扩展；返回失败结果最终仍为 commandFailed，真实 nonZeroExit 保留原 command/result；其他 throw 原样退出。取消在读前、返回后、退避期间及再次执行前检查，不自动重放 mutation。
- 30 秒是传给 runner 的执行预算，不是硬墙钟上限；既有 host runner 的 terminate/drain 清理可额外耗时。同步 runner 在途不会被本实现主动中断，取消可在返回后阻止后续重试；退避每不超过10ms检查取消。
- 完整诊断白名单刻意保守；未捕获的新原生诊断形状保持失败，不能凭子串扩展。所有暂态测试为离线夹具，未在真实 Simulator 重现，不证明设备恢复概率或跨进程状态稳定。

证据见[红测试](plans/20261026-red-evidence.md)、[精确首轮测试快照](plans/20261026-red-tests.swift.txt)和[候选交接](plans/20261026-candidate-handoff.md)。主控[SP-222](../SP-222-simulator-resource-retry-integration/README.md)拥有整合、共享文档与完整 CLI 时段。新会话显式 model=gpt-6.1-sol，不回退。

## 本轮经验沉淀

生产 runHostCommand 非零时直接抛 HostCommandRunError.nonZeroExit；只测 fake 返回结果会漏掉真正调用路径。先以旧reader取得实际断言失败，再分别测返回/抛错、完整命令绑定、严格诊断、预算与取消反例。成功来源绑定收紧后，旧 mutation fixture 固定字符串导致四个失败；获主控授权后只对齐 sourceCommand，未放宽产品规则或原断言。后续诊断匹配须保留“暂态文字出现在无关错误中”的反例，并明确配置预算与 runner 清理时间的区别。本轮沉淀留在本 space；共享 skill/memory/索引交主控整合。


主控SP-222在联合候选4249bd26/tree3a1e130e验证focused37/37及完整CLI（XCTest91、SwiftTesting1515/153 suites，3个真实环境测试跳过）退出0。root整合本候选后仍须合后门禁；此处不提前标local_merged。


## 最终整合验收

实际main合并`a0eebff06564dcf68ccf728efc97ec2d4f3d9292`，SP222独立focused37/fullCLI通过；actualmain合后XCTest91、SwiftTesting1515/153 suites（3真实环境skip）、root5+108+293、适用local及ci-docs/check-docs/diff通过。30s为配置执行预算含退避与各次timeout，不含runner额外清理；真实设备恢复/跨Xcode未测。未push/tag/release。证据见SP-222/plans/20261026-main-merge.md；当前候选/历史开发段均为过程记录，以此最终验收接替未完成断言。
