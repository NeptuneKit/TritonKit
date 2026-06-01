# Round 42: connected capability test fixtures

## 目标

将 `SchemaFactSourceTests` 中 connected-only capabilities 检查统一收敛到 helper，减少直接散落的 `runtimeCapabilities(host:port:serverReachable:connected:)` 构造。

## 完成结果

- 新增测试 helper：`connectedCapabilities()`。
- 新增测试 helper：`connectedCapabilityMap()`。
- connected-only schema / capability 不变量测试统一复用 `runtime-connected` fixture：
  - schema provided capabilities discoverability；
  - capability name uniqueness；
  - capability planning arrays；
  - group / requiredBy / evidence taxonomy；
  - capability evidence nonempty；
  - schema provided capabilities planning metadata；
  - capability nextAction schema alignment；
  - execution / evidence / webview / route schema provided capability subset 检查。
- 保留 doctor 与三态 capabilities matrix 测试中的显式状态构造，因为它们本身就在验证不同连接状态。

## 验证

```bash
swift test --package-path CLI --filter SchemaFactSourceTests
swift test --package-path CLI
```

结果：通过。Schema fact source 当前为 35 个 Swift Testing 用例通过；CLI 全量当前为 106 个 Swift Testing 用例通过。

## 风险与后续

- 这是测试侧重构，不改变 CLI schema、capabilities、plan 或 runtime 行为。
- 下一轮建议进入 Round 43：继续抽取 schema-backed command 校验或 placeholder / single invocation 相关 helper，减少 agent-facing schema 不变量测试中的重复断言路径。

## 提交状态

未提交。用户未授权 commit / push / tag / release。
