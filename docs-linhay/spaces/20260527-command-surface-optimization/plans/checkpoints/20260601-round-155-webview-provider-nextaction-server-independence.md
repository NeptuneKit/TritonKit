# Round 155 - WebView provider capabilities nextAction server-independence

## 目标

收敛 WebView provider 能力在 capabilities matrix 中的恢复语义，避免 `server-unreachable` 或 `runtime-disconnected` 时被统一回退到 `serve/status`，与 `--runtime-base-url` 支持边界冲突。

## 变更

1. `runtimeCapabilityRequiresServer` 移除以下能力：
   - `webview-current-url`
   - `webview-snapshot`
   - `webview-bridge-call`
   - `webview-events`
   - `webview-wait`
2. `runtimeCapabilityNextAction` 的 disconnected fallback 列表移除同一批 WebView provider 能力，保持它们在 connected/disconnected/server-unreachable 三态都返回命令级 nextAction，而不是 `serve/status`。
3. `SchemaFactSourceTests` 对齐：
   - `capabilitiesMatrixExposesGroupsDependenciesRecoveryAndEvidence`：
     - `webview-current-url` 在 disconnected/server-unreachable 状态下 nextAction 均为 `triton webview current-url --json`，且非 long-running。
   - 新增 `webviewProviderCapabilitiesKeepServerIndependentNextActions` 批量断言，覆盖：
     - `webview-current-url`
     - `webview-snapshot`
     - `webview-bridge-call`
     - `webview-events`
     - `webview-wait`
     - `route-current-url-assert`
   - 要求 disconnected/server-unreachable 两态下均保持命令级 nextAction 且 `requiresLongRunningProcess != true`。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/capabilitiesMatrixExposesGroupsDependenciesRecoveryAndEvidence`
- `swift test --package-path CLI --filter SchemaFactSourceTests/harmonyHostActionCapabilitiesKeepServerIndependentNextActions`
- `swift test --package-path CLI --filter SchemaFactSourceTests/webviewProviderCapabilitiesKeepServerIndependentNextActions`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
