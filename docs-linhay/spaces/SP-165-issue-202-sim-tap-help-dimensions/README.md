# SP-165：`sim tap` help/schema 与 host action 维度契约对齐

## 边界

- 对应 GitHub issue：#202 `triton sim tap --help` 只宣传 `--simulator/--x/--y` 与输出格式，但运行时在 dispatch 前以 `host_action_failed: "tap requires width."` 拒绝，且 help/schema 没有 `--width/--height` 可满足该要求。
- 影响层：CLI `sim tap` 的 help、schema（`sim.tap` subcommand 与 `host.simulator-input` output contract）、host iOS HID action model（`webIOSBaguetteCommand` / `webIOSBaguetteSwipeLifecycle` 的 width/height 解析）与 focused tests；不新增 HTTP/Web/Wails 控制面。
- 工作目录：`../TritonKit-worktrees/SP-165-issue-202-sim-tap-help-dimensions/`
- 分支：`feat/SP-165-issue-202-sim-tap-help-dimensions`
- 基线：`origin/main@8cc72765`
- 目标：优先从 Simulator 布局 metadata 推导 point-space 维度，使 help 宣传的 `sim tap --x <x> --y <y>` 形状无需调用方传 width/height 即可满足 host action model；同时对齐 schema 的 failureCodes / summary 与输出语义。

## 非目标

- 不连接/启动真实 Simulator、不运行 xcrun/simctl、不修改设备状态；纯 parser/schema/fixture 验证。
- 不改变实际坐标 dispatch 行为（tap 仍走 host-HID adapter 与 Baguette argv），只修 help/schema/validation 契约一致性。
- 不新增必选 `--width/--height` CLI 选项；优先从 Simulator layout metadata（`baguette chrome layout` 已查询的 screen 尺寸）推导 point-space。
- 不触碰其他 worktree 或主仓库；不改 `act tap` 的 selector/routing 语义。

## BDD 验收

### 场景 1：`sim tap --x <x> --y <y>` 不再要求调用方传 width/height

- Given 用户按 help 宣传形状执行 `triton sim tap --simulator <udid|booted> --x <x> --y <y> --json`
- When host iOS HID 命令构建（`webIOSBaguetteCommand`）处理该 tap
- Then 不再抛出 `tap requires width.` / `tap requires height.`；point-space 宽度/高度从 Simulator layout metadata（screen.width/screen.height）推导并写入 Baguette argv `--width/--height`。

### 场景 2：带调用方 width/height 的坐标归一化保持不变

- Given 调用方提供自己的坐标空间（如 framebuffer 1206×2622）
- When 构建 Baguette tap/swipe 命令
- Then 坐标仍先经 `normalizeWebIOSSimulatorInput` 归一化到 Simulator point-space，Baguette argv 的 `--width/--height` 仍等于 Simulator screen 尺寸；既有归一化/argv 测试不回归。

### 场景 3：swipe/longPress 同样从 layout metadata 推导 point-space

- Given swipe lifecycle 或 longPress 输入未提供 width/height
- Then `webIOSBaguetteSwipeLifecycle` / longPress 命令从 screen layout 推导，不再抛 `swipe requires width.` / `longPress requires width.`。

### 场景 4：schema 与运行时一致

- Given agent 读取 `triton schema --command sim.tap --json`（或 `sim --json`）
- Then `tap` subcommand requiredOptions 仅为 `--x/--y`，不要求 `--width/--height`，summary 说明坐标位于 simulator points 且 point-space 从 simulator layout metadata 推导。
- Then failureCodes 包含运行时实际可产生的 `host_action_failed`（含 host tool 缺失/失败场景），help 宣传的形状与 schema 一致。

### 场景 5：失败输出保持单一合法 JSON envelope

- Given 任一 host failure（如 simulator 未 boot、host tool 不可用）
- When `sim tap` 失败
- Then stdout 仍是单一 `{ ok:false, error:{ code, message, hint, nextAction? } }`，不二次包装。

## 验收命令

```bash
swift test --package-path CLI --scratch-path .build/sp165-202 --filter SingleDeviceWebPageTests
swift test --package-path CLI --scratch-path .build/sp165-202 --filter SimulatorAdvancedControlsTests
swift build --package-path CLI --scratch-path .build/sp165-202-rel -c release --product triton
.build/sp165-202-rel/release/triton sim tap --help
.build/sp165-202-rel/release/triton schema --command sim.tap --json
docs-linhay/scripts/check-docs.sh
git diff --check
```

按本轮边界只运行 focused gates，不运行完整 `verify.sh --local`；真实 Simulator/Baguette 不作为验收前置条件。

## 当前状态

- 已完成（本地）：`webIOSBaguetteCommand`（tap/longPress）与 `webIOSBaguetteSwipeLifecycle`（swipe）新增 `webIOSSimulatorPointSpace` 推导：调用方未提供 width/height 时，point-space 取 Simulator layout metadata（screen.width/screen.height）；提供时保持既有归一化语义。`sim.tap` schema 的 summary 与 failureCodes 已补充 `host_action_failed` 并说明 point-space 推导。
- TDD red：新增 `SingleDeviceWebPageTests` 两个用例（tap/swipe 无 width/height 从 layout 推导）先以 `tap requires width.` / `swipe requires width.` 失败；新增 `simTapSchemaRequiresOnlyXYAndDeclaresInferredPointSpaceFailureCodes` 先因 summary 缺 "point"、failureCodes 缺 `host_action_failed` 失败。
- TDD green：最小实现后 `SingleDeviceWebPageTests` 30/30、`SimulatorAdvancedControlsTests` 34/34 通过；既有归一化/Baguette argv/swipe lifecycle 测试无回归。
- release CLI：`swift build -c release --product triton` 通过；release `sim tap --help` 与 `schema --command sim.tap --json` 已确认 help/schema 一致（仅 `--x/--y` 必选、无 width/height、`host_action_failed` 在 failureCodes）。
- 文档：`check-docs.sh` 与 `git diff --check` 通过；space 已登记到 INDEX 与路线总览。
- 风险：未连接真实 Simulator/Baguette；host-HID 成功仍只是提交回执，业务后置状态须以 observe/wait/screenshot 验证。
- 已评论并关闭远端 #202（合并提交 `07a11612`，CI `31791782001` 全绿）；真实 Simulator/Baguette smoke 保留为后续设备验证。
