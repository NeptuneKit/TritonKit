# Round 62: Command Required Options Scope

## 目标

移除命令级 `requiredOptions[]` 中的子命令人读摘要，让 agent 不再解析 `summary/failures:--path`、`record:--template` 或 `workspace defaults or ...` 这类复合字符串。

## 改动

- 新增 `SchemaFactSourceTests.commandLevelRequiredOptionsStayDirectOrSubcommandScoped`。
- 测试要求：如果 command 暴露 `subcommands[]`，父命令级 `requiredOptions[]` 必须为空；子命令需求应写入具体 `subcommands[]`。
- 测试同时保留无子命令 command 的 direct required option 覆盖检查，要求 command-level `requiredOptions[]` 只能引用自身 `options[]` 或 `argumentForms[]`。
- 红灯暴露 `xcode`、`xcresult`、`xctrace`、`coverage` 仍在父级聚合子命令参数需求。
- 清空上述父命令的 `requiredOptions[]`，保留已有 `subcommands[].requiredOptions[]`、`oneOfRequiredOptions[]`、`optionalOptions[]` 作为机器可读事实源。
- 更新 `SimulatorAdvancedControlsTests.schemaExposesXctraceAndCoverageCommands`，断言 `xcresult` 与 `coverage` 父级不再暴露聚合 requirement。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/commandLevelRequiredOptionsStayDirectOrSubcommandScoped`
- `swift test --package-path CLI --filter SimulatorAdvancedControlsTests/schemaExposesXctraceAndCoverageCommands`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：全部通过。CLI 全量测试当前为 123 个 Swift Testing 用例通过。

## 风险与后续

- 这是面向 schema 消费者的破坏性清理：旧 agent 若依赖父级 `requiredOptions[]` 的人读摘要，需要改读 `subcommands[]`。
- 当前项目边界允许破坏性更新，无兼容层负担。
- 下一步建议 Round 63 检查 `defaultProviders[]` / `inheritsDefaultsFrom[]` 是否都指向 schema-backed Triton 命令，继续减少 agent 对 README 或实现记忆的依赖。
