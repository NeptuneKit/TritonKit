# Round 158 - observe and node capability metadata consistency guard

## 目标

加强 discovery 能力的 capability 元数据门禁，避免后续只保住 nextAction 但让 `group/requiredBy/evidence` 漂移。

## 变更

1. 强化 `SchemaFactSourceTests.discoveryCapabilitiesKeepServerIndependentNextActions`：
   - 新增 `observe-harmony` 覆盖；
   - 对每个能力新增精确断言：
     - `group`
     - `requiredBy`
     - `evidence`
2. 覆盖能力：
   - `observe-ios`
   - `observe-harmony`
   - `webview-list`
   - `webview-current`
   - `node-resolve`
3. 在 `runtime-disconnected` 与 `server-unreachable` 两态下同时锁定：
   - `supported` 语义
   - 元数据（group/requiredBy/evidence）
   - 命令级 nextAction 与非 long-running 语义

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/discoveryCapabilitiesKeepServerIndependentNextActions`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
