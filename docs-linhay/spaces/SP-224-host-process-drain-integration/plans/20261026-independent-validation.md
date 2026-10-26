# SP-224 独立候选验收（2026-10-26）

## Requested

仅验收 SP-223 CLI 三 runner 的退出后管道收尾；不改变设备、HTTP/Web、公共 DTO 或进程树生命周期。按 root 授权串行整合 main 文档基线和冻结候选，核对原始红绿证据，独立 focused/full CLI、实际产物单 envelope、文档结构与进程清理。主目录用户 docs WIP、共享索引/state/memory 均未改。

## Observed

执行候选完整 SHA 为 `25205ea2f0c1e549c0c6777b2e045e3a7f7088e0`，文档基线 `f86e9cb1434a8c658a9b0575803b3dcec7ba71a6`，本 worktree 联合提交 `80922842f64f8a24ce49902d3ecac54c18a1a63e`，tree `1dc074cc8273fb9279820c1bb503ddcc127a18f9`。仅 SP-223 README add/add 冲突，保留一份规划和候选证据；生产函数、新 drain、测试三文件与候选及执行 manifest 的 SHA-256 全部一致，运行后重核一致。未添加依赖或修改锁文件。

实现以 O_NONBLOCK read + 10ms poll、共享单调时钟 post-exit 0.25s 预算避免继承 FD 无限等 EOF；持续可读时仍检查截止。worker 独占读端与关闭，结果 join 后经锁读取。只有 read==0 判为 EOF，读取错误和截止分开。普通 EOF 非零退出保留既有语义；未 EOF 用内部 `HostProcessOutputFailure` 同时保留 cause、实际 exitCode、部分内存结果/计数与 artifactBytes。artifact 不完整结果删除部分文件，错误中保留计数，不对外提供 partial artifact DTO。

## Evidence

- [机器清单](validation/manifest.json)绑定实际 worktree、联合候选、tree、环境与产品 hash；Apple Swift 6.4，arm64 macOS。所有执行候选已提交的验证日志 hash 已与其 manifest 逐项匹配。
- 正式旧实现红测证据已复核：[原始三测试版本](../../SP-223-host-process-drain-deadline/plans/validation/red-test-source.swift.txt)、[红测](../../SP-223-host-process-drain-deadline/plans/validation/red.log)。三 runner × stdout/stderr 继承 FD 六场景，18 条实际行为断言失败，旧代码等待后代自然退出，约 18.176s；其余大输出/普通非零对照通过。此处是独立审查既有红测，不宣称本会话重跑旧代码。
- 初版退出事实丢失经[review-red](../../SP-223-host-process-drain-deadline/plans/validation/review-gap-red.log)复核：两测试六参数场景共 6 条断言失败，因缺内部 partial/exit 结果；持续可读的初版本身已能截止，不能把这 6 条失败误述为持续写无法截止。冻结候选的[执行聚焦绿测](../../SP-223-host-process-drain-deadline/plans/validation/green.log)为 50 tests / 2 suites / 13.122s。
- **通过，独立 focused**：[日志](validation/focused.log)、[命令/退出记录](validation/focused.json)，50 tests / 2 suites / 13.091s，wall 111.175s 含联合重编译，exit0，外部 watchdog300s未触发。提交日志保留 Build complete 起完整连续输出，编译噪声原始日志 hash / ignored 归档路径保留在 manifest。
- **通过，独立完整 CLI**：[日志](validation/full-cli.log)、[记录](validation/full-cli.json)，Swift Testing 1527 tests / 154 suites / 34.649s，另 XCTest 91 tests / 0 failures / 4.654s，wall46.124s，exit0，外部 watchdog1200s未触发。两次均使用 `swift test --package-path CLI --no-parallel --disable-automatic-resolution --skip-update`，focused 追加 `--filter 'HostProcessDrainTests|SimulatorAdvancedControlsTests'`。未把 focused 和 full 重叠计数相加。
- **通过，实际 CLI 安全 fake 入口**：[可复跑脚本](validation/check-cli-envelope.py)、[四场景记录](validation/cli-envelope-cases.json)、[外部监督摘要](validation/cli-envelope.json)。本候选 debug/triton 的真实 `device list --platform android --scope emulator --adb <自建fake> --json`，成功、普通 exit7、未EOF exit0、未EOF exit7 均只产生一个合法 JSON envelope；后三者非零退出，未EOF code=`host_output_incomplete`，最后一项消息保留 `exitCode: 7`。每例 fake 仅收到一次 `devices -l`，无重放；未EOF返回均低于1.5s，holder在fixture精确PID清理前存活。未调用真实 adb/设备/服务。首次详细文件与watchdog摘要同名被覆盖，经root审查指出后改为分文件并只重跑四场景；这是证据路径修正，产品未变，无需重跑完整CLI。
- **通过，外部监督与清理**：[watchdog](validation/run-watchdog.py)只对自建 session group 超时清理；正常测试 fixture 仅清理自建 shell 记录 PID，持 FD sleep 有自然上限3s。[本次自有组检查](validation/owned-process-groups.json)为空；执行的自有组清理证据另在其 space。未对名称扫描出的未知进程发信号。
- **通过，文档门禁**：[verify --ci-docs](validation/ci-docs.json)与[完整输出](validation/ci-docs.log)、[check-docs](validation/check-docs.json)与[完整输出](validation/check-docs.log)均 exit0，224 spaces 结构通过。`git diff --check`通过；最终证据提交前再检查候选与文档差异。

两次 CLI 测试与真实 CLI 均显式绑定本 worktree `CLI/.build/debug/triton`；临时 `CLI/.build` 软链接复用 root 已有缓存，测试时段经 root 串行授权，无并发构建。已核对并移除本次创建的 link，未删除缓存目标或 stage link；运行时路径与产物hash保留于机器记录。

## Gaps / Fixes made

[候选前审查](20261026-static-review.md)的三 runner 无界等待、读错误伪装 EOF 与退出码丢失均已由冻结候选及组合反例解决。本会话未修改生产实现，整合只处理 README 冲突并新增本 space 验收证据。没有新发现的阻断性产品缺口。

## Remaining risk

0.25s 是管道收尾预算，不能对调度停顿或同步 artifact open/write/close 的慢/故障文件系统承诺硬总截止；测试只注入 read/setup/sink 回调错误，未注入真实磁盘耗尽/close故障。没有线程 sanitizer 运行，本结论基于所有权/锁审查和实际回归。同步大 stdin 的旧行为、进程树管理不在本轮范围；关闭读端后后代未来写入可能自行收到 EPIPE/SIGPIPE，不等于 runner 主动 kill 未知后代。

root/local、main 合并及合后门禁仍待 root；发布、安装替换、设备/签名/DDI、第三方实现执行和用户真实场景未执行。本报告只证明上述联合候选的本机独立验收。

经验检查已完成：复核命中 CLI 单 envelope、候选绑定/正式反证与原 space 记录；新增审查纠正保留在 SP-223 原记录和本报告中，同一事件不另建共享经验项。通用 skill / memory / state 收口交 root，未越权写入。
