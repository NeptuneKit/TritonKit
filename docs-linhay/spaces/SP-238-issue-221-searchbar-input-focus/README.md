# SP-238 · 搜索框已聚焦输入对象解析

- Issue：[GitHub #221](https://github.com/NeptuneKit/TritonKit/issues/221)
- 影响层：iOS embedded shared runtime；不改变 CLI 参数或 host keyboard 能力。
- 分支：`feat/SP-238-issue-221-searchbar-input-focus`
- Worktree：`../TritonKit-worktrees/SP-238-issue-221-searchbar-input-focus`
- 状态：候选冻结，待主控联合 native 构建及 App-hosted UIKit 验证，未整合发布。

## BDD 与验收

1. Given 搜索栏内部 UITextField 聚焦，When 无 targetOID 的 type，Then 解析实际聚焦字段，文本插入成功而不是落到 UISearchBar 包装层。
2. Given 容器转发 descendant 的 isFirstResponder，When 查找 first responder，Then 优先已聚焦 descendant，不能让父包装层遮蔽它。
3. Given 搜索框未聚焦，When 另一个可输入视图聚焦或完全无焦点，Then 不选取搜索框、不自动抢焦点。
4. Given 显式 targetOID 或前台 modal 边界，Then 维持原有显式选择及 foreground 校验。

## 范围与证据

仅调整 first responder 遍历优先级，仍要求目标 `isFirstResponder == true`，不把“可输入”或父子关系当作焦点。UIKit 回归将覆盖转发型容器和实际 UISearchBar。macOS 根包通过不能替代 UIKit 执行；设备测试由批次主控统一协调。
