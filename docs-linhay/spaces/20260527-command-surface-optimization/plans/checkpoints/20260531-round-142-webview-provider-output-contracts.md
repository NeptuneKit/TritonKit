# Round 142: webview provider output contracts

## 目标

补齐 WebView provider 级命令的 schema output contract，避免 agent 只能从 `successShape` 文本里推断 `current-url`、`call`、`events` 的 JSON 字段。

## 变更

1. 新增 `webview.current-url` output contract：
   - model: `WebViewCurrentURLSummary`
   - kind: `webview-provider-url`
   - 覆盖 `url/title/pageSessionID/providerStatus/bridgeStatus/sourceCommands`
2. 新增 `webview.call` output contract：
   - model: `TKWebViewBridgeCallResponse`
   - kind: `webview-bridge-call`
   - 覆盖 allowlist bridge `method/result/error/elapsedMs/redaction`
3. 新增 `webview.events` output contract：
   - model: `TKWebViewEventsResponse`
   - kind: `webview-events`
   - 覆盖 event id、timestamp、webViewID、pageSessionID、name、payload、redaction、source
4. schema kind taxonomy 同步新增：
   - `webview-provider-url`
   - `webview-bridge-call`
   - `webview-events`

## 验收

1. `triton schema --command webview --json` 能直接暴露 provider URL 输出模型。
2. `triton schema --command webview --json` 能直接暴露 WebView bridge call 输出模型。
3. `triton schema --command webview --json` 能直接暴露 WebView page events 输出模型。
4. 所有新增 output contract 的 selector、kind、model、fields 都满足现有 schema taxonomy。

## 验证

已通过：

```text
swift test --package-path CLI --filter SchemaFactSourceTests
```

## 风险

本轮只补 schema contract，不改变 runtime 输出、provider 权限边界或 WebView bridge 行为。

## 下一步

继续检查 route/assert/action 输出面中是否还有成功 payload 只能通过 prose shape 解析的缺口。
