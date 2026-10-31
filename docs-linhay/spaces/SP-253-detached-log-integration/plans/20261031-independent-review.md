# SP253 独立审查

## Requested

核对SP252叶子竞争拒绝、0600/CLOEXEC、失败资源释放、原错误与nil/成功兼容。限定CLI host helper，父目录竞态不在本轮范围。

## Observed 与 Evidence

独立审查agent review_baguette先检查旧逻辑及红测夹具，提出fcntl返回-1按位判断假通过、FIFO前置失败继续blocking open两项修正；执行方在原生产逻辑上重跑red后修复。随后最终静态审查无阻断项。主控核对实现候选86662bfe与审查前后hash一致：

- CLIHostProcessRuntime.swift SHA256 fe437b79507a14d27296d56366465d30a69f3355fc8bfa88ad7d3ed02f27b624。
- HostDetachedOutputTests.swift SHA256 6fc3b28bf3ac7a83b3c36385ee730db5538c5ee1ea40cb7b25c185b2464a35e7。

实际旧逻辑两轮red各exit1/16断言问题；观察到FileManager.createFile替换竞争者叶子，不是已复现hardlink/symlink目标写穿。0600权限与显式close保障分别验证；stderr retained引用只证明新增显式关闭保证，不证明ARC后持续泄漏。原launch失败关闭是回归覆盖。focused green为4测试函数/8参数场景、exit0；原始日志在仓外archives/SP-252-detached-log-exclusive-create，由主控继续核对完整CLI结果。

## Gaps 与 Remaining risk

所有静态建议已闭合；本审查未重复运行执行者scratch，完整CLI及合后门禁另记录。父目录替换、任意跨进程竞态、所有文件系统、长期真实detached设备服务未测，不外推。标准umask环境下权限为0600，额外收紧umask可能产生更窄权限。
