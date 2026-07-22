# GitHub Issue #159：UIAlert Modal Tap Boundary

> 状态：执行
>
> GitHub：[NeptuneKit/TritonKit#159](https://github.com/NeptuneKit/TritonKit/issues/159)
>
> Branch：`feat/20260722-issue-159-alert-modal-boundary`
>
> Worktree：`../TritonKit-worktrees/20260722-issue-159-alert-modal-boundary/`

`docs-linhay/scripts/create-space.sh` 当前不存在，因此本 space 按固定模板直接建立并同步总索引。

## 背景

embedded iOS runtime 对可见 `UIAlertController` action 的坐标点击会命中 action view，却继续向层级外寻找 collection/table cell ancestor，最终越过 modal 边界激活背后的内容并返回假成功。

## 范围

- 在 UIKit input resolution 中把 presented alert/action sheet 作为不可跨越的 modal boundary。
- 能通过公开 UIKit 语义安全激活 alert action 时执行并验证 dismiss；不能安全执行时返回稳定 `unsupported_capability`。
- 禁止 alert action 命中后回退到 modal 后方的 collection/table ancestor。
- 增加 alert + selectable collection fixture 回归；不使用私有 selector，不扩展 host UI 产品面。

## BDD 场景

### 场景 1：Cancel action 不激活背景 cell

- Given collection view 上方呈现包含 Cancel 的 alert
- When 坐标命中可见 alert action
- Then collection/table ancestor fallback 不得越过 alert controller
- And 背景 selection 状态保持不变

### 场景 2：安全 alert action 可被激活

- Given action 可由公开 UIKit 对象关系解析
- When 执行 tap
- Then 对应 handler 被调用且 alert dismiss
- And success strategy/message 明确属于 alert action

### 场景 3：无安全路径时明确失败

- Given 命中的是 alert action view但无法映射到公开 action
- When 执行 tap
- Then 返回单一 `unsupported_capability` envelope
- And 不返回 collection/table selection 成功

## 验收门禁

- 先补 UIKit focused 失败测试并确认红灯，再做最小实现。
- focused runtime tests、根包 `swift test`、CLI input/schema tests 与本地门禁通过。
- 若使用真实 Simulator，先保存 Triton status/doctor/capabilities/schema/plan，再用 fixture 的 dismiss 与背景 selection 后置状态验收。
- 更新相关 agent 控制文档、public skills、memory 与 space 索引。

## 停止条件

三个场景、自动化验证、main 集成与线上 CI 全部满足后评论并关闭 #159。
