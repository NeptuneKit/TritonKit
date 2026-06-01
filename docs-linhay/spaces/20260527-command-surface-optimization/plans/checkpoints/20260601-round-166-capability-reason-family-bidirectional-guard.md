# Round 166 - capability reason-family bidirectional guard

## 目标

为 capability `reason` 文本与 capability family 之间建立双向门禁，防止 reason 语义变更后能力分组漂移或回归被静默放过。

## 变更

1. 新增测试 `SchemaFactSourceTests.capabilityReasonTextStaysBidirectionallyAlignedWithCapabilityFamilies`。
2. 建立 `reason -> capability family` 约束：
   - `Requires connected embedded TritonKit runtime` 只能出现在 runtime-family capability 集合；
   - `Requires WebView provider metadata from embedded runtime or --runtime-base-url` 只能出现在 webview-provider family capability 集合；
   - `Host-side Harmony clear is not available in the current adapter` 只能对应 `harmony-clear-text`；
   - `Host-side HID is not available in the embedded runtime` 只能对应 `press`。
3. 建立 `capability family -> reason` 反向约束（connected/disconnected/server-unreachable 三态）：
   - runtime-family capability：connected reason 必须为空，disconnected/server-unreachable reason 必须为 runtime-reason；
   - webview-provider family capability：connected reason 必须为空，disconnected/server-unreachable reason 必须为 webview-provider-reason；
   - `press` 与 `harmony-clear-text` 在三态 reason 必须保持各自 boundary 文本不变。
4. 本轮仅新增测试门禁，不改 runtime 行为与 schema 事实源。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/capabilityReasonTextStaysBidirectionallyAlignedWithCapabilityFamilies`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
