# Issue 43: iOS Simulator Host Input

## 背景

GitHub issue: https://github.com/NeptuneKit/TritonKit/issues/43

真实 iOS App 验证时，`triton sim screenshot` 已可在 embedded runtime 不可用时通过 host-side Simulator adapter 获取截图，但 `triton tap` / `triton type` 默认进入 embedded runtime。若 `triton serve` 未运行或 App 未连接 runtime，agent 无法继续用 TritonKit 完成简单 UI 设置，只能回退到外部工具。

本需求为 iOS Simulator 增加最小 host-side input 能力，优先服务 agent 可执行、可审计、可 JSON 解析的本机模拟器工作流。

## 范围

本期包含：

- 新增 agent-facing CLI：`triton sim tap --simulator <udid|booted> --x <x> --y <y> --json`。
- 新增 agent-facing CLI：`triton sim type --simulator <udid|booted> --text <ascii-text> --json`。
- 输出保持 JSON envelope，标记 `runtimeScope=host-simulator`，并暴露 `sourceCommand` / adapter 信息。
- `triton schema --command sim --json` 暴露 `tap` / `type` subcommands、失败码、输出契约与能力。
- `triton capabilities --json` 暴露 host iOS Simulator input capability。
- `triton plan ios-smoke --json` 在 iOS smoke 计划中给出 host-side Simulator input fallback 提示，供 embedded runtime action 被 `server_unavailable` 阻塞时选用。

本期不包含：

- 不新增 Web / Wails UI。
- 不支持真机输入。
- 不实现 App 内语义 selector tap；host-side iOS tap 只承诺坐标。
- 不宣称非 ASCII、复杂 IME、硬件按键、Home/App Switcher、拖拽、多指手势、长按等 primitive 可用。
- 不把 host-side input 混入 embedded runtime 的语义 action 成功定义。

## 公开 host primitive 调研结论

可用的稳定公开命令：

- 坐标点击：`xcrun simctl io <simulator> tap <x> <y>`。
- 文本输入：`xcrun simctl io <simulator> keyboard type <text>`。

边界：

- `keyboard type` 面向当前焦点输入目标，无法证明业务文本已进入正确控件；后续必须结合截图、runtime wait/assert、偏好读取或 evidence 验证。
- 文本首期限制 ASCII，避免 IME、组合字符、shell quoting 与 Simulator keyboard 行为差异被误报为成功。
- 若底层 `simctl` 不支持对应子命令或返回失败，TritonKit 必须返回 `ok=false` 与稳定错误码，不伪造成 input 成功。

## BDD 场景

### 场景 1：坐标 tap 不依赖 embedded runtime

Given 一台已 boot 的 iOS Simulator
And App 未连接 `triton serve`
When agent 执行 `triton sim tap --simulator booted --x 200 --y 400 --json`
Then TritonKit 通过 host-side adapter 调用 `xcrun simctl io booted tap 200 400`
And 输出 `ok=true`
And 输出包含 `action=sim.tap`
And 输出包含 `runtimeScope=host-simulator`
And 输出包含 `adapter=xcrun-simctl`
And 输出包含可审计的 `sourceCommand`
And 输出包含后续验证建议，提醒 host action 不是业务成功证明

### 场景 2：ASCII type 不依赖 embedded runtime

Given 一台已 boot 的 iOS Simulator
And 当前 UI 已聚焦到可输入文本框
When agent 执行 `triton sim type --simulator booted --text "http://127.0.0.1:8000" --json`
Then TritonKit 通过 host-side adapter 调用 `xcrun simctl io booted keyboard type <text>`
And 输出 `ok=true`
And 输出包含 `action=sim.type`
And 输出包含 `runtimeScope=host-simulator`
And 输出包含 `adapter=xcrun-simctl`
And 输出包含 `textEncoding=ascii`
And 输出不内联或二次记录敏感文本以外的 App 状态

### 场景 3：非 ASCII 文本明确拒绝

Given agent 准备输入非 ASCII 文本
When agent 执行 `triton sim type --simulator booted --text "登录" --json`
Then TritonKit 不调用 `simctl`
And 输出 `ok=false`
And 错误码为 `unsupported_text_input`
And 输出建议改用 embedded runtime 语义输入、pasteboard flow 或后续受支持的 host primitive

### 场景 4：schema 与 capabilities 暴露 host input 能力

When agent 执行 `triton schema --command sim --json`
Then `sim` schema 包含 `tap` / `type` subcommands
And subcommands 的 `outputSelectors` 指向 host simulator input 输出契约
And schema `providedCapabilities` 包含 `ios-simulator-host-tap` 与 `ios-simulator-host-type`

When agent 执行 `triton capabilities --json`
Then capabilities matrix 包含上述能力
And 每个能力都有 `group=host`、`runtimeScope=host-simulator` 语义描述、next action 与 evidence
And `requiredBy[]` 包含 `action` 与 `smoke`，说明它服务动作/冒烟工作流但仍属于 host adapter

### 场景 5：ios-smoke plan 给出 fallback 路径

Given agent 正在规划 iOS smoke
When agent 执行 `triton plan ios-smoke --json`
Then plan 保留 embedded runtime wait/assert/evidence 为主验证路径
And plan 在 action/setup 阶段给出 host-side `triton sim tap` / `triton sim type` fallback step
And step 标记 `category=prepare-target`
And step 的 `argv[]` 与 schema 保持一致

## 验收标准

- 新增或更新测试先失败，再通过实现修复。
- CLI mock/focused tests 覆盖 tap/type 成功 envelope、非 ASCII 拒绝、schema 暴露、capabilities 暴露与 ios-smoke fallback。
- focused tests 通过。
- 能构建 CLI 时，执行 `swift build --package-path CLI --scratch-path .build/cli --product triton`。
- 能执行 schema smoke 时，执行 `.build/cli/debug/triton schema --command sim --json`。
- 更新 `README.md`、`docs-linhay/dev/ai-cli-readable-control.md` 与 memory，说明 host action 的能力边界和验证要求。
