# Round 130 - generic error subfield contract

## 本切片目标

把 `TKCLIErrorDetail` 的 machine-readable contract 从 replay 专项提升到通用 schema helper：凡是 output contract 里声明 `error: TKCLIErrorDetail?`，都自动展开同一组稳定子字段，而不是只补 `nextAction` 的局部信息。

## 完成结果

- `schemaContractFields(...)` 现在对通用 `error: TKCLIErrorDetail?` 自动展开：
  - `error.endpoint`
  - `error.hint`
  - `error.nearestCandidates`
  - `error.suggestedCommands`
  - `error.candidateCount`
  - `error.nextAction`
  - `error.nextAction.command`
  - `error.nextAction.args`
  - `error.nextAction.category`
  - `error.nextAction.requiresLongRunningProcess`
- `SchemaFactSourceTests` 从“只检查 `error.nextAction.category`”升级为检查整套稳定 error subfields。
- replay 专项 contract 保持不变；本轮是把同类规则推广到所有使用 `TKCLIErrorDetail` 的命令 output contract。

## 影响文件

- `Sources/TritonKitCLI/CLISchemaContracts.swift`
- `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- `docs-linhay/memory/2026-05-31.md`

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests`

## 剩余风险

- 本轮只补了 output contract 展开，不代表所有命令都会在运行时实际填满这些字段；是否填值仍取决于各自错误路径。
- 某些命令如果未来切换到非 `TKCLIErrorDetail` 失败模型，需要单独定义对应 contract，而不是默认继承这套字段。

## 下一步

继续检查 bootstrap / capabilities / plan 是否还缺少能减少 agent 二次推断的 machine-readable 字段，优先回到跨命令入口的职责边界整理。
