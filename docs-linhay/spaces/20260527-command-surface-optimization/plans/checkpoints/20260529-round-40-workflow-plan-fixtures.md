# Round 40: workflow plan test fixtures

## 目标

抽取 `SchemaFactSourceTests` 中重复构造的 workflow plan fixtures，降低后续继续加 plan 不变量时的维护成本。

## 完成结果

- 新增测试 helper：`workflowPlanFixtures(includeTaskInputs:)`。
- 统一生成六类 plan：
  - server 不可达的通用 plan；
  - server 可达但 target/runtime 缺失的通用 plan；
  - server 与 runtime 均可用的通用 plan；
  - `ios-smoke` 任务 plan；
  - `open-url` 任务 plan；
  - `webview-check` 任务 plan。
- `includeTaskInputs=true` 用于已有具体输入值的 schema-backed command 校验。
- `includeTaskInputs=false` 用于 placeholder / single-invocation 这类需要覆盖默认占位符的测试。
- 替换了多处重复 plan 构造，行为不变。

## 验证

```bash
swift test --package-path CLI --filter SchemaFactSourceTests
swift test --package-path CLI
```

结果：通过。Schema fact source 当前为 35 个 Swift Testing 用例通过；CLI 全量当前为 106 个 Swift Testing 用例通过。

## 风险与后续

- 这是测试侧重构，不改变 CLI schema、plan 或 runtime 行为。
- 下一轮建议进入 Round 41：将 capabilities 三态 fixtures 也抽成 helper，继续降低全局不变量测试重复。

## 提交状态

未提交。用户未授权 commit / push / tag / release。
