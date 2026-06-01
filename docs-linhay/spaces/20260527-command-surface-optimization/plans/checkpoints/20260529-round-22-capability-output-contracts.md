# Round 22 Capability Output Contracts

## 目标

强化方案 C 的 schema fact source：任何声明 `providedCapabilities[]` 的命令，都必须暴露机器可读 `outputContracts[]`，否则 agent 虽然知道能力存在，却无法稳定解析成功输出。

## 完成结果

- 新增 `SchemaFactSourceTests.commandsThatProvideCapabilitiesExposeOutputContracts`。
- 测试遍历所有 command schema，要求 `providedCapabilities` 非空的命令 `outputContracts` 也非空。
- 红灯暴露缺口：`ax`、`clear`、`paste`、`press`、`swipe`、`type`。
- 为 `swipe`、`type`、`paste`、`clear` 复用 `inputResultOutputContract()`。
- 为 `press` 增加 embedded `input.result` 与 Harmony host `host.key-action` 输出契约。
- 新增 `axOutputContract()`，描述 `[TKAXNode]` / `TKAXHierarchyMapResponse` 主要字段；`ax` 同时声明 Harmony host artifact 输出契约。

## 改动文件

- `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`
- `Sources/TritonKitCLI/CLISchemaActionCommands.swift`
- `Sources/TritonKitCLI/CLISchemaObservationCommands.swift`
- `Sources/TritonKitCLI/CLISchemaContracts.swift`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `.agents/tritonkit-skills/public/tritonkit-dev-feedback/SKILL.md`

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/commandsThatProvideCapabilitiesExposeOutputContracts` 通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests` 通过，18 个 Swift Testing 用例通过。
- `swift test --package-path CLI` 通过，89 个 Swift Testing 用例通过。

## 下一步

Round 23 建议检查 `outputContracts[].fields` 至少包含 success/failure 解析所需的核心字段，避免出现空字段或低信号 contract。
