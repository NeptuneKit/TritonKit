# Issue 43: iOS Simulator Host Input

## 背景

GitHub issue: https://github.com/NeptuneKit/TritonKit/issues/43

真实 iOS App 验证时，`triton sim screenshot` 已可在 embedded runtime 不可用时通过 host-side Simulator adapter 获取截图，但 `triton tap` / `triton type` 默认进入 embedded runtime。若 `triton serve` 未运行或 App 未连接 runtime，agent 无法继续用 TritonKit 完成简单 UI 设置，只能回退到外部工具。

本需求为 iOS Simulator 增加最小 host-side input 能力，优先服务 agent 可执行、可审计、可 JSON 解析的本机模拟器工作流。

## 范围

本期包含：

- 新增 agent-facing CLI 保留入口：`triton sim tap --simulator <udid|booted> --x <x> --y <y> --json`。
- 新增 agent-facing CLI 保留入口：`triton sim type --simulator <udid|booted> --text <ascii-text> --json`。
- 当前公开 `xcrun simctl io` contract 不暴露稳定 tap / keyboard type primitive，因此两个入口返回 JSON `unsupported_host_input`，不伪造成提交成功。
- `triton schema --command sim --json` 暴露 `tap` / `type` subcommands、失败码、输出契约与 unsupported capability。
- `triton capabilities --json` 暴露 host iOS Simulator input capability，但 `supported=false`，并保留 schema-backed nextAction。
- `triton plan ios-smoke --json` 给出 host input blocker 检查步骤，供 embedded runtime action 被 `server_unavailable` 阻塞时快速判断是否需要外部 fallback 或 app-owned debug hook。

本期不包含：

- 不新增 Web / Wails UI。
- 不支持真机输入。
- 不实现 App 内语义 selector tap；host-side iOS tap 只承诺坐标。
- 不宣称非 ASCII、复杂 IME、硬件按键、Home/App Switcher、拖拽、多指手势、长按等 primitive 可用。
- 不把 host-side input 混入 embedded runtime 的语义 action 成功定义。

## 公开 host primitive 调研结论

当前本机 `xcrun simctl io help` 只列出 `enumerate`、`poll`、`recordVideo`、`screenshot`、`screenConfig`，没有稳定公开的 `tap` 或 `keyboard type` primitive。

边界：

- `triton sim tap` / `triton sim type` 作为 agent-facing contract 保留，便于 schema、capabilities 和 plan 明确表达能力缺口。
- `sim type` 仍先做非 ASCII 校验，避免未来替换 adapter 时把 IME、组合字符或 shell quoting 差异误报为成功。
- 在没有稳定 host primitive 前，TritonKit 必须返回 `ok=false` 与稳定错误码，不伪造成 input 成功。
- 后续若选择 CGEvent、Accessibility、Simulator.app automation 或第三方 adapter，需新建/更新 space 重新定义风险、权限、审计与验收。

## BDD 场景

### 场景 1：坐标 tap 明确返回 unsupported

Given 一台已 boot 的 iOS Simulator
And App 未连接 `triton serve`
When agent 执行 `triton sim tap --simulator booted --x 200 --y 400 --json`
Then TritonKit 不调用不存在的 `simctl io tap`
And 输出 `ok=false`
And 错误码为 `unsupported_host_input`
And 输出 hint 指向 embedded runtime input、app-owned debug hook 或其他已验证 host tool

### 场景 2：ASCII type 明确返回 unsupported

Given 一台已 boot 的 iOS Simulator
And 当前 UI 已聚焦到可输入文本框
When agent 执行 `triton sim type --simulator booted --text "http://127.0.0.1:8000" --json`
Then TritonKit 不调用不存在的 `simctl io keyboard type`
And 输出 `ok=false`
And 错误码为 `unsupported_host_input`
And 输出 hint 指向 embedded runtime semantic input 或 pasteboard/debug-hook flow

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
And 每个能力都有 `supported=false`、`group=host`、next action 与 `unsupported-envelope` / `command-schema` evidence
And `requiredBy[]` 包含 `action` 与 `smoke`，说明这是动作/冒烟工作流中的 host adapter 缺口

### 场景 5：ios-smoke plan 给出 blocker 检查路径

Given agent 正在规划 iOS smoke
When agent 执行 `triton plan ios-smoke --json`
Then plan 保留 embedded runtime wait/assert/evidence 为主验证路径
And plan 在 action/setup 阶段给出 host-side input blocker 检查 step
And step 标记 `category=diagnose`
And step 的 `argv[]` 与 schema 保持一致

## 验收标准

- 新增或更新测试先失败，再通过实现修复。
- CLI focused tests 覆盖 tap/type unsupported envelope、非 ASCII 拒绝、schema 暴露、capabilities 暴露与 ios-smoke blocker step。
- focused tests 通过。
- 能构建 CLI 时，执行 `swift build --package-path CLI --scratch-path .build/cli --product triton`。
- 能执行 schema smoke 时，执行 `.build/cli/debug/triton schema --command sim --json`。
- 更新 `README.md`、`docs-linhay/dev/ai-cli-readable-control.md` 与 memory，说明 host action 的能力边界和验证要求。
