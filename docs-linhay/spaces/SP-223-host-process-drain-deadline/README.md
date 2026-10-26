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

执行候选已完成聚焦验证，待 SP-224 独立审查与主控整合；详见下方执行记录。

## 2026-10-26 执行候选

实现与聚焦验证完成，待 SP-224 主控独立审查及整合；本目录不是 main 已交付声明。执行会话 `01a1773d-1703-7152-bfa0-a6e452491809`，基线 `8fcd856f2927fa81754bb3e10b80d066c0591f37`。共享索引、memory 与整合状态由 root 维护，本切片不写。

- 三 runner 共用 0.25s post-exit drain budget，使用非阻塞 POSIX read + 最长 10ms poll；仅真实零字节读取判定 EOF。读端由其 worker 自行关闭，主线程等待 worker 完成，再读取加锁结果。
- 未 EOF 返回 `host_output_incomplete`，读端错误返回 `host_output_read_failed`，沿现有 failHostCommand 输出单一 envelope；输出/关闭写入错误仍走既有 launchFailed 失败语义。不自动重放、不递归 kill 后代。
- 正式旧生产函数红测：六个继承 stdout/stderr 场景共 18 条断言失败，约 18.176s；大输出与非零退出对照通过。红测中 holder 已自行结束，存活断言失败不代表 runner 曾 kill 后代。
- 最终聚焦绿测：50 tests / 2 suites / 13.122s，其中新增 HostProcessDrainTests 为 12 个测试定义（含参数化场景），以及现有 SimulatorAdvancedControlsTests。保留了初次绿测和错误注入 fixture 崩溃的真实历史，不混计重复测试。
- [验证报告](plans/20261026-candidate-validation.md)、[机器清单](plans/validation/manifest.json)、[正式红测](plans/validation/red.log)、[最终绿测](plans/validation/green.log)、[watchdog](plans/validation/run-focused.py)。

经验沉淀限定本 space：截止必须在直接子进程退出后生效，区分 EOF / deadline / read error，不能通过另一线程 close 阻塞 FileHandle 读来保证截止；异常测试不要访问已关闭 Foundation FileHandle 的 fileDescriptor（macOS 会抛 Objective-C 异常）。下次复用本回归和 watchdog；公共流程推广由 root 判断。

独立审查修正：初版 drain 失败会遮住直接子进程非零退出事实。新增 exit7+未EOF 与持续可读的三 runner 反例在初版产生 6 条实际断言失败；现内部 `HostProcessOutputFailure` 同时保留 cause、实际 exitCode、两 stream 的部分结果/观察计数及 artifactBytes，envelope 文本保留退出码与计数。普通 EOF 的非零退出仍使用原 nonZeroExit 语义。新加原始非 UTF-8 尾字节与未知 sink/error envelope 反例已通过。收尾预算只约束管道读取等待；同步 artifact open/write/close 及内核/文件系统延迟不受该预算硬截止约束。
