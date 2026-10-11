# 真机只读验收（2026-10-12）

用户要求进行真机验证。本轮沿用 SP-183，使用已合并源码构建的 Release CLI；原始结果保存在保留 worktree 的私有 `.triton/real-acceptance-20261012/`。本次不改变此前排除的配对/解除配对、诊断采集、Temporary 创建及业务内容读取边界；已询问是否扩大范围，未收到扩大授权时只执行只读验收。

## 场景与结果

| 场景 | 实际结果 | 证据边界 |
| --- | --- | --- |
| 发现真机及精确选择 | 3 条 iPhone 记录，2 台在线、1 台离线；逐一精确选择在线目标 | 一台有线、一台局域网；不将离线记录当可用设备 |
| details/lockState file-JSON 与身份绑定 | 2 台成功，均已解锁过且当前无需密码 | 只读取状态，不解锁 |
| wait-ready | 2 台成功 | host readiness，不代表业务 App runtime 已连接 |
| Crash 日志域浅 metadata | 分别159、23条，均通过 | 无文件内容、无递归、无诊断压缩包 |
| Crash 预算负向 | max-entries=1 返回 device_files_limit_exceeded、exit 1、单 JSON | 不截断冒充完整结果 |
| App 容器语义 | 4 个实际安装 App 的 SDK bundle/container 绑定通过 | 仅 SDK metadata；hostFilesystemInspected=false |
| App Group 语义 | 从 SDK 实际 membership 与 groupContainerPaths 取同一 group，再精确查询成功 | 无名称或目录猜测；不读取容器业务内容 |
| 真机容器 --list | app_container_unsupported_listing、exit 1、单 JSON | 不冒充 CoreSimulator 原生路径能力 |
| Temporary 无策略 | device_file_domain_policy_required、exit 1、单 JSON | 创建未执行 |
| pair/unpair/diagnose | 三个 plan-only 成功，executed/executable=false | 不计为管理执行或诊断采集验收 |
| 证据权限与连接状态 | 24个原生 artifact 文件0600、父目录0700；前后连接状态一致 | 不声称只读查询期间设备内部完全无变化 |

## 限制与下一步

Triton status/doctor/capabilities/plan 返回 server_unavailable；host device doctor 正常。本轮 host CLI 独立成功，但未验收 embedded runtime、App 启动或业务状态。未连接非 iOS Apple 硬件；本次 iPhone 验收不能代替 watchOS/tvOS 输入验证。配对写入、解除配对、真实诊断、Temporary 创建、DeviceFS 挂载仍未执行。专门 Simulator 的 runtime 下载阻塞沿用前轮结论，本轮没有重试下载。

本轮未修改实现代码；真实命令与负向退出/单 JSON 已实际运行。文档门禁 `verify.sh --ci-docs`、`check-docs.sh`、`git diff --check` 已通过。用户此前授权测试后合并，本轮仅本地提交合并，不推送发布。

[脱敏机器可读结果](20261012-real-device-verification.json)
