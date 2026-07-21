# GitHub Issue #157：UITableViewCell Ancestor Selection Callback

> 状态：已归档
>
> GitHub：[NeptuneKit/TritonKit#157](https://github.com/NeptuneKit/TritonKit/issues/157)
>
> Branch：`feat/20260721-issue-157-table-cell-selection-callback`
>
> Worktree：`../TritonKit-worktrees/20260721-issue-157-table-cell-selection-callback/`

## 背景

当前 `ancestor-table-cell-selection` 把 `selectRow` 与 optional delegate callback 延迟到 `DispatchQueue.main.async`，却在动作真正执行前立即返回 `ok=true`。真实回归因此可能看到“Submitted selection”成功，但下一条业务验证没有 `didSelectRowAt` 产生的 alert/状态变化。机器可读成功不能只代表异步任务已排队。

## 范围

- 让 UITableViewCell ancestor selection 在返回前完成 public UIKit selection 与 delegate callback。
- 尊重 `willSelectRowAt` 返回的实际 index path；selection denied 继续返回结构化失败。
- 只有 selection state 与 callback dispatch 已同步完成才返回 `ok=true`；message 不再使用弱语义的 `Submitted`。
- 同时覆盖 label/ancestor 与 coordinate-resolved cell 入口；不引入私有 touch synthesis、HID 或 Web/Wails。
- 更新 fixture、测试、schema/output semantics 文档、skills 与 memory。

## BDD 场景

### 场景 1：ancestor label tap 同步触发 didSelect

- Given 可选择 UITableViewCell 的 label 被 smart/ancestor 策略命中
- When embedded runtime 执行 tap
- Then 在返回前 select 实际 row 并调用 `didSelectRowAt`
- And result 为 `ok=true`、`strategy=ancestor-table-cell-selection`
- And delegate 可观察后置状态已经变化

### 场景 2：coordinate-resolved cell 使用同一闭环

- Given 坐标解析到 UITableViewCell
- When 执行 tap
- Then 使用与 label ancestor 相同的同步 selection/callback helper
- And 不只修改 highlight/selection state

### 场景 3：willSelect 重定向或拒绝被尊重

- Given delegate 将原 index path 重定向到另一个 row 或返回 nil
- When 执行 ancestor selection
- Then 使用重定向后的 row，或返回 denied failure
- And 不对原 row 伪报成功

### 场景 4：返回成功前 selection 可验证

- Given table 允许选择且 callback 可用
- When helper 准备返回成功
- Then `indexPathForSelectedRow` 与实际 index path 一致
- And message 明确 selection/callback 已执行，而不是仅 submitted

## 验收门禁

- 先补同步 callback、redirect/deny 与 coordinate path 失败测试并确认红灯。
- focused UIKit input tests、根包 `swift test` 与 local/release gate 通过。
- Triton-first 真实 Simulator TestFixture 中，row tap 后的稳定 alert/title 或 label 必须由 `triton verify` 证明。
- 文档、real-project/dev-feedback skill 与 memory 写回。

## 停止条件

四个场景、自动化门禁、真实 Simulator 证据、文档/memory、main 集成与线上 CI 全部满足后关闭 #157。随后与 #156 一起进入下一 patch release，不移动 `v0.2.13`。

## 实现与验收记录

- `performTableCellTap` 已移除 `DispatchQueue.main.async`，同步执行 `willSelectRowAt → selectRow → selection state check → didSelectRowAt`；重定向使用实际 index path，拒绝返回 `ancestor-table-cell-selection-denied`。
- 成功 message 改为 `Selected UITableViewCell ancestor and invoked delegate callback`；selection 未更新返回 `ancestor-table-cell-selection-failed`，不再用 `Submitted` 伪报已完成。
- `TKObjectRegistry` 会在 ObjectIdentifier 对应弱引用已释放时清理 stale mapping，再为地址复用的新对象分配 OID，避免长生命周期 runtime 把新 window/view 解析为失效对象。
- iOS focused tests 对同步 callback、willSelect redirect/deny、coordinate entry 共 4 项先红后绿；UIKit suite 串行化以隔离 key-window 竞争。
- TestFixture 新增 `Select Fixture Row`；真实 Simulator 中 label/ancestor 与坐标 `(201,584)` 两条入口均返回 `ancestor-table-cell-selection` 与同步 callback message，随后 `verify text-exists "Fixture Table Selection Complete"` 返回 `ok=true,count=1`。
- 根包 `swift test` 226 项通过；CLI `WebViewRouteTests` 18 项通过；TestFixture 由 `triton xcode run` 完成 build/install/launch。
- 另用 `triton xcode test` 跑过全量 iOS suite：本次新增 4 项均通过；suite 仍保留 35 个既有失败（主要为 key-window/concurrency 与根 Package cwd 基线），结果保存在 `/private/tmp/triton-issue157-full.xcresult`，不把无关基线伪报为本次已修复。
- Triton-first baseline 保存于 `/private/tmp/triton-issue-157-baseline/`；`triton xcode` schema 未暴露 `only-testing`，因此 focused iOS test 保存缺口证据后回退 raw `xcodebuild`。
- feature commit `99fae7a5` 已通过 merge commit `3981467f` 合入并推送 `main`；线上 CI run `29799367673` 全绿，完成评论留证后关闭 GitHub #157。
