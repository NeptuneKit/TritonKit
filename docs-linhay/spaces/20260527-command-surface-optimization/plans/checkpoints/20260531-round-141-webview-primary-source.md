# Round 141: webview primary source

## 目标

把 `webview list/current` 的首选事实来源提升到顶层，避免 agent 从 `sources[]` 数组顺序自行推断当前结果到底是 provider 级事实、runtime AX 候选，还是 host layout 候选。

## 变更

1. 为 `TKWebViewListResponse` 新增 `primarySource: TKWebViewSource?`。
2. 为 `TKWebViewCurrentResponse` 新增 `primarySource: TKWebViewSource?`。
3. 新 payload 构造时自动回填 `primarySource`；旧 JSON payload 缺字段时也按同一规则解码回填。
4. WebView source canonical 优先级固定为：
   - `webview-provider`
   - `runtime-tree`
   - `host-layout`
   - 其他可用 source
   - 首个 source
5. 为 `webview` schema 增加 output contracts：
   - `webview.list`
   - `webview.current`
6. schema kind taxonomy 新增：
   - `webview-candidates`
   - `webview-current`

## 验收

1. agent 读取 `triton webview list --json` 时，可以直接消费 `primarySource` 判断候选来源优先级。
2. agent 读取 `triton webview current --json` 时，可以直接消费 `primarySource` 判断当前 WebView 是否来自 provider。
3. `webview-provider` 可用时优先于 `runtime-tree`；`runtime-tree` 可用时优先于 `host-layout`。
4. 旧 payload 没有 `primarySource` 时仍能解码并回填。
5. `triton schema --command webview --json` 暴露 `webview.list` / `webview.current` output contract。

## 验证

已通过：

```text
swift test --filter TKObservationModelsTests
swift test --package-path CLI --filter SchemaFactSourceTests
```

## 风险

1. 本轮只补 WebView list/current 的来源选择，不改变 `current-url/snapshot/call/events/wait` 的 provider 能力边界。
2. 当前 priority 是 WebView 语义专用，不能直接套到 observe surface；observe 仍保持 `runtime-tree -> host-layout -> webview-provider`。

## 下一步

继续检查 `target` / `route` / `assert` 输出里是否还存在“首选诊断对象藏在数组中”的一跳事实缺口。
