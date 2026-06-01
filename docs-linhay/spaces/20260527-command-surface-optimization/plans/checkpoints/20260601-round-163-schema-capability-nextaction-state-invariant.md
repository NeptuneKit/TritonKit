# Round 163 - schema capability nextAction state invariant

## 目标

将 `schema.providedCapabilities` 的三态门禁从 metadata 一致性继续扩展到执行入口质量，防止 disconnected/server-unreachable 分支出现不可执行或脱离 schema 的 nextAction。

## 变更

1. 新增测试 `SchemaFactSourceTests.schemaProvidedCapabilitiesKeepSchemaBackedNextActionsAcrossCapabilityStates`。
2. 对所有 schema capability 在三态（`runtime-connected` / `runtime-disconnected` / `server-unreachable`）逐项校验：
   - capability 必须存在；
   - `group` 必须存在且不能是 `misc`；
   - `evidence` 不能为空；
   - `nextAction` 不能为空；
   - `nextAction` 必须能通过 schema-backed argv 校验（命令/参数都可由 `commandSchemaMap` 解释）。
3. 本轮不改 runtime 行为与 schema 事实源，仅新增测试门禁。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaProvidedCapabilitiesKeepSchemaBackedNextActionsAcrossCapabilityStates`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
