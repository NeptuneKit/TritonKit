# SP-223 — 宿主进程退出后的有界输出收尾

影响层为CLI host-process执行/输出采集，不新增HTTP/Web/schema控制面。

## 来源与实际缺口

参考[sim-use c065434](https://github.com/lycorp-jp/sim-use/commit/c065434be4fddceea59024fc74d79b5a8f8f1f32)与[923415fb](https://github.com/lycorp-jp/sim-use/commit/923415fbf0fc066edfb7695e4a408189d47351a7)的Viewer输出收尾思想，准确完整SHA以SP-207补查机器证据commits.json为准；本轮只独立实现同类防挂起机制，不复制上游代码。sim-use固定HEAD Apache-2.0全文hash见[SP-207补查](../SP-207-reference-adoption-pipeline/plans/20261026-partial-recovery.md)，不套用外部分发依赖。

main@8fcd856f的runHostCommand正常退出后stdout/stderr group.wait无期限；自有原函数提取probe命令预算0.25s、主进程约0.01s退出，后代持FD2.5s时实际2.52s才返回。该证据非正式CLI E2E，需正式测试再复现；两artifact路径相似代码仅静态风险。证据位于`.build/reference-monitor/20261026-followup/host-drain/`，实现前复制必要小型证据到本space。

## BDD与验收

- 给定直接子进程已退出、后代保留stdout或stderr，必须在明确post-exit输出收尾预算内完成；不自动kill未拥有的后代，不自动重放命令。
- 给定尾部合法输出/大输出/非零退出，保留完整可获取字节、字节计数与既有错误语义；未EOF不得伪造完整成功。收尾预算不足返回明确失败或不完整标识，机器envelope仍单一。
- 三条runner（内存、stdout artifact、combined artifact）分别以自有真实shell/FD回归验证；超时/取消和读写错误不得静默变成功；close不会阻塞、后台线程状态无数据竞态。
- 测试有外部监督预算与自有PID清理，不留下孤儿/影响其他进程。先旧代码失败、再最小修复，完整CLI及适用root/local/docs由主控验证。

## 文件面与边界

执行仅拥有Sources/TritonKitCLI/CLIHostProcessRuntime.swift、新增配套CLIHostProcess*内部实现（如必要）、CLI/Tests/TritonKitCLITests中新独立HostProcessDrainTests.swift和本SP-223目录。不得修改已有巨型测试、公共DTO/Shared/HTTP/Web或其他space；如确需越界先回报root。不更改进程树管理/远程或设备功能。紧耦合三runner同切片。

分支feat/SP-223-host-process-drain-deadline，同级worktree。执行候选本地必要提交；不push/tag/release、安装依赖、设备、第三方代码运行，不stash。主控SP-224独立审查真实diff、正式红绿/完整测试、残留进程与输出完整性后才合main。

## 当前阶段

已分派实现中，正式三runner红测试已复现；候选须经SP-224独立验收后才合main。

真实thread `01a1773d-1703-7152-bfa0-a6e452491809`，显式gpt-6.1-sol；同级worktree/feat分支已建，已分派，尚未验收/合并。
