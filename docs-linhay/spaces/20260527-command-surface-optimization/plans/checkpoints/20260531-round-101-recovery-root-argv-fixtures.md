# Round 101 - recovery root argv fixtures

## 背景

Round 98-100 之后，plan / replay / schema fixture 的大部分 schema-backed 校验已经走 `argv`，但 recovery taxonomy 相关的两条测试仍从 `fixture.command` 字符串提取 root command。只要这两处还在，`command` 字段就还隐含承担部分机器事实源职责。

## 本轮动作

1. 更新 `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`：
   - `schemaRecoveryCommandRootsStayWithinRecoveryTaxonomy`
   - `schemaRecoveryCommandRootsExposeStableCategories`
   这两条测试改为直接读取 `fixture.argv` 推导 Triton root command。
2. 删除已无引用的 `validateSchemaBackedCommandString(...)` helper，减少测试基座里的 string-first 遗留入口。

## 结果

1. recovery command root taxonomy 与 category taxonomy 的测试路径现在也统一走 `argv`。
2. `schemaNextCommandFixtures()` 产出的字符串 fixture 只保留：
   - `command` 用于单条 invocation / placeholder 质量检查；
   - `argv` 用于 schema-backed 执行事实校验与 recovery root 分类。

## 验证

1. `swift test --package-path CLI --filter SchemaFactSourceTests`

## 下一步

1. 继续清点 `SchemaFactSourceTests` 里是否还存在仅剩展示价值的 string-first helper。
2. 若测试基座已足够干净，可转入更高层的 `schema/capabilities/plan` 领域入口与任务入口重构。
