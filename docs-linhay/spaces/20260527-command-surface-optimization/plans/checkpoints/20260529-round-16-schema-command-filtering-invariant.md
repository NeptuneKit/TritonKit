# Round 16 Schema Command Filtering Invariant

## 目标

强化方案 C 的 command fact source：agent 不只要能读取全量 schema，还必须能对每个已注册命令执行 `triton schema --command <name> --json`，并得到单命令契约。

## 完成结果

- 新增 `SchemaFactSourceTests.schemaCommandFilteringCoversTheFullCommandInventory`。
- 测试遍历 `commandSchemas().map(\.name)`，逐个调用 `buildSchemaResponse(command:)`，要求：
  - `schemaVersion == 1`
  - `commands.map(\.name) == [commandName]`
  - `httpManagementAPI.isEmpty`
- 该测试防止后续新增命令只进入全量 schema，却不能被 agent 单独查询。

## 改动文件

- `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `TritonKit.skills/tritonkit-dev-feedback/SKILL.md`

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaCommandFilteringCoversTheFullCommandInventory` 通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests` 通过，13 个 Swift Testing 用例通过。

## 下一步

Round 17 建议检查 `triton plan` 输出的 command 字符串与 schema 参数形态是否一致，优先覆盖 `ios-smoke`、`open-url`、`webview-check` 和 evidence/replay 后续命令。
