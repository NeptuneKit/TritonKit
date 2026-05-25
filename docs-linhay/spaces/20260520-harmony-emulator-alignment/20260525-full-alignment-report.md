# 20260525 Harmony 全量对齐报告

## 背景

本轮目标是把 Harmony Emulator 的 CLI 行为尽量对齐 iOS 侧既有能力，重点核查：

1. 点击 / 滑动 / 输入 / 粘贴 / 按键。
2. `ax` / `wait` / `screenshot` / `device` 基础链路。
3. `webview` 是否已经达到 iOS 的 provider / snapshot / bridge 级别。

结论先写在前面：Harmony 的 host-side 动作链路已经补到可用，但 WebView 仍未达到 iOS 的 provider 级对齐；当前只能做到 host-layout 候选，不应误写成 DOM / URL / bridge 已对齐。

## 已对齐

### 设备与就绪

- `triton device list --platform harmony --json` 成功返回单个 Connected target：`127.0.0.1:10100`。
- `triton device wait-ready --platform harmony --target 127.0.0.1:10100 --timeout 5 --json` 成功返回 `ready=true`。

### Host-side 观测

- `triton ax --platform harmony` 仍走 `hdc shell uitest dumpLayout`。
- `triton screenshot --platform harmony` 仍走 `snapshot_display` + `file recv`。

### Host-side 输入

- `tap` 已是 Harmony host 侧实现。
- 本轮补齐了 `swipe`、`type`、`paste`、`press` 的 Harmony host 分支。
- `swipe` 使用 `hdc shell uitest uiInput swipe`，`duration` 会换算为 velocity。
- `type` / `paste` 使用 `uiInput text` / `inputText`。
- `press` 使用 `uiInput keyEvent`，`home/back/power/lock` 已做映射。
- 真实执行已通过：
  - `triton swipe --platform harmony --target 127.0.0.1:10100 --start-x 350 --start-y 900 --end-x 350 --end-y 300 --json`
  - `triton press home --platform harmony --target 127.0.0.1:10100 --json`

### 代码与测试

- 新增测试 `CLI/Tests/TritonKitCLITests/HarmonyActionAlignmentTests.swift`。
- 扩展了 `Tests/TritonKitSharedTests/TKHostAdapterModelsTests.swift` 对 Harmony HDC argv 的覆盖。
- 相关测试已通过：
  - `swift test --filter HarmonyActionAlignmentTests`
  - `swift test --package-path CLI --scratch-path .build/cli --filter HarmonyActionAlignmentTests`
  - `swift test --filter TKHostAdapterModelsTests`

## 部分对齐

### `swipe`

- 已对齐到 Harmony host 侧。
- 但 `--width/--height` 归一化没有 Harmony 语义，当前会明确拒绝。
- `duration` 只能近似换算为 velocity，不是 iOS 语义的一比一等价。

### `type` / `paste`

- 已对齐到 Harmony host 侧。
- 但当前只支持焦点输入或坐标聚焦，不支持 `--oid`。
- `paste` 本质是“先聚焦，再输入文本”，不是独立剪贴板语义。

### `press`

- 已对齐到 Harmony host 侧的 `keyEvent`。
- 但 `--duration` 不支持，长按语义仍未落地。

### `clear`

- 当前没有稳定的 Harmony `uitest` 清空当前输入框语义。
- 这条路径现在明确返回 `unsupported_capability`，不再假装已对齐。

## 未对齐 / 阻塞

### WebView provider / bridge

当前 Harmony `triton webview list --platform harmony --target 127.0.0.1:10100 --json` 的真实结果是：

- `candidates[]` 为空。
- `host-layout` 可用。
- `runtime-tree` 不可用，原因是没有 `runtime-base-url`。
- `webview-provider` 不可用，原因是 `provider not registered`。

`triton webview current-url --platform harmony --target 127.0.0.1:10100 --json` 也明确失败，返回：

- `error.code=webview_not_found`
- `message=No visible WebView candidate found.`

这意味着 Harmony 目前还停在“可见 Web 容器候选”阶段，未达到 iOS 那种：

- `webview current-url`
- `webview snapshot`
- `webview call`
- `webview events`

的 provider / bridge 级对齐。

### WebView 相关能力缺口

- `DOM`
- `URL`
- `JS bridge`
- `page events`
- `wait on WebView state`

都还没有 Harmony provider 支撑，不能写成已对齐。

## 证据

执行过的关键命令：

```bash
.build/cli/debug/triton schema --command swipe --json
.build/cli/debug/triton schema --command webview --json
.build/cli/debug/triton device list --platform harmony --json
.build/cli/debug/triton device wait-ready --platform harmony --target 127.0.0.1:10100 --timeout 5 --json
.build/cli/debug/triton webview list --platform harmony --target 127.0.0.1:10100 --json
```

## 结论

Harmony Emulator 的 host action 层已经和 iOS 更接近了，尤其是点击、滑动、输入、粘贴、按键这些基础动作。

但 WebView 仍然没有达到 iOS 的 provider / bridge 对齐，当前只能算 host-layout 级别的候选发现。后续如果要继续追平，需要先在 Harmony 侧补一个可注册的 WebView provider，再谈 snapshot / current-url / call / events。
