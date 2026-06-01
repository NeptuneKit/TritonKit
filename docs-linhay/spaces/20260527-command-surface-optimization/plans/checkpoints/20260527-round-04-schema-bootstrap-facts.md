# Round 04: Schema Bootstrap Facts

## 目标

让 `triton schema --json` 先覆盖 agent 启动阶段必需的事实源：`status`、`doctor`、`capabilities`、`plan`、`schema`。本轮不做命令重命名，不进入 `target` / `action` 破坏性重排。

## 本轮完成

- 新增 `SchemaFactSourceTests`，用测试锁住 agent bootstrap 命令必须暴露：
  - `failureCodes`
  - `nextCommands`
  - `outputContracts`
- 新增 `CLISchemaContracts.swift`，集中放置 bootstrap schema output contract helper，避免继续把重复 contract 定义堆入 `CLISchemaRuntime.swift`。
- 更新 `status` schema：
  - 补齐 `server_unavailable` / `request_failed`。
  - 补齐 `triton serve`、`triton doctor`、`triton list` 下一步建议。
  - 补齐 `status` JSON output contract。
- 更新 `doctor` / `capabilities` schema：
  - 补齐 `server_unavailable` / `target_unavailable` / `request_failed`。
  - 补齐 `capabilities` output contract。
  - 补齐用于继续诊断、规划、启动 server、列 target 的下一步建议。
- 更新 `plan` schema：
  - 明确 `plan` 只输出建议，不执行真实命令。
  - 补齐 `plan.next-steps` output contract。
  - 补齐 `doctor`、`capabilities`、`schema` 下一步建议。
- 更新 `schema` schema：
  - 补齐 `schema.commands` output contract。
  - 补齐 `triton schema --command <command> --json` 下一步建议。
- 第二批继续覆盖 agent 执行、验收和证据闭环命令：
  - `find`: 补齐 `target.resolution` output contract、目标消歧恢复建议和失败码。
  - `wait`: 补齐 `wait.result` output contract、timeout / validation / runtime 失败码和后续 assert/evidence 建议。
  - `tap`: 补齐 `input.result` output contract、目标查找失败和 validation 失败码、后续 wait/assert/evidence 建议。
  - `input`: 补齐 `input.result` 与 `input.summary` output contract、批处理失败码和后续证据建议。
  - `assert`: 补齐 `assert.result` output contract、断言失败码和后续 evidence/find/screenshot 建议。
  - `evidence` / `capture`: 补齐 `evidence.manifest` output contract、bundle artifact 标注和 summary/redact 后续建议。
  - `replay`: 补齐 `replay.result` output contract、dry-run / failed step 后续建议和失败码。
- 第三批覆盖 agent 观察、诊断和运行时事实入口：
  - `runtime`: 补齐 `runtime.manifest` output contract、runtime / target 失败码和 capabilities / state / snapshot 后续建议。
  - `state`: 补齐 `runtime.state` output contract、app / scene / route / responder 统一状态字段和 snapshot / observe / evidence 后续建议。
  - `snapshot`: 补齐 `runtime.snapshot` output contract、snapshot artifact 标注和 assert / wait / evidence 后续建议。
  - `observe`: 补齐 `observe.surface` output contract、iOS / Harmony 观察失败码、Harmony layout artifact 标注和 webview / find / screenshot / evidence 后续建议。
  - `webview`: 补齐 `webview.snapshot` 与 `webview.wait` output contract、WebView provider / selection / wait / bridge 失败码和 route / snapshot / wait / observe 后续建议。
  - `route`: 补齐 `route.current-url-assert` output contract、URL mismatch 与 WebView provider 失败码和 current-url / snapshot / evidence 后续建议。
  - `screenshot`: 补齐 `screenshot.metadata` 与 `host.artifact` output contract、screenshot artifact 标注和 evidence / observe / assert 后续建议。
- 第四批覆盖 host-side 目标、App、Smoke 和 plan 模板入口：
  - `device`: 补齐 `host.device-list`、`host.device-selection`、`host.device-ready`、`host.artifact`、`runtime.manifest` output contract，以及 target 消歧、ready、runtime-url、screenshot 失败码和后续建议。
  - `sim`: 补齐 `host.simulator-list`、`host.simulator-action` output contract，标注 screenshot / video / logs / diagnostics artifacts，补齐 simctl、runtime maintenance 和 destructive-gated 失败码。
  - `app`: 补齐 `host.app-action`、`host.app-open-url` output contract，标注 container / prefs / runtime snapshot artifacts，补齐 install / launch / terminate / open-url / prefs 失败码。
  - `smoke`: 补齐 `smoke.result` output contract，标注 evidence / screenshot / layout artifacts，补齐 smoke、target、wait、assert 和 evidence 失败码。
  - `record`: 补齐 `record.plan` output contract，标注 `.tritonplan` artifact，补齐 plan inspect / replay dry-run 后续建议。
- 第五批覆盖低层 runtime inspection 与 semantic action 入口：
  - `list` / `inspect`: 补齐 `targets.list`、`target.summary` output contract，以及 target discovery 后续建议和 server / target 失败码。
  - `hierarchy` / `nodes` / `node` / `attrs` / `object`: 补齐 hierarchy、node、attributes、object output contract，标注 hierarchy artifact，补齐 hierarchy unavailable、node not found、target 消歧等失败码。
  - `export`: 补齐 `hierarchy.info` 与 `export.archive` output contract，标注 hierarchy JSON / archive artifacts，补齐 artifact write 失败码和 evidence 后续建议。
  - `geometry` / `hit`: 补齐窗口 geometry 与 hit-test output contract，补齐 point validation、runtime unavailable 失败码和 point tap / node inspect 后续建议。
  - `focus` / `set-text` / `select-segment` / `set-switch`: 补齐 `semantic.action` output contract、semantic action 失败码和 ledger / evidence 后续建议。
  - `ledger`: 补齐 `runtime.ledger` 与 `runtime.ledger-entry` output contract，标注 runtime-ledger artifact，补齐 runtime failure 和 evidence 后续建议。

## 改动范围

- `Sources/TritonKitCLI/CLISchemaContracts.swift`
- `Sources/TritonKitCLI/CLISchemaRuntime.swift`
- `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`
- `docs-linhay/memory/2026-05-27.md`

## 验证

- 红灯：`swift test --package-path CLI --filter SchemaFactSourceTests` 失败，记录 53 个 schema contract 缺口。
- 绿灯：`swift test --package-path CLI --filter SchemaFactSourceTests` 通过。
- 回归：`swift test --package-path CLI` 通过，68 个 Swift Testing 用例通过。
- 第二批红灯：`swift test --package-path CLI --filter SchemaFactSourceTests/executionAndEvidenceSchemasExposeRecoveryCommandsAndOutputContracts` 失败，记录 99 个 execution / evidence schema contract 缺口。
- 第二批绿灯：`swift test --package-path CLI --filter SchemaFactSourceTests` 通过。
- 第二批回归：`swift test --package-path CLI` 通过，69 个 Swift Testing 用例通过。
- 第三批红灯：`swift test --package-path CLI --filter SchemaFactSourceTests` 失败，记录 137 个 observation / runtime schema contract 缺口。
- 第三批绿灯：`swift test --package-path CLI --filter SchemaFactSourceTests` 通过。
- 第三批回归：`swift test --package-path CLI` 通过，70 个 Swift Testing 用例通过。
- 第四批红灯：`swift test --package-path CLI --filter SchemaFactSourceTests/hostWorkflowSchemasExposeTargetAndArtifactContracts` 失败，记录 93 个 host workflow schema contract 缺口。
- 第四批绿灯：`swift test --package-path CLI --filter SchemaFactSourceTests/hostWorkflowSchemasExposeTargetAndArtifactContracts` 通过。
- 第四批回归：`swift test --package-path CLI` 通过，71 个 Swift Testing 用例通过。
- 第五批红灯：`swift test --package-path CLI --filter SchemaFactSourceTests/lowLevelRuntimeSchemasExposeInspectionAndActionContracts` 失败，记录 160 个低层 runtime / semantic action schema contract 缺口。
- 第五批绿灯：`swift test --package-path CLI --filter SchemaFactSourceTests/lowLevelRuntimeSchemasExposeInspectionAndActionContracts` 通过。
- 第五批 schema 回归：`swift test --package-path CLI --filter SchemaFactSourceTests` 通过。
- 第五批回归：`swift test --package-path CLI` 通过，72 个 Swift Testing 用例通过。
- schema 摘要：
  - 第一批后：`nextCommands` 覆盖命令数从 2 提升到 7，`failureCodes` 从 4 提升到 9，`outputContracts` 从 4 提升到 9。
  - 第二批后：`nextCommands` 覆盖命令数提升到 15，`failureCodes` 提升到 17，`outputContracts` 提升到 17，`artifacts` 提升到 6。
  - 第三批后：`nextCommands` 覆盖命令数提升到 22，`failureCodes` 提升到 24，`outputContracts` 提升到 24，`artifacts` 提升到 10。
  - 第四批后：`nextCommands` 覆盖命令数提升到 27，`failureCodes` 提升到 29，`outputContracts` 提升到 29，`artifacts` 提升到 14。
  - 第五批后：`nextCommands` 覆盖命令数提升到 42，`failureCodes` 提升到 44，`outputContracts` 提升到 44，`artifacts` 提升到 17。
  - 当前已有 output contract 的命令：`status`、`doctor`、`plan`、`capabilities`、`schema`、`xcode`、`xcresult`、`xctrace`、`coverage`、`runtime`、`state`、`snapshot`、`focus`、`set-text`、`select-segment`、`set-switch`、`ledger`、`device`、`sim`、`app`、`list`、`inspect`、`observe`、`webview`、`route`、`hierarchy`、`nodes`、`node`、`attrs`、`object`、`export`、`evidence`、`capture`、`smoke`、`assert`、`record`、`replay`、`find`、`wait`、`geometry`、`hit`、`screenshot`、`tap`、`input`。

## 决策

- Round 04 第一刀不先改 root 命令结构，先补 agent 初始探测链路的事实源。
- Bootstrap output contract helper 独立成文件，后续命令可复用，不继续扩大 `CLISchemaRuntime.swift` 的重复定义。
- 本轮只提升 schema 元数据，不改变 CLI 行为。
- 第二批仍沿用“schema 描述先行 + 测试锁定”的方式，不把 `find/tap/input` 立即迁移到 `action` namespace；命令重排留到方案 C 的破坏性阶段。
- 第三批将 `runtime/state/snapshot/observe/webview/route/screenshot` 视为 agent 诊断主干，优先于 host simulator / app / device 继续补齐，因为这些命令直接决定 agent 是否能判断当前 UI、WebView、route 和证据入口。
- 第四批把 host 目标选择、host app 控制、smoke 和 `.tritonplan` 模板纳入 schema 事实源，为后续 `target` / `project` / `plan` 破坏性重排建立现状契约。
- 第五批把低层 inspection 和 semantic action 也纳入 schema 事实源，避免 agent 在最需要诊断时回退到 README 或经验猜测。

## 风险

- 仍有少数命令没有 `nextCommands` / `failureCodes` / `outputContracts`，但 agent 主干链路、host workflow、evidence/replay、runtime observation 和低层 inspection 已完成 schema facts 覆盖。
- `failureCodes` 目前仍是 schema 描述，尚未系统性验证每个运行时错误路径和 schema 枚举完全一致；这属于 Round 05 的错误 envelope 统一范围。
- 当前工作区仍包含既有 Issue 20 与 WebView wait WIP，本轮没有清理或提交这些改动。

## 下一轮建议

进入 Round 05：系统核对运行时错误 envelope 与 schema `failureCodes` 是否一致，优先验证 JSON 失败输出是否保持单个 envelope，避免外层二次包装。
