# 20260711 WebView-aware Tap Smoke

## 结论

真实 iOS Simulator 动态验收通过：

- Simulator：`83407554-53AB-45B4-A0C1-D59F34E26A67`，iPhone 17 Pro，iOS 26.5。
- 命令：`triton act tap --webview-aware --selector "#submit" --expect-text "submitted=true" --json`。
- 结果：`ok=true`、`status=passed`、`attempts[].method=dom_dispatch`、`trusted=false`、`verification.textMatched=true`。
- 完整 harness 同时通过 overview、edge、navigation、stale page session 与 event 回归。

## 红绿证据

- `red-expected/webview-aware-tap.json`：DOM click 已派发，但页面没有业务状态变化，结果为 `status=uncertain`、`textMatched=false`。
- `passed/webview-aware-tap.json`：Demo 增加 `#submit` 点击状态后，结果转为 `status=passed`、`textMatched=true`。
- `passed/xcode-run.jsonl`：通过 `triton xcode run` 完成构建、安装和启动。
- `passed/status-after-launch.json`：embedded runtime 已连接。

目标 Simulator 通过 `triton sim boot --wait --jsonl` 启动，证据见 `sim-boot.jsonl`。全程未使用裸 `xcrun`、XcodeBuildMCP 或其他 fallback。

## Triton-first 基线

目录根部保留 `status`、`doctor`、`capabilities`、`schema-act`、`schema-xcode` 与 `plan-webview-check` 输出。初始 server 不可用，harness 按既有契约启动本机 `triton serve` 后继续。
