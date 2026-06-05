# Round 20 Schema NextCommands Alignment

## 目标

强化方案 C 的 schema fact source：`nextCommands[]` 是失败恢复和下一步建议契约，不能退化成未校验的自由文本。

## 完成结果

- 新增 `SchemaFactSourceTests.schemaNextCommandsStayAlignedWithCommandSchemas`。
- 测试遍历所有 command schema 的 `nextCommands[]`，要求：
  - 每条建议必须是 `triton <command> ...`。
  - 根命令必须存在于 `commandSchemas()`。
  - 如果目标 command 声明了 `subcommands[]`，建议中的子命令必须存在。
  - 所有 `--flag` 必须存在于目标 command schema 或 subcommand schema 的参数声明中。
- 当前新增不变量直接通过，说明现有 `nextCommands[]` 与 schema 参数事实源一致。

## 改动文件

- `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `TritonKit.skills/tritonkit-dev-feedback/SKILL.md`

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaNextCommandsStayAlignedWithCommandSchemas` 通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests` 通过，17 个 Swift Testing 用例通过。
- `swift test --package-path CLI` 通过，88 个 Swift Testing 用例通过。

## 下一步

Round 21 建议抽取重复的 schema-backed command 校验逻辑，避免后续 plan / capabilities / schema 恢复建议各自维护一套解析规则。
