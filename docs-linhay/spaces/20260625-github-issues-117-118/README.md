# GitHub Issues 117 / 118

## 背景

- Issue #117：iOS embedded runtime 的 hierarchy/display-item 构建路径在后台 executor 里再次读取 UIViewController.view，触发 Main Thread Checker。
- Issue #118：对外 tritonkit-dev-feedback skill 顶层 SKILL.md 过长，agent 每次触发都要加载大量无关平台指南和契约规则。

## 范围

- 修复 hierarchy builder，让 UIKit 派生的 host view controller 数据只在 MainActor 采集阶段读取。
- 拆分 TritonKit.skills/tritonkit-dev-feedback，让顶层 SKILL.md 只保留核心工作流和 references 路由。

## 验收

1. buildItem 不再调用 data.view?.tk_hostViewController 或其他会触发 UIViewController.view 的后台 UIKit 路径。
2. host view controller metadata 仍能输出到 TKDisplayItem.hostViewControllerObject。
3. tritonkit-dev-feedback/SKILL.md 控制在 150 行以内，并明确路由到 issue filing、iOS runtime evidence、host devices evidence、schema contract、iOS/Harmony integration references。
4. 相关 Swift 测试、文档结构检查和 skill 包检查通过。
