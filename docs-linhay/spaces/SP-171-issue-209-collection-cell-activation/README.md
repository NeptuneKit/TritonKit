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

- 执行中：space 已建立，等待实现。
