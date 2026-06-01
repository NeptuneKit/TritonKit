# Round 156 - observe-ios nextAction server-independence

## 目标

收敛 `observe-ios` capability 与 `--runtime-base-url` 执行边界：当 server 不可达或 runtime 未连接时，能力恢复提示不再被统一劫持到 `serve/status`。

## 变更

1. `runtimeCapabilityRequiresServer` 移除 `observe-ios`。
2. `runtimeCapabilityNextAction` 的 disconnected fallback 列表移除 `observe-ios`。
3. `SchemaFactSourceTests.capabilitiesMatrixExposesGroupsDependenciesRecoveryAndEvidence` 增加 `observe-ios` 三态断言：
   - connected：`supported=true`，`group=observe`，`requiredBy` 包含 `action/assert/evidence`，nextAction 为 `observe current --platform ios --json`。
   - runtime-disconnected：`supported=false`，nextAction 仍为 `observe current --platform ios --json`。
   - server-unreachable：`supported=false`，nextAction 仍为 `observe current --platform ios --json`，且非 long-running。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/capabilitiesMatrixExposesGroupsDependenciesRecoveryAndEvidence`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
