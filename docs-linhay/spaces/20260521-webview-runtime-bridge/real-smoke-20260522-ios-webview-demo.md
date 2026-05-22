# 20260522 iOS WebView Demo Real Smoke

## 目标

验证 iOS 专用模拟器上的真实 `WKWebView` smoke 页面，并确认本轮新增 `triton webview list/current` 可读取 provider metadata；`webview call/events` 只能通过页面 opt-in bridge 工作，不开放任意 JavaScript eval。

## 环境

- Simulator：`TritonKit Dedicated iPhone 17`
- UDID：`0333546D-2AC6-4C22-AF01-293E2F4BA5BC`
- App：`Examples/TritonKitDemo/TritonKitDemo.xcodeproj`
- Scheme：`TritonKitDemo`
- Triton server：`127.0.0.1:19421`
- Artifact 目录：`docs-linhay/spaces/20260521-webview-runtime-bridge/screenshots/20260522/ios-webview-demo/`

## 执行命令

```bash
.build/cli/debug/triton xcode use --project Examples/TritonKitDemo/TritonKitDemo.xcodeproj --scheme TritonKitDemo --configuration Debug --simulator 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --json
.build/cli/debug/triton xcode run --jsonl
.build/cli/debug/triton status --json
.build/cli/debug/triton webview list --platform ios --json
.build/cli/debug/triton webview current --platform ios --json
.build/cli/debug/triton webview call getRouteState --platform ios --json
.build/cli/debug/triton webview call submitSearch --arg keyword=events --platform ios --json
.build/cli/debug/triton webview call deleteAccount --platform ios --json
.build/cli/debug/triton webview events --platform ios --limit 10 --json
.build/cli/debug/triton observe tree --platform ios --json
.build/cli/debug/triton sim screenshot --simulator 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --output docs-linhay/spaces/20260521-webview-runtime-bridge/screenshots/20260522/ios-webview-demo/20260522-ios-webview-screenshot-real-v02.png --json
```

## 结果

1. XcodeBuildMCP `build_run_sim` 构建、安装、启动成功，App bundle 为 `com.neptunekit.tritonkit.demo`。
2. `triton serve` 使用本轮 `.build/cli/debug/triton` 启动于 `127.0.0.1:19421`，Demo 重新 launch 后连接成功。
3. `webview list --platform ios --json` 返回 1 个 provider 候选：`source=webview-provider`、`candidateOnly=false`、`providerStatus=available`、`webViewID=ios-webkit:234`。
4. provider metadata 可读：`url=https://tritonkit.local/smoke`、`title=Triton WebView Smoke`、`pageSessionID=ios-webkit:234:page:4469301163300129400`、`isLoading=false`、`estimatedProgress=1`、`frame={x:16,y:593.3333333333333,width:370,height:150}`。
5. `webview current --platform ios --json` 返回同一 WebView provider descriptor。
6. `webview call getRouteState --platform ios --json` 成功，result 为 `{ route: "/smoke", ready: true, title: "Triton WebView Smoke" }`。
7. `webview call submitSearch --arg keyword=events --platform ios --json` 成功，result 为 `{ ok: true, keywordLength: 6 }`。
8. `webview call deleteAccount --platform ios --json` 失败符合预期，`error.code=webview_method_not_allowed`，证明未 allowlist 方法不会被执行。
9. `webview events --platform ios --limit 10 --json` 返回 `search.submitted`，`payload.keywordLength=6`，`source=page-bridge`，且响应中的 `limit=10`。
10. host-side screenshot 已保存：`20260522-ios-webview-screenshot-real-v02.png`。

## 证据

- `20260522-ios-webview-list-real-v02.json`
- `20260522-ios-webview-current-real-v01.json`
- `20260522-ios-webview-observe-tree-real-v02.json`
- `20260522-ios-webview-screenshot-real-v02.png`

## 结论

本轮真实验证通过：CLI 已能在 iOS runtime 侧读取当前可见 `WKWebView` provider metadata，并能通过页面显式 opt-in bridge 调用 allowlist 方法、读取页面事件。当前仍不开放任意 JS eval；DOM snapshot、Web 内点击/输入、wait/evidence/replay 仍是后续阶段。
