# SP-267 Harmony wait role 约束

## 边界与状态

对应 [issue #5 新反馈](https://github.com/NeptuneKit/TritonKit/issues/5#issuecomment-6573214473)。历史基线 main `572b4afb`；当前已由 PR #266 合入远端 main `ac2c3b2e`，精确候选 CI、24 项组合与 18 项实际 CLI fixture 通过，待 v0.2.39 发布。影响 CLI Harmony host wait 的 `--text` / `--exists` / `--gone`；不涉及设备输入或私有 App；已与 #147 总超时修复联合回归。独立 worktree：`../TritonKit-worktrees/SP-267-issue-5-wait-role`，分支 `feat/SP-267-issue-5-wait-role`。

## BDD

- Given 文本相同而类型不同的 ArkUI 节点，When 指定 `--role button`，Then 仅同一 `Button` 节点同时满足文本及 role 才匹配；不能组合不同节点的属性。
- Given 仅 Text 节点，When `--text` 或 `--exists` 加 `--role button`，Then 超时且 `matched=false`；无 role 与正确 Text role 正向对照通过。
- Given 错误 role 或缺失文本，When `--gone`，Then 仅该文本+role 组合确实不存在才返回通过；仍存在相同组合时超时。
- Given 缺失 type 的节点，When 有 role，Then 不能匹配。role 与原生 ArkUI `type` 去首尾空白后按大小写不敏感精确比较；不推断父子语义、不把 clickable 等价为 Button。

- Given 显式空或纯空白 role，When 使用 `--text` / `--exists` / `--gone`，Then 在 discovery 前输出单个 `validation_failed` JSON、非零退出、零 backend 调用；不能把非法 role 当作目标不存在。

## 验收

实际 CLI fake-HDC fixture 通过 `--hdc` 显式注入；只输出合成目标和布局，不委托任何真实 backend。保留旧候选失败、最小函数/等待回归、最新二进制进程验收及源码 hash。Git/构建与最终索引由主控串行处理。

[验收记录](plans/20261102-validation.md)

2026-11-02最终优化候选真实 Harmony 只读验收 6/6 通过：自有 HVD 锁屏稳定文本的正确 native Text role、错误 role 与 gone 正负对照，8秒负例实际8.03–8.04秒；单 JSON、空 stderr 与退出码符合契约，无输入/解锁/IME操作。二进制SHA `83ea863040ff2b9764b837145befb0e2b6f6b3a56def93bb8dfd6bf0695b664c`；自有HVD已停。原始报告在同级 `archives/SP264/acceptance/harmony-role-candidate/`，这不是尚未发布的公开包验收。
