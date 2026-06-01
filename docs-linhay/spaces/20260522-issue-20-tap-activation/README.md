# Issue 20 Tap Activation

## 背景

GitHub issue #20 反馈：真实 UIKit 页面中，`triton tap "<text>"` 经常匹配到 `UILabel` 或文本节点，但业务点击处理挂在父级 `UIControl`、`UITableViewCell` / `UICollectionViewCell` 或带 `UITapGestureRecognizer` 的父视图上，导致 transport 返回成功但页面无业务响应。

## 范围

- 只处理 text/label 匹配后的 activation target 选择。
- 不处理 #19 的多目标消歧排序策略。
- 不处理 #21 的连接、transport 或 server 生命周期逻辑。
- 不引入 Web/Wails UI。

## BDD 场景

1. Given `triton tap "<text>"` 匹配到 `UILabel` 子节点，When 父级存在 enabled `UIControl`，Then runtime 激活该 `UIControl`，并输出 matched / activation / strategy。
2. Given `triton tap "<text>"` 匹配到 cell 内部 label，When 父级是 `UITableViewCell` 或 `UICollectionViewCell`，Then runtime 优先触发可用 selection 路径，并输出 matched / activation / strategy。
3. Given `triton tap "<text>"` 匹配到 label，When 父级仅存在 tap gesture view 且 embedded runtime 无法公开派发该 gesture，Then 返回机器可读 unsupported strategy 与 activation target，避免假成功。
4. Given 调试者需要旧行为，When 使用 exact/低层 selector，Then 仍保留旧的 oid/coordinate 行为。
5. Given 使用 `--ax-oid` / `--ax-label` 低层 selector，When 未显式指定 strategy，Then 保持 exact；When 显式指定 `--strategy smart|ancestor`，Then 使用对应 activation strategy。

## 验收

- `TKInputRequest` 能表达 matched node 与 activation strategy。
- `TKInputResult` 能表达 matched node、activation target 与策略。
- UIKit 单元测试覆盖 UIControl、table cell、collection cell 与 gesture-backed parent。
- UIControl 测试断言业务 action 被同步触发；cell activation 尊重 selection 开关与 delegate selection 门禁。
- 相关 Swift 测试通过。

## 实现记录

- 2026-05-26：补齐 exact / low-level selector 的 matched、activation 和 strategy 透传，并让 CLI text 输出显式展示这些字段。
