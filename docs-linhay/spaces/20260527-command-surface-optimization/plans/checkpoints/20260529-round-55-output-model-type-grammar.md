# Round 55 - output contract model type grammar

## 目标

锁定 `outputContracts[].model` 的机器可读类型语法，让 agent 可以把 model 字段当作主输出模型名，而不是解析自然语言或 Swift 泛型片段。

## 完成结果

- 新增 `SchemaFactSourceTests.schemaOutputContractModelsStayMachineReadable`。
- 首次红灯发现三个问题：
  - `nodes:hierarchy.nodes:Dictionary<String, [HierarchyNodeSummary]>`
  - `ax:ax.nodes:[TKAXNode]|TKAXHierarchyMapResponse`
  - `screenshot:screenshot.metadata:embedded screenshot metadata dictionary`
- 修正测试 helper，支持 union 中包含数组类型，例如 `[TKAXNode]|TKAXHierarchyMapResponse`。
- 将截图元数据 model 收敛为 `ScreenshotMetadataOutput`。
- 将 hierarchy nodes map model 收敛为 `HierarchyNodeSummaryMap`。
- 同步更新 agent-facing CLI 信息架构文档、AI CLI 控制文档，以及三个 public skill 的 model 契约说明。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaOutputContractModelsStayMachineReadable`：先失败，修正后通过，1 个 Swift Testing 用例通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests`：通过，45 个 Swift Testing 用例通过。
- `swift test --package-path CLI`：通过，116 个 Swift Testing 用例通过。

## 风险与后续

- 该切片改变了 schema model 字符串，但只把低信号描述收敛为稳定模型名，不改变 runtime 输出。
- 下一轮可继续检查 selector / kind / model 命名风格一致性，或抽取 schema type grammar helper 的单元测试。

## 提交状态

未提交。
