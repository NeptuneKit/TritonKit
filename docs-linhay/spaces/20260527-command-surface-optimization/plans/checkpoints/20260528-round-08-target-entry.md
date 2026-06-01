# Round 08: Target Entry

## 目标

把 `target` 建成 agent-facing 的一等目标选择入口，先把 discover / resolve / current / use / wait-ready 这条前置链路固定下来，再继续迁移 `device` / `sim` 中的其余 host 工具能力。

## 本轮完成

- 新增 `Sources/TritonKitCLI/CLITargetCommands.swift`：
  - 新增 `Target` 根命令组，子命令为 `list`、`use`、`current`、`resolve`、`wait-ready`。
  - 复用现有 `HostDeviceSelectionRequest`、`resolveHostDeviceSelection`、`waitForHostDeviceReady`、`loadHostTargetAliasStore` 和 `saveHostTargetAliasStore`。
  - `target use` / `target current` / `target resolve` 输出已沿用现有 host selection envelopes，避免重复 DTO。
- 更新 `Sources/TritonKitCLI/TritonKitCLI.swift`：
  - 将 `Target.self` 注册进 root subcommands，放在 bootstrap 之后、Xcode 之前。
- 新增 `Sources/TritonKitCLI/CLISchemaTargetCommands.swift`：
  - `target` schema 作为一等命令事实源，暴露 list/use/current/resolve/wait-ready 的机器可读契约。
  - `target` schema 复用 host device list / selection / ready output contracts。
  - `target` schema 的 nextCommands 明确指向 `target resolve/use/wait-ready`。
- 更新 `Sources/TritonKitCLI/CLISchemaRuntime.swift`：
  - `commandSchemas()` 组合中插入 `targetCommandSchemas()`，让 `target` 进入 schema 事实源顺序。
- 更新 `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`：
  - 新增 `targetSchemasExposeDiscoveryAndReadinessContracts`。
  - 锁定 `target` 的 failure codes、nextCommands 和输出契约字段。
  - 将 schema inventory 数量更新为 53，并把 `target` 放入稳定顺序。
- 更新 `docs-linhay/dev/ai-cli-readable-control.md`：
  - 补入 `triton target list|use|current|resolve|wait-ready` 入口说明。
- 更新 `README.md`：
  - 将 `target` 标记为首选目标选择入口。
  - iOS / Harmony 示例改为优先使用 `target` 做目标发现、解析和 ready 等待。

## 验收

- `swift test --package-path CLI --filter SchemaFactSourceTests` 通过。
- `swift test --package-path CLI` 通过，79 个 Swift Testing 用例通过。
- `git diff --check` 通过。
- `docs-linhay/scripts/check-docs.sh` 通过。

## 决策

- `target` 只负责目标发现、解析、当前目标和 ready 等待，不把 alias / runtime-url / screenshot / stop 一并塞进来。
- 现有 `device` 继续承担 host 工具探测、alias 管理、runtime-url、screenshot 和 Harmony stop；下一轮再继续把仍属于 target 前置上下文的能力搬过去。
- `target` 的输出优先复用现有 host selection envelopes，避免引入重复 DTO。

## 风险

- `README` 中仍有大量 `device` 语法和旧 selector 表述，后续需要继续收敛到 `target` 优先口径。
- `device` / `sim` 与 `target` 的职责边界仍未完全收束，Round 09 之后还要继续拆分和迁移。

## 下一轮建议

进入 Round 09：升级 `capabilities` 为环境能力矩阵，并让 `target`、`device`、`runtime`、`app` 和 `xcode` 的能力输出保持一致可解释。

