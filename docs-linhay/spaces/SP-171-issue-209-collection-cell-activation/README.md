# SP-171：UICollectionViewCell 安全激活（对齐 table-cell 选择契约）

## 边界

- 对应 GitHub issue：#209 `[Feature] Support safe UICollectionViewCell activation`
- 影响层：embedded iOS runtime 输入动作（`Sources/TritonKit/TKRuntimeInputActions.swift`）、必要的 shared 模型（`Sources/TritonKitShared/`）、agent-facing action schema（`Sources/TritonKitCLI/CLISchemaActionCommands.swift`）、focused tests；不新增 HTTP/Web/Wails 控制面。
- 工作目录：`../TritonKit-worktrees/SP-171-issue-209-collection-cell-activation/`
- 分支：`feat/SP-171-issue-209-collection-cell-activation`
- 基线：`main@a56d7d6a`
- 目标：为 `UICollectionViewCell` 提供与既有 `ancestor-table-cell-selection` 对称的安全激活路径：尊重 selection eligibility（`allowsSelection` / delegate `shouldSelectItemAt`）、解析 index path、走公开 selection API 与 delegate 回调，并要求可见业务后置条件验证；不可安全激活时保持 fail-closed typed unsupported。

## 非目标

- 不引入私有 API、不绕过 delegate eligibility、不做 host-HID 静默回退（CLI 侧 `--allow-host-hid-fallback` 已由 SP-162 收口，本 space 仅在 schema/契约需要时同步描述）。
- 不改 table-cell 既有契约；不触碰 `TKRuntimeInputActions.swift` 中 longPress/swipe 相关区域（SP-172 在本 space 合入后串行处理）。
- 不连接真实 Simulator / 私有 App；以离线单测与 fixture 验证。
- 不新增 HTTP/Web/Wails 表面；不触碰其他 worktree 或 main 仓库。

## BDD 验收

### 场景 1：文本解析 → 安全选择

- Given 自定义 `UICollectionViewCell` 及其可见后代文本，delegate 允许选择
- When 执行 `triton act tap "<visible-cell-text>" --json`
- Then runtime 解析 owning cell → 检查 selection eligibility → 选中解析出的 index path → 触发公开 delegate 选择回调 → 返回 `ok:true`、结构化 strategy 名（如 `ancestor-collection-cell-selection`）与 verification 结果。

### 场景 2：坐标解析 → 同一选择路径

- Given 坐标命中的 hit view 属于某个 collection cell
- When 执行坐标 tap
- Then 走与场景 1 相同的 eligibility 检查与选择路径。

### 场景 3：eligibility 拒绝时 fail-closed

- Given `allowsSelection == false` 或 delegate `shouldSelectItemAt` 返回 false
- Then 返回 typed unsupported（稳定 error code），不假成功、不越过当前 cell。

### 场景 4：回归 fixture

- Then 新增离线 fixture 覆盖自定义 collection cell 的文本解析与坐标解析两条路径（含 delegate 回调与 verification 断言）。

## 验收命令

```bash
swift test --scratch-path .build/sp171-root --filter TKRuntimeInputActions
swift test --scratch-path .build/sp171-root
swift build --package-path CLI --scratch-path .build/sp171-cli -c release --product triton
docs-linhay/scripts/check-docs.sh
git diff --check
```

真实 Simulator / 私有 App 不作为本次验收前置；以 runtime 单测 fixture 验证 eligibility、index path 选择与 delegate 回调顺序。

## 当前状态

- 已完成实现与离线验证（影子 worktree patch 待主控合入真实 worktree）。
- 运行时实现：`Sources/TritonKit/TKRuntimeInputActions.swift` 新增 `performCollectionCellTap`（约 1036–1128 行）与 `collectionCellSelectionVerificationBoundary()`（约 31–39 行）；`performTap` 与 `performAncestorTapActivation` 的 collection cell 分支在 nearer UIControl / accessibility gesture 之后接入该选择路径；`unsupportedCollectionCellTap` 语义收窄为"无法安全解析公开选择路径"时的 fail-closed fallback（strategy=`ancestor-collection-cell-unsupported`、`unsupported_capability` 保留，SP-162 host-HID opt-in 契约不变）。
- 契约：eligibility 依次检查 `collectionView.allowsSelection` + `cell.isUserInteractionEnabled`（strategy=`ancestor-collection-cell-selection-blocked`，error.code=`collection_cell_selection_blocked`）与 delegate `collectionView(_:shouldSelectItemAt:)`（strategy=`ancestor-collection-cell-selection-denied`，error.code=`collection_cell_selection_denied`）；通过后 `selectItem(at:)` 选中解析出的 index path，校验 `indexPathsForSelectedItems` 后触发公开 `didSelectItemAt` 回调，返回 strategy=`ancestor-collection-cell-selection` + verification boundary（required=true / not-verified）。
- CLI schema：`act` outputSemantics、act/tap 的 `--strategy`、`--allow-host-hid-fallback` 描述、`tapFailureCodes`（新增两个稳定 error code）已同步；两处发布 skills 参考文档（emulator-cli-takeover、dev-feedback）的 collection cell 契约描述已对齐。
- 测试：新增 `Tests/TritonKitTests/TKCollectionCellActivationTests.swift`（文本/坐标选择、allowsSelection=false、shouldSelect 拒绝、helper 顺序、unresolvable fallback 共 6 场景）；`TKAXUIKitTextTests.swift` 三个 reject 场景改写为 select 契约断言，外层 gesture 逃逸防护测试改为断言走 cell selection 且不触发外层 gesture。
- 验证：根包 `swift test` 编译通过、263 项非 UIKit 测试全过；CLI release build 通过；release `triton schema` 实测新 error codes 与语义文本已进 act/tap 契约；`git diff --check` 通过。
- 已知限制：本机 SwiftPM（Testing Library 1902，macOS destination）不执行 `#if canImport(UIKit)` fixture（与既有 `TKAXUIKitTextTests`、`TKRuntimeInputActionsTests` 同等待遇，CI 亦仅跑 macOS `swift test`）；UIKit 路径的运行期回归需 iOS destination（`xcodebuild test`）或真实 Simulator 验收，超出本 space 离线边界。
