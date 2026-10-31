# SP-252 — Detached 日志独占创建

## 边界与来源

状态：已通过主控验收并合入本地main `56ef7719`，合后完整CLI/local通过，工作区/分支已清理、执行聊天已归档。影响层CLI host process helper；不新增CLI参数/HTTP/Web控制面。来自Mobile MCP 1.0.15输出hardlink安全机制对照，固定来源与评估见[10月31日审阅](../SP-207-reference-adoption-pipeline/plans/20261031-mobile-next-mobile-mcp-review.md)。actual main 1139db77 的 hostDetachedOutputHandle 是prepare→createFile→FileHandle reopen，和已有独占artifact写入不一致；随后以两轮确定性red证实竞争者叶子被替换，并完成修复验证。主控为[SP-253](../SP-253-detached-log-integration/README.md)。

## BDD 与验收

- Given预检后目标被regular file/hardlink/symlink/FIFO抢占，When打开detached stdout/stderr，Then原子独占创建拒绝，不截断或写穿、不阻塞；竞争者内容与目标不变。
- Given新日志路径，When成功打开，Then单次open得到0600文件、O_EXCL/O_NOFOLLOW/O_CLOEXEC；后续不按路径reopen。
- Given stdout已打开而stderr打开失败，When启动返回错误，Then没有启动子进程且stdout描述符关闭。
- Given合法stdout/stderr或nil，When自有短命fixture启动，Then原有detached行为及/dev/null不变；launch失败也释放所有句柄。

允许变更Sources/TritonKitCLI/CLIHostProcessRuntime.swift及一个独立helper（若需要）、CLI/Tests/TritonKitCLITests/HostDetachedOutputTests.swift、本文与plans；不改shared core、schema、其他runtime，不清理他人工作区。目标仅最终文件叶子创建安全，不宣称父路径替换/跨用户目录威胁已全面解决。

验证：先同接口红测，再focused，主控独立审查与完整CLI、适用local/docs门禁；真实Simulator/设备及第三方执行不在授权内，不运行。主控负责main合并、证据归档、工作区和执行聊天关闭；执行者停在冻结候选。

## 执行证据与交接

[验证记录](plans/20261031-validation.md)保存红绿结果、实际命令、归档与边界。生产修复只在叶子上使用一次独占 open（0600 / CLOEXEC），不按路径重开；各句柄获取后立即 defer 关闭。预检保留友好错误信息，安全性依赖原子创建。

经验检查：本机旧逻辑实际替换竞争者叶子的 inode，并未观察到 hardlink/symlink 目标被写穿；测试必须检查竞争者叶子本身。stderr retained 引用只证明显式关闭新保证，不证明原 ARC 回收后持续泄漏；原 launch 失败关闭属于回归覆盖。夹具前置失败即停，避免 FIFO 测试阻塞；fcntl 先确认成功再检查标志。共享索引、memory 与 adoption-state 按分派交由 SP-253 主控维护。

## 主线交付

合后162 XCTest + 1665 Swift Testing、适用local通过；真实设备/父目录攻击/发布未执行。证据、清理和会话结果见[SP253主线收口](../SP-253-detached-log-integration/plans/20261031-main-closeout.md)。
