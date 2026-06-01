# Round 159 - observe/node schema-capability cross-check

## 目标

把 `observe` / `node` 的 schema `providedCapabilities` 与 capabilities matrix 直接绑定，防止 schema 与 capability metadata 逐步漂移。

## 变更

1. 新增测试 `SchemaFactSourceTests.observeAndNodeProvidedCapabilitiesStaySchemaMatrixAligned`。
2. 断言 `command schema` 层 capability 声明：
   - `observe.providedCapabilities == ["observe", "observe-ios", "observe-harmony"]`
   - `node.providedCapabilities == ["node", "node-resolve"]`
3. 对上述能力在 `runtime-connected` / `runtime-disconnected` 两态做交叉检查：
   - `group`
   - `requiredBy`
   - `evidence`
   - `supported`
   - `nextAction.command/args`
4. 明确 `node` 与 `node-resolve` 的状态边界：
   - `node` 在 disconnected 态保持 `status --json` 恢复语义；
   - `node-resolve` 在 disconnected 态保持 `node resolve --text <text> --json` 命令级入口。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/observeAndNodeProvidedCapabilitiesStaySchemaMatrixAligned`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
