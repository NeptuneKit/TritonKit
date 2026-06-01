# Round 36: long-running nextAction semantics

## 目标

收紧 `capabilities[].nextAction.requiresLongRunningProcess` 的语义，避免 agent 把普通一次性恢复命令误当成需要后台进程管理的动作。

## 完成结果

- 新增 `SchemaFactSourceTests.capabilityLongRunningNextActionsStayExplicit`。
- 测试覆盖三种 capabilities 状态：server 不可达、server 可达但 runtime 未连接、server 与 runtime 均可用。
- 当前唯一允许的 long-running nextAction 是 server bootstrap：`serve --host 127.0.0.1 --port 19421`。
- 聚焦测试、schema fact source 全量测试和 CLI 全量测试已通过。
- 同步更新 agent-facing 信息架构、AI CLI 控制文档和 public skills。

## 验证

```bash
swift test --package-path CLI --filter SchemaFactSourceTests/capabilityLongRunningNextActionsStayExplicit
swift test --package-path CLI --filter SchemaFactSourceTests
swift test --package-path CLI
```

结果：通过。Schema fact source 当前为 32 个 Swift Testing 用例通过；CLI 全量当前为 103 个 Swift Testing 用例通过。

## 风险与后续

- 如果后续 `xcode run` 或真实 emulator bootstrap 需要标记为 long-running，必须先明确 agent 的进程管理责任，再扩展测试允许集合。
- 下一轮建议进入 Round 37：检查 capability `nextAction.args` 中占位符与 schema option 类型的关系，避免 `<placeholder>` 形式漂移。

## 提交状态

未提交。用户未授权 commit / push / tag / release。
