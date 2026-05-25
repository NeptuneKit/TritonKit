# 20260525 iOS Simulator WebView Harness Real Smoke

## 目标

验证方案 A：扩展现有 `Examples/TritonKitDemo` 作为 iOS Simulator WebView / runtime harness，而不是新建独立测试 App。

## 环境

- Simulator：`TritonKit Dedicated iPhone 17`
- UDID：`0333546D-2AC6-4C22-AF01-293E2F4BA5BC`
- App：`Examples/TritonKitDemo/TritonKitDemo.xcodeproj`
- Scheme：`TritonKitDemo`
- Triton server：`127.0.0.1:19421`
- 输出目录：`/tmp/triton-ios-webview-harness-script`

## 执行命令

```bash
swift build --package-path CLI --scratch-path .build/cli --product triton
TRITON_SIMULATOR=0333546D-2AC6-4C22-AF01-293E2F4BA5BC TRITON_VERIFY_OUT_DIR=/tmp/triton-ios-webview-harness-script docs-linhay/scripts/verify-ios-webview-harness.sh
```

## 覆盖场景

1. `overview` 默认场景保持旧 complex harness + basic WebView 布局。
2. `webview-edge` 场景通过 `triton find "Web Edge" --all --json` 读取 segmented label 坐标，再用 `triton tap --x --y` 切换。
3. `webview-edge` snapshot 验证：
   - `webView.title=Triton WebView Edge`
   - forms / links 均受 `max-dom-nodes` 上限约束
   - password field 仅返回 `valueRedaction=length-only`
   - 长文本触发 `truncation.truncated=true`
4. `webview-edge` bridge / events 验证：
   - `webview call getRouteState` 返回 `route=/edge`
   - `webview call emitEdgeEvent` 后，`webview events` 包含 `edge.ready`
5. `webview-navigation` 场景验证：
   - 初始 `webview current` 返回 `Triton WebView Navigation A`
   - `webview call navigateDetails` 返回 `route=/navigation/b`
   - 使用旧 `pageSessionID` 请求 snapshot 返回 `error.code=webview_navigation_changed`
   - 新 `webview current` 返回 `Triton WebView Navigation B`
   - `webview events` 包含 `navigation.changed`

## 结果

脚本输出：

```text
iOS WebView harness verification passed
output: /tmp/triton-ios-webview-harness-script
simulator: 0333546D-2AC6-4C22-AF01-293E2F4BA5BC
```

## 过程修正

真实 smoke 暴露了两个问题并已同步修复：

1. 直接 `triton tap "Web Edge"` 会命中 segmented label，但 UIKit segmented control 内部节点顺序可能导致选中错误 index；脚本改为先 `find` 获取 label frame，再用坐标 tap。
2. stale `pageSessionID` 时 runtime 已返回 WebView error envelope，但 CLI 先解码 `TKWebViewSnapshotResponse`，导致错误被包成 `request_failed`；CLI 现在会先尝试 snapshot，再尝试 `TKWebViewErrorResponse`，保留 `webview_navigation_changed`。

## 结论

现有 Demo 已可作为 iOS Simulator WebView harness 覆盖 snapshot、redaction、truncation、bridge call、events 和 navigation-changed error。该 harness 仍只覆盖本机 iOS Simulator DEBUG runtime；Harmony ArkWeb provider、`webview wait` 与 evidence/replay 接入仍留到后续切片。
