# Technical Scheme v02: Host + Runtime First

## 结论

本期技术方案调整为 **Host + Runtime first，Web provider later**。

P0 内测不强制业务显式替换 Harmony `Web` 为 `TritonWeb`。`TritonWeb` wrapper / `registerWebView` / 页面 bridge 仍保留，但定位从首期主路径调整为 P1/P2 增强接入。首期先证明 CLI 能在不改业务 Web 组件的情况下，通过模拟器 host 侧节点树和 App 内 runtime/provider 联合获取当前 App 动态信息。

新的能力分层：

1. **Host-only**：不改源码，通过 HDC / uitest / screenshot 获取当前模拟器可见节点，支持截图、可见性判断、坐标点击、输入。
2. **Host + Runtime**：在 DEBUG 包中接入或编译期注入 runtime root，获取 UIContext / route / view tree / responder / semantic action，和 host layout 融合成 current app snapshot。
3. **Host + Runtime + Web provider**：只有需要 URL、DOM、JS bridge、页面事件时，再接入 Web provider / page bridge。

## 为什么调整

最初方案把 Harmony Web 接管主路径放在 `TritonWeb` wrapper 上，适合最终完整 Web 能力，但对内测有三个问题：

1. 用户希望尽量小侵入，最好不改业务源码。
2. CLI 已经可以从模拟器侧获取当前屏幕节点，host layout 本身就是可靠观测来源。
3. 本期目标不只 WebView，也包括整个 App 动态信息；先做 whole-app observation 比先替换 Web 组件更通用。

因此本期不再把“替换 Web 组件”作为进入门槛，而是把它后移到确实需要 Web 内部能力的阶段。

## 架构

```text
triton CLI
  -> Host adapter
       - hdc target discovery
       - foreground app / ability hints
       - uitest dumpLayout
       - screenshot metadata
       - tap / type / swipe
  -> Runtime connector
       - iOS embedded websocket
       - Harmony embedded HTTP runtime
       - runtime manifest / state / snapshot / ledger / action
  -> Observation fusion
       - source normalization
       - node matching
       - fusedNodeId
       - confidence / missingSources / candidateOnly
  -> Optional Web provider
       - iOS WKWebView provider
       - Harmony ArkWeb provider
       - page bridge / events / DOM summary
```

## P0 内测范围

P0 目标是让 CLI 能回答“当前 App 画面是什么、有哪些节点、能不能定位和操作”，不要求回答“Web 内部 DOM/JS 状态是什么”。

P0 包含：

1. Harmony host layout capture：通过 HDC / uitest 获取当前可见节点树。
2. Host screenshot metadata：记录尺寸、时间、方向、artifact path。
3. Runtime availability probe：如果 App 已有 TritonKit runtime，则读取 manifest / snapshot / route / ledger。
4. Fusion snapshot：把 host-layout、runtime-tree、screenshot metadata 合成一个机器可读 current app snapshot。
5. Node resolve：按 text/id/type/bounds 在融合树中定位节点。
6. Host action fallback：runtime 语义动作不可用时，CLI 能用 host 坐标点击/输入，但证据中明确 `source=host-layout`。
7. Evidence：保存 host layout、runtime snapshot、screenshot metadata 和 fusion result。

P0 不包含：

1. 不替换业务 `Web(...)`。
2. 不读取 Web DOM。
3. 不执行任意 JavaScript。
4. 不要求 H5 页面实现 bridge。
5. 不把 host 侧疑似 Web 容器声明为已具备 WebView bridge 能力。

## P1 / P2 增强

### P1：Runtime root 注入

目标：让 Harmony runtime 能稳定拿到 App 内动态树和语义状态。

可选接入：

1. 显式 Debug bootstrap：业务在入口调用 `TritonKit.setUIContext(this.getUIContext())` 或等价 API。
2. 编译期注入：在 DEBUG 构建中自动给 `@Entry` / 页面组件注入 runtime root 绑定。
3. provider 注册：业务可选提供 route/responder/action provider。

这一步仍不要求替换 Web。

### P2：Web provider / bridge

目标：需要 Web 内部状态时再进入。

触发条件：

1. 需要 URL/title/loading/pageSessionId。
2. 需要 DOM 文本、表单、按钮摘要。
3. 需要 JS bridge call。
4. 需要页面事件，如 `checkout.ready`。

接入顺序：

1. 优先编译期注入 Web provider 注册点。
2. 复杂存量页面可用 `registerWebView` handle。
3. 新页面或愿意改造的页面再使用 `TritonWeb` wrapper。
4. H5 可改时增加 `window.__tritonBridge` allowlist。

## CLI 契约

### Whole app observation

```bash
triton observe current --platform harmony --target <hdc-target> --json
triton observe tree --platform harmony --target <hdc-target> --sources host,runtime --json
triton node resolve --platform harmony --target <hdc-target> --text "登录" --json
triton snapshot --platform harmony --target <hdc-target> --include host-layout,runtime-tree,screenshot-metadata --json
```

### WebView observation

```bash
triton webview current --platform harmony --target <hdc-target> --source fused --json
triton webview snapshot --runtime-base-url <baseURL> --include metadata,dom,text,forms --json
triton webview call getRouteState --runtime-base-url <baseURL> --json
```

`webview current --source fused` 在没有 Web provider 时只能返回 `candidateOnly=true`：

```json
{
  "ok": true,
  "candidateOnly": true,
  "bridgeStatus": "unavailable",
  "capabilities": ["visible", "tap", "type"],
  "missingCapabilities": ["webview.url", "webview.dom", "webview.bridge-call"]
}
```

## Fusion 输出模型

```json
{
  "ok": true,
  "platform": "harmony",
  "capturedAt": "2026-05-21T00:00:00Z",
  "sources": [
    { "name": "host-layout", "available": true, "freshness": "fresh" },
    { "name": "runtime-tree", "available": true, "freshness": "fresh" },
    { "name": "webview-provider", "available": false, "reason": "provider not registered" }
  ],
  "nodes": [
    {
      "fusedNodeId": "fused:node-1",
      "confidence": 0.86,
      "sources": ["host-layout", "runtime-tree"],
      "role": "button",
      "text": "登录",
      "frame": { "x": 120, "y": 640, "width": 300, "height": 88 },
      "capabilities": ["visible", "tap"],
      "missingCapabilities": []
    }
  ]
}
```

融合原则：

1. Host 节点和 runtime 节点通过 frame overlap、中心点距离、text、id/key/accessibilityId、type、hierarchy path、zIndex 和 capturedAt 时间差匹配。
2. 匹配不确定时返回多个 candidate，并要求 `--within` / `--index` / `--node-id` 消歧。
3. Fusion 只合成证据，不提升能力；没有 Web provider 就不能声明 DOM/JS 能力。
4. 每个节点必须保留 `sources` 和 `confidence`。

## Harmony 低侵入口径

本期对业务侧的推荐顺序：

1. **不改源码**：host-only 观测和操作，适合 P0 内测。
2. **最小 runtime root**：显式 Debug bootstrap 或编译期注入 UIContext/provider，适合 P1。
3. **Web provider 注册**：需要 Web metadata / DOM / bridge 时再做，适合 P2。
4. **TritonWeb wrapper**：只作为新页面或愿意集中托管 Web 组件时的增强方案，不作为 P0 门槛。

## iOS 对齐

iOS 仍然可以从 App 内 `connectedScenes -> UIWindowScene.windows` 递归拿当前 UIKit / AX / geometry，因此 P0 不需要 host layout 才能拿 App 内树。但为了三端一致，iOS 也应在后续 observation schema 中保留 source 概念：

1. `runtime-tree`：UIKit / AX / geometry。
2. `host-screenshot`：Simulator screenshot metadata。
3. `webview-provider`：WKWebView descriptor / bridge。

## 验收场景

### 场景 1：Harmony P0 不改 Web 组件仍可观测当前页面

- Given DevEco Emulator 上运行一个未替换 `Web` 的 DEBUG App
- When 执行 `triton observe current --platform harmony --target <target> --json`
- Then 输出包含 `host-layout` source
- And 输出当前屏幕节点、bounds、text/type
- And Web 容器只标记为 candidate，不声明 DOM/JS 能力

### 场景 2：Runtime root 接入后融合 App 内语义

- Given App DEBUG runtime 已提供 UIContext / route provider
- When 执行 `triton observe tree --sources host,runtime --json`
- Then 输出包含 host-layout 与 runtime-tree
- And 匹配节点带 `fusedNodeId`、`confidence`、`sources`
- And route/provider 状态进入 snapshot artifacts

### 场景 3：没有 Web provider 时 webview current 不伪装成功

- Given 当前屏幕存在疑似 Web 容器
- And App 未注册 Web provider
- When 执行 `triton webview current --source fused --json`
- Then 返回 `candidateOnly=true`
- And `bridgeStatus=unavailable`
- And `missingCapabilities` 包含 `webview.dom` 和 `webview.bridge-call`

### 场景 4：Web provider 接入后升级为完整 WebView current

- Given App 已注册 Web provider
- When 执行 `triton webview current --runtime-base-url <baseURL> --json`
- Then 返回 URL/title/pageSessionId/bridgeStatus
- And `candidateOnly=false`
- And `webview.snapshot/call/events` 按 manifest capability 暴露

## 实施顺序

1. S0：先补 shared DTO 草案和 CLI schema，明确 host/runtime/web source。
2. S1：实现 Harmony host layout capture 和 screenshot metadata。
3. S2：实现 observe current/tree 的 mock contract。
4. S3：接入 runtime snapshot 融合，支持 provider 不存在时 partial result。
5. S4：实现 node resolve 和 host action fallback。
6. S5：再进入 Web provider / bridge。

## 风险与边界

1. host layout 可能包含系统 UI、遮挡层或非业务节点，必须保留 source 和 confidence。
2. host-only 能点击输入，但不能知道业务状态是否完成，必须用 screenshot / layout / runtime snapshot 二次验证。
3. Harmony runtime root 注入只能在 DEBUG 生效，Release 必须 disabled/no-op。
4. Web provider 只能通过公开 ArkWeb / WebKit 能力和页面 allowlist，不使用私有 Inspector。
5. unsafe eval 仍默认 unsupported。
