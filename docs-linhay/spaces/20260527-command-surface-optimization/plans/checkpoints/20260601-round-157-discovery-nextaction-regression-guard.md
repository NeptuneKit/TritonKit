# Round 157 - discovery nextAction regression guard

## 目标

为 server-independent discovery 能力补批量防回退门禁，避免后续改动把命令级 nextAction 重新劫持为 `serve/status`。

## 变更

1. 新增测试 `SchemaFactSourceTests.discoveryCapabilitiesKeepServerIndependentNextActions`。
2. 覆盖能力：
   - `observe-ios`
   - `webview-list`
   - `webview-current`
   - `node-resolve`
3. 在 `runtime-disconnected` 与 `server-unreachable` 两态下锁定以下不变量：
   - `supported` 与既有语义一致（`observe-ios=false`，其余 `true`）；
   - `nextAction.command/args` 保持命令级入口；
   - `nextAction.requiresLongRunningProcess != true`。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/discoveryCapabilitiesKeepServerIndependentNextActions`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
