# 20260521 WebView Runtime Bridge

## 背景

真实业务 App 中存在大量由原生容器承载的 WebView 页面。TritonKit 目前能通过 iOS embedded runtime 观察和控制 App 内 UIKit 树，也能通过 Harmony embedded HTTP runtime 读取 App provider 提供的状态；但当当前页面主体是 WebView 时，CLI 通常只能看到外层容器，无法稳定知道网页内部路由、文本、表单、按钮、业务事件和异步状态。

本需求要让 `triton` CLI 能和客户端当前显示的 WebView 及当前 App 动态节点进行受控沟通，首期同时纳入 iOS `WKWebView`、Harmony host layout、Harmony embedded runtime 和后续 ArkWeb / `Web` provider。AI agent 应先能读取当前 App 可见节点、定位目标、执行可验证动作；只有需要 Web 内部状态时，再通过 Web provider / bridge 读取网页状态、调用页面显式开放的方法、等待网页事件，并把这些交互纳入 runtime ledger、snapshot、evidence 和 replay。

## 北极星目标

CLI 仍是 AI agent 的唯一稳定控制入口。iOS embedded runtime 负责在 App 进程内发现当前可见 `WKWebView` 并转发受控消息；Harmony 需要同时纳入 host 侧模拟器节点树和 App 内 embedded runtime：host 侧通过 HDC / uitest / 截图知道当前模拟器可见节点，runtime 侧通过 UIContext / ArkWeb provider / Web 组件注册信息提供 App 内语义和 Web 控制柄。WebView 页面不应成为第二套隐藏控制平面，而应通过机器可读、可审计、可脱敏的 bridge 契约加入现有 `triton` 体系。

首期目标不是做一个通用浏览器自动化框架，也不是默认允许任意 JavaScript 执行，而是建立 Host + Runtime first 的三层闭环：

1. **P0 Host-only / Host + Runtime 动态观测**：CLI 能从模拟器 host layout、截图、前台 Ability/App 信息获取当前可见节点；如果 App 内 runtime 可用，再融合 UIContext / route / view tree / responder / ledger，形成 current app snapshot。
2. **P1 Runtime root 语义增强**：Harmony 通过显式 Debug bootstrap 或编译期注入拿到 `UIContext` / provider；iOS 继续通过 App 内 scene/window/view/AX 树获取动态信息。
3. **P2 Web provider / bridge 增强**：只有需要 URL、DOM、JS bridge、页面事件时，才接入 Web provider、`registerWebView`、`TritonWeb` 或页面 bridge。
4. **可验证可复盘**：所有 host layout、runtime snapshot、Web provider 调用、事件、超时、错误和脱敏状态进入 JSON/JSONL 输出、runtime ledger 和 evidence。

本期执行入口见 [WebView Runtime Bridge 技术方案整理 v02](./technical-scheme-v02-summary.md)，长版设计见 [Technical Scheme v02: Host + Runtime First](./technical-scheme-v02-host-runtime-first.md)。

## 官方能力基线

### iOS WebKit

1. `WKUserContentController` 可安装 JavaScript message handler，供网页脚本向原生侧发送消息。
2. `WKScriptMessageHandlerWithReply` 可让原生 handler 向网页脚本返回 reply，适合 request/response bridge。
3. `WKWebView.evaluateJavaScript` / `callAsyncJavaScript` 可在指定 frame 和 content world 执行脚本。
4. `WKContentWorld` 可隔离 App 注入脚本与页面脚本变量，降低命名冲突风险；但 DOM 变化对所有 content world 可见。

### Harmony ArkWeb

Harmony 侧优先使用 ArkWeb / Webview 公开能力和现有 embedded HTTP runtime provider 机制：

1. `@ohos.web.webview` 提供 `WebviewController`、`WebMessagePort`、Web 组件相关类型和控制能力。
2. ArkWeb NDK `ControllerAPI` 暴露 `runJavaScript`、`registerJavaScriptProxy`、`registerAsyncJavaScriptProxy`、`createWebMessagePorts`、`postWebMessage` 等能力。
3. `JavaScriptProxy` 可注入应用侧对象到页面 `window`，并通过 `permission` JSON 配置 object / method 级 URL 白名单。
4. Web 组件回调可提供 page begin/end、over-scroll 等页面生命周期线索，但业务路由和业务动作仍应由 App provider 或页面 bridge 显式提供。

设计结论：默认 bridge 使用公开 WebKit / ArkWeb 能力；禁止依赖私有 WebKit、Safari Remote Inspector、DevEco 私有 Inspector 或系统级 AX。需要访问页面业务对象时，必须由页面或 App provider 显式 opt-in 暴露 allowlist 方法。

## 需求范围

### In Scope

1. iOS embedded runtime 内发现当前可见 `WKWebView`，并返回候选列表和唯一 current 结果。
2. Harmony host-side adapter 获取当前模拟器可见节点树、截图 metadata、前台 App/Ability 线索，并能在 runtime 缺失时提供 host-only observation。
3. Harmony embedded runtime 通过 UIContext / provider 提供 App 内 route、view tree、responder、semantic action 和 ledger；该能力可显式接入，也可后续通过 DEBUG 编译期注入。
4. Observation fusion 输出带 `sources/confidence/missingSources/candidateOnly` 的 current app snapshot。
5. CLI 已新增 `observe current/tree` 与 `node resolve` 的 iOS runtime / Harmony host layout P0 契约；`snapshot --include host-layout,runtime-tree,webview` 作为后续融合项继续规划，所有输出保持稳定 JSON/JSONL。
6. Web provider 作为增强能力：iOS 发现当前 `WKWebView`，Harmony 通过 ArkWeb provider 注册当前 Web descriptor，暴露到 `/v2/runtime/webview/*` 或共享 runtime request。
7. 当前 WebView 元数据读取：platform、url、title、loading/progress、canGoBack/canGoForward、frame/visibleRatio、window/scene/controller/ability/page 线索。
8. 页面 opt-in bridge：页面或 App provider 注册 allowlist 方法，CLI 通过 bridge 调用方法并收到结构化结果。
9. 页面事件上报：iOS 通过 WebKit message handler，Harmony 通过 JavaScriptProxy / WebMessagePort / App provider 上报 `event`、`stateChanged`、`error` 等结构化消息。
10. DOM 轻量 snapshot：读取标题、文本摘要、表单字段摘要、链接/按钮摘要、滚动状态；secure/password 字段只回传类型和长度，不回传明文。
11. `wait` 能等待 host layout text、runtime route/responder、Web URL/title/selector/bridge event 或页面 idle。
12. runtime manifest / capabilities / schema 暴露 Host / Runtime / WebView 能力、边界和 unsafe eval 状态。
13. ledger / evidence 记录 host layout、runtime snapshot、WebView call、event、timeout、JavaScript error、redaction 和 source command。

### 本轮 P1 只读验收

1. Given iOS DEBUG runtime 已连接，且当前页面包含可见 `WKWebView` / WebView 容器候选；When 执行 `triton webview list --platform ios --json`；Then 返回 `candidates[]`，每个候选带 `webViewID/platform/source/frame/candidateOnly/providerStatus/bridgeStatus/capabilities/missingCapabilities`。
2. Given iOS DEBUG runtime 只有一个明确 WebView 候选；When 执行 `triton webview current --platform ios --json`；Then 返回同一个候选，且 `candidateOnly=true`、`providerStatus=unavailable`、`missingCapabilities` 包含 `webview.url/webview.dom/webview.bridge-call`。
3. Given Harmony 模拟器 host layout 存在 Web 组件候选但未接入 embedded Web provider；When 执行 `triton webview list --platform harmony --target <hdc-target> --json`；Then 只声明 `host-coordinate-tap` / `host-scroll` 等 host 能力，不声明 DOM、URL、JS 或 bridge。
4. Given 多个候选无法唯一判断 current；When 执行 `triton webview current --json`；Then 返回明确错误，提示先 `webview list` 再传 `--webview-id`，不能隐式猜测。

### Out of Scope

1. 不恢复 Web/Wails UI。
2. 不做通用浏览器 DevTools、网络面板、HAR 抓包或远程调试代理。
3. 不默认开放任意 JavaScript eval。
4. 不绕过网页登录、权限、CSP、same-origin 或跨域 iframe 限制。
5. 不读取 cookie、localStorage、IndexedDB、Keychain 或业务缓存，除非后续单独 opt-in 设计。
6. 不承诺控制系统弹窗、SafariViewController、App 外浏览器、SpringBoard 或 DevEco 系统 UI。
7. 不在 Release runtime 中启用任何采集、注入、调用或事件监听。

## 方案选型

### 方案 A：只做当前 WebView 元数据与 DOM snapshot

最小方案。实现 `webview current/list/snapshot/wait`，不提供页面业务 bridge。

- 工作量：低。
- 风险：低。
- 建立在现有 `snapshot`、`ax`、`ledger`、`schema`、iOS WebKit `evaluateJavaScript` 和 Harmony ArkWeb `runJavaScript` / provider 之上。
- 问题：只能观察，不能和业务页面协商动作或事件，无法满足“沟通”的核心诉求。

### 方案 B：当前 WebView + opt-in 页面 / App provider bridge

推荐方案。WebView 发现和 DOM snapshot 作为基础能力，页面或 App provider 通过显式 allowlist 暴露 bridge 方法和事件，CLI 通过 `triton webview call/post/wait/events` 与当前页面沟通。

- 工作量：中。
- 风险：中。
- 建立在现有 embedded runtime request/response、Harmony direct runtime `--runtime-base-url`、semanticAction、ledger、schema、evidence 之上。
- 优点：默认安全，能双向沟通，能被业务页面逐步接入。
- 代价：iOS 页面需要接入一个很小的 JS bridge 或显式注册方法；Harmony App 需要在 embedded SDK 注册 ArkWeb provider 或页面 bridge。

### 方案 C：开放 debug JavaScript eval

给 CLI 暴露 `triton webview eval`，允许 AI 直接执行 JavaScript。

- 工作量：中低。
- 风险：高。
- 建立在 `WKWebView.evaluateJavaScript` / `callAsyncJavaScript`、Harmony ArkWeb `runJavaScript` 之上。
- 问题：容易读取或修改敏感页面状态，输出不可控，失败也难以抽象成稳定业务契约。

## 推荐方案

采用 Host + Runtime first。WebView provider / bridge 仍采用方案 B 的安全边界，但不再作为 P0 内测前置条件。方案 C 只作为显式配置开启的本地 DEBUG 诊断能力。

推荐路径：

1. P0 先实现 host layout + screenshot metadata + runtime availability + fusion snapshot，证明 CLI 在不替换 Harmony `Web` 的情况下也能获取当前 App 可见节点并执行可验证动作。
2. P1 增加 runtime root / UIContext / route / responder / semantic provider 接入，优先支持 DEBUG 显式 bootstrap，后续规划编译期注入。
3. P2 再实现 Web provider / page bridge，让业务页面定义 allowlist 方法和事件；`TritonWeb` wrapper 只作为新页面或集中托管 Web 组件时的增强入口。
4. P3 再讨论 unsafe eval，仅允许 iOS `TritonKit.start { config.allowWebViewEval = true }` 或 Harmony `tritonkit` runtime config 显式打开，且 CLI 追加 `--unsafe-eval` 时生效，并强制写入 ledger。

## 当前 P0 落地

已实现并进入 schema 的命令：

```bash
triton observe current --platform ios --json
triton observe tree --platform ios --runtime-base-url <baseURL> --json
triton observe current --platform harmony --target <target> --json
triton observe tree --platform harmony --target <target> --json
triton node resolve --platform ios --text "登录" --json
triton node resolve --platform harmony --target <target> --text "登录" --json
```

边界：

1. iOS 侧当前通过 DEBUG embedded runtime 的 AX / runtime snapshot 获取动态节点。
2. Harmony 侧当前通过 HDC / `uitest dumpLayout` 获取 host layout，支持不改源码、不替换 `Web(...)` 的场景。
3. Web 容器当前只标记 `candidateOnly=true` 和缺失能力；没有 Web provider 时不能声明 DOM、JS 或 bridge 可用。
4. `node resolve` 支持 `--index`、`--within`、`--at`、`--all`，用于避免多候选时隐式猜测目标。

攻击面校验：

1. 依赖失败：页面或 Harmony App provider 未接入 bridge 时，CLI 仍能通过 host layout 返回 current app snapshot；WebView current 只能返回 `candidateOnly=true` 或 `webview_provider_unavailable`，不能伪装具备 DOM/JS 能力。
2. 规模扩大：DOM 文本和节点数量按 manifest limits 截断，snapshot 返回 `truncation`，避免大页面拖垮 WebSocket。
3. 回滚成本：所有能力都是 DEBUG-only runtime capability，关闭 manifest capability 或 App config 后 CLI 返回 unsupported，不需要迁移数据。
4. 前提坍塌：如果当前页面不是 iOS `WKWebView` / Harmony Web 组件，或存在多个可见 WebView，`current` 必须返回 `webview_not_found` 或 `ambiguous_webview`，不能猜测目标。

## Harmony 低侵入接管策略

Harmony 侧 P0 不要求业务显式替换 `Web(...)`。推荐四档接入：

1. **P0：host-only**。不改源码，CLI 通过 HDC / uitest / screenshot 获取当前模拟器可见节点，支持截图、可见性判断、坐标点击和输入。
2. **P1：runtime root**。业务显式 Debug bootstrap 或后续编译期注入 `UIContext` / provider，让 embedded runtime 提供 App 内 route、view tree、responder 和 semantic action。
3. **P2：Web provider 注册**。只有需要 URL、DOM、JS bridge、页面事件时，才注册 ArkWeb / Web descriptor；优先编译期注入或轻量 `registerWebView`。
4. **P2+：`TritonWeb` wrapper / 页面 bridge**。新页面或愿意集中托管 Web 组件时使用 wrapper；H5 可改时增加 `window.__tritonBridge.methods` allowlist。

详细技术调研见 [Harmony Low-Intrusion Web Takeover Technical Research](./technical-research-harmony-low-intrusion-web-takeover-v01.md)。

## WebView 选择规则

`current` 只在唯一候选明确时返回成功：

1. iOS 只扫描当前 App 进程内 key window / foreground scene 的可见 view tree。
2. iOS 候选必须是 `WKWebView`，且 `isHidden=false`、`alpha>0.01`、frame 与 window 可见区域有交集。
3. Harmony 候选优先来自 App provider 注册的 ArkWeb / Web component descriptor；如果 provider 未注册，runtime 返回 `webview_provider_unavailable`，CLI 可以用 host 侧 layout 标记疑似 Web 容器节点，但该节点只能用于截图、坐标、点击、输入和可见性判断，不能伪装成已具备 DOM / JS / URL / bridge 能力。
4. 优先选择可见面积最大、z-order 最靠前、所在 controller / ArkUI page / Ability 为当前 visible route 子树的 WebView。
5. 多个候选可见且分数接近时返回 `ambiguous_webview`，列出 `webViewId/platform/frame/visibleRatio/url/title/controllerOrPage`，要求调用方传 `--webview-id` 或 `--within`。
6. WebView navigation 后 `webViewId` 可保持进程内稳定，但 page session id 必须变化，避免对旧页面继续调用。

## CLI 契约草案

```bash
triton webview list --json
triton webview current --json
triton webview snapshot --include metadata,dom,text,forms,links --json
triton webview call <method> --arg key=value --json
triton webview post <event> --payload-json '<json>' --json
triton webview wait --selector '#submit' --timeout 5 --json
triton webview wait --event checkout.ready --timeout 10 --json
triton webview events --limit 50 --jsonl
triton webview ledger --limit 100 --jsonl
```

Harmony direct runtime 入口沿用现有 `--runtime-base-url` 设计：

```bash
triton device runtime-url --platform harmony --target <hdc-target> --probe-manifest --json
triton webview current --runtime-base-url http://127.0.0.1:28767 --json
triton webview snapshot --runtime-base-url http://127.0.0.1:28767 --include metadata,dom,text,forms,links --json
triton webview call getRouteState --runtime-base-url http://127.0.0.1:28767 --json
triton webview events --runtime-base-url http://127.0.0.1:28767 --limit 50 --jsonl
```

可选诊断能力：

```bash
triton webview eval '<javascript>' --unsafe-eval --json
```

`eval` 默认不出现在 supported capabilities 中；只有 App config 和 CLI flag 同时开启时才可用。

## HTTP / Runtime 契约草案

新增 request type 建议：

1. `webViewList`
2. `webViewCurrent`
3. `webViewSnapshot`
4. `webViewBridgeCall`
5. `webViewBridgePost`
6. `webViewWait`
7. `webViewEvents`
8. `webViewLedger`

共享 DTO 需要覆盖：

1. `TKWebViewDescriptor`：`platform/runtime/webViewId/pageSessionId/url/title/isLoading/estimatedProgress/canGoBack/canGoForward/frame/visibleRatio/controllerPath/ability/page/bridge/status`。
2. `TKWebViewSnapshotResponse`：`metadata/dom/text/forms/links/skipped/truncation/redaction`。
3. `TKWebViewBridgeCallRequest/Response`：`method/arguments/sourceCommand/timeoutMs/ok/result/error/redaction/elapsedMs`。
4. `TKWebViewEvent`：`id/timestamp/webViewId/pageSessionId/name/payload/redaction/source`。
5. `TKWebViewError`：稳定错误码，例如 `webview_not_found`、`ambiguous_webview`、`webview_provider_unavailable`、`webview_navigation_changed`、`webview_bridge_unavailable`、`webview_method_not_allowed`、`javascript_timeout`、`javascript_error`、`unsafe_eval_disabled`。

iOS 经由 `triton serve` 的 WebSocket `/request` 转发；Harmony standalone runtime 经由 embedded HTTP route 映射到 `/v2/runtime/webview/*`。建议 Harmony 路由：

1. `GET /v2/runtime/webview/list`
2. `GET /v2/runtime/webview/current`
3. `POST /v2/runtime/webview/snapshot`
4. `POST /v2/runtime/webview/call`
5. `POST /v2/runtime/webview/post`
6. `POST /v2/runtime/webview/wait`
7. `GET /v2/runtime/webview/events`

## 页面 Bridge 草案

页面侧只需要暴露 opt-in allowlist，不要求页面知道 TritonKit CLI 细节：

```javascript
window.__tritonBridge = {
  version: 1,
  methods: {
    getRouteState: async () => ({ route: location.pathname }),
    submitSearch: async ({ keyword }) => {
      // 业务页面自行执行动作，并返回结构化结果
      return { ok: true, keywordLength: keyword.length }
    }
  }
}
```

iOS 页面向 TritonKit 上报事件：

```javascript
window.webkit.messageHandlers.triton.postMessage({
  type: "event",
  name: "checkout.ready",
  payload: { step: "payment" }
})
```

Harmony 页面可以通过 App 注入的 `JavaScriptProxy` 或 WebMessagePort 上报同一结构：

```javascript
window.triton.postMessage(JSON.stringify({
  type: "event",
  name: "checkout.ready",
  payload: { step: "payment" }
}))
```

Harmony App provider 负责把 ArkWeb 回调、JavaScriptProxy 调用和 WebMessagePort 消息归一为 `TKWebViewEvent`，并写入 Harmony runtime ledger。

约束：

1. bridge 方法名必须在页面 allowlist 中。
2. 参数和返回值必须 JSON serializable。
3. payload 默认按 redaction policy 处理，secure 字段只允许长度或摘要。
4. bridge 不负责认证绕过，页面当前用户态是什么就只能看到什么。

## Manifest / Capability

新增 capability 建议：

1. `webview.current`
2. `webview.list`
3. `webview.snapshot`
4. `webview.bridge-call`
5. `webview.bridge-post`
6. `webview.wait`
7. `webview.events`
8. `webview.eval`

平台能力要求：

1. iOS `runtime manifest` 在 DEBUG 且 WebKit 可用时暴露 `webview.*` capability。
2. Harmony `runtime manifest` 只有在 App 注册 WebView provider 后才把 `webview.current/list/snapshot` 标记 supported；未注册 provider 时 capability 应为 unsupported，reason 为 `Harmony WebView provider is not registered`。
3. Harmony `webview.bridge-call/events/wait` 只有在 provider 暴露 allowlist bridge 或事件 buffer 后才标记 supported。
4. `webview.eval` 两端都默认 unsupported。

## Host + Runtime 联合观测

Harmony 侧需要明确区分三种来源：

1. **Host layout source**：CLI 通过 HDC / uitest / 截图读取当前模拟器可见节点、bounds、text、type、accessibilityId、hostWindowId、zIndex 和截图 metadata。它不要求 App 接入 SDK，也能看到系统 UI、前台窗口和当前屏幕上的节点，但通常拿不到 Web DOM、SPA route、JS runtime 和 App 私有状态。
2. **Runtime source**：App 内 embedded SDK 通过 `UIContext`、`FrameNode`、provider、route/responder/action hooks 读取 App 进程内语义。它能给出更可信的 App route、组件树、可操作语义、ledger 和 redaction 策略，但需要 App 在 DEBUG 包内接入或由编译期注入完成接入。
3. **Web source**：WebView provider / page bridge 提供 URL、title、loading、pageSessionId、DOM 摘要、allowlist 方法和页面事件。它是唯一能稳定执行页面 JS bridge 的来源。

CLI 不应把三种来源混成一个不透明结果，而应返回带来源和置信度的融合结果：

```json
{
  "ok": true,
  "capturedAt": "2026-05-21T00:00:00Z",
  "platform": "harmony",
  "sources": [
    { "name": "host-layout", "available": true, "freshness": "fresh" },
    { "name": "runtime-tree", "available": true, "freshness": "fresh" },
    { "name": "webview-provider", "available": false, "reason": "provider not registered" }
  ],
  "current": {
    "foregroundApp": { "bundle": "com.example.app", "ability": "EntryAbility" },
    "nodes": [
      {
        "id": "fused:main-web",
        "confidence": 0.86,
        "sources": ["host-layout", "runtime-tree"],
        "role": "web-container",
        "frame": { "x": 0, "y": 120, "width": 1080, "height": 1800 },
        "capabilities": ["visible", "tap", "type"],
        "missingCapabilities": ["webview.dom", "webview.bridge-call"]
      }
    ]
  }
}
```

融合规则：

1. 同屏节点匹配优先使用 frame overlap / IoU、中心点距离、type、text、id/key/accessibilityId、hierarchy path、zIndex、hostWindowId 和 capturedAt 时间差。
2. host 节点与 runtime 节点匹配成功后生成 `fusedNodeId`；匹配不确定时保留候选并返回 `ambiguous_node`，不能猜测。
3. host source 可以证明“屏幕上有一个节点、能点、能输入、能截图验证”；runtime source 可以证明“这是 App 内哪个组件、属于哪个 route、能否执行语义动作”；web source 可以证明“这是哪个 WebView、当前 URL/session、能否执行 bridge call”。
4. `triton webview current` 在只有 host source 时可以返回 `candidateOnly=true` 的疑似 Web 容器，但 `bridgeStatus` 必须是 `unavailable`，`snapshot.dom` / `call` / `events` 必须返回明确 unsupported。
5. evidence 必须保存三份原始 artifact：host layout、runtime snapshot、screenshot metadata，再保存融合后的 normalized snapshot，便于后续回放和排错。

建议 CLI 入口：

```bash
triton observe current --platform harmony --target <hdc-target> --bundle <bundle> --json
triton observe tree --platform harmony --target <hdc-target> --sources host,runtime,web --json
triton node resolve --text "登录" --platform harmony --target <hdc-target> --json
triton webview current --platform harmony --target <hdc-target> --source fused --json
triton snapshot --platform harmony --target <hdc-target> --include host-layout,runtime-tree,webview,screenshot-metadata --json
```

这个方向并不否定低侵入 provider。相反，provider 越少，融合结果越偏向 host 黑盒观察；provider 越完整，融合结果越能从“能看见、能点击”升级为“知道业务 route、知道当前 WebView、能受控执行页面 bridge”。

`webview.eval` 默认：

```json
{
  "name": "webview.eval",
  "supported": false,
  "scope": "embedded",
  "boundary": "app-process",
  "reason": "Unsafe JavaScript eval requires explicit DEBUG config and CLI --unsafe-eval"
}
```

## BDD 验收场景

### 场景 1：CLI 能发现 iOS 当前唯一可见 WebView

- Given DEBUG iOS App 当前页面包含一个可见 `WKWebView`
- When 执行 `triton webview current --json`
- Then 返回 `ok=true`
- And 返回 `webViewId/pageSessionId/url/title/frame/visibleRatio/isLoading/estimatedProgress`
- And `capabilities` 标记 WebView current/snapshot 可用

### 场景 2：CLI 能通过 Harmony provider 发现当前 Web 组件

- Given DEBUG Harmony App 已集成 `tritonkit` embedded SDK
- And App 注册了 ArkWeb WebView provider
- When host 通过 `triton device runtime-url --platform harmony --target <hdc-target> --probe-manifest --json` 获取 `baseURL`
- And 执行 `triton webview current --runtime-base-url <baseURL> --json`
- Then 返回 `ok=true`
- And 返回 `platform=harmony`、`runtime=embedded-http`、`webViewId/pageSessionId/url/title/ability/page`
- And manifest 中 `webview.current`、`webview.list`、`webview.snapshot` 为 supported

### 场景 3：Harmony 未注册 provider 时明确 unsupported

- Given DEBUG Harmony App 未注册 WebView provider
- When 执行 `triton webview current --runtime-base-url <baseURL> --json`
- Then 返回 `ok=false`
- And `error.code=webview_provider_unavailable`
- And manifest 中 WebView capabilities 标记 unsupported，并给出 provider 注册提示

### 场景 4：多个 WebView 时不猜测

- Given 当前页面同时存在两个可见 WebView
- When 执行 `triton webview current --json`
- Then 返回 `ok=false`
- And `error.code=ambiguous_webview`
- And 返回候选列表与 `nextAction`，提示使用 `--webview-id` 或 `--within`

### 场景 5：CLI 能读取 DOM 轻量快照并脱敏

- Given 当前 WebView 页面包含标题、普通输入框、密码输入框、按钮和链接
- When 执行 `triton webview snapshot --include metadata,dom,text,forms,links --json`
- Then 输出文本、表单字段类型、按钮和链接摘要
- And 密码字段不返回明文，只返回 `redaction.secureText=length-only`
- And 超过节点或字节上限时返回 `truncation.truncated=true`

### 场景 6：CLI 能调用页面 opt-in bridge 方法

- Given 页面暴露 `window.__tritonBridge.methods.getRouteState`
- When 执行 `triton webview call getRouteState --json`
- Then 返回 `ok=true`
- And 输出页面返回的 JSON result
- And runtime ledger 记录 method、elapsedMs、sourceCommand 和 redaction

### 场景 7：Harmony 能通过 provider 调用 ArkWeb bridge 方法

- Given Harmony App 的 WebView provider 暴露 allowlist 方法 `getRouteState`
- When 执行 `triton webview call getRouteState --runtime-base-url <baseURL> --json`
- Then 返回 `ok=true`
- And 输出 provider 归一后的 JSON result
- And Harmony runtime ledger 记录 provider、method、elapsedMs、sourceCommand 和 redaction

### 场景 8：未注册方法明确失败

- Given 页面未暴露 `deleteAccount`
- When 执行 `triton webview call deleteAccount --json`
- Then 返回 `ok=false`
- And `error.code=webview_method_not_allowed`
- And 不执行任何页面脚本副作用

### 场景 9：页面事件可被 CLI 等待

- Given 页面会在数据加载完成后上报 `checkout.ready`
- When 执行 `triton webview wait --event checkout.ready --timeout 10 --json`
- Then 如果事件到达，返回 `ok=true` 和事件 payload 摘要
- And 如果超时，返回 `ok=false,error.code=webview_event_timeout`

### 场景 10：导航导致旧 page session 失效

- Given CLI 已获取 `pageSessionId=A`
- When WebView 导航到新页面并生成 `pageSessionId=B`
- And CLI 使用旧 session 发起 bridge call
- Then 返回 `ok=false,error.code=webview_navigation_changed`
- And 提示重新执行 `triton webview current --json`

### 场景 11：Release runtime 完全 no-op

- Given App 是 Release build
- When 执行 `triton runtime manifest --json`
- Then `enabled=false`
- And WebView capabilities 为空或 unsupported
- When 执行任何 `triton webview *`
- Then 返回稳定 `unsupported_runtime_scope` 或 `runtime_disabled`

### 场景 12：unsafe eval 默认不可用

- Given App 未显式开启 `allowWebViewEval`
- When 执行 `triton webview eval 'document.title' --unsafe-eval --json`
- Then 返回 `ok=false,error.code=unsafe_eval_disabled`
- And ledger 记录一次被拒绝的 unsafe eval 尝试

## 测试门禁

1. Shared DTO：新增 WebView 模型必须覆盖 encode/decode、默认值、错误码、redaction、truncation。
2. CLI schema：`triton schema --command webview --json` 必须列出参数、默认值、runtime scope、成功/失败 shape、示例和 capability。
3. HTTP/request：新增 request type 覆盖 iOS `/request` 和 Harmony `/v2/runtime/webview/*` route、JSON body、超时、runtime error envelope。
4. iOS runtime：用 Demo 增加 `WKWebView` harness 页面，覆盖 current/list/snapshot/bridge call/event/wait/navigation changed。
5. Harmony runtime：在 `harmony-tritonkit` Demo 增加 ArkWeb provider smoke，覆盖 provider unavailable、current/snapshot/bridge call/event/wait/navigation changed。
6. Harmony real emulator：需要端到端验证时，使用专用 DevEco Emulator target，经 `triton device runtime-url --platform harmony --target <hdc-target> --probe-manifest --json` 获取 `baseURL` 后复跑 WebView smoke；不占用通用 emulator。
7. Mock smoke：不依赖真实 iOS / Harmony 的 CLI mock 覆盖 ambiguous、provider unavailable、bridge unavailable、unsafe eval disabled、error envelope。
8. Evidence：`capture/evidence --include webview` 时写入 `webview-current.json`、`webview-snapshot.json`、`webview-events.jsonl` 和 manifest skipped reason。
9. Release：Release/no-op 测试证明 capability 关闭、handler/proxy 不注入、message handler 不安装、命令不执行。

## 分期计划

1. P0a 契约：Shared DTO、TKRequestType、CLI schema、capabilities、错误码、Harmony embedded HTTP route 映射。
2. P0b iOS 发现：iOS runtime 扫描当前可见 `WKWebView`，实现 `list/current`。
3. P0c Harmony provider：`harmony-tritonkit` 增加 WebView provider interface、manifest capability 动态标记和 `/v2/runtime/webview/current|list`。
4. P0d snapshot：两端实现 DOM 轻量摘要、redaction、truncation、`webview snapshot`。
5. P1a bridge call：两端实现页面 / provider opt-in method call 和稳定 result/error envelope。
6. P1b events/wait：两端实现页面事件 ring buffer、`events --jsonl` 和 `wait --event/--selector/--text`。
7. P1c evidence/replay：WebView artifacts 进入 evidence，`.tritonplan` 支持 `webview.call` / `webview.wait` step。
8. P2 unsafe eval：仅在明确配置后进入诊断能力，默认不支持。

## 风险与约束

1. WebView 中页面未接入 bridge 时，只能提供观察能力，不能保证业务动作。
2. 页面 DOM 很大时必须截断，AI 不能依赖完整 HTML。
3. SPA 路由变化不一定触发 WebKit / ArkWeb navigation，需由 snapshot URL/title、page bridge event 或 injected history listener 共同判断。
4. 注入脚本可能和业务页面脚本冲突；iOS 默认应使用独立 content world，Harmony 默认应使用 provider / JavaScriptProxy 白名单，需要暴露给页面 JS 的最小入口才放到页面全局对象。
5. `WKWebView` / ArkWeb 内跨域 iframe 仍受浏览器安全模型限制，TritonKit 不绕过。
6. Harmony provider 若由业务 App 实现，通用 SDK 只能验证契约和错误码，不能保证业务页面一定暴露某个方法。
7. 任何 bridge call 都可能触发业务副作用，因此必须进入 ledger，并支持 replay/evidence 审计。

## 参考链接

- [iOS Embedded SDK Expansion](../20260521-ios-embedded-sdk-expansion/README.md)
- [Harmony TritonKit SDK Alignment](../20260521-harmony-tritonkit-sdk-alignment/README.md)
- [AI CLI Readable Control](../../dev/ai-cli-readable-control.md)
- [Harness Reference](../../references/harness.md)
- Apple WebKit 本地文档：`WKWebView`、`WKUserContentController`、`WKContentWorld`
- Harmony 本地文档：`@ohos.web.webview`、`ArkWeb_ControllerAPI`、`JavaScriptProxy`、`WebMessagePort`
