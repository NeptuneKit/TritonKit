# SP-223 候选验证（2026-10-26）

## Requested / Observed

仅实现 CLI 内存、stdout artifact、combined artifact 三 runner 的退出后输出收尾。不新增 HTTP/Web/公共 DTO，不复制第三方实现。直接子进程退出后共享 0.25s 收尾预算；执行超时路径在原有 terminate/KILL 处理后启用相同收尾。读取使用 O_NONBLOCK 与 10ms poll，持续可读也检查截止；仅 read==0 视作 EOF。数据结果在 worker 完成后通过锁读取。没有按进程树清理或命令重放。

正常 EOF 保留尾字节、总观察字节、内存/文件截断和非零退出语义；未 EOF 显式失败，artifact 的不完整正常退出结果删除其输出文件，内存不返回伪造成功。新内部错误由现有 failHostCommand 输出一个 JSON envelope。输出文件 open/write/close 失败仍映射既有 launchFailed。

## Evidence

实际工作目录是同级 `TritonKit-worktrees/SP-223-host-process-drain-deadline`；基线和三个产品/测试文件 hash 见 [manifest](validation/manifest.json)。没有依赖安装、更新或 Package.resolved 修改。构建复用主目录 CLI/.build（执行期间暂建软链接）；由本人移除该软链接后冻结，未删除目标缓存。

正式红测先于实现运行在基线生产函数：`swift test --package-path CLI --no-parallel --disable-automatic-resolution --skip-update --filter HostProcessDrainTests`。旧测试源见 [red source](validation/red-test-source.swift.txt)。外部 Python watchdog 240s，swift PID 43481，退出 1，总 196.737s（含首次编译），测试 18.176s；6 个继承 FD 参数场景等 3s 后误报成功，共 18 条断言失败；其余大输出/非零对照通过。[红测输出](validation/red.log)保留从 Build complete 开始的连续原输出；完整编译日志保留在 ignored `.build/sp223-validation/red.log`，原始 hash 见 manifest。

第一次绿测 3 tests / 1.708s。[扩展测试一次失败](validation/fixture-crash.log)由 fixture 访问已关闭 FileHandle.fileDescriptor 触发 macOS Objective-C exception，不是生产函数崩溃；改为 POSIX 层注入 fd=-1 与目录 fd，区分 setup/read 错误。单独 sink 回调抛错验证写错误不会变成成功，非真实磁盘写失败/关闭失败注入。

最终命令在原参数加 `--filter 'HostProcessDrainTests|SimulatorAdvancedControlsTests'`，匹配并通过 2 suites、50 tests、13.122s；外部监督记录 PID 63527，退出 0，总 36.319s。[最终输出](validation/green.log)。较早的 47-test / 9 个新增定义 pre-review run 已被本次 50-test / 12 个新增定义的候选验证接替；旧 run 曾带未匹配的第三个 ApplePlatformRunnerTests filter，历史报告不将其算作覆盖。

新增 12 个测试定义覆盖：三 runner × stdout/stderr 长继承 FD（返回前 holder 存活，测试仅 kill shell 记录的自有 PID）；三 runner 1,200,004 字节完整尾部；三 runner 非零退出；三 runner 延迟 0.05s 尾字节及真实 EOF；内存/combined 截断计数；三 runner 执行超时（仅 exec 后的直接 PID）；combined 主动中断状态；read/setup/sink 失败；错误输出为单个可解析 JSON 对象；三 runner 的 exit7+未EOF 同时保留 cause/退出码/两路结果计数；三 runner 持续可读也必须截止；三 runner 原始非 UTF-8 尾字节。未知 sink NSError 保持失败，未知错误 envelope 仍只有一个对象。静默 sleep holder 最长 3s；持续写入 writer 由正常测试 defer 清理自己的精确 PID，异常超预算由自有 session watchdog 清理；watchdog 仅对其自建 session 进程组发信号，不按名称扫描或 kill 其他任务。

## Gaps / Remaining risk

- `verify.sh --ci-docs` 与 `check-docs.sh` 均已执行但失败：当前旧基线分支缺 SP-223 的共享索引登记。root 已在主目录维护登记，本任务禁止改共享索引；整合后由 SP-224 重跑。[门禁日志](validation/docs-gate.log)、[结构日志](validation/check-docs.log)。`git diff --check` 通过。
- 完整 CLI、根包、local gate、实际 CLI 二进制场景与最终单 envelope 独立复验由 SP-224 执行；本候选仅声明聚焦生产函数和现有调用回归通过。
- 不处理进程树生命周期、同步大 stdin 先写后读的旧行为、持久后台任务、内核/文件系统不可中断 I/O；不会通过杀未知后代换取输出 EOF。关闭读管道后，后代未来写入可能自行收到系统 EPIPE/SIGPIPE，这是关闭管道的系统行为。
- 固定 0.25s 是输出收尾预算，不是整个命令总预算；timeout 原有 terminate/KILL 等待仍另计。磁盘 open/write/close 等操作本身不是可取消 I/O，测试没有注入真实磁盘耗尽或故障文件系统。
- artifact 未 EOF 时失败并移除部分文件；新内部 HostProcessOutputFailure 同时保留实际 exitCode、cause、两路 HostProcessResult（含内存部分原始数据/截断/总字节），artifactBytes 另记实际写入数；未新增公共部分输出 DTO。EOF 通过情况下完整字节/计数已验证。

## Fixes made / 经验

改动仅 CLIHostProcessRuntime.swift、新内部 CLIHostProcessDrain.swift、新独立 HostProcessDrainTests.swift 和本 space。没有 public schema、依赖、设备、HTTP/Web、共享索引或 memory 改动。经验检查完成：截止/EOF/错误区分、worker 关闭所有权、Foundation 异常 fixture 的检查规则写回本 space README；跨任务技能/索引由主控统一判断，无越界写入。

## 独立审查缺口的红绿闭环

SP-224 指出初版在构造结果前抛 drain error，丢失非零退出事实。先加入仅类型 scaffold 与新生产函数反例，在不改变 runner 行为时运行 `--filter 'incompleteNonzero|continuousWriter'`：PID 61153，退出 1，41.600s（含编译）、测试 1.560s，2 个测试定义 / 6 个参数场景均因缺少携带退出事实的内部失败结果而实际断言失败。[第二轮红测](validation/review-gap-red.log)。pre-review 产品文件 hash 留在 manifest 对应字段。

修复将结果构造移至错误判断前，内部 HostProcessOutputFailure 包含 cause、result 与 artifactBytes；failHostCommand 显式映射 cause 的机器错误码，错误 message 包含实际 exitCode 和 stdout/stderr 总观察字节数。EOF 未完成时不会转为普通 nonZeroExit，也不会丢失非零退出事实。三 runner 反例验证 exitCode=7、数据/两路计数或 artifactBytes，最终 50 tests 绿测覆盖此候选。

收尾预算准确边界：0.25s 只约束 post-exit 管道读取等待（另有 poll/调度开销）；同步输出文件 open/write/close 与文件系统延迟没有可取消机制，不能承诺硬总截止。所有本次 watchdog 自建 session 进程组均已检查无残留，见 [自有进程组检查](validation/owned-process-groups.json)。没有扫描或 kill 不属于本次测试的进程。
