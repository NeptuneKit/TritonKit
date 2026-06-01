# Round 41: capability state test fixtures

## 目标

抽取 `SchemaFactSourceTests` 中重复构造的 capabilities 三态 fixtures，降低继续增加 capability 不变量时的维护成本。

## 完成结果

- 新增测试 helper：`capabilityStateFixtures()`。
- 统一生成三类 capabilities matrix：
  - `server-unreachable`：server 不可达，runtime 未连接；
  - `runtime-disconnected`：server 可达，runtime 未连接；
  - `runtime-connected`：server 可达，runtime 已连接。
- 替换了 `capabilityLongRunningNextActionsStayExplicit` 和 `capabilityNextActionPlaceholdersAreCompleteArgvTokens` 中重复的三态构造。
- 失败上下文现在包含 fixture 名称，后续定位更直接。

## 验证

```bash
swift test --package-path CLI --filter SchemaFactSourceTests
swift test --package-path CLI
```

结果：通过。Schema fact source 当前为 35 个 Swift Testing 用例通过；CLI 全量当前为 106 个 Swift Testing 用例通过。

## 风险与后续

- 这是测试侧重构，不改变 CLI schema、capabilities 或 plan 行为。
- 下一轮建议进入 Round 42：将 connected-only capabilities 检查也统一走 helper，继续减少 `runtimeCapabilities(host:port:serverReachable:connected:)` 直接散落。

## 提交状态

未提交。用户未授权 commit / push / tag / release。
