# SP-172：longPress / 坐标 swipe 的手势识别路径修复（fail-closed）

## 边界

- 对应 GitHub issue：#208 `[Bug] Long press input does not drive UILongPressGestureRecognizer`
- 影响层：embedded iOS runtime 输入动作（`Sources/TritonKit/TKRuntimeInputActions.swift`）、必要的 shared 模型（`Sources/TritonKitShared/TKInputModels.swift`）、action schema（`Sources/TritonKitCLI/CLISchemaActionCommands.swift`）、focused tests；不新增 HTTP/Web/Wails 控制面。
- 工作目录：`../TritonKit-worktrees/SP-172-issue-208-longpress-gesture-path/`
- 分支：`feat/SP-172-issue-208-longpress-gesture-path`
- 基线：`main@a56d7d6a`
- 目标：
  1. `longPress` 不再返回假成功：只有当附加的 `UILongPressGestureRecognizer` 能通过公开 UIKit 事件路径观察到 `.began`（及可选 `.changed`、terminal）转换时才返回 `ok:true`；否则返回 typed `unsupported_capability` 并附 host-HID / app-owned semantic action 恢复指引。
  2. 非 UIScrollView 目标的坐标 `swipe` 不再被 `Hit view is not inside a UIScrollView` 一刀切拒绝：在显式 opt-in 的 host-HID 路径可分发，或返回 typed unsupported；默认行为不得静默失败。

## 非目标

- 不引入私有 API（不伪造 `UITouch` 私有构造、不绕过 window sendEvent 边界）；embedded runtime 只承诺公开 UIKit API 可验证的 in-app 控制。
- 不实现 host-side simulator gesture provider 的新产品面（host HID 既有 opt-in 模式沿用，不扩权）。
- 不改 `TKRuntimeInputActions.swift` 中 collection cell 区域（SP-171 先行，本 space 在其合入后串行执行）。
- 不连接真实 Simulator / 私有 App；以离线单测与 fixture 验证。

## BDD 验收

### 场景 1：longPress 不再假成功

- Given `UIControl` 附加 `UILongPressGestureRecognizer`，embedded 注入无法驱动 recognizer
- When 执行 `{"type":"longPress","x":...,"y":...,"duration":6}`
- Then 返回 typed `unsupported_capability`（稳定 error code + recovery 指引），而不是 `ok:true` + `control-long-press-touch-events` 假成功；若采用可驱动 recognizer 的公开路径实现，则必须以可验证的 recognizer 状态转换作为成功前提。

### 场景 2：非 scroll view 的坐标 swipe 可显式分发或明确 unsupported

- Given 坐标 swipe 的 hit view 是 `UIControl`（非 UIScrollView）
- When 显式 opt-in host-HID fallback
- Then swipe 事件可提交到 host 路径；未 opt-in 时返回 typed unsupported（含恢复动作），不再以 UIScrollView 限制为由直接失败且无出路。

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

真实 Simulator / 私有 App 不作为本次验收前置；recognizer 可驱动性以 fixture 与公开 API 契约验证。

## 当前状态

- 执行中：space 已建立；与 SP-171 共享 `TKRuntimeInputActions.swift`，按主控调度在 SP-171 之后串行实现。
