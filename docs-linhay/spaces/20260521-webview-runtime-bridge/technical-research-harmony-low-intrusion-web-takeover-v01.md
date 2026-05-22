# Harmony Low-Intrusion Web Takeover Technical Research v01

## 背景

用户希望 Harmony 方向尽量小侵入，但仍能让 TritonKit 接管当前页面的 Web 能力。这里的“接管”不是 host 侧强行读 ArkWeb 内部状态，而是在业务 App 接入 TritonKit embedded SDK 后，用最少业务改动统一接管 Web descriptor、页面事件、受控 bridge call 和执行审计。

结论：Harmony 不能可靠无侵入地从模拟器侧获取当前 Web 内部 DOM / URL / JS runtime，但 CLI 可以从模拟器侧获取当前可见节点树、截图和前台窗口线索。可行方案不是把 host 侧黑盒能力和 App 内 provider 二选一，而是做联合观测：host layout 负责“当前屏幕上有什么、在哪里、能否点击输入”，embedded runtime 负责“App 内语义、route、UIContext、Web 控制柄和 ledger”，Web provider / bridge 负责“DOM / JS / URL / 页面事件”。最新方案将 P0 内测主路径调整为 Host + Runtime first，不再强制替换业务 `Web(...)`；`TritonWeb` wrapper / `createTritonWebController()` 保留为需要 Web 内部能力时的 P2 增强入口。

## 现有证据

### TritonKit Harmony SDK 现状

`harmony-tritonkit` 已具备可复用的 provider 模式：

1. `ExportServer` 已有 `setRuntimeSceneStateProvider`、`setRuntimeRouteStateProvider`、`setRuntimeResponderStateProvider`、`setRuntimeActionProvider`。
2. 未注册 provider 时，对应 endpoint 返回稳定 `unsupported_runtime_scope`，manifest 中 capability 动态标记 unsupported。
3. 已有 runtime ledger、manifest、snapshot、state、semantic action 和 `--runtime-base-url` direct runtime 验证链路。

这说明 Web 接管不需要另起一套服务；应扩展同一套 provider / capability / ledger 体系。

### 源码核对结论

当前代码形态说明“鸿蒙没有 iOS 那种从全局根节点自然递归拿完整 App 树”的问题不是隐藏开关，而是入口模型不同：

1. iOS 主仓 `Sources/TritonKit/TritonKitRequestHandler.swift` 已通过 `UIApplication.shared.connectedScenes -> UIWindowScene.windows` 获取当前窗口，再在 `runtimeSnapshot` 中聚合 app、scene、route、AX、geometry 和 screenshot metadata。这是 UIKit 公开 API 能提供的 App 内根。
2. Harmony SDK `harmony-tritonkit/src/main/ets/ui-tree/ArkUIViewTreeCollector.ets` 也能采集 App 内树，但入口是显式 `setUIContext(context)`；拿到 `UIContext` 后才调用 `getFilteredInspectorTree()`，并在必要时用 `getFrameNodeByUniqueId()` 补 frame。
3. Harmony SDK `harmony-tritonkit/src/main/ets/server/ExportServer.ets` 当前通过 `setViewTreeSnapshotProvider`、`setInspectorSnapshotProvider`、`setRuntimeSceneStateProvider`、`setRuntimeRouteStateProvider`、`setRuntimeResponderStateProvider`、`setRuntimeActionProvider` 暴露 provider；未注册 provider 时返回 unsupported，而不是内部偷偷枚举全局根。
4. 因此 Harmony 不是没有动态节点能力，而是 HAR 自身没有一个稳定公开的“任意时刻获取当前 Ability/UIContext 全局根”的通用入口。要么 App 显式给 `UIContext`，要么 CLI 从模拟器 host 侧拿 `uitest dumpLayout`，再与 runtime/provider 融合。

### Harmony ArkWeb 公开能力

本地 Harmony 文档显示：

1. `@ohos.web.webview` 提供 `WebviewController`、`WebMessagePort` 等 Webview 能力。
2. `JavaScriptProxy` 可以把应用侧对象注入到页面 `window`，只能声明方法，不能声明属性；`permission` 可配置 object / method 级 URL 白名单。
3. ArkWeb NDK `ControllerAPI` 暴露 `runJavaScript`、`registerJavaScriptProxy`、`registerAsyncJavaScriptProxy`、`createWebMessagePorts`、`postWebMessage`。
4. Controller API 文档要求在 UI 线程获取相关 native API，并建议用 `ARKWEB_MEMBER_MISSING` 校验 ROM / SDK 是否有对应函数指针。

这说明“页面和 App 双向通信”有公开能力承载，但仍需要业务 App 在创建 Web 组件时把 controller / webTag / 生命周期交给 TritonKit。

## 能力分层

### L0：模拟器侧黑盒观测与执行

入口：host-side HDC / uitest / screenshot / layout。

能力：

1. 启动 Ability。
2. 截图。
3. dump ArkUI layout。
4. 点击坐标、输入文本。
5. 判断当前屏幕可见节点、bounds、type、text、accessibilityId、hostWindowId、zIndex。
6. 在 App 未接入 runtime 时，作为当前页面 smoke、可见性判断和坐标动作的最低可用来源。

不能稳定做到：

1. 读取 Web 内部 DOM。
2. 读取 SPA route。
3. 调用页面 JS 方法。
4. 等待页面内部事件。
5. 获取表单/按钮语义。

定位：作为 host observation 主来源和端到端 smoke。它可以参与 current app snapshot 融合，但不单独声明 Web 接管成功。

### L1：runtime root / UIContext 接入

入口：业务显式 Debug bootstrap 或后续编译期注入，将当前页面 `UIContext`、route provider、responder provider、action provider 交给 TritonKit。

能力：

1. 获取 App 内 view tree / inspector tree。
2. 获取 route、responder、semantic action 等业务语义。
3. 与 host layout 做融合，提升节点解释能力。
4. 不要求替换 `Web(...)`。

定位：P1 主路径。它比 Web wrapper 更通用，适合 whole-app dynamic information。

### L2：Web provider 注册

入口：业务把原来的 `Web(...)` 替换为 TritonKit 提供的 `TritonWeb(...)` 或 `createTritonWebController(...) + registerTritonWebView(...)`。

建议对业务暴露两个接入口：

```ts
const webController = createTritonWebController({
  id: 'main-web',
  tag: 'mainWeb',
  route: () => currentRoute,
  title: () => pageTitle,
})

Web({ src: url, controller: webController.controller })
  .onPageBegin((event) => webController.onPageBegin(event))
  .onPageEnd((event) => webController.onPageEnd(event))
```

或进一步包装为：

```ts
TritonWeb({
  id: 'main-web',
  src: url,
  route: () => currentRoute,
  bridge: {
    getRouteState: async () => ({ route: currentRoute }),
    submitSearch: async (args) => submitSearch(args),
  },
  onEvent: (event) => handleWebEvent(event),
})
```

TritonKit 负责：

1. 创建或接收 `WebviewController`。
2. 注册 Web descriptor：`webViewId`、`webTag`、`pageSessionId`、`url`、`title`、`loading`、`ability`、`page`、`visible`。
3. 绑定页面生命周期：page begin/end、navigation/session 更新。
4. 注入最小 JS bridge：`window.triton.postMessage(...)` 或 `window.__tritonBridge`。
5. 管理 allowlist 方法和事件 buffer。
6. 写 runtime ledger。
7. 动态更新 manifest capability。

定位：P2 增强路径。业务侵入点集中在 Web 创建处，后续 Web 接管能力由 TritonKit 统一演进；但 P0/P1 不以替换 Web 组件为前提。

### L3：增强页面 bridge

入口：页面主动暴露 `window.__tritonBridge.methods`，App 侧只负责转发。

适用：

1. H5 页面本身可改。
2. 需要更细的业务语义，如登录态、表单状态、业务完成事件。
3. 需要跨 App / 多页面复用同一 bridge 约定。

风险：

1. 页面需要配合发布。
2. 方法副作用更强，必须 allowlist。
3. payload 需要 redaction。

定位：P2/P3 能力，不作为最低接入门槛。

### L4：unsafe eval 诊断

入口：App config 显式打开 + CLI `--unsafe-eval`。

限制：

1. 默认 unsupported。
2. 只允许 DEBUG。
3. 每次调用必须写 ledger。
4. 输出按 payload limit 截断。
5. 不进入普通 replay 计划默认路径。

定位：本地诊断能力，不作为产品主路径。

## 推荐架构

```text
triton CLI
  -> HostHarmonyAdapter
       - hdc target / foreground app
       - uitest dumpLayout
       - screenshot metadata
       - host input actions
  -> RuntimeConnector
       - --runtime-base-url / triton serve
       - Harmony embedded HTTP runtime
       - ExportServer providers
  -> ObservationFusion
       - host layout nodes
       - runtime view tree / inspector
       - webview descriptors / bridge state
       - fused node ids + confidence
  -> WebViewProvider
       - TritonWebRegistry
       - TritonWebHandle
            - WebviewController
            - webTag
            - pageSessionId
            - descriptor provider
            - bridge allowlist
            - event buffer
            - redaction policy
       - ArkWeb Web component / JavaScriptProxy / WebMessagePort
```

关键点：

1. `HostHarmonyAdapter` 是当前模拟器可见节点和截图的事实来源。
2. `RuntimeConnector` / provider 是 App 内 route、view tree、responder、semantic action 和 ledger 的事实来源。
3. `ObservationFusion` 只合成证据，不提升能力；host 看到疑似 Web 容器时，只能标记 `candidateOnly`，不能声明可执行 JS。
4. `TritonWebRegistry` 是 current Web 控制柄、pageSessionId 和 bridge 状态的事实来源，但只在 P2 需要 Web 内部能力时启用。
5. `TritonWebHandle` 只保存必要控制柄，不保存敏感页面数据。
6. `ExportServer` 不直接依赖具体 ArkUI 页面，只依赖 provider interface。
7. `TritonWeb` wrapper 是 Web 增强接入层，不是 P0 内测门槛。
8. CLI 只看机器契约，不关心 ArkWeb 内部 API。

## 联合观测设计

### Source 分层

1. `host-layout`：来自 HDC / uitest 的当前屏幕节点树。字段重点是 `nodeId/type/text/originalText/bounds/origBounds/clickable/enabled/focused/visible/hostWindowId/zIndex/hierarchy/accessibilityId/key`。
2. `runtime-tree`：来自 embedded SDK 的 `viewTreeSnapshot` / `inspectorSnapshot`。字段重点是 `id/name/frame/style/text/visible/parentId/children`，以及 App provider 给出的 scene/route/responder。
3. `webview-provider`：来自 `TritonWebRegistry` 的 Web descriptor、bridge allowlist、event buffer 和 DOM snapshot。
4. `screenshot`：来自 host 截图，用于验证 capture 时间、分辨率、方向和像素级证据，不作为唯一语义来源。

### 融合策略

1. 先按 foreground bundle / ability / window 过滤 host layout，排除明显系统状态栏和导航栏；无法识别前台 App 时保留系统节点但给出 `foreground_unknown` warning。
2. 对 host node 与 runtime node 计算 match score：frame IoU、中心点距离、text 相似度、type 映射、id/key/accessibilityId 相似度、层级深度、zIndex、capturedAt 时间差。
3. score 高于阈值时生成稳定 `fusedNodeId`，并记录 `matchedSources`、`confidence`、`sourceNodeIds`。
4. score 接近或多个候选重叠时返回 `ambiguous_node`，要求调用方追加 `--within`、`--index`、`--node-id` 或重新截图。
5. WebView current 选择优先级是 `webview-provider` > `runtime-tree Web node` > `host-layout candidate`。只有第一档能执行 `call/events/dom snapshot`；后两档只能返回 candidate 和可见性/坐标能力。

### 能力提升规则

1. host-only：支持 `visible/screenshot/tap/type/swipe`，不支持 `route/responder/webview.dom/webview.bridge-call`。
2. host + runtime：支持 current app snapshot、route/responder/provider 语义、节点解释、部分 semantic action。
3. host + runtime + webview-provider：支持 current Web、DOM 摘要、bridge call、events、wait 和 ledger。
4. 任一来源缺失时，输出 `partial=true` 和 `missingSources`，但不把缺失来源的能力标为 supported。

建议新增错误 / warning：

1. `host_layout_unavailable`
2. `runtime_unavailable`
3. `webview_provider_unavailable`
4. `fused_partial`
5. `ambiguous_node`
6. `node_conflict`
7. `webview_candidate_only`

### CLI 草案

```bash
triton observe current --platform harmony --target <hdc-target> --json
triton observe tree --platform harmony --target <hdc-target> --sources host,runtime,web --json
triton node resolve --platform harmony --target <hdc-target> --text "登录" --json
triton webview current --platform harmony --target <hdc-target> --source fused --json
triton snapshot --platform harmony --target <hdc-target> --include host-layout,runtime-tree,webview,screenshot-metadata --json
```

`observe` 和 `node resolve` 属于 whole-app dynamic information，不只服务 WebView；`webview current` 消费融合结果，但必须保留 Web 能力边界。

## Provider API 草案

### SDK 侧接口

```ts
export interface TritonWebDescriptor {
  webViewId: string
  webTag: string
  pageSessionId: string
  url?: string
  title?: string
  isLoading?: boolean
  estimatedProgress?: number
  canGoBack?: boolean
  canGoForward?: boolean
  visible?: boolean
  visibleRatio?: number
  ability?: string
  page?: string
  bridgeStatus: 'unavailable' | 'ready' | 'partial'
}

export interface TritonWebBridgeRequest {
  method: string
  args?: Object
  sourceCommand?: string
  timeoutMs?: number
}

export interface TritonWebBridgeResponse {
  ok: boolean
  method: string
  elapsedMs: number
  result?: Object
  errorCode?: 'webview_method_not_allowed' | 'webview_bridge_unavailable' | 'javascript_timeout' | 'javascript_error'
  message?: string
  redaction?: Object
}

export interface TritonWebProvider {
  list(): TritonWebDescriptor[]
  current(): TritonWebDescriptor | null
  snapshot(webViewId: string, include: string[]): Object
  call(webViewId: string, request: TritonWebBridgeRequest): Promise<TritonWebBridgeResponse>
  events(webViewId: string, limit: number): TritonWebEvent[]
}
```

### ExportServer 扩展

```ts
exportServer.setRuntimeWebViewProvider(provider)
```

新增 endpoint：

```text
GET  /v2/runtime/webview/list
GET  /v2/runtime/webview/current
POST /v2/runtime/webview/snapshot
POST /v2/runtime/webview/call
POST /v2/runtime/webview/wait
GET  /v2/runtime/webview/events
```

Manifest capability 动态规则：

1. 未注册 provider：`webview.* supported=false`，reason 为 `Harmony WebView provider is not registered`。
2. 注册 provider 但无 current：`webview.list supported=true`，`webview.current` 请求返回 `webview_not_found`。
3. current 存在但 bridge 未 ready：`webview.current/snapshot supported=true`，`webview.bridge-call/events/wait` 根据 provider 能力动态标记。
4. Release：全部 WebView capability disabled/no-op。

## 低侵入接入方式

### 方式零：host-only

不改业务源码。CLI 只通过 HDC / uitest / screenshot 获取当前可见节点和执行坐标动作。

优点：

1. 侵入性最低。
2. 适合 P0 内测和未知业务 App。
3. 可以先验证 target discovery、layout capture、screenshot、node resolve 和 evidence。

风险：

1. 无法读取 Web DOM / JS runtime。
2. 无法直接知道 App 私有 route / responder / 业务状态。
3. 坐标动作必须配合二次截图或 layout 验证。

### 方式一：runtime root / provider

业务显式 Debug bootstrap 或编译期注入，把 `UIContext` 和必要 provider 交给 TritonKit。

优点：

1. 不替换 `Web(...)`。
2. 能获取 App 内 view tree、route、responder、semantic action。
3. 能和 host layout 融合，提高节点解释和动作稳定性。

风险：

1. 仍需要 DEBUG runtime 接入或编译期注入。
2. provider 质量决定语义能力上限。

### 方式二：替换组件

业务需要完整 Web 接管时，可接受 TritonKit wrapper：

```diff
- Web({ src, controller })
+ TritonWeb({ id: 'home-web', src, controller })
```

优点：

1. 后续能力统一由 wrapper 演进。
2. 业务无需理解 provider、ledger、CLI route。
3. 可以自动绑定 page begin/end、session 更新和 basic bridge。

风险：

1. wrapper 必须尽量透传原 Web 组件能力，否则业务会担心行为差异。
2. 如果业务大量链式调用 Web 事件，需要 wrapper 设计成 builder/adapter，避免破坏原写法。

### 方式三：保留 Web，注册 handle

业务只在已有 WebController 创建后加一行注册：

```ts
const controller = new webview.WebviewController()

TritonKit.registerWebView({
  id: 'home-web',
  webTag: 'homeWeb',
  controller,
  route: () => currentRoute,
  title: () => title,
})
```

优点：

1. 不替换 Web 组件。
2. 对已有复杂页面更友好。

风险：

1. 生命周期事件仍需业务转发，否则 navigation/session 不完整。
2. 容易出现注册了 controller 但没有可见性、title、route 的半成品接入。

### 方式四：页面 bridge-only

页面 H5 自行实现 `window.__tritonBridge`，App 只注入转发通道。

优点：业务语义最强。

风险：需要 H5 配合，发布链路更长。

结论：P0 默认方式零；P1 默认方式一；P2 需要 Web 内部能力时再选方式二/三/四。

## CLI 执行语义

新增 CLI 命令不应直接暴露 ArkWeb 细节。本期优先 whole-app observation：

```bash
triton observe current --platform harmony --target <hdc-target> --json
triton observe tree --platform harmony --target <hdc-target> --sources host,runtime --json
triton node resolve --platform harmony --target <hdc-target> --text "登录" --json
triton snapshot --platform harmony --target <hdc-target> --include host-layout,runtime-tree,screenshot-metadata --json
```

Web provider 接入后再启用：

```bash
triton webview current --runtime-base-url <baseURL> --json
triton webview snapshot --runtime-base-url <baseURL> --include metadata,text,forms --json
triton webview call getRouteState --runtime-base-url <baseURL> --json
triton webview wait --event checkout.ready --runtime-base-url <baseURL> --timeout 10 --json
triton webview events --runtime-base-url <baseURL> --limit 50 --jsonl
```

错误码：

1. `webview_provider_unavailable`：App 未接入 Web provider。
2. `webview_not_found`：provider 存在，但当前没有可见 Web。
3. `ambiguous_webview`：多个候选，要求 `--webview-id`。
4. `webview_bridge_unavailable`：当前 Web 没有 bridge。
5. `webview_method_not_allowed`：方法未在 allowlist。
6. `webview_navigation_changed`：调用时 page session 已变化。
7. `javascript_timeout`：页面调用超时。
8. `unsafe_eval_disabled`：eval 未启用。

host-only Web candidate 需要使用：

1. `webview_candidate_only`：host layout 只能证明可见 Web 容器候选，不能证明 URL/DOM/bridge。
2. `runtime_unavailable`：runtime 未接入或无法访问。
3. `host_layout_unavailable`：HDC / uitest layout 获取失败。

## 测试策略

### Mock 合同测试

1. `webview.current` provider 未注册。
2. provider 注册但无 current。
3. current 存在但 bridge unavailable。
4. current + bridge call success。
5. method not allowed。
6. event wait success / timeout。
7. navigation changed。
8. Release no-op。

### Harmony SDK 单仓测试

在 `harmony-tritonkit` 中新增脚本：

```bash
node scripts/verify-runtime-webview-provider-contract.mjs
```

覆盖：

1. `setRuntimeWebViewProvider` 动态 capability。
2. `/v2/runtime/webview/current|list|snapshot|call|events` route。
3. ledger 是否记录 call/event/error。
4. redaction 和 truncation。

### DevEco Emulator E2E

需要真实验证时，使用专用 DevEco Emulator target：

```bash
triton device runtime-url --platform harmony --target <dedicated-target> --probe-manifest --json
triton webview current --runtime-base-url <baseURL> --json
triton webview call getRouteState --runtime-base-url <baseURL> --json
```

约束：

1. 不占用通用 emulator。
2. 不依赖 DevEco 私有 Inspector。
3. 只使用 HDC fport + embedded HTTP runtime + App 内 provider。

## 风险

1. ArkTS wrapper 需要尽量贴近原 `Web` 使用体验，否则“低侵入”会变成迁移成本。
2. 如果业务 Web 创建分散在很多页面，方式一需要批量替换；可先提供方式二作为过渡。
3. 页面桥接方法有业务副作用，必须 allowlist、ledger 和 redaction。
4. SPA 路由变化可能不触发 Web page begin/end，需要 bridge event 或 history listener 辅助。
5. 不同 Harmony API / ROM 对 ArkWeb NDK 函数支持不一致时，需要 capability 探测，不可假设 `registerJavaScriptProxyEx` 一定存在。
6. host layout 与 runtime tree 的节点粒度不一定一致，融合结果必须带置信度和来源，不能把低置信度候选当作确定节点。
7. host layout 可能包含系统 UI 或遮挡层；执行动作前应优先用 screenshot / foreground app / bounds 复核。
8. host-only 模式可以获取当前屏幕节点，但不能获取 App 私有业务状态或 Web JS runtime；对外文档需要避免把黑盒可见性包装成完整接管。

## 结论

Harmony 侧要“尽量小侵入且统一接管”，最佳方案不是只靠模拟器侧硬控，也不是只靠 App provider，而是把 host 侧当前模拟器节点与 App 内 runtime/provider 联合起来：

1. host layout / screenshot 作为无 SDK 场景的最低可见性和执行来源。
2. `TritonWeb` wrapper 作为推荐 Web provider 入口。
3. `registerWebView` handle 作为存量页面过渡入口。
4. 页面 bridge 作为增强入口。
5. `observe` / `snapshot` / `/v2/runtime/webview/*` 作为机器契约。
6. `triton observe ...` 与 `triton webview ...` 作为 AI agent 的操作入口。

这样即使 App 内部暂时拿不到某些节点，CLI 也能通过模拟器侧节点树参与判断；当业务愿意提供 DEBUG-only provider 时，TritonKit 再把“能看见、能点击”提升为“知道 App route、知道当前 WebView、能受控执行页面 bridge”。
