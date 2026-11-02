# 2026-11-02 验证

初始状态：已读 issue 最新反馈与当前调用链。Wait.run 在 resolveHarmonyTarget 后才创建布局轮询时钟；harmonyTargets 的 plain fallback catch 会吞超时。已有 harmony_discovery_timeout 分类可复用，不增加错误枚举。

RED/GREEN 由主控绑定实际候选串行执行；当前未执行。无真实设备操作。

## 实际 CLI RED

使用当前已构建基线 CLI（SHA256 `795e5d6428e0096b8eb3d48e8188a2357a5d7fc4c8a90e8323ee191cfe1d5082`），运行本目录 `verify-discovery-deadline.py`。有效 RED 在 `.triton/sp266-red-cli-v3/report.json`：

| 合成场景 | 预算 | 实际耗时 | 错误行为 |
| --- | --- | --- | --- |
| verbose 发现延迟 1.5s | 0.15s | 1.979s | 返回 target_not_found，继续 plain fallback |
| plain fallback 延迟 1.5s | 0.3s | 2.349s | 返回 target_not_found，未按总预算取消 |
| 已发现目标消耗 0.3s | 0.55s | 0.656s | 重置预算并启动布局采集，返回 harmony_layout_failed |
| 快速 missing 对照 | 1s | 0.308s | 正常 target_not_found |

首版/第二版 Python fixture 的启动成本干扰亚秒预算且 `[Empty]` 不是可靠的空列表 fixture，原始失败保留在 v1/v2，不能拿它们证明 plain fallback。v3 改为 `/bin/sh`、空 stdout；长延迟使用 `exec /bin/sleep`，使记录的 PID 就是被取消的进程，避免引入孙进程。未委托任何原生 HDC 或设备。

## 候选实现

发现 runner 在每次 verbose/plain 命令前从同一 deadline 计算剩余预算；有 deadline 时 plain fallback 不吞 timeout。无 deadline 的其它发现入口保持原行为。CLI 从发现前记录 startedAt，布局 helper 可接收该时间，保留 smoke 等已有调用默认值。正常missing/offline/ambiguous继续由#252分类。

`--timeout` 是执行阶段预算；现有 host runner 的有界 SIGTERM/SIGKILL 回收可能额外耗时，不承诺操作系统级绝对墙钟硬上限。测试会同时验证正常可取消 fake 进程无遗留。

## 首次 GREEN 的测试设计修正

主控 `archives/SP264/issue147-green.log` 记录 23 tests / 10 issues，不能记为通过。本机进程启动常达约 0.3 秒，早先 0.15/0.3 秒预算可能在 shell 写 calls/PID 前结束；0.55 秒“发现后低于 capture floor”同样不是可靠的阶段 fixture。旧 condition 测试原本用 0.001 秒，只覆盖发现完成后的旧时钟，从总deadline修复后必须重新构造条件阶段。

修正没有增加产品预算、吞错误或删断言：真实发现取消使用 2 秒总预算与 10 秒 `exec sleep`，仍要求 <2.8 秒、准确调用序列、单 JSON、无存活 PID；共享剩余预算/预耗尽零启动/plain fallback透传使用注入 runner 与 startedAt 的单元对照。旧 condition fixture 实现真实合法 dump/recv 的 Other 节点，给2秒预算走条件timeout，不借助亚毫秒竞态。该轮测试修订等待主控重跑。

## 自定义 HDC 名称的分类修复

第二次 GREEN（`archives/SP264/issue147-green-v2.log`）16 tests 中15通过、1失败：注入 `fake-hdc` 的 plain discovery timeout 被全局classifier按basename判成 `host_command_timeout`。这不只是测试命名问题：`--hdc` 支持自定义可执行文件名。实际已构建候选用 `custom-hdc` 与2秒预算复现，耗时2.124秒、返回 `host_command_timeout`，证据 `.triton/sp266-custom-name-red/report.json`。

最小修复仅在 Harmony wait 已知配置边界，联合 `command.executable == hdc` 与准确 `list targets [-v]` 参数分类为 `harmony_discovery_timeout`，保留当前配置的 doctor nextAction；不扩大全局basename classifier，也不把布局命令或其它工具误归类。追加实际custom-named executable正例与layout/不同executable负例；新测试共8项，CLI fixture追加custom-tool，第3次GREEN尚待主控运行。

## 主控最终定向验证

18 项 Swift tests 通过（`archives/SP264/issue147-green-v3.log`）。5 个实际 fake-HDC CLI 场景通过（`.triton/sp266-green-cli-v5/report.json`），绑定 SHA-256 `0494501312a708d8348fcfc51ecd5299cf871c119d6d77023714d2dda64b1631`，包含自定义 executable 名称、verbose/plain discovery、条件超时与 missing target 对照。

v4 原记录保留：首个冷 CLI 调用总墙时 3.13s 超过 fixture 2.8s 门槛；内部 discovery timeout 为 1.9999s，错误码、精确调用与直接子进程回收正确，随后四例通过。同候选、同门槛 v5 五例通过。不把复验擦除首次观测；产品预算从 Wait.run 开始，CLI 启动及既有有界终止/pipe drain 不属于严格墙钟等式，亦不证明整棵进程树回收。
