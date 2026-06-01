# Round 06: Schema Runtime Split

## 目标

开始治理巨型 `CLISchemaRuntime.swift`。本轮只做低风险拆分：先锁定 schema command inventory，再把共享 option、failure code、input action schema 和 render helper 移出命令事实数组文件，保持 `triton schema --json` 对外输出顺序不变。

## 本轮完成

- 扩展 `SchemaFactSourceTests`：
  - 新增 `schemaCommandInventoryRemainsStableForAgentDiscovery`。
  - 锁定 schema command 数量为 52。
  - 锁定 command name 唯一性和当前 agent-facing command 顺序。
- 新增 `Sources/TritonKitCLI/CLISchemaShared.swift`：
  - 迁出 schema 共享 options：host/port、target、format/json alias、language、runtime base URL、metadata alias、refresh。
  - 迁出共享 failure code 集合：runtime target、hierarchy、node、semantic action、input command。
  - 迁出 `inputActionSchemas()` 与 `inputField(...)`。
  - 迁出 `renderSchema(...)`。
- 更新 `Sources/TritonKitCLI/CLISchemaRuntime.swift`：
  - 顶部本地重复定义改为引用 shared facts。
  - 保留 52 个 `TKCommandSchema` 的顺序与内容位置。
  - 文件行数从约 2452 行降到约 2267 行；本轮未继续移动 command group，避免一次性重排过大。
- 新增 `Sources/TritonKitCLI/CLISchemaBootstrapCommands.swift`：
  - 迁出 `version`、`serve`、`status`、`doctor`、`plan`、`capabilities`、`schema` 这 7 个 agent bootstrap command facts。
  - `commandSchemas()` 改为 `bootstrapCommandSchemas() + [...]`，让 bootstrap 信息架构独立成组。
  - `CLISchemaRuntime.swift` 进一步降到约 2124 行。
- 新增 `Sources/TritonKitCLI/CLISchemaXcodeCommands.swift`：
  - 机械迁出 `xcode`、`xcresult`、`xctrace`、`coverage` 这 4 个 host Xcode command facts。
  - `commandSchemas()` 改为 `bootstrapCommandSchemas() + xcodeCommandSchemas() + [...]`。
  - `CLISchemaRuntime.swift` 进一步降到约 1639 行。
- 新增 `Sources/TritonKitCLI/CLISchemaRuntimeCommands.swift`：
  - 机械迁出 `runtime`、`state`、`snapshot`、`focus`、`set-text`、`select-segment`、`set-switch`、`ledger` 这 8 个 embedded runtime command facts。
  - `commandSchemas()` 改为 `bootstrapCommandSchemas() + xcodeCommandSchemas() + runtimeCommandSchemas() + [...]`。
  - `CLISchemaRuntime.swift` 进一步降到约 1377 行，低于 1500 行治理线。
- 新增 `Sources/TritonKitCLI/CLISchemaHostCommands.swift`：
  - 机械迁出 `device`、`sim`、`app` 这 3 个 host command facts。
  - `commandSchemas()` 改为 `bootstrapCommandSchemas() + xcodeCommandSchemas() + runtimeCommandSchemas() + hostCommandSchemas() + [...]`。
  - `CLISchemaRuntime.swift` 进一步降到约 1056 行。
- 新增 `Sources/TritonKitCLI/CLISchemaObservationCommands.swift`：
  - 机械迁出 `list`、`inspect`、`observe`、`webview`、`route`、`hierarchy`、`nodes`、`node`、`attrs`、`object`、`export`、`geometry`、`hit`、`screenshot` 这 14 个 observation command facts。
  - `commandSchemas()` 改为 `bootstrapCommandSchemas() + xcodeCommandSchemas() + runtimeCommandSchemas() + hostCommandSchemas() + observationCommandSchemas() + [...]`。
  - `CLISchemaRuntime.swift` 进一步降到约 243 行，回到纯组合层。
- 新增 `Sources/TritonKitCLI/CLISchemaActionCommands.swift`：
  - 机械迁出 `tap`、`swipe`、`type`、`paste`、`clear`、`press`、`input` 这 7 个 action command facts。
  - `commandSchemas()` 改为 `bootstrapCommandSchemas() + xcodeCommandSchemas() + runtimeCommandSchemas() + hostCommandSchemas() + observationCommandSchemas() + actionCommandSchemas()`。
  - `CLISchemaRuntime.swift` 进一步降到约 13 行，只保留组合调用。

## 验证

- 拆分前新增测试基线：`swift test --package-path CLI --filter SchemaFactSourceTests` 通过，7 个 Swift Testing 用例通过。
- 拆分后 schema 聚焦回归：`swift test --package-path CLI --filter SchemaFactSourceTests` 通过，7 个 Swift Testing 用例通过。
- CLI 全量回归：`swift test --package-path CLI` 通过，78 个 Swift Testing 用例通过。
- 格式检查：`git diff --check -- Sources/TritonKitCLI/CLISchemaRuntime.swift Sources/TritonKitCLI/CLISchemaShared.swift CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift` 通过。
- 文档结构检查：`docs-linhay/scripts/check-docs.sh` 通过。
- bootstrap 拆分后 schema 聚焦回归：`swift test --package-path CLI --filter SchemaFactSourceTests` 通过，7 个 Swift Testing 用例通过。
- bootstrap 拆分后 CLI 全量回归：`swift test --package-path CLI` 通过，78 个 Swift Testing 用例通过。
- Xcode group 拆分后 schema 聚焦回归：`swift test --package-path CLI --filter SchemaFactSourceTests` 通过，7 个 Swift Testing 用例通过。
- 中断恢复后重新跑 CLI 全量回归：`swift test --package-path CLI` 通过，78 个 Swift Testing 用例通过。
- runtime group 拆分后 schema 聚焦回归：`swift test --package-path CLI --filter SchemaFactSourceTests` 通过，7 个 Swift Testing 用例通过。
- runtime group 拆分后 CLI 全量回归：`swift test --package-path CLI` 通过，78 个 Swift Testing 用例通过。
- host group 拆分后 schema 聚焦回归：`swift test --package-path CLI --filter SchemaFactSourceTests` 通过，7 个 Swift Testing 用例通过。
- host group 拆分后 CLI 全量回归：`swift test --package-path CLI` 通过，78 个 Swift Testing 用例通过。
- observation group 拆分后 schema 聚焦回归：`swift test --package-path CLI --filter SchemaFactSourceTests` 通过，7 个 Swift Testing 用例通过。
- observation group 拆分后 CLI 全量回归：`swift test --package-path CLI` 通过，78 个 Swift Testing 用例通过。
- action group 拆分后 schema 聚焦回归：`swift test --package-path CLI --filter SchemaFactSourceTests` 通过，7 个 Swift Testing 用例通过。
- action group 拆分后 CLI 全量回归：`swift test --package-path CLI` 通过，78 个 Swift Testing 用例通过。
- 收尾验证：`git diff --check` 通过；`docs-linhay/scripts/qmd-sync.sh` 完成并成功 embed 40 chunks from 3 documents；`swift test --package-path CLI` 通过，78 个 Swift Testing 用例通过。

## 决策

- schema 拆分必须先锁 command inventory，再移动代码；否则 agent bootstrap surface 变更不易审计。
- 当前迁出共享 helper 和 bootstrap command group，不重排 52 个 command facts。后续再按 domain 拆 `CLISchemaRuntime.swift`，每批都保持 command order 测试绿色。
- 新增 helper 文件命名为 `CLISchemaShared.swift`，只放 schema runtime 的共享事实和渲染/输入 schema helper，不混入 output contract helper；output contract 继续留在 `CLISchemaContracts.swift`。
- Bootstrap group 单独命名为 `CLISchemaBootstrapCommands.swift`，对应方案 C 的自发现入口层：`status` / `doctor` / `capabilities` / `plan` / `schema`。
- Xcode group 单独命名为 `CLISchemaXcodeCommands.swift`，覆盖 host Xcode workflow 与 artifact inspection 层：`xcode` / `xcresult` / `xctrace` / `coverage`。
- Runtime group 单独命名为 `CLISchemaRuntimeCommands.swift`，覆盖 embedded runtime observation / semantic action / ledger 层：`runtime` / `state` / `snapshot` / `focus` / `set-text` / `select-segment` / `set-switch` / `ledger`。
- Host group 单独命名为 `CLISchemaHostCommands.swift`，覆盖 host device / simulator / app 生命周期层：`device` / `sim` / `app`。
- Observation group 单独命名为 `CLISchemaObservationCommands.swift`，覆盖 target discovery、visible surface、WebView、route、hierarchy、artifact、screenshot 层。
- Action group 单独命名为 `CLISchemaActionCommands.swift`，覆盖 tap / swipe / type / paste / clear / press / input 执行面。

## 风险

- 本轮操作仍误用过并行 wrapper 触发 SwiftPM、qmd、check 命令；其中一个 qmd session 因 SQLite primary key constraint 失败，另一个 qmd session 完整成功并完成 embed。后续巡航必须严格单命令串行执行 SwiftPM、qmd、check-docs。
- `CLISchemaRuntime.swift` 已降到约 13 行，只保留组合调用，root 治理目标已完成。
- 后续重点转向最终验收和报告收敛，不再治理 root 大小。

## 下一轮建议

Round 06 已收尾：收尾证据已补齐，下一步转入 Round 07 / 方案 C 的后续切片或下一期 backlog，不再继续治理 root 文件大小。
