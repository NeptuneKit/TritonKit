# Round 05: Error Envelope Consistency

## 目标

系统核对 JSON 失败输出与 schema `failureCodes` 的一致性。本轮第一刀只处理 runtime HTTP error envelope：当 runtime / server 已经返回 `TKCLIErrorResponse` 时，CLI 必须原样透传，不再包装成新的 `request_failed`。

## 本轮完成

- 扩展 `FailureDiagnosticsTests`：
  - 锁定 runtime HTTP 返回的 `runtime_ui_interrupted` envelope 经过 CLI helper 后仍保持原 code/message/endpoint/hint。
  - 锁定 runtime-facing schema 必须暴露真实 runtime envelope code：`runtime_ui_interrupted`、`request_timeout`、`invalid_payload`。
  - 锁定 semantic action schema 额外暴露 `action_not_supported`、`unsupported_runtime_scope`。
- 更新 `CLIRuntimeTransport.swift`：
  - 新增 `cliErrorResponse(for:endpoint:host:port:)`，集中处理 error-to-envelope 映射。
  - `printCLIError` 与 `failCommand` JSON 分支统一使用该 helper。
  - `CLIHTTPError.response` 存在时直接返回该 response，避免二次包装。
- 更新 `CLISchemaRuntime.swift`：
  - 将 runtime-facing failure code 集合补齐为 server / target / request / runtime / timeout / payload / validation 组合。
  - 将 semantic action failure code 集合补齐 action unsupported 与 unsupported runtime scope。
  - `runtime`、`state`、`snapshot`、`geometry`、`hit`、`ledger` 和 semantic action 命令共享更接近真实 runtime envelope 的 failure code 描述。
- 第二批覆盖 host-side `failHostCommand`：
  - 新增集合级测试，要求 `device` / `sim` / `app` / `xcode` / `xcresult` / `xctrace` / `coverage` / `observe` / `webview` / `route` / `screenshot` / `smoke` schema 的 `failureCodes` 并集覆盖 `failHostCommand` 可能输出的 host error code。
  - 补齐 `sim` schema 的 status bar、privacy、location、UI、pasteboard、push、pair/unpair/clone/erase/upgrade、record/logs/diagnose/logverbose 等实际失败码。
  - 补齐 `app` schema 的 `plist_not_found`。
  - 补齐 `observe` schema 的 Harmony layout path/text/layout/artifact recv 失败码。
- 第三批覆盖 command-local validation / workflow 专用失败码：
  - 新增 `FailureDiagnosticsTests.commandLocalValidationAndWorkflowSchemasCoverSpecializedFailureCodes`，锁定 `webview`、`route`、`smoke`、`sim`、`app`、输入动作命令和 evidence/replay/record/assert 的 schema failure code。
  - 补齐 `route` schema 的 server / target / request 透传失败码，避免 route 断言失败以外的 provider/request 失败被 schema 漏掉。
  - 补齐 `smoke` schema 的 `runtime_not_connected`、`smoke_step_failed`、`app_info_not_available`。
  - 补齐 `sim` schema 的 command-local validation code：`confirmation_required`、`invalid_duration`、`invalid_location_value`、`runtime_delete_selector_required`、`runtime_dyld_cache_selector_required`、`runtime_match_selector_required`。
  - 补齐 `app` schema 的 `destructive_action_requires_policy`。
  - 为 `swipe`、`type`、`paste`、`clear`、`press` 补齐输入动作命令的 `failureCodes` 与 failure shape。
- 第四批覆盖 `triton schema --command` 入口自身：
  - 新增 `SchemaFactSourceTests.schemaCommandFilteringAndUnknownCommandDiagnosticsAreMachineReadable`，锁定单命令过滤和未知命令诊断。
  - 从 `Schema.run()` 中抽出 `buildSchemaResponse(command:)`，让 schema response 构建逻辑可被测试直接覆盖。
  - 新增 `SchemaCommandLookupError` 与 `schemaUnknownCommandErrorResponse(_:)`，未知命令在 JSON 模式下输出单个 `{ ok:false, error:{ code:"unknown_command_schema", ... nextAction } }` envelope。
  - 保持 `triton schema --command tap --json` 输出仍是 `TKCLISchemaResponse`，只包含一个 `tap` command。

## 验证

- 红灯：`swift test --package-path CLI --filter FailureDiagnosticsTests` 编译失败，确认缺少 `cliErrorResponse` helper。
- 第二次红灯：`swift test --package-path CLI --filter FailureDiagnosticsTests` 失败，确认 `state` / `snapshot` schema 缺少 preserved runtime envelope code。
- 绿灯：`swift test --package-path CLI --filter FailureDiagnosticsTests` 通过，4 个用例通过。
- schema 回归：`swift test --package-path CLI --filter SchemaFactSourceTests` 通过，5 个用例通过。
- CLI 回归：`swift test --package-path CLI` 通过，74 个 Swift Testing 用例通过。
- 第二批红灯：`swift test --package-path CLI --filter FailureDiagnosticsTests` 失败，确认 schema 缺少 20 个 host-side error code。
- 第二批绿灯：`swift test --package-path CLI --filter FailureDiagnosticsTests` 通过，5 个用例通过。
- 第二批 schema 回归：`swift test --package-path CLI --filter SchemaFactSourceTests` 通过，5 个用例通过。
- 第二批 CLI 回归：`swift test --package-path CLI` 通过，75 个 Swift Testing 用例通过。
- 第三批红灯：`swift test --package-path CLI --filter FailureDiagnosticsTests` 失败，确认 schema 缺少 route、smoke、sim、app 和输入动作命令的 command-local failure code。
- 第三批绿灯：`swift test --package-path CLI --filter FailureDiagnosticsTests` 通过，6 个用例通过。
- 第三批 schema 回归：`swift test --package-path CLI --filter SchemaFactSourceTests` 通过，5 个用例通过。
- 第三批 CLI 回归：`swift test --package-path CLI` 通过，76 个 Swift Testing 用例通过。
- 第四批红灯：`swift test --package-path CLI --filter SchemaFactSourceTests` 编译失败，确认缺少 `buildSchemaResponse`、`SchemaCommandLookupError`、`schemaUnknownCommandErrorResponse`。
- 第四批绿灯：`swift test --package-path CLI --filter SchemaFactSourceTests` 通过，6 个用例通过。
- 第四批 CLI 回归：`swift test --package-path CLI` 通过，77 个 Swift Testing 用例通过。
- 第四批真实 CLI 验证：`swift run --package-path CLI triton schema --command not-a-command --json` 返回 exit 1，并输出单个 JSON `unknown_command_schema` envelope。

## 决策

- 真实 runtime/server 已经返回 `TKCLIErrorResponse` 时，CLI JSON 输出必须保留原 envelope，而不是把机器错误码折叠成 `request_failed`。
- schema `failureCodes` 不只列 CLI 自己制造的错误码，也要列 runtime/server 可能透传到 agent 的错误码，否则 agent 不能从 schema 规划恢复动作。
- Host-side schema 的 `failureCodes` 至少要覆盖 `failHostCommand` 可能输出的 code；具体 code 可以落在最相关的 domain schema 上，不要求每个 code 出现在所有 host schema。
- Command-local validation 与 workflow summary 中出现的专用 code 也必须进入对应 command schema；agent 不能只从 runtime/server failure code 推断恢复动作。
- 输入动作命令 `tap` / `swipe` / `type` / `paste` / `clear` / `press` 属于同一类 agent action surface，至少共享 validation、unsupported capability、server、target、request failure code 基线。
- `schema` 自身也是 agent bootstrap command；未知 command 不能落到 ArgumentParser / RuntimeError 文本输出，JSON 模式必须返回机器可读 error envelope 和下一步恢复命令。

## 风险

- 当前只通过 helper 级测试验证 envelope preserve，没有启动真实 server 造 HTTP 504 runtime response；后续可加 httptest/handler 级验证。
- WebView selection、smoke step failure 和 command-local validation failure 已纳入 schema 测试；后续还可继续做“源码 error code 自动抽取 vs schema”审计，降低人工硬编码遗漏。
- 本轮执行中误触发过并发 SwiftPM / 文档记录 命令；最终相关命令均完成并通过，但后续必须严格避免并发 SwiftPM 和 文档记录。第四批也出现过 SwiftPM 等待另一个实例的提示，后续必须单命令串行调用。

## 下一轮建议

继续 Round 06：开始拆解巨型 `CLISchemaRuntime.swift`，优先把 schema contracts、错误码集合和 command facts 分组迁出，保持 `triton schema --json` 输出不变。
