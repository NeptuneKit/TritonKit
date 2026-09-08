# SP-172：longPress / 坐标 swipe 的手势识别路径修复（fail-closed）

> 当前状态：已归档。主线代码 CI 通过，对应 issue 已关闭；以下前期验证记录保留为历史。

## 边界

- 对应 GitHub issue：#208 `[Bug] Long press input does not drive UILongPressGestureRecognizer`
- 影响层：embedded iOS runtime 输入动作（`Sources/TritonKit/TKRuntimeInputActions.swift`、`TKRuntimeGestureActions.swift`）、必要的 shared 模型（`Sources/TritonKitShared/TKInputModels.swift`）、action schema（`Sources/TritonKitCLI/CLISchemaActionCommands.swift`）、focused tests；不新增 HTTP/Web/Wails 控制面。
- 工作目录：`../TritonKit-worktrees/SP-172-issue-208-longpress-gesture-path/`
- 分支：`feat/SP-172-issue-208-longpress-gesture-path`
- 基线：`main@a56d7d6a`
- 目标：
  1. `longPress` 不再返回假成功：只有当附加的 `UILongPressGestureRecognizer` 能通过公开 UIKit 事件路径观察到 `.began`（及可选 `.changed`、terminal）转换时才返回 `ok:true`；否则返回 typed `unsupported_capability` 并附 host-HID / app-owned semantic action 恢复指引。
  2. 非 UIScrollView / UISlider 目标的坐标 `swipe` 返回 typed unsupported；当前不提供 iOS host swipe/hold-and-drag 原语，不将 capability discovery 描述为事件分发。

## 非目标

- 不引入私有 API（不伪造 `UITouch` 私有构造、不绕过 window sendEvent 边界）；embedded runtime 只承诺公开 UIKit API 可验证的 in-app 控制。
- 不实现 host-side simulator gesture provider 的新产品面（host HID 既有 opt-in 模式沿用，不扩权）。
- SP-171 先行；本 space 仅修补其审计发现的测试缺口，并为满足 1500 行约束机械搬移 collection helper 至 `TKRuntimeCollectionActions.swift`，不改变 collection selection 的运行时行为。
- 不连接真实 Simulator / 私有 App；以离线单测与 fixture 验证。

## BDD 验收

### 场景 1：longPress 不再假成功

- Given `UIControl` 附加 `UILongPressGestureRecognizer`，embedded 注入无法驱动 recognizer
- When 执行 `{"type":"longPress","x":...,"y":...,"duration":6}`
- Then 返回 typed `unsupported_capability`（稳定 error code + recovery 指引），而不是 `ok:true` + `control-long-press-touch-events` 假成功；若采用可驱动 recognizer 的公开路径实现，则必须以可验证的 recognizer 状态转换作为成功前提。

### 场景 2：非 scroll view 的坐标 swipe 明确 unsupported

- Given 坐标 swipe 的 hit view 是 `UIControl`（非 UIScrollView）
- When 执行 embedded 坐标 swipe
- Then 返回 `unsupported_capability` + `embedded-swipe-gesture-unsupported`；`nextAction` 指向可执行的 semantic snapshot，`suggestedCommands` 提供 schema discovery，并明确它们不会提交手势。
- And `UIScrollView` contentOffset 和 `UISlider` value 的既有公开更新仍保留，不能当作 recognizer 状态转换证据。

### 场景 3：离线回归覆盖

- Then 离线单测覆盖策略选择、envelope 形状与 recovery 字段；schema（如涉及）同步更新 failureCodes。

## 验收命令

```bash
swift test --scratch-path .build/sp172-root --filter TKRuntimeInputActions
swift test --scratch-path .build/sp172-root
swift build --package-path CLI --scratch-path .build/sp172-cli -c release --product triton
docs-linhay/scripts/check-docs.sh
git diff --check
```

macOS `swift test` 只运行跨平台契约测试，不能执行 `#if canImport(UIKit)` fixture，也不能证明 UIKit recognizer 行为。UIKit fixture 需在独立 iOS Simulator destination 运行；由主控串行调度，不在本 worktree 执行设备动作。

## 当前状态

- 2026-09-08 已完成 embedded fail-closed 实现，等待主控集成与平台验证。
- `performLongPress` 对已解析 target 统一返回 typed unsupported，不再调用 UIControl `sendActions`、等待 duration 或伪造触摸。存在 local/ancestor recognizer 时保留 strategy=`long-press-gesture-recognizer`，其余 target 使用 `embedded-long-press-unsupported`。
- 非 scroll/slider `performSwipe` 返回 strategy=`embedded-swipe-gesture-unsupported`，保留 matched/activation 元数据。
- 错误契约：`error.code=unsupported_capability`；`nextAction=snapshot --include semantic --json`；辅助命令为 `schema --command sim/act --json`。文案明确 app-owned DEBUG integration 需要应用提供，当前没有可推荐的 duration-aware host longPress 命令，不能用 `tap --duration` 假装恢复成功。
- #208 2026-08-28 补充评论中的 host tap duration 丢失，由主控在集成目录补 typed reject 与 CLI fixture；本 space 负责 schema 描述同步。
- 新增跨平台 `TKEmbeddedGestureRecoveryTests` 2 场景：unsupported envelope、round-trip、可执行 discovery，以及不虚构 host hold；红灯为缺失 helper 的编译错误，实现后 2 场景通过。加上既有 collection recovery，共 3 个 focused 场景通过。
- UIKit fixture：plain UIControl、local/ancestor UILongPressGestureRecognizer、UIView recognizer 和非 scroll control swipe，断言无 callback、副作用与 recognizer state 转换；此处尚未运行 iOS destination。
- 源文件分离：gesture/collection 专属函数从原 1992 行文件搬出，`TKRuntimeInputActions.swift` 1496 行，`TKRuntimeGestureActions.swift` 276 行，`TKRuntimeCollectionActions.swift` 208 行。


## 验证记录（2026-09-08）

- `swift test --scratch-path .build/sp172-audit-root --filter 'TKEmbeddedGestureRecoveryTests|TKCollectionCellRecoveryTests'`：3 tests / 2 suites 通过。
- `swift test --scratch-path .build/sp172-audit-root`：265 tests / 33 suites 通过；destination 为 macOS，不计作 UIKit 实测。
- `git diff --check`：通过。
- `docs-linhay/scripts/check-docs.sh`：被分支既有索引缺口阻塞，错误为 `space registry IDs must be contiguous from SP-001: SP-171-issue-209-collection-cell-activation`；当前 INDEX 从 SP-169 跳到 SP-171，主控负责整合公共索引。
- 无锁文件、生成文件或运行设备的产物变更；独立 scratch 与构建日志忽略入库。

- CLI red：`EmbeddedGestureSchemaTests` 2 场景与 SP-171 旧 schema fixture 共 3 tests / 9 assertions 失败，证明缺失/过期契约；修复后 `swift test --package-path CLI --scratch-path .build/sp172-audit-cli --filter 'EmbeddedGestureSchemaTests|WebViewRouteTests'` 为 20 tests / 2 suites 全过。
- CLI 契约同步：act 顶层和 tap 描述明确所有 `tap --duration` 路由 typed reject；raw input longPress fail-closed；swipe 仅承诺 UIScrollView/UISlider 公开更新；act 顶层补充 collection selection blocked/denied codes。
- `.build/sp172-audit-cli/debug/triton schema --command sim --json` 与 `schema --command snapshot --json` 均成功，输出可 JSON decode；未执行恢复手势、私有工程或设备操作。
- 完整 CLI 回归、Release build、UIKit destination 与 `verify.sh --local` 由主控在集成 worktree 统一执行；本 worktree 没有重复跑共享设备或全局门禁。


## UIKit 集成复跑后的 fixture 修补（2026-09-08）

- 主控在独立 iOS 26.5 Simulator 合跑 4 suites，46 tests 中 19 pass / 27 fail。原始 stdout 显示三个 window suite 同时启动；大量失败为 `stale_runtime_hierarchy: attached to an inactive window` / `No key window`，部分坐标命中其他 fixture。每个 suite 单独 `.serialized` 无法避免跨 suite async 期间抢 keyWindow。
- 新增 `Tests/TritonKitTests/TKUIKitWindowTestSupport.swift`：外层 `@Suite(.serialized) TKUIKitWindowTests` 统一包住 input / collection / AX 三 suite；保留独立源文件。UIKit 测试选择器改为 `TritonKitTests/TKUIKitWindowTests`。
- window helper 优先选择 foregroundActive / foregroundInactive UIWindowScene；hostless runner 无 scene 时创建真实 UIWindow 并使用 runtime 既有 object registry 注册。helper 严格检查 visible 与 `keyWindows().first` identity；不能成立时立即停止该 fixture 并清理窗口，不改 runtime 安全检查、不 swizzle、不伪造 scene 状态。
- 此次修改仅 test fixture；未修改 #211 fixture。macOS recovery focused 3 tests / 2 suites 通过、diff check 通过；修补后的真实 UIKit 复跑由主控继续串行执行，尚不能宣称 iOS 通过。

## 2026-09-08 主控集成验收

2026-09-08 用户授权后，已合入并推送 main（`82a13db5`），[代码 CI](https://github.com/NeptuneKit/TritonKit/actions/runs/34179623896) 通过；#207～#212 已逐条回填证据并关闭，关闭后 open 查询为 0。最终 CLI 全量 977/977、根包 269/269、专用 iOS 26.5 Simulator UIKit 46/46 通过；本地总门禁通过。UIKit 覆盖包含 collection selection、longPress fail-closed、富文本 run 和实际 trait；Harmony 为离线 CDP/HDC fixture，不声称真实 DevEco smoke。详细证据与失败→修补过程见 ../SP-176-open-issues-integration/plans/20260908-issue-audit.md。
