# Round 13 Observe / WebView / Route Boundaries

## 目标

把 `observe` / `webview` / `route` 层纳入方案 C 的 agent-facing 信息架构，重点解决 schema 已暴露 WebView / route 能力，但 `triton capabilities --json` 不能同名发现的问题。

## 完成结果

- `triton capabilities --json` 新增 WebView / route 细粒度能力：
  - `webview-list`
  - `webview-current`
  - `webview-current-url`
  - `webview-snapshot`
  - `webview-bridge-call`
  - `webview-events`
  - `webview-wait`
  - `route-current-url-assert`
- 能力矩阵将 `webview-list/current` 定义为候选发现能力，证据为 `webview-candidates`、`host-layout`、`runtime-ax`。
- 能力矩阵将 `webview-current-url/snapshot/bridge-call/events/wait` 和 `route-current-url-assert` 定义为 provider 级能力，runtime 未连接时给出 `status --json` 或 `serve` 恢复动作。
- `route-current-url-assert` 独立归入 `route` group，避免 agent 把 WebView URL 断言混同为 native route 或 AX/layout 文本匹配。
- `SchemaFactSourceTests` 新增断言，确保 `schema.providedCapabilities` 暴露的 WebView / route 能力都能在 capabilities matrix 中找到。

## 改动文件

- `Sources/TritonKitCLI/CLIRuntimeTransport.swift`
- `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`
- `README.md`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `.agents/tritonkit-skills/public/tritonkit-dev-feedback/SKILL.md`
- `.agents/tritonkit-skills/public/tritonkit-real-project-regression/SKILL.md`
- `.agents/tritonkit-skills/public/tritonkit-emulator-cli-takeover/SKILL.md`

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests` 通过，11 个 Swift Testing 用例通过。
- `swift test --package-path CLI` 通过，82 个 Swift Testing 用例通过。

## 剩余风险

- `doctor` 当前仍只做 server、target、runtime、action surface 和 plan readiness 的粗粒度排序；是否需要新增 WebView provider 诊断项，留给后续真实 hybrid smoke 场景决定。
- capabilities 只能表达命令面与环境前置条件，不能证明具体页面已经注册 provider；真实执行仍必须以 `webview current-url/snapshot/call/events/wait` 的结果和 evidence 为准。

## 下一步

Round 14 进入 `assert` / `evidence` / `replay` 闭环，重点检查失败后的 evidence 指向、assert 输出与 replay dry-run 是否足够让 agent 自恢复。
