# Round 14 Assert / Evidence / Replay Closure

## 目标

继续方案 C 的事实源对齐，把 `assert` / `evidence` / `replay` 闭环纳入 capabilities 矩阵，避免 agent 只能从 schema 发现 evidence、smoke 或 replay dry-run 能力。

## 完成结果

- `triton capabilities --json` 新增或补齐：
  - `evidence`
  - `smoke-ios`
  - `smoke-harmony`
- `evidence-summary` 与 `evidence-redact` 的 `nextAction` 从泛化 `evidence --output ...` 改为对应子命令：
  - `evidence summary <dir.tritonevidence> --json`
  - `evidence redact <dir.tritonevidence> --output <safe.tritonevidence> --json`
- `smoke-ios` / `smoke-harmony` 独立归入 `smoke` group，并给出对应 smoke 子命令 nextAction 与 `smoke-summary` / `evidence-bundle` evidence。
- `replay` schema 的 `providedCapabilities` 增加 `replay-dry-run`，明确 dry-run 是离线校验能力，不等同于真实 replay 执行。
- `SchemaFactSourceTests` 新增断言，确保 evidence / capture / smoke / record / replay 的 `providedCapabilities` 都能在 capabilities matrix 中找到。

## 改动文件

- `Sources/TritonKitCLI/CLIRuntimeTransport.swift`
- `Sources/TritonKitCLI/CLISchemaObservationCommands.swift`
- `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `.agents/tritonkit-skills/public/tritonkit-dev-feedback/SKILL.md`
- `.agents/tritonkit-skills/public/tritonkit-real-project-regression/SKILL.md`
- `.agents/tritonkit-skills/public/tritonkit-emulator-cli-takeover/SKILL.md`

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests` 通过，11 个 Swift Testing 用例通过。

## 剩余风险

- `smoke-ios` / `smoke-harmony` 当前表示 CLI 编排能力可用，不证明某个具体 target、bundle、ability 或 runtime 已准备好；真实 pass/fail 仍必须由 smoke summary、wait/assert 和 evidence 决定。
- `replay-dry-run` 只能证明 plan 变量和命令展开可校验，不证明真实 App 状态。

## 下一步

Round 15 建议回到 `schema --command` 过滤、命令 inventory 和 public README 示例，检查方案 C 的“agent 首选路径”是否已覆盖 `target -> plan -> execute -> assert -> evidence -> replay`。
