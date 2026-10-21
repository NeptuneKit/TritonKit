# SP-220 — Simulator Resizable display 主控集成

## 边界

SP-220 只验证并整合 SP-219 的候选 diff：核对来源 revision、文件互斥面、路由 identity 与零副作用负例，运行 focused/CLI/docs 门禁，并在通过后本地合入 main。不得独自扩大实现范围，不执行真实设备动作、远端写入、发布或依赖安装。

## BDD / 验收

- Given SP-219 有真实候选 diff，When 主控检查，Then 所有变更均在登记文件面，测试先证明失败再证明通过，未知/跨目标/伪 display 输入均 fail-closed。
- Given 验收未通过，Then 保留候选 worktree 并继续修复，不标记合并完成。
- Given 验收通过，Then 顺序本地合入 main，记录 merge SHA、测试输出、main 后回归与 cleanup manifest；真实 Simulator/Xcode 未执行时明确保留边界。

主控会话必须显式使用 `model="gpt-6.1-sol"`；接口拒绝时记录 `model_validation_failed`，不得换模型或伪造 thread ID。由于桌面接口持续拒绝该模型，本轮由当前主控完成同等审查并保留空 thread ID；验证记录见 `plans/validation-20261021.md`。

## 状态

已完成主控验收并本地合并到 `main`：候选 `51cd20dd` → `f9399e5e`。未执行真实 Simulator/Xcode、设备、远端写入、推送或发布。
