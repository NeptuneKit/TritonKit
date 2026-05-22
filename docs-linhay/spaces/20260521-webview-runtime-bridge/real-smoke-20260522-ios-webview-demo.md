# 20260522 iOS WebView Demo Real Smoke

## 目标

验证 iOS 专用模拟器上的真实 `WKWebView` smoke 页面，并确认本轮新增 `triton webview list/current` 只暴露 WebView 候选与 provider 边界，不误报 DOM、JS、bridge、tap 或 type 可用。

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
.build/cli/debug/triton observe tree --platform ios --json
.build/cli/debug/triton sim screenshot --simulator 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --output docs-linhay/spaces/20260521-webview-runtime-bridge/screenshots/20260522/ios-webview-demo/20260522-ios-webview-screenshot-real-v02.png --json
```

## 结果

1. `xcode run` 构建、安装、启动成功，App 进程 pid 为 `86699`。
2. `status --json` 返回 `connected=true`、`activeHierarchyAvailable=true`、`targetCount=1`，target 为 `triton:ios-simulator:0333546D-2AC6-4C22-AF01-293E2F4BA5BC`。
3. `webview list --platform ios --json` 返回 1 个候选：`webViewID=ios-runtime:242`、`identifier=WebViewSmokeScrollView`、`role=scrollView`、`text=Triton WebView Smoke Container`。
4. 候选保持 `candidateOnly=true`、`providerStatus=unavailable`、`bridgeStatus=unavailable`。
5. 候选能力只有 `visible` 与 `runtime-oid`；`missingCapabilities` 包含 `webview.url`、`webview.dom`、`webview.bridge-call`、`webview.tap`、`webview.type`。
6. `webview current --platform ios --json` 返回同一候选，没有隐式声明 DOM / JS / bridge 能力。
7. `observe tree --platform ios --json` 中 `WebViewSmokeScrollView` 被标记为 `candidateOnly=true`，普通 `tap` capability 被移除，并包含 `webview.url/webview.dom/webview.bridge-call` 缺失能力。
8. host-side screenshot 已保存：`20260522-ios-webview-screenshot-real-v02.png`。

## 证据

- `20260522-ios-webview-list-real-v02.json`
- `20260522-ios-webview-current-real-v01.json`
- `20260522-ios-webview-observe-tree-real-v02.json`
- `20260522-ios-webview-screenshot-real-v02.png`

## 结论

本轮真实验证通过：CLI 已能在 iOS runtime 侧识别当前可见 WebView 候选，并把 Web provider 缺失作为机器可读边界暴露。当前仍不能执行 DOM、JS bridge、Web 内按钮点击或输入；这些能力必须等 WebView provider / page bridge 接入后再开放。
