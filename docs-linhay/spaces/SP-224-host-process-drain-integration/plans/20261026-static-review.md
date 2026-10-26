# SP-224 静态独立审查（候选冻结前）

日期：2026-10-26。审查仓库为同级 `SP-224-host-process-drain-integration` worktree；基线 main / HEAD 均为 `8fcd856f2927fa81754bb3e10b80d066c0591f37`。本阶段只审查、写本 space，不修改产品或共享索引、state、memory；尚未运行产品测试，不代表 SP-223 验收通过。

## Requested

依据主目录 SP-223 / SP-224 README：三条生产 runner 在直接子进程退出后必须有界收尾；未 EOF 不得伪造完整成功；保留已获得字节、计数、截断与既有非零语义；读写失败不得静默成功。只管理自己启动且可精确识别的进程，不杀未知后代、不自动重放。生产函数正式红绿测试需有外部 watchdog 和自有 PID 清理。

## Observed

- `Sources/TritonKitCLI/CLIHostProcessRuntime.swift:294`、`:370`、`:454` 的正常退出路径分别无界等待两个 pipe / combined pipe；命令自身 timeout 不约束 post-exit 收尾。
- 同文件 `:24`、`:55`、`:86` 的 `try? read` 将读取失败和 EOF 合并，无法证明完整性。
- 同文件超时分支跨线程关闭读端，再有限等待；这并不证明 close 本身有界。新设计需消除阻塞 read/close 互相等待风险。
- drain 结果经异步闭包写入局部变量。正常路径 group 完成后才读取；新设计若在 group 未完成时返回、快照或删除 artifact，必须另有同步和结束协议，不能沿用未同步共享变量。
- `CLIHostModels.swift:962` 的 `HostProcessResult` 只有字节截断字段，无 EOF 完整性字段；`:999` 的现有错误也没有专用 drain 错误。范围不允许随意改公共模型，执行可采用本次内部错误并在已有单 envelope 映射中返回失败，但需要证明真实错误可识别且不会被吞成 unsupported 或成功。
- `CLIHostSimulatorConsoleRuntime.swift:35` 将 combined runner 返回值输出为 `ok:true`；单纯把未 EOF 映射为 `artifactTruncated` 会混淆 byte cap 与采集不完整，应 fail-closed 或显式完整性契约，不能只改变描述字符串。

## Evidence

以上为 main 实际 blob / worktree 同基线静态检查；原函数提取 probe 仅作为 SP-223 已知线索，不能替代本轮生产函数回归。当前尚无 root 确认冻结候选 SHA；未整合执行分支，未启动 focused/full CLI 或任何设备动作。

2026-10-26 已按本轮协调授权向执行会话 `01a1773d-1703-7152-bfa0-a6e452491809` 发送检查点：EOF/deadline/read/write error 区分、共享状态同步、close/read 有界、自有 watchdog/cleanup 与正式生产测试。不扩大执行文件面。

## Gaps

以下均待冻结实际候选及独立验证，不能标通过：

| 场景 | 必须核验的证据 |
| --- | --- |
| stdout / stderr / combined 后代持 FD | 直接子进程先退出，明确 post-exit 预算内失败，后代仍存活直到 fixture 精确清理 |
| 持续输出但不 EOF | deadline 不因每次可读而重置，循环排空也不能饿死截止检查 |
| 大输出 / 尾字节 | 超过 pipe 容量、跨读块、末尾非整块及原始非 UTF-8 字节；观察数与保留数分别准确 |
| 字节上限 | 达 cap 仍排空，cap 截断独立于未 EOF；不能将未知剩余字节计为完整总数 |
| 非零 / 语义失败 | 正常 EOF 保留原 exit/status 和已有 hdc 失败语义；非零且未 EOF 不丢失退出事实 |
| read/write error | 明确失败；不得把错误默认为 EOF、成功或普通字节截断；artifact 清理策略可解释 |
| timeout / interrupt | 有界、无后台状态竞态；combined 按 duration 中断的既有行为保持，异常未 EOF 仍失败 |
| 外部 watchdog / cleanup | 外部独立预算，不靠测试自身 elapsed 断言防挂；只清理 fixture 精确 PID，异常路径也无残留 |
| CLI 输出 | 实际候选产物绑定 `TRITON_CLI_PATH`，失败仍单一合法 JSON envelope、非零退出；未知错误反例不变成功 |

## Fixes made

无产品修改。仅新增本静态审查证据；发现的行为缺口已交执行会话，由其实现并提交候选。

## Remaining risk

尚无正式旧代码红测试、候选实现、独立 focused/full CLI 结果。等待 root 确认冻结 SHA 与串行验证时段后，再在本 worktree 整合实际候选并审查真实联合差异。完整 CLI、root/local/docs、main 合并与合后门禁分别报告，不能以静态审查替代。

经验检查：已命中经验索引的 CLI 单 envelope 与治理文档的候选绑定/反证要求；本轮新观察先保留于本 space，跨任务通用沉淀与共享索引由 root 收口，未越权写入。

## 未冻结实现的追加审查

root 后续通知 docs 基线已到 `087237ba`，正式红测与执行聚焦绿测已产；本审查未把执行摘要当作独立验收，也未整合或启动测试。

只读检查执行 worktree 的未冻结 `CLIHostProcessDrain.swift`、runtime diff 与测试后：

本次读取后记录 SHA-256：runtime `c20045c6335cdd87cf7a4d16397d8bf5c138d04dd6005495c18c3b18fc2e6cb6`；drain `ddf796cbd21710d7bf1ea96af87797d0f0fac14c9c8d348d4d399058d4140973`；测试 `2c239b1bfb46bad427c61b56d4001465c7023cb28241b9950ca9e1458b65362a`。执行仍在修改，后续候选需重新审查，不能把本条当作其最终缺陷或通过结论。

- `O_NONBLOCK` read + 10ms poll，循环头检查共享单调时钟 deadline，持续可读不会跳过截止；worker 独占读取与关闭，join 完成后锁取结果，这个方向消除了原先跨线程 close/read 依赖与未同步局部结果。
- **Bug，已交执行修订**：当前三 runner 在构造结果/检查 terminationStatus 前直接抛 drain 错误；`incomplete` 只有单流 observedBytes。直接子进程 `exit 7` 且后代持 FD 时，实际 exit7 和已有部分结果均不可查。应以内部错误保留真实 exit/partial 信息，同时明确未 EOF，不扩大公共模型文件面；需三 runner 正式反例。
- **Verification miss，已交执行补证**：持续写入不 EOF、非 UTF-8 原始尾字节、未知错误不变成功。已有大输出字符串与独立 EOF 非零测试不能替代这些组合场景。
- **承诺限制**：artifact 的同步 open/write/close 与文件系统有关；管道 deadline 不能使这些操作可取消，不能声称慢/故障文件系统下的硬总截止。执行文档已开始记录该限制，独立验证仍待冻结。

上述意见已发 root 与获授权执行会话。未修改其实现；本阶段不运行 full CLI。
