# Round 170 - lane placeholder arg semantics

## 目标

新增 capability `requiredBy` lane 与 `nextAction.args` 占位符语义的一致性门禁，避免 workflow lane 的参数语义被过度泛化或误判。

## 变更

1. 新增测试 `SchemaFactSourceTests.capabilityNextActionArgsKeepLaneSpecificPlaceholderSemantics`。
2. 新增 lane 语义约束：
   - `route` lane（或 `group=route`）下的 `route` 根命令必须包含 `<expected-url>`。
   - `smoke-ios` 必须包含 `ios`、`<device>`、`<bundle-id>`、`<url>`、`<text>`。
   - `smoke-harmony` 必须包含 `harmony`、`<device>`、`<bundle>`、`<ability>`、`<text>`。
3. `webview-check` lane 改为 capability 级精确约束，而非统一要求 URL/text 占位符：
   - `route-current-url-assert`、`webview-wait` 必须包含 URL/text 占位符（`<expected-url>|<url>|<text>`）。
   - `webview-bridge-call` 必须包含 `<method>`。
   - `webview-current-url`、`webview-snapshot`、`webview-events` 不强制 URL/text 占位符。
4. 本轮仅收敛测试门禁语义，不改 runtime 行为与 schema 事实源。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/capabilityNextActionArgsKeepLaneSpecificPlaceholderSemantics`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
