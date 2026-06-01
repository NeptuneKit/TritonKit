# Round 27: Schema Examples Quality

## 目标

让 `examples[]` 成为 agent 可复用的 argv 样本，而不是可能漂移的说明文本。

## 红灯

新增 `SchemaFactSourceTests.schemaExamplesAndOutputFormatsRemainAgentUsable` 后，聚焦测试失败：

- `input` 示例是 shell pipeline，原校验只接受字符串首 token 为 `triton`，无法抽取 pipeline 内的 `triton input`。
- `sim` 示例使用了未声明的 `--duration`、`--style`、`--confirm`、`--dry-run`。
- `app` 示例使用了未声明的 `--user-only`、`--bundle`、`--ability`、`--confirm`、`--kind`。

## 修复

- 调整 schema-backed command 校验 helper，允许从示例 token 中定位第一个 `triton` 调用，支持 pipeline 示例。
- `sim` schema 补齐 `--duration`、`--style`、`--confirm`、`--dry-run`。
- `app` schema 补齐 `--bundle`、`--ability`、`--user-only`、`--confirm`、`--kind`。
- 新不变量同时要求每个 command 有非空 `outputFormats[]` 与至少一个 example。
- 更新 agent-facing CLI 信息架构文档、AI CLI 可读控制文档和 public skills。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaExamplesAndOutputFormatsRemainAgentUsable` 通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests` 通过，23 个 Swift Testing 用例。
- `swift test --package-path CLI` 通过，94 个 Swift Testing 用例。

## 风险

- 当前示例校验仍是轻量 token 校验，不解析 shell quoting、位置参数 required 关系或 flag value 类型。

## 后续

Round 28 建议检查 `nextCommands[]`、plan commands 和 examples 中的 `--json` / `--format json` 口径是否一致，优先让 agent-facing 示例默认机器可读。
