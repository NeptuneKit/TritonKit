# Round 26: Schema Metadata Quality

## 目标

继续把 `triton schema` 做成 agent 可直接消费的事实源，检查参数与子命令元数据是否足够完整。

## 改动

- 新增 `SchemaFactSourceTests.schemaOptionsAndSubcommandsExposeNonemptyMetadata`。
- 校验每个 command 的 `options[]`：
  - `name` 非空。
  - `type` 非空。
  - `description` 非空。
  - 同一 command 内 option name 不重复。
- 校验每个 command 的 `subcommands[]`：
  - `name` 非空。
  - `summary` 非空。
  - 同一 command 内 subcommand name 不重复。
- 当前 schema 直接通过，未发现空参数元数据或重复子命令。
- 更新 agent-facing CLI 信息架构文档、AI CLI 可读控制文档和 public skills。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaOptionsAndSubcommandsExposeNonemptyMetadata` 通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests` 通过，22 个 Swift Testing 用例。
- `swift test --package-path CLI` 通过，93 个 Swift Testing 用例。

## 风险

- 本轮只检查字段存在与重复项，不检查 option 命名是否符合 CLI 语义，例如 alias、互斥关系或 required 关系。

## 后续

Round 27 建议检查 `outputFormats[]` 和 examples 的最低质量：每个 command 应有非空输出格式和至少一个可执行示例，示例中的 command / flag 继续走 schema-backed 校验。
