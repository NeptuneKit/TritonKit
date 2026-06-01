# Round 154 - route capability nextAction server-independence

## 目标

修复 `route-current-url-assert` 的 capability 恢复提示与 schema `requiresServer=false` 不一致问题，避免 server 不可达时被错误劫持为 `serve`/长进程恢复。

## 变更

1. `runtimeCapabilityRequiresServer` 移除 `route-current-url-assert`。
2. `runtimeCapabilityNextAction` 的 disconnected fallback 列表移除 `route-current-url-assert`，保持 route 能力在 connected/disconnected/server-unreachable 三态都给出同一 nextAction：
   - `triton route assert-current-url <expected-url> --json`
3. 测试加固（`SchemaFactSourceTests.capabilitiesMatrixExposesGroupsDependenciesRecoveryAndEvidence`）：
   - connected 状态：`route` nextAction 仍是 `route assert-current-url`。
   - disconnected 状态：`supported=false`，nextAction 仍是 `route assert-current-url`。
   - server-unreachable 状态：`supported=false`，nextAction 仍是 `route assert-current-url`，且 `requiresLongRunningProcess != true`。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/capabilitiesMatrixExposesGroupsDependenciesRecoveryAndEvidence`
- `swift test --package-path CLI --filter SchemaFactSourceTests/harmonyHostActionCapabilitiesKeepServerIndependentNextActions`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
