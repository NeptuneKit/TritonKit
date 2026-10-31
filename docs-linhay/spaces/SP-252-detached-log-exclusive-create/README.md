# SP-252 — Detached 日志独占创建

## 边界与来源

状态：已评估，待执行分派。影响层CLI host process helper；不新增CLI参数/HTTP/Web控制面。来自Mobile MCP 1.0.15输出hardlink安全机制对照，固定来源与评估见[10月31日审阅](../SP-207-reference-adoption-pipeline/plans/20261031-mobile-next-mobile-mcp-review.md)。actual main 1139db77 的 hostDetachedOutputHandle 是prepare→createFile→FileHandle reopen，和已有独占artifact写入不一致；此时仅静态候选，需红测试证实。主控为[SP-253](../SP-253-detached-log-integration/README.md)。

## BDD 与验收

- Given预检后目标被regular file/hardlink/symlink/FIFO抢占，When打开detached stdout/stderr，Then原子独占创建拒绝，不截断或写穿、不阻塞；竞争者内容与目标不变。
- Given新日志路径，When成功打开，Then单次open得到0600文件、O_EXCL/O_NOFOLLOW/O_CLOEXEC；后续不按路径reopen。
- Given stdout已打开而stderr打开失败，When启动返回错误，Then没有启动子进程且stdout描述符关闭。
- Given合法stdout/stderr或nil，When自有短命fixture启动，Then原有detached行为及/dev/null不变；launch失败也释放所有句柄。

允许变更Sources/TritonKitCLI/CLIHostProcessRuntime.swift及一个独立helper（若需要）、CLI/Tests/TritonKitCLITests/HostDetachedOutputTests.swift、本文与plans；不改shared core、schema、其他runtime，不清理他人工作区。目标仅最终文件叶子创建安全，不宣称父路径替换/跨用户目录威胁已全面解决。

验证：先同接口红测，再focused，主控独立审查与完整CLI、适用local/docs门禁；真实Simulator/设备及第三方执行不在授权内，不运行。主控负责main合并、证据归档、工作区和执行聊天关闭；执行者停在冻结候选。
