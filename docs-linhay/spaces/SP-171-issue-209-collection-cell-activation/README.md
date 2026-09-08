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


## 2026-09-08 只读审计与后续修补

- Requested：文本/坐标命中 owning collection cell，尊重 selection eligibility，公开 selectItem + didSelect 回调，要求独立业务后置验证。
- Observed / Evidence：审计提交 `5681f96e`；实现满足 `allowsSelection` / `isUserInteractionEnabled` / delegate `shouldSelectItemAt` → `selectItem` → 验证 selection state → `didSelectItemAt` 顺序。成功输出 `verification.required=true`、`status=not-verified`，未宣称业务导航完成。
- Gaps：`TKCollectionCellActivationTests` 的 5 个 harness 用 `_` 丢弃弱引用 dataSource，可能在 iOS 测试执行前释放；CLI `WebViewRouteTests` 仍断言 collection selection 不受支持，与新 schema 矛盾。历史记录只有 macOS root tests / CLI release build，不能证明 UIKit fixture 或 CLI 全量测试通过。
- Fixes made：在 SP-172 串行后继 worktree 保持 dataSource 至 fixture 结束；更新过期 schema 断言，覆盖 eligibility failure code 和 verification boundary。为遵守单 Swift 文件 1500 行规则，将 collection 专属 helper 机械搬至 `Sources/TritonKit/TKRuntimeCollectionActions.swift`，不改变选择逻辑。
- Remaining risk：UIKit fixture 仍需在 iOS destination 运行；真实私有业务后置条件须由调用方以 wait/verify/evidence 验证。本轮未触碰 Simulator、真实设备或私有 App。

- 后继离线验证：根包 265 tests / 33 suites 通过（macOS）；CLI `EmbeddedGestureSchemaTests|WebViewRouteTests` 20 tests / 2 suites 通过。旧 collection schema fixture 在修复前实际报 3 个反向断言失败，修复后通过；同时补齐 act 顶层 collection selection blocked/denied failure codes。`git diff --check` 通过；公共 docs check 被旧索引缺少 SP-170 阻塞，由主控统一修复。


## UIKit 集成复跑后的 fixture 修补（2026-09-08）

- 主控在独立 iOS 26.5 Simulator 合跑 4 suites，46 tests 中 19 pass / 27 fail。原始 stdout 显示三个 window suite 同时启动；大量失败为 `stale_runtime_hierarchy: attached to an inactive window` / `No key window`，部分坐标命中其他 fixture。每个 suite 单独 `.serialized` 无法避免跨 suite async 期间抢 keyWindow。
- 新增 `Tests/TritonKitTests/TKUIKitWindowTestSupport.swift`：外层 `@Suite(.serialized) TKUIKitWindowTests` 统一包住 input / collection / AX 三 suite；保留独立源文件。UIKit 测试选择器改为 `TritonKitTests/TKUIKitWindowTests`。
- window helper 优先选择 foregroundActive / foregroundInactive UIWindowScene；hostless runner 无 scene 时创建真实 UIWindow 并使用 runtime 既有 object registry 注册。helper 严格检查 visible 与 `keyWindows().first` identity；不能成立时立即停止该 fixture 并清理窗口，不改 runtime 安全检查、不 swizzle、不伪造 scene 状态。
- 此次修改仅 test fixture；未修改 #211 fixture。macOS recovery focused 3 tests / 2 suites 通过、diff check 通过；修补后的真实 UIKit 复跑由主控继续串行执行，尚不能宣称 iOS 通过。

## 2026-09-08 主控集成验收

2026-09-08 用户已授权提交、合入 main、推送和关闭 issue；各实现分支已串行合入本地 main，正在等待 push/CI 后远端收口。最终 CLI 全量 977/977、根包 269/269、专用 iOS 26.5 Simulator UIKit 46/46 通过；本地总门禁通过。UIKit 覆盖包含 collection selection、longPress fail-closed、富文本 run 和实际 trait；Harmony 为离线 CDP/HDC fixture，不声称真实 DevEco smoke。详细证据与失败→修补过程见 ../SP-176-open-issues-integration/plans/20260908-issue-audit.md。
