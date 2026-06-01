# Round 171 - group machine-readable nextAction flags

## 目标

新增 capability group 维度的 nextAction 输出模式门禁，确保 agent 在 capability 恢复路径中持续获得机器可读输出，而不是退回人读文本。

## 变更

1. 新增测试 `SchemaFactSourceTests.capabilityGroupsKeepMachineReadableNextActionOutputFlags`。
2. 新增全量约束（跨 connected/disconnected/server-unreachable 三态）：
   - 除 `serve` 外，所有 capability `nextAction.args` 必须至少包含一种机器可读输出语义：
     - `--json`
     - `--jsonl`
     - `--format json`（例如 `plan --format json`）
     - `--metadata`（用于 `screenshot` 的结构化元数据出口）
3. 对 `observe` 组的 `screenshot` 路径补强约束：
   - `nextAction.args` 必须同时包含 `--metadata` 与 `<path.png>`，固定“图像文件 + 元数据”双轨产物语义。
4. 本轮仅新增测试门禁，不改 runtime 行为与 schema 事实源。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/capabilityGroupsKeepMachineReadableNextActionOutputFlags`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
