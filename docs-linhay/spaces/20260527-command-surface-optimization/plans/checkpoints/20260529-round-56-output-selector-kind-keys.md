# Round 56 - output selector and kind keys

## 目标

锁定 `outputContracts[].selector` 和 `outputContracts[].kind` 的 agent key 命名风格，避免 schema 输出模型 key 出现空格、驼峰、下划线或临时人读短语。

## 完成结果

- 新增 `SchemaFactSourceTests.schemaOutputContractSelectorsAndKindsUseStableAgentKeys`。
- 新增 helper：
  - `isAgentSelectorKey(_:)`：要求 selector 是点分层级 key，每段为小写 kebab。
  - `isKebabCaseKey(_:)`：要求 kind 是小写 kebab key。
- 当前 schema 已满足该不变量，没有发现非法 selector 或 kind。
- 同步更新 agent-facing CLI 信息架构文档、AI CLI 控制文档，以及三个 public skill 的 selector/kind key 契约说明。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaOutputContractSelectorsAndKindsUseStableAgentKeys`：通过，1 个 Swift Testing 用例通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests`：通过，46 个 Swift Testing 用例通过。
- `swift test --package-path CLI`：通过，117 个 Swift Testing 用例通过。

## 风险与后续

- 该切片不改变 runtime 输出，只增加 schema key 命名门禁。
- 下一轮可检查 command/subcommand/option 名称风格，或抽取 schema key grammar helper 的专门测试。

## 提交状态

未提交。
