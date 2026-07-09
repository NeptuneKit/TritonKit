# WebView-aware `act tap` 技术方案 v01

日期：2026-07-09

## 背景

真实 H5 回归中出现一类失败：native AX / hit-test 只能看到 `WKWebView` 或其 native 容器，看不到 WebView 内 DOM 按钮；真实 HID 点击可见按钮后也没有请求，说明可见按钮、真实可点击 DOM 层、overlay、disabled 状态、滚动偏移或前端 handler 之间可能不一致。

TritonKit 面向 AI agent 的入口仍应是 `triton act`，而不是要求 agent 手工编排 `webview snapshot -> DOM selector -> DOM click -> wait -> HID fallback`。底层 WebView 命令用于 evidence/debug，高层 agent 体验应保持单一动作入口。

## 外部 advisor 裁决

采纳：

1. `triton act tap` 是 agent-facing 主入口；`webview hit-test/click` 只作为内部积木或 debug/evidence。
2. 第一刀显式 opt-in：`--webview-aware` 默认关闭，避免影响现有 native tap 链路。
3. 第一刀必须包含极简 runtime `webview.tap` 闭环，不能只交付纸面契约。
4. DOM click 的成功语义只能是 `dispatched=true, trusted=false`；只有 `--expect-*` 验证通过才可 `passed`。
5. `expect-request` 首期完全排除，避免引入 proxy / request interception 依赖。

拒绝：

1. 不把复杂坐标换算、selector 提取和验证循环交给 agent。
2. 不在第一刀做 Shadow DOM、iframe、复杂 CSS selector、文本模糊匹配或自动网络判断。
3. 不默认开启 WebView-aware 路由。

## 第一刀范围

### CLI

新增：

```bash
triton act tap --webview-aware --selector "#submit" --expect-text "成功" --json
triton act tap --webview-aware --selector "#submit" --webview-id "webview-1" --page-session-id "page-1" --expect-text "成功" --json
triton act tap --webview-aware --selector "#submit" --json
```

参数：

- `--webview-aware`：显式启用 WebView provider 路径。
- `--selector`：首期只支持 CSS selector 字符串，由 runtime 内 `document.querySelector` 执行。
- `--webview-id`：多 WebView 歧义时由 `triton webview list --json` 返回的候选 id。
- `--page-session-id`：可选页面会话防漂移校验；导航变化时失败并要求重新观察。
- `--expect-text`：复用现有 WebView wait text 语义作为业务完成证明。
- `--timeout`：复用 wait 超时；无 expect 时仅用于 runtime 调用安全边界。

首期不暴露：

- `--expect-request`
- `--click-mode`
- `--coordinate-space`
- `--webview-id` / `--page-session-id` 以外的底层 dispatch 细节
- 任意 JavaScript eval

### Runtime

新增极简 request：

```text
webViewTap -> /v2/runtime/webview/tap
```

行为：

1. 选择当前 WebView 或 `webViewID` 指定 WebView。
2. 校验 `pageSessionID` 未变化。
3. 执行受限脚本：`document.querySelector(selector)`，必要时 `scrollIntoView({ block: "center", inline: "center" })`。
4. 对元素执行合成 DOM click / MouseEvent。
5. 返回 `dispatched`、`trusted=false`、元素摘要、WebView frame、DOM rect 和 source command。

### 状态语义

- `passed`：DOM dispatch 成功，且 `--expect-text` 验证通过。
- `failed`：WebView provider 不可用、selector 不合法/未找到、page session 已变化、JS 执行错误。
- `uncertain`：DOM dispatch 成功，但没有 `--expect-text`，或 expect 未达成。返回 recovery command，不能假称业务完成。

## BDD 验收

### 场景 1：AX 盲区内的 H5 按钮可由 agent 单入口触发

- Given native AX 树只暴露 `WKWebView` 容器，不暴露 H5 `button#submit`
- When 执行 `triton act tap --webview-aware --selector "#submit" --expect-text "成功" --json`
- Then CLI 通过 `webViewTap` 派发 DOM click
- And 通过 WebView wait 观察到 `成功`
- And 输出 `status=passed`、`context=webview`、`attempts[0].method=dom_dispatch`、`trusted=false`

### 场景 2：没有 expect 时不得假成功

- Given H5 `button#submit` 存在且 DOM dispatch 返回成功
- When 执行 `triton act tap --webview-aware --selector "#submit" --json`
- Then 输出 `status=uncertain`
- And `verification.expectProvided=false`
- And `note` 明确说明 DOM dispatch 不等于业务完成

### 场景 3：expect 未达成时返回可恢复状态

- Given DOM click 已派发，但页面没有出现期望文本
- When 执行 `triton act tap --webview-aware --selector "#submit" --expect-text "成功" --json`
- Then 输出 `status=uncertain`
- And `verification.textMatched=false`
- And 输出 `recoveryCommand`，建议 agent 使用带显式验证的 native/HID 或 evidence 路径继续排查

## 测试门禁

1. Shared DTO encode/decode：覆盖 `passed/failed/uncertain`、`dispatched=true trusted=false`、recovery command。
2. Request route：`TKCLICommandRequest(type: "webViewTap")` 与 `/v2/runtime/webview/tap` 稳定。
3. Runtime script helper：selector 查找成功/失败 JSON 可解码；不支持任意 eval。
4. CLI schema：`act tap` 暴露 `--webview-aware`、`--selector`、`--expect-text`，且不暴露 `--expect-request`。
5. CLI decision helper：有 expect 且 matched 才 `passed`；无 expect 或 expect timeout 为 `uncertain`；selector not found 为 `failed`。

## Deferred

1. `expect-request` 与 proxy session 集成。
2. `webview hit-test --at` 和坐标映射输出。
3. 自动 HID fallback。
4. Shadow DOM / iframe / 复杂 CSS selector / 文本模糊匹配。
5. 默认开启 `--webview-aware`。
