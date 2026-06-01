# Round 131 - generic nextAction subfield contract

## 本切片目标

把 output contract 里的 `TKCLINextAction?` 从零散手写字段收口为统一 schema 规则，减少 agent 在看到 `nextAction` 后还要回到 DTO 定义猜 `command/args/category/requiresLongRunningProcess`。

## 完成结果

- `Sources/TritonKitCLI/CLISchemaContracts.swift`
  - 新增通用 `nextActionSchemaFields(...)` helper。
  - `schemaContractFields(...)` 现在会对任意 `TKCLINextAction?` 字段自动展开：
    - `<name>.command`
    - `<name>.args`
    - `<name>.category`
    - `<name>.requiresLongRunningProcess`
  - `error: TKCLIErrorDetail?` 的自动展开逻辑改为复用同一套 nextAction helper。
  - 去掉 `capabilities`、`doctor`、`replay` contract 里与自动展开重复的手写 nextAction 子字段。
- `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`
  - 新增 `nextAction output contracts expose stable next action subfields`。
  - bootstrap contract 断言补齐：
    - `capabilities[].nextAction.command/args/category/requiresLongRunningProcess`
    - `checks[].nextAction.command/args/category/requiresLongRunningProcess`
  - replay contract 断言补齐：
    - `failureError.nextAction.category`
    - `steps[].error.nextAction.category`

## 影响边界

- 这是 schema contract 收紧，不改 runtime 执行语义。
- 直接提升了 agent 对 `capabilities`、`doctor` 和 replay failure surfaces 的机器可读性。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests`
  - 通过，85 个 Swift Testing 用例通过

## 后续队列

- 继续检查 bootstrap / capability / plan 三个事实源之间是否还存在需要 agent 手工聚合的首选入口字段，例如 top-level primary next action / primary capability lane。
