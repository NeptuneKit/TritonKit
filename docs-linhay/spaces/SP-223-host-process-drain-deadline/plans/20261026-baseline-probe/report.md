# Host pipe drain 本地验证（2026-10-26）

结论：本地可复现 **runHostCommand 在主进程正常或非零退出后，因后代仍持有 stdout/stderr FD 而超过 command.defaultTimeoutSeconds 才返回**。这不是仅按代码字符串推测；Foundation control 实测 terminationHandler 在约 0.010 秒触发，远早于 pipe EOF（约 2.515 秒）。因此正常分支进入无界 group.wait，现有 timeout 分支不再约束总完成时间。

来源：main `8fcd856f2927fa81754bb3e10b80d066c0591f37` 的 `Sources/TritonKitCLI/CLIHostProcessRuntime.swift`。完整 main blob 原文保存在 `main-CLIHostProcessRuntime.swift.txt`，Git blob 与 SHA-256 见 source.json。runHostCommand、drainPipe、queue/result helper、configureHostProcessExecutable、semantic-failure 判定逐字提取；仅 TKHostCommand/HostProcessResult/error 数据类型和 source formatter 为最小 stub。没有修改正式源码。

环境与完整时间、进程 PID、退出码、stdout/stderr：result.json 和每场景 JSON。父 shell 写出 shell PID、父 probe PID 和 `$!` 后代 PID；所有后代是本轮自有 /bin/sleep 2.5。未运行设备、第三方工具、安装依赖或共享 CLI build。

## 对照结果

| 场景 | command timeout | 原函数实际完成 | 返回 |
|---|---:|---:|---|
| 普通 stdout/stderr | 0.25s | 0.022s | exit 0 |
| 后代仅保留 stdout | 0.25s | 2.520s | exit 0 |
| 后代仅保留 stderr | 0.25s | 2.512s | exit 0 |
| shell exit 7 + 后代保留 stdout | 0.25s | 2.515s | nonZeroExit，code 7 |

独立 instrumented Foundation control 的 stdout/stderr/nonzero 场景，terminationHandler 均在 0.010–0.011s 收到，保留管道约 2.51s 后才 EOF。普通场景 handler 与 EOF 均约 0.007s。

监督器每场景上限 8 秒，全部自然结束，未触发 kill；如超时只 kill 本轮 start_new_session 创建的专用进程组。probe stdout 的 thrown 文本由 harness 捕获并以进程成功退出表示 harness 完成，不应把 probe process code 0 误读为 fixture 成功。

## 边界和后续开发

这是 macOS 本地真实 Foundation + /bin/sh 的原函数提取验证，**不是已构建 triton 产物端到端验收**。本次没有发现可在不设备、不修改源码条件下安全注入自有 shell 的已构建 CLI 公共入口，故选择隔离提取。只动态验证 runHostCommand；stdout-artifact（370/371）及 combined-artifact（454）的同形等待仍只是静态候选，不能宣称这两路径也已动态复现。短寿命后代证明等待可超过 timeout，未以永久后代制造无限挂起。

建议新开发边界限定 CLI host-process I/O completion：先增加真实 shell 后代持 FD 的回归场景，确定独立 post-exit drain deadline、返回 partial/truncated/error 契约、并发读状态和有界安全关闭；分别覆盖 stdout、stderr、combined/artifact、非零退出、大输出与正常尾部输出。不要从本证据直接推断应 kill 未拥有后代，也不扩展设备/产品面。修复必须在正式测试与实际 CLI 候选中重新验证。

经验检查：本次新发现属于父控本轮参考采用评估；证据和本报告留在授权 scratch，由父控决定向原权威 space/memory 写回。本子任务未越界修改治理资料。
