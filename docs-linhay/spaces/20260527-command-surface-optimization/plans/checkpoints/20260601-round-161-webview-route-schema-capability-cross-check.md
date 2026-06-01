# Round 161 - webview/route schema-capability cross-check

## 目标

把 `webview` 与 `route` 的 `providedCapabilities` 和 capabilities matrix 绑定到同一测试门禁，防止新增/调整 WebView 子能力时只修改 schema 或 matrix 的一侧。

## 变更

1. 新增测试 `SchemaFactSourceTests.webviewAndRouteProvidedCapabilitiesStaySchemaMatrixAligned`。
2. 对 schema 声明做固定断言：
   - `webview.providedCapabilities == ["webview-list", "webview-current", "webview-current-url", "webview-snapshot", "webview-bridge-call", "webview-events", "webview-wait"]`
   - `route.providedCapabilities == ["route-current-url-assert"]`
3. 对上述能力在 `runtime-connected` / `runtime-disconnected` 两态做交叉检查：
   - `group`
   - `requiredBy`
   - `evidence`
   - `supported`
   - `nextAction.command/args`
4. 明确并锁定 WebView provider 与 route 断言能力在 disconnected 态的恢复边界：保持命令级 nextAction，不回退到 `serve/status`。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/webviewAndRouteProvidedCapabilitiesStaySchemaMatrixAligned`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
