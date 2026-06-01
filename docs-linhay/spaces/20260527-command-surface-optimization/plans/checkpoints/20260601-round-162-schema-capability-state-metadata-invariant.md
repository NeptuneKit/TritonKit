# Round 162 - schema capability state metadata invariant

## 目标

把 `schema.providedCapabilities` 的门禁从“只检查存在性”升级为“跨状态元数据一致性”，降低 capability matrix 在 disconnected/server-unreachable 分支发生静默漂移的风险。

## 变更

1. 新增测试 `SchemaFactSourceTests.schemaProvidedCapabilitiesKeepStableMetadataAcrossCapabilityStates`。
2. 对所有 `schema.providedCapabilities` 执行三态覆盖检查：
   - `runtime-connected`
   - `runtime-disconnected`
   - `server-unreachable`
3. 新增断言：
   - 三态都必须存在该 capability；
   - `group` 在三态保持一致；
   - `requiredBy` 在三态保持一致；
   - `evidence` 在三态保持一致。
4. 该轮只新增测试门禁，不改 runtime 行为或 schema 事实源。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaProvidedCapabilitiesKeepStableMetadataAcrossCapabilityStates`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
