# Round 169 - group / nextAction root alignment

## 目标

新增 capability `group` 与 `nextAction.command` 根命令的一致性门禁，防止能力分类与执行入口错位。

## 变更

1. 新增测试 `SchemaFactSourceTests.capabilityGroupStaysAlignedWithNextActionRootCommands`。
2. 建立 `group -> allowed nextAction roots` 约束（三态生效），例如：
   - `target -> target`
   - `webview -> webview`
   - `route -> route`
   - `smoke -> smoke`
   - `xcode -> xcode|xcresult|xctrace|coverage`
   - `host -> device|sim|app|ax`（含 `harmony-ax` host 能力的 `ax` 入口）
   - `runtime/observe/evidence/assert/replay/action/bootstrap` 按当前契约限制对应根命令集合。
3. 初版门禁命中了真实边界：`harmony-ax` 的 group 为 `host`，nextAction root 为 `ax`。测试规则已显式纳入该 host-side 特例，避免误报。
4. 本轮仅新增测试门禁，不改 runtime 行为与 schema 事实源。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/capabilityGroupStaysAlignedWithNextActionRootCommands`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
