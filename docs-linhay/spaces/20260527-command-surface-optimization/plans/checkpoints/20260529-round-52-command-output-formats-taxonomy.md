# Round 52 - command output formats taxonomy

## 目标

锁定命令级 `outputFormats[]` 的可选输出模式 taxonomy，避免 schema 中出现未定义或重复的输出格式值。

## 完成结果

- 新增 `SchemaFactSourceTests.schemaOutputFormatsStayWithinCommandTaxonomy`。
- 固定允许的命令级输出模式为 `text`、`json`、`jsonl`、`logs`、`tree`、`auto`、`archive`、`file`、`json-metadata`。
- 同一命令内的 `outputFormats[]` 不允许重复。
- 当前 schema 已满足该不变量，没有发现越界或重复输出格式。
- 同步更新 agent-facing CLI 信息架构文档、AI CLI 控制文档，以及三个 public skill 的命令级输出格式契约说明。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaOutputFormatsStayWithinCommandTaxonomy`：通过，1 个 Swift Testing 用例通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests`：通过，43 个 Swift Testing 用例通过。
- `swift test --package-path CLI`：通过，114 个 Swift Testing 用例通过。

## 风险与后续

- `outputFormats[]` 是命令可选输出模式，`outputContracts[].format` 是输出契约解析模式，两者已分别约束。
- 下一轮可检查 output contract field `type` taxonomy，或整理 schema taxonomy helper，减少测试内显式集合分散。

## 提交状态

未提交。
