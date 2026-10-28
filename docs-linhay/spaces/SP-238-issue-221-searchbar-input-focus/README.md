# SP-238 · 搜索框已聚焦输入对象解析

当前状态：已随PR #233合入远端main（`40850dde`），issue #221已completed关闭；现场复验范围见[远端处置](https://github.com/NeptuneKit/TritonKit/issues/221#issuecomment-6460614460)。 本批次未发布；[合并归档报告](../SP-241-open-issues-validation/plans/20261028-merge-closeout.md)为当前事实源。
- Issue：[GitHub #221](https://github.com/NeptuneKit/TritonKit/issues/221)
- 影响层：iOS embedded shared runtime；不改变 CLI 参数或 host keyboard 能力。
- 分支：`feat/SP-238-issue-221-searchbar-input-focus`
- Worktree：`../TritonKit-worktrees/SP-238-issue-221-searchbar-input-focus`

## BDD 与验收

1. Given 搜索栏内部 UITextField 聚焦，When 无 targetOID 的 type，Then 解析实际聚焦字段，文本插入成功而不是落到 UISearchBar 包装层。
2. Given 容器转发 descendant 的 isFirstResponder，When 查找 first responder，Then 优先已聚焦 descendant，不能让父包装层遮蔽它。
3. Given 搜索框未聚焦，When 另一个可输入视图聚焦或完全无焦点，Then 不选取搜索框、不自动抢焦点。
4. Given 显式 targetOID 或前台 modal 边界，Then 维持原有显式选择及 foreground 校验。

## 范围与证据

优先已聚焦且符合UIKeyInput的公共输入owner，再查非输入包装层，仍要求目标 `isFirstResponder == true`，不把“可输入”或父子关系当作焦点。真实App-hosted UIKit回归已覆盖转发型容器、内部field editor身份、实际UISearchBar和未聚焦负例。macOS 根包通过不能替代 UIKit 执行；最终设备证据以SP-241联合验收为准。
