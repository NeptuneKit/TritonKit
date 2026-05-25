# iOS Simulator Harness Design v01

## 背景

本 space 已经验证 iOS `WKWebView` provider metadata、bridge call、events 与 bounded snapshot。为了让后续 WebView / runtime 能力有稳定回归入口，本轮采用方案 A：扩展现有 `Examples/TritonKitDemo`，把它作为 iOS Simulator 专用 harness，而不是新建第二个 App。

## 目标

1. 单个 Demo App 覆盖 overview、runtime 连接、UIKit 控件、WebView 基础页面、WebView 边界页面和 WebView 导航页面。
2. 每个场景提供稳定文本和 accessibility identifier，便于 `triton observe/node/webview/assert` 命令回归。
3. WebView 场景覆盖 metadata、DOM/text/forms/links snapshot、allowlist bridge、events、redaction、truncation 和 page session 变化。
4. Demo 保持 DEBUG-only runtime 接入；Release 构建仍不启用采集或 bridge。

## 非目标

1. 不新增 Web/Wails UI。
2. 不新增独立三端 harness 工程。
3. 不把 Harmony ArkWeb provider 或 Android WebView 一次性混入本切片。
4. 不开放任意 `webview eval`。
5. 不把 Demo 当作生产集成样板；生产接入仍按 Debug bootstrap 文档执行。

## 场景设计

### 场景一：overview

- Given Demo 首次启动
- Then 默认显示 `ComplexHarnessPanel` 与基础 `WKWebView`
- And 既有 complex harness smoke 与 WebView smoke 不需要先切换场景即可继续运行

稳定标识：

- `HarnessScenarioPicker`
- `ComplexHarnessPanel`
- `WebViewSmokeWebView`

### 场景二：runtime-basic

- Given Demo 在 iOS Simulator Debug 模式运行
- When `triton serve` 可用且 App 已连接
- Then 页面显示 `runtime-basic ready`
- And CLI 可通过 `triton list --json` / `triton status --json` 读取 target

稳定标识：

- `HarnessScenarioPicker`
- `HarnessRuntimePanel`
- `HarnessRuntimeReadyText`

### 场景三：native-controls

- Given 用户切到 `native-controls`
- When 执行 `triton observe tree --platform ios --json`
- Then 输出包含 `ComplexHarnessPanel`、`ComplexHarnessPrimary`、`ComplexHarnessTextField`
- When 对 `Primary` 执行 tap
- Then `ComplexHarnessStatus` 的文本递增

### 场景四：webview-basic

- Given 用户切到 `webview-basic`
- When 执行 `triton webview list --platform ios --json`
- Then 返回一个 `webview-provider` 候选
- When 执行 `triton webview call getRouteState --platform ios --json`
- Then result 包含 `route=/smoke` 与 `ready=true`
- When 执行 `triton webview call submitSearch --arg keyword=events --platform ios --json`
- Then `triton webview events --platform ios --limit 10 --json` 返回 `search.submitted`

### 场景五：webview-edge

- Given 用户切到 `webview-edge`
- When 执行 `triton webview snapshot --platform ios --include metadata,dom,text,forms,links --max-dom-nodes 6 --max-text-bytes 512 --json`
- Then 返回 bounded snapshot
- And forms / links 不超过节点上限
- And secure field 只返回 `valueRedaction=length-only`
- And label 解析支持复杂 id，不依赖 selector 拼接
- And 大文本触发 `truncation.truncated=true`

### 场景六：webview-navigation

- Given 用户切到 `webview-navigation`
- When CLI 先读取 `pageSessionID=A`
- And 页面通过 allowlist bridge 执行 navigation
- And CLI 用旧 `pageSessionID=A` 请求 snapshot 或 bridge call
- Then 返回 `error.code=webview_navigation_changed`

## 推荐回归命令

首选使用已沉淀脚本：

```bash
TRITON_SIMULATOR=<udid> TRITON_VERIFY_OUT_DIR=/tmp/triton-ios-webview-harness docs-linhay/scripts/verify-ios-webview-harness.sh
```

脚本会自动执行 Demo `xcode run`，通过 `triton find` 读取 segmented label 坐标并用坐标 tap 切换 `Web Edge` / `Web Nav`，再验证 snapshot、bridge call、events 和 stale page session error。保留坐标 tap 是因为当前 iOS embedded runtime 的 AX tree 对 SwiftUI segmented label 可见，但不稳定暴露 SwiftUI Button accessibility identifier。

手工排查时可使用以下命令：

```bash
.build/cli/debug/triton xcode build --project Examples/TritonKitDemo/TritonKitDemo.xcodeproj --scheme TritonKitDemo --configuration Debug --simulator <udid> --jsonl --timeout 180
.build/cli/debug/triton serve --host 127.0.0.1 --port 19421
.build/cli/debug/triton xcode run --project Examples/TritonKitDemo/TritonKitDemo.xcodeproj --scheme TritonKitDemo --configuration Debug --simulator <udid> --jsonl --timeout 180
.build/cli/debug/triton observe tree --platform ios --json
.build/cli/debug/triton webview list --platform ios --json
.build/cli/debug/triton webview snapshot --platform ios --include metadata,dom,text,forms,links --max-dom-nodes 20 --max-text-bytes 2048 --json
.build/cli/debug/triton webview call getRouteState --platform ios --json
.build/cli/debug/triton webview events --platform ios --limit 10 --json
```

## 实现策略

1. 在现有 SwiftUI `ContentView` 顶部增加场景选择器。
2. 默认 `overview` 保留旧布局：UIKit complex harness + 基础 WebView，避免破坏既有 smoke。
3. 保留现有 UIKit complex harness，作为 `native-controls` 场景。
4. 将 `WebViewSmokePanel` 参数化为 `basic`、`edge`、`navigation` 三种 HTML fixture。
5. 每个 HTML fixture 使用固定 title、route 文本、form/link/button id 和 allowlist bridge 方法。
6. 不改 Xcode project 结构，不新增 package dependency。
7. 真实 CLI 场景切换暂以 segmented label 坐标 tap 验证，不依赖 SwiftUI Button identifier。

## 验证门禁

1. `swift test --filter TKRuntimeWebViewSnapshotTests`
2. `swift test --package-path CLI --scratch-path .build/cli --filter WebViewRouteTests`
3. `.build/cli/debug/triton schema --command webview --json`
4. `triton xcode build` iOS Simulator Debug
5. 条件允许时跑 `docs-linhay/scripts/verify-ios-webview-harness.sh`，并写入 `real-smoke-YYYYMMDD-ios-simulator-harness.md`
