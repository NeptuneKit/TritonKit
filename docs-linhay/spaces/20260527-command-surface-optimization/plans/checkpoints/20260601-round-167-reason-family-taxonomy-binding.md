# Round 167 - reason-family taxonomy binding

## 目标

把 reason family 与 `group/requiredBy/evidence` taxonomy 绑定成可执行门禁，避免 reason 映射与规划/证据语义脱钩。

## 变更

1. 新增测试 `SchemaFactSourceTests.capabilityReasonFamiliesStayAlignedWithGroupWorkflowAndEvidenceTaxonomies`。
2. 在 `runtime-disconnected` 与 `server-unreachable` 两态校验以下约束：

### Runtime reason family（`Requires connected embedded TritonKit runtime`）

- `group` 必须属于 `runtime|observe|assert|evidence|replay|action`；
- `requiredBy` 不得包含 `webview-check`；
- `evidence` 不能为空，且不得混入 webview/provider 证据键。

### WebView-provider reason family（`Requires WebView provider metadata from embedded runtime or --runtime-base-url`）

- `group` 必须属于 `webview|route`；
- `requiredBy` 必须包含 `webview-check`、`assert`、`evidence`；
- `evidence` 必须包含 `webview-provider`。

### Boundary reason（`press` / `harmony-clear-text`）

- 两者都必须是 `group=action`；
- `requiredBy` 必须包含 `action`、`assert`、`evidence`；
- `evidence` 必须等于 `["unsupported-envelope","command-schema"]`（集合意义）。

3. 本轮仅新增测试门禁，不改 runtime 行为与 schema 事实源。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/capabilityReasonFamiliesStayAlignedWithGroupWorkflowAndEvidenceTaxonomies`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
