# WebView Runtime Bridge 技术方案整理 v02

## 一句话结论

本期采用 **Host + Runtime first，Web provider later**。

Harmony 内测不再要求业务显式替换 `Web(...)`，也不把 `TritonWeb` wrapper 作为 P0 门槛。P0 先由 CLI 在模拟器侧获取当前可见节点、截图和可操作坐标；如果 DEBUG runtime 已存在，再融合 App 内 route / view tree / responder / ledger。只有确实需要 Web 内部 URL、DOM、JS bridge、页面事件时，才进入 Web provider / page bridge。

## 目标边界

### 本期要解决

1. CLI 能回答当前 App 画面是什么、有哪些可见节点、目标在哪里、能否执行点击/输入。
2. Harmony 在不改业务 Web 组件的情况下，也能通过 HDC / uitest / screenshot 做 host-only 观测与基础执行。
3. iOS / Harmony / 后续 Android 使用同一种 source 模型表达观测来源，而不是各自暴露裸平台工具。
4. Runtime 存在时，把 App 内语义和 host layout 融合为 current app snapshot。
5. WebView 内部能力作为增强层，明确 provider 缺失时只能返回 candidate，不能伪装成 DOM / JS 可用。

### 本期不做

1. 不恢复 Web / Wails UI。
2. 不做真机、远端 agent、设备云或多租户服务。
3. 不默认开放任意 JavaScript eval。
4. 不绕过页面登录态、CSP、same-origin、iframe 或业务权限。
5. 不把 host 侧疑似 Web 容器当作已接管 WebView。
6. Release runtime 不启用采集、注入、执行或 bridge。

## 分层架构

```text
triton CLI
  -> Host adapter
       - target discovery
       - foreground app / ability hints
       - host layout dump
       - screenshot metadata
       - coordinate action
  -> Runtime connector
       - iOS embedded websocket
       - Harmony embedded HTTP runtime
       - manifest / snapshot / route / ledger / semantic action
  -> Observation fusion
       - source normalization
       - node matching
       - fusedNodeId / confidence / missingSources / candidateOnly
  -> Optional Web provider
       - WKWebView descriptor / bridge
       - ArkWeb descriptor / bridge
       - page events / DOM summary / allowlist methods
```

核心原则：**fusion 只合成证据，不提升能力**。某个 source 没有提供的能力，不能因为融合后就标记为 supported。

## 分期计划

### P0：Host-only / Host + Runtime 观测闭环

P0 是当前内测主线。

能力：

1. Harmony host layout capture：通过 HDC / uitest 获取当前可见节点树。
2. Host screenshot metadata：记录截图尺寸、时间、方向、artifact path。
3. App lifecycle：安装、启动、停止、打开 URL 等 host action。
4. Host action fallback：按 text 或 bounds 解析节点，必要时用坐标点击。
5. Runtime availability probe：如果 App runtime 可用，读取 manifest / snapshot / route / ledger。
6. Fusion snapshot：输出 sources、nodes、confidence、missingSources、candidateOnly。
7. Evidence：保存 host layout、runtime snapshot、screenshot metadata 和融合结果。

P0 已落到现有 CLI 能力：

```bash
triton app install --platform harmony --target <target> --app <path.hap> --json
triton app launch --platform harmony --target <target> --bundle <bundle> --ability <ability> --json
triton app terminate --platform harmony --target <target> --bundle <bundle> --json
triton ax --platform harmony --target <target> --json
triton wait --platform harmony --target <target> --text "登录" --json
triton tap --platform harmony --target <target> --text "登录" --json
triton screenshot --platform harmony --target <target> --output <file.png> --json
```

正式 whole-app 命令已进入 P0 契约：

```bash
triton observe current --platform ios --json
triton observe tree --platform ios --runtime-base-url <baseURL> --json
triton observe current --platform harmony --target <target> --json
triton observe tree --platform harmony --target <target> --json
triton node resolve --platform ios --text "登录" --json
triton node resolve --platform harmony --target <target> --text "登录" --json
triton snapshot --platform harmony --target <target> --include host-layout,runtime-tree,screenshot-metadata --json
```

当前实现说明：

1. iOS `observe current/tree` 通过 DEBUG embedded runtime 的 runtime snapshot / AX 树输出 `runtime-tree` source。
2. Harmony `observe current/tree` 通过 HDC `uitest dumpLayout` 输出 `host-layout` source，并把疑似 Web 节点标记为 `candidateOnly=true`。
3. `node resolve --platform ios|harmony --text <text>` 能按当前动态节点解析目标，并支持 `--index`、`--within`、`--at`、`--all`。
4. Web provider 尚未实现；所有 Web 容器节点必须继续输出缺失能力，例如 `webview.dom`、`webview.bridge-call`，不能伪装成页面 bridge 可用。

### P1：Runtime root 语义增强

目标是让 Harmony runtime 稳定拿到 App 内动态树和业务语义，但仍不要求替换 Web。

接入方式按侵入性从低到高：

1. 显式 Debug bootstrap：业务入口绑定 UIContext / provider。
2. 编译期 DEBUG 注入：自动给 `@Entry` / 页面组件注入 runtime root。
3. Provider 注册：业务可选提供 route / responder / semantic action。

输出能力：

1. `runtime-tree`
2. `route`
3. `responder`
4. `semantic-action`
5. `ledger`

### P2：Web provider / bridge

只有需要 Web 内部状态时进入 P2。

触发条件：

1. 需要 URL / title / loading / pageSessionId。
2. 需要 DOM 文本、表单、按钮、链接摘要。
3. 需要调用页面 allowlist 方法。
4. 需要等待页面事件，如 `checkout.ready`。

接入优先级：

1. 编译期注入 Web provider 注册点。
2. `registerWebView` / `createTritonWebController`。
3. `TritonWeb` wrapper。
4. H5 页面暴露 `window.__tritonBridge.methods` allowlist。

示例命令：

```bash
triton webview current --platform harmony --target <target> --source fused --json
triton webview snapshot --runtime-base-url <baseURL> --include metadata,dom,text,forms --json
triton webview call getRouteState --runtime-base-url <baseURL> --json
triton webview events --runtime-base-url <baseURL> --limit 50 --jsonl
```

没有 Web provider 时，`webview current` 只能返回：

```json
{
  "ok": true,
  "candidateOnly": true,
  "bridgeStatus": "unavailable",
  "capabilities": ["visible", "tap", "type"],
  "missingCapabilities": ["webview.url", "webview.dom", "webview.bridge-call"]
}
```

## Source 与能力规则

| Source | 来源 | 能力 | 禁止声明 |
| --- | --- | --- | --- |
| `host-layout` | HDC / uitest layout | visible、bounds、text、tap、type、swipe | route、DOM、JS、bridge |
| `host-screenshot` | emulator screenshot | 像素证据、尺寸、方向、artifact | 业务语义 |
| `runtime-tree` | embedded runtime | App 内 view tree、route、responder、semantic action | Web DOM，除非 provider 提供 |
| `webview-provider` | WKWebView / ArkWeb provider | URL、title、DOM summary、bridge call、events | 未 allowlist 方法、unsafe eval |

能力提升规则：

1. host-only 只能证明屏幕可见和坐标动作可执行。
2. host + runtime 可以证明 App 内语义和当前 route。
3. host + runtime + webview-provider 才能证明 WebView 内部状态。
4. source 缺失时输出 `partial=true`、`missingSources` 和稳定 reason。

## 融合模型

```json
{
  "ok": true,
  "platform": "harmony",
  "capturedAt": "2026-05-21T00:00:00Z",
  "partial": true,
  "sources": [
    { "name": "host-layout", "available": true, "freshness": "fresh" },
    { "name": "runtime-tree", "available": false, "reason": "runtime unavailable" },
    { "name": "webview-provider", "available": false, "reason": "provider not registered" }
  ],
  "nodes": [
    {
      "fusedNodeId": "fused:host:node-1",
      "confidence": 0.74,
      "sources": ["host-layout"],
      "role": "button",
      "text": "登录",
      "frame": { "x": 120, "y": 640, "width": 300, "height": 88 },
      "capabilities": ["visible", "tap"],
      "missingCapabilities": ["semantic-action"]
    }
  ]
}
```

匹配因子：

1. frame IoU / 中心点距离。
2. text / id / key / accessibilityId。
3. role / type 映射。
4. hierarchy path / depth / zIndex。
5. capturedAt 时间差。

冲突处理：

1. 多候选返回 `ambiguous_node`。
2. 要求调用方追加 `--within`、`--index`、`--node-id`。
3. 不猜测、不隐式选择风险目标。

## 验收场景

### 场景 1：Harmony 不替换 Web 仍可观察当前页面

- Given DevEco Emulator 上运行一个未替换 `Web(...)` 的 DEBUG App
- When 执行 `triton ax --platform harmony --target <target> --json`
- Then 输出包含 host layout artifact
- And 当前屏幕节点包含 text / bounds / type
- And 疑似 Web 容器不声明 DOM / JS / bridge 能力

### 场景 2：按 host layout 定位并执行动作

- Given 当前屏幕存在文案为“登录”的可点击节点
- When 执行 `triton tap --platform harmony --target <target> --text "登录" --json`
- Then CLI 根据 host layout 解析节点中心点
- And 通过 HDC 执行坐标点击
- And 输出记录 source command、target、bounds、elapsedMs 和 next verification hint

### 场景 3：Runtime 可用时融合 App 内语义

- Given App DEBUG runtime 已提供 manifest / snapshot / route provider
- When 执行 `triton observe tree --sources host,runtime --json`
- Then 输出包含 `host-layout` 与 `runtime-tree`
- And 匹配节点带 `fusedNodeId`、`confidence`、`sources`
- And route/provider 状态进入 snapshot artifacts

### 场景 4：没有 Web provider 时不伪装 Web 接管成功

- Given 当前屏幕存在疑似 Web 容器
- And App 未注册 Web provider
- When 执行 `triton webview current --source fused --json`
- Then 返回 `candidateOnly=true`
- And `bridgeStatus=unavailable`
- And `missingCapabilities` 包含 `webview.dom` 和 `webview.bridge-call`

### 场景 5：Web provider 接入后升级为完整 WebView current

- Given App 已注册 Web provider
- When 执行 `triton webview current --runtime-base-url <baseURL> --json`
- Then 返回 URL / title / pageSessionId / bridgeStatus
- And `candidateOnly=false`
- And `webview.snapshot`、`webview.call`、`webview.events` 按 manifest capability 暴露

## 实施顺序

1. S0：锁定 P0 host-side CLI 契约和 parser tests。
2. S1：完成 Harmony HDC command model：install、terminate、open-url、dumpLayout、recvFile、tap、screenshot。
3. S2：完成 host layout parser 和 text/bounds resolve。
4. S3：在 `app`、`ax`、`wait`、`tap`、`screenshot` 命令暴露 `--platform harmony`。
5. S4：补 `observe current/tree` 与 `node resolve` 的正式 schema，并覆盖 iOS runtime 与 Harmony host layout。
6. S5：设计 snapshot source/artifact DTO，支持 host/runtime/web source。
7. S6：接入 runtime snapshot fusion。
8. S7：进入 Web provider / page bridge。

## 当前落地判断

当前本期应以 P0 host-side MVP 作为可交付切片：

1. `ax/wait/tap/screenshot --platform harmony` 可以先作为 `observe/node` 前身交付。
2. `observe current/tree` 和 `node resolve` 已作为正式 agent-facing 契约进入 schema hardening。
3. Web provider 不进入 P0 阻塞项。
4. 编译期注入属于 P1/P2 的优雅接入方式，需要单独设计构建链与回滚策略。

## 风险与控制

1. Host layout 可能包含系统 UI 或遮挡层：输出 source、foreground hint、confidence、warnings。
2. 坐标点击不是业务成功：动作后必须用 wait / ax / screenshot / runtime snapshot 二次验证。
3. Runtime provider 缺失：返回 partial result，不报假成功。
4. Web provider 缺失：只返回 candidate，不声明 DOM / JS。
5. 编译期注入风险较高：只允许 DEBUG 构建，产物必须可审计、可关闭、可回滚。
6. unsafe eval 默认 unsupported，只有 App config 和 CLI flag 双开才允许，并写 ledger。

## 关联文档

1. [长版技术方案 v02](./technical-scheme-v02-host-runtime-first.md)
2. [Harmony 低侵入 Web 接管调研](./technical-research-harmony-low-intrusion-web-takeover-v01.md)
3. [Runtime CLI Contract Hardening](../20260521-runtime-cli-contract-hardening/README.md)
