# Round 17 Capability Planning Metadata Invariant

## 目标

强化方案 C 的 capabilities fact source：agent 不只要能从 `schema.providedCapabilities[]` 找到能力名，还必须能从 `triton capabilities --json` 得到可规划、可执行、可诊断的元数据。

## 完成结果

- 新增 `SchemaFactSourceTests.schemaProvidedCapabilitiesExposePlanningMetadata`。
- 测试遍历所有 `commandSchemas().flatMap(\.providedCapabilities)`，要求 connected capabilities matrix 中对应能力满足：
  - `group` 非空。
  - `group != "misc"`。
  - `nextAction` 非空。
  - `evidence` 非空。
- 补齐 bootstrap、runtime state、semantic action、observe、node、wait/assert、screenshot、Xcode 基础能力和 replay dry-run 的 `nextAction` / `evidence`。
- 该测试防止后续新增 schema 能力只登记名字，却无法让 agent 判断下一步命令或证据面。

## 改动文件

- `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`
- `Sources/TritonKitCLI/CLIRuntimeTransport.swift`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `.agents/tritonkit-skills/public/tritonkit-emulator-cli-takeover/SKILL.md`
- `.agents/tritonkit-skills/public/tritonkit-dev-feedback/SKILL.md`
- `.agents/tritonkit-skills/public/tritonkit-real-project-regression/SKILL.md`

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaProvidedCapabilitiesExposePlanningMetadata` 通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests` 通过，14 个 Swift Testing 用例通过。
- `swift test --package-path CLI` 通过，85 个 Swift Testing 用例通过。

## 下一步

Round 18 建议继续检查 `triton plan` 输出的 command 字符串与 schema 参数形态是否一致，优先覆盖 `ios-smoke`、`open-url`、`webview-check` 和 evidence/replay 后续命令。
