# Round 160 - capability cross-check fixture refactor

## 目标

在不改变行为的前提下，收敛 `SchemaFactSourceTests` 中 capability 状态读取与断言样板代码，降低后续扩展 `observe/webview/route/node` 门禁时的维护成本。

## 变更

1. 在 `SchemaFactSourceTests` 提取共享 helper：
   - `capabilityMap(state:)`
   - `disconnectedCapabilityMap()`
   - `unavailableServerCapabilityMap()`
   - `assertCapability(...)`
2. 将以下测试改为复用 helper，保持原断言语义不变：
   - `webviewProviderCapabilitiesKeepServerIndependentNextActions`
   - `discoveryCapabilitiesKeepServerIndependentNextActions`
   - `observeAndNodeProvidedCapabilitiesStaySchemaMatrixAligned`
3. 本轮不修改 `CLIRuntimeTransport`、schema 事实源或 capability matrix，仅做测试代码去重与可读性收敛。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
