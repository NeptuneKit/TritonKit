# Issue 60 UITableView Row Tap

## 背景

Issue #60 反馈私有 iOS App 中 Eureka / `UITableView` form row 的可见 `UILabel` 能被 `triton ax` 发现，但 `triton tap '<row-label>'` 与 `--strategy ancestor` 都无法触发行点击行为。该类 row 的业务动作通常不挂在 `UIControl` action 上，而是由 `UITableViewDelegate.tableView(_:didSelectRowAt:)` 实现。

TritonKit embedded runtime 当前边界仍是 DEBUG-only App 内观测与控制，必须优先使用公开 UIKit API。不得把 host-side HID、SimulatorKit 或裸 simulator 事件注入方案塞进 embedded runtime。

## 目标

- 当 tap 命中可见文本节点，且该节点位于可选择的 `UITableViewCell` 内时，`smart` / `ancestor` 激活策略应爬升到 owning cell 并触发表格行选择。
- 成功结果需要保留 matched label 与 activation cell 的机器可读信息，便于 agent 审计 `triton tap` 实际激活目标。
- 对不可选择、delegate 拒绝或仅有 tap gesture 的场景保留稳定诊断，不伪装成真实 coordinate / HID 点击。

## 范围

包含：

- Embedded runtime 的 UIKit tap activation。
- `UILabel` inside `UITableViewCell` 的 focused tests。
- 不破坏既有 `UIControl`、`UICollectionViewCell`、text input、gesture unsupported 诊断语义。

不包含：

- Host-side Simulator HID / coordinate event tap。
- Web / Wails UI。
- 真实私有 App 回归接入。
- qmd / memory 集成，本 issue worker 完成后交由主控统一处理。

## BDD 验收场景

### 场景 1：smart tap 激活 table row

Given 一个可见 `UITableView` row，row 内部 `UILabel` 文本为 `内科医生`  
And row 行为由 `UITableViewDelegate.tableView(_:didSelectRowAt:)` 实现  
When runtime 收到 matched label OID 的 `tap` request，`activationStrategy=smart`  
Then TritonKit 选择 owning `UITableViewCell`  
And 调用 delegate 的 `didSelectRowAt`  
And 返回 `ok=true`、`strategy=ancestor-table-cell-selection`  
And 返回 matched label OID/class 与 activation cell OID/class

### 场景 2：ancestor tap 激活 table row

Given 同样的 `UITableView` row 与 matched label  
When runtime 收到 `activationStrategy=ancestor`  
Then 行为与 smart 一致，明确证明 `triton tap '<row-label>' --strategy ancestor` 的 embedded runtime 路径可用

### 场景 3：既有语义不回退

Given matched label 位于 `UIControl`、`UICollectionViewCell` 或 tap gesture wrapper 中  
When runtime 执行 smart / ancestor tap  
Then `UIControl` 仍走 control action，collection cell 仍走 collection selection，gesture wrapper 仍返回公开 UIKit API 无法派发 gesture 的稳定诊断

## 测试计划

1. 先新增或更新 `Tests/TritonKitTests/TKAXUIKitTextTests.swift` 聚焦测试，至少覆盖 `UILabel` inside `UITableViewCell` 的 `smart` 与 `ancestor` tap。
2. 先运行新增测试过滤器确认红灯；若基线已含实现导致无法得到红灯，在交付说明中说明该 worktree 已存在相关实现，并继续用新增测试锁定缺口。
3. 最小实现通过测试，优先复用现有 `performAncestorTapActivation` / `performTableCellTap` 路径。
4. 最小验证命令：

```bash
swift test --filter TKAXUIKitTextTests
```

若本机环境无法运行 Swift / UIKit 测试，需要记录具体错误与风险。

## 实施记录

- 当前 worktree 基线已包含 `performAncestorTapActivation` 到 `UITableViewCell` 的公开 UIKit API 实现：解析 owning `UITableView` / `IndexPath`，检查 `allowsSelection` 与 `cell.isUserInteractionEnabled`，尊重 `willSelectRowAt` nil 拒绝，然后执行 `selectRow` 并调用 `didSelectRowAt`。
- 本轮新增显式 `activationStrategy=ancestor` 的 `UILabel` inside `UITableViewCell` 测试，补齐 issue 中 `--strategy ancestor` 失败路径的回归覆盖。
- 未新增 host-side HID / SimulatorKit / raw coordinate event tap。

## 验证记录

- `swift test --filter TKAXUIKitTextTests`：构建通过，但当前 SwiftPM 运行目标为 `arm64e-apple-macos14.0`，`TKAXUIKitTextTests` 被 `#if canImport(UIKit)` 排除，实际执行 0 个测试。
- `git diff --check`：通过。
- `docs-linhay/scripts/check-docs.sh`：通过。
