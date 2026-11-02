# SP-266 Harmony wait 总 deadline

## 边界与状态

针对 [#147 新反馈](https://github.com/NeptuneKit/TritonKit/issues/147#issuecomment-6573083668)，当前基线 `572b4afb`。影响 CLI host Harmony wait 的发现与条件轮询预算；不操作真实设备，不修改 role 匹配，不扩大 Android/iOS 范围。#252 的 missing/offline/ambiguous 分类保留，发现超时复用 `harmony_discovery_timeout`，不伪造未解析目标。

## BDD

- Given 合成 HDC 的 target discovery 延迟 1.5 秒，When wait timeout=0.1 秒，Then 在有界进程回收后结束，返回单一 discovery timeout envelope，不进行布局采集，子进程不遗留。
- Given verbose discovery 返回空后 plain fallback 延迟，Then 两次发现共享同一总截止时间，fallback 的超时不能被吞成 target_not_found。
- Given 发现阶段消耗部分预算后成功，Then 布局轮询仅使用剩余预算，elapsedMs 包含发现耗时。
- Given 快速 missing/offline/ambiguous 或 unsupported --idle，Then 保留既有明确错误；idle 不启动后端。

## 验证与责任

独立新套件 `HarmonyWaitDeadlineTests` 与合成 fake-HDC CLI fixture；主控在 warm scratch 串行运行 RED/GREEN/既有 Harmony 回归。候选由本 agent 冻结并报告，主控负责共享索引、整合、CI 和发布。未执行的门禁不记为通过。进度见 [验证记录](plans/20261102-validation.md)。
