# Round 72: Failure Code Recovery Category Families

## 目标

把 `failureCodes[]` 从“稳定错误码集合”推进为 agent 可分类的恢复阶段输入。agent 应能从 `error.code` 推导候选恢复阶段，再结合 `recoveryCommands[]` 选择具体命令。

## 本轮结果

- 新增 `SchemaFactSourceTests.schemaFailureCodesMapToRecoveryCategoryFamilies`。
- 新增 `recoveryCategories(forFailureCode:)` 命名族映射，覆盖 target/runtime/server、host command、artifact、WebView、action/input、validation、assertion、route、timeout、unsupported、confirmation 等失败码族。
- 测试只要求每个 failure code 可映射到合法 recovery category family，不强制当前命令的 `recoveryCommands[]` 立即覆盖该 family 的所有候选 category。

## 取舍

初始红灯显示，如果直接要求 `failureCodes[]` 的期望 category 必须出现在同一命令的 `recoveryCommands[]` 中，会牵动大量 schema `nextCommands[]`。本轮先锁定错误码分类能力，命令级精确恢复覆盖留到后续小切片。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaFailureCodesMapToRecoveryCategoryFamilies`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：全部通过，完整 CLI package 当前 133 个 Swift Testing 用例通过。

## 后续

Round 73 可继续按命令族收紧高优先级恢复覆盖，例如 server/runtime/target 不可用优先必须有 `diagnose` 或 `prepare-target` 类恢复入口，artifact 失败优先必须有 `archive` 或 evidence 入口。
