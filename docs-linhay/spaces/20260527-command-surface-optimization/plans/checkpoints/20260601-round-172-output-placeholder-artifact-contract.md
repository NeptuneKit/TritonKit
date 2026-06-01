# Round 172 - output placeholder artifact contract

## 目标

新增 capability `nextAction --output` 参数的显式契约门禁，确保 agent-facing 恢复命令不会退化为硬编码路径或模糊产物类型。

## 变更

1. 新增测试 `SchemaFactSourceTests.capabilityNextActionOutputPlaceholdersStayArtifactTypedAndExplicit`。
2. 新增约束（覆盖 connected/disconnected/server-unreachable 三态）：
   - 所有包含 `--output` 的 capability nextAction，`--output` 后继值必须是占位符 token（`<...>`）。
   - 每个已声明 `--output` 的 capability 必须出现在显式白名单中，防止新增输出能力未经契约审查直接落地。
3. 当前固定的输出占位符语义：
   - `record -> <file.tritonplan>`
   - `device/ios/harmony* screenshot -> <path>`
   - `sim-video -> <path.mov>`
   - `sim-logs -> <path.ndjson>`
   - `sim-diagnostics -> <path>`
   - `capture/evidence -> <dir.tritonevidence>`
   - `evidence-redact -> <safe.tritonevidence>`
   - `screenshot -> <path.png>`
4. 本轮仅新增测试门禁，不改 runtime 行为与 schema 事实源。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/capabilityNextActionOutputPlaceholdersStayArtifactTypedAndExplicit`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
