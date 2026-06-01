# Round 19 Capability NextAction Schema Alignment

## 目标

强化方案 C 的 capabilities fact source：`capabilities[].nextAction` 不只是提示文本，而是 agent 可直接组装执行的 schema-backed recommendation。

## 完成结果

- 新增 `SchemaFactSourceTests.capabilityNextActionsStayAlignedWithCommandSchemas`。
- 测试遍历 connected capabilities matrix 中所有 `nextAction`，要求：
  - `nextAction.command` 存在于 `commandSchemas()`。
  - 如果命令声明了 `subcommands[]`，`nextAction.args.first` 中的子命令必须存在。
  - 所有 `--flag` 必须存在于根 schema 或 subcommand schema 的参数声明中。
- 红灯暴露了 `sim`、`app` 相关 nextAction 与 schema 参数覆盖不一致：
  - simulator artifact 命令缺少 `--simulator` / `--output` / `--bundle-id` / `--payload` schema 声明。
  - app prefs 缺少 `--bundle-id` schema 声明。
  - Harmony install nextAction 错误使用了 iOS `--app`。
- 修正 `sim` schema，补齐 artifact / push 相关 flags。
- 修正 `app` schema，补齐 `--bundle-id`、`--app`、`--hap`。
- 修正 Harmony app install nextAction 为 `app install --platform harmony --hap <path.hap> --json`。

## 改动文件

- `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`
- `Sources/TritonKitCLI/CLIRuntimeTransport.swift`
- `Sources/TritonKitCLI/CLISchemaHostCommands.swift`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `.agents/tritonkit-skills/public/tritonkit-emulator-cli-takeover/SKILL.md`
- `.agents/tritonkit-skills/public/tritonkit-dev-feedback/SKILL.md`
- `.agents/tritonkit-skills/public/tritonkit-real-project-regression/SKILL.md`

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/capabilityNextActionsStayAlignedWithCommandSchemas` 通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests` 通过，16 个 Swift Testing 用例通过。
- `swift test --package-path CLI` 通过，87 个 Swift Testing 用例通过。

## 下一步

Round 20 建议继续把 `nextCommands[]` 的命令字符串纳入 schema 参数形态校验，覆盖 schema 自身给出的恢复建议。
