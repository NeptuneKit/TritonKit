# Round 64: Schema Artifact Taxonomy

## 目标

把 schema `artifacts[]` 从自由字符串收敛为固定 taxonomy，方便 agent 规划 evidence、日志、截图、trace、coverage 和 runtime snapshot 的消费方式。

## 改动

- 新增 `SchemaFactSourceTests.schemaArtifactsStayWithinTheArtifactTaxonomy`。
- 新增 `schemaArtifactTaxonomy()` helper。
- 测试覆盖 command 级 `artifacts[]` 与 subcommand 级 `artifacts[]`，要求取值在固定集合内且同一层级不重复。
- 当前 schema 直接满足该不变量；本轮不修改 runtime 行为或 schema 数据。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaArtifactsStayWithinTheArtifactTaxonomy`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：全部通过。CLI 全量测试当前为 125 个 Swift Testing 用例通过。

## 风险与后续

- taxonomy 当前锁定的是已出现 artifact 名称；新增 host/runtime/evidence artifact 时需要同步扩展 helper、文档和 public skills。
- 下一步建议 Round 65 检查 `jsonlEvents[]` / `finalEventKind` 的命名和覆盖关系，继续稳定长任务事件面。
