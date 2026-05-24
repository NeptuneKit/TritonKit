# Xcode Workflow Takeover Technical Design

## 设计立场

XcodeBuildMCP 的能力面值得完整对齐，但 TritonKit 的产品入口必须保持统一：`triton` CLI/HTTP schema 是事实契约，未来 MCP 只能是薄适配层。

首选实现路径：

```text
triton CLI / HTTP / future MCP
  |
  v
Command schema + target resolver + defaults
  |
  +-- XcodeWorkflowService
  |     +-- ProjectDiscoveryAdapter
  |     +-- XcodebuildAdapter
  |     +-- XcresultAdapter
  |     +-- CoverageAdapter
  |     +-- LogsAdapter
  |     +-- SwiftPMAdapter
  |
  +-- Simulator Host Adapter
  |     +-- SimctlAdapter
  |     +-- App lifecycle / container / prefs
  |
  +-- Runtime Service
  |     +-- AX / input / wait / assert / screenshot
  |
  +-- Evidence / Plan Service
        +-- build/test/log/coverage artifacts
        +-- runtime artifacts
        +-- action trace JSONL
```

## Target Graph

新增 target 层级：

```text
workspace:<hash>
xcode:<workspace-or-project-path>
xcode:<workspace>:scheme:<scheme>
xcode:<workspace>:scheme:<scheme>:configuration:<configuration>
spm:<package-path>
xcresult:<path>
coverage:<xcresult-path>
```

绑定关系：

1. `xcode scheme` 可以绑定 `sim:<udid>`。
2. build 产物可以绑定 `sim:<udid>:app:<bundle-id>`。
3. launch 后可以绑定 `runtime:<target-id>`。
4. test result 可以绑定 `xcresult:<path>` 和 evidence artifact。

## Workspace Defaults

`.triton/host-defaults.json` 后续扩展：

```json
{
  "defaultSimulatorUDID": "0333546D-2AC6-4C22-AF01-293E2F4BA5BC",
  "xcode": {
    "workspace": "App.xcworkspace",
    "project": null,
    "scheme": "App",
    "configuration": "Debug",
    "sdk": "iphonesimulator",
    "destination": "platform=iOS Simulator,id=0333546D-2AC6-4C22-AF01-293E2F4BA5BC",
    "derivedDataPath": ".triton/DerivedData"
  }
}
```

解析优先级：

1. 显式 CLI 参数。
2. `.triton/host-defaults.json`。
3. 单一候选自动选择。
4. 多候选返回 `ambiguous_target` / `ambiguous_scheme` / `ambiguous_workspace`。

## Internal Capability Registry

参考 XcodeBuildMCP manifest / tool catalog，但不复用其 YAML 文件格式或工具命名。TritonKit 内部需要一个 Swift-native capability descriptor，作为 CLI、HTTP、future MCP 和 `triton schema --json` 的共同来源。

```swift
struct TKHostCapabilityDescriptor: Codable, Sendable {
    var namespace: String
    var action: String
    var summary: String
    var stability: TKCapabilityStability
    var riskLevel: TKHostRiskLevel
    var requiresDaemon: Bool
    var outputSchema: String
    var progressEvents: [String]
    var artifactKinds: [String]
    var nextActions: [TKNextActionTemplate]
}
```

约束：

1. `xcode` / `xcresult` / `coverage` / `logs` / `spm` / `debug` / `device` 都必须注册 capability。
2. `workflow` 只作为内部分组，不作为用户命令参数。
3. `nextActions` 用于告诉 agent 下一步可以执行 `xcresult failures`、`coverage summary`、`runtime wait/assert` 等命令。
4. public schema 不暴露 XcodeBuildMCP 的 MCP tool name。

## Command Surface

### Discovery

```bash
triton xcode discover --path . --json
triton xcode schemes --workspace App.xcworkspace --json
triton xcode settings --workspace App.xcworkspace --scheme App --json
triton xcode bundle-info --workspace App.xcworkspace --scheme App --json
triton xcode use --workspace App.xcworkspace --scheme App --configuration Debug --simulator <udid> --json
```

### Build / Test / Run

```bash
triton xcode build --jsonl
triton xcode test --result-bundle /tmp/App.xcresult --jsonl
triton xcode run --jsonl
triton xcode clean --json
```

`run` 是复合命令：

1. resolve defaults
2. `xcodebuild build`
3. discover `.app`
4. `triton app install`
5. `triton app launch`
6. optional wait for embedded runtime target

### Result / Coverage

```bash
triton xcresult summary --path /tmp/App.xcresult --json
triton xcresult failures --path /tmp/App.xcresult --json
# P1 follow-up, not currently implemented:
# triton xcresult attachments --path /tmp/App.xcresult --output /tmp/attachments --json
triton coverage report --xcresult /tmp/App.xcresult --output /tmp/coverage.json --json
triton coverage report --xcresult /tmp/App.xcresult --only-targets --output /tmp/coverage-targets.json --json
triton coverage report --xcresult /tmp/App.xcresult --target App --output /tmp/coverage-files.json --json
```

### Instruments Trace

```bash
triton xctrace record --template "Time Profiler" --device <udid> --time-limit 5s --output /tmp/App.trace --json
triton xctrace record --template "Allocations" --output /tmp/tool.trace --time-limit 10s -- /tmp/tool arg1
```

`xctrace record` 默认在未指定 `--attach` 或 launch command 时走 `--all-processes`，并加 `--no-prompt`，避免 agent 运行时被 GUI prompt 阻塞。`.trace` 文件只作为 host evidence artifact；业务成功仍必须通过 runtime wait/assert/screenshot/evidence 证明。

### Logs

```bash
triton logs stream --simulator <udid> --bundle-id <id> --jsonl
triton logs collect --simulator <udid> --bundle-id <id> --output /tmp/logs --json
triton logs build --derived-data .triton/DerivedData --json
```

### SwiftPM

```bash
triton spm discover --package-path . --json
triton spm build --package-path . --jsonl
triton spm test --package-path . --jsonl
triton spm run <executable> --package-path . --jsonl
```

### Debug

```bash
triton debug attach --bundle-id <id> --simulator <udid> --json
triton debug breakpoint set --symbol <symbol> --json
triton debug stack --json
triton debug eval <expression> --json
triton debug detach --json
```

调试命令必须显式 opt-in，不进入默认 `triton plan` smoke 推荐。

## Output Contracts

长任务输出分两层：

1. progress event：JSONL，每行一个 typed domain event。
2. final summary：命令结束时输出稳定 JSON envelope。

raw stdout/stderr 不作为 agent 默认解析契约，只进入 `transcript` event 或 artifact。

### Progress Event

```json
{
  "ok": true,
  "event": "xcodebuild.compile",
  "target": "App",
  "file": "Sources/App/HomeView.swift",
  "elapsedMs": 1203,
  "sourceCommand": "xcodebuild ..."
}
```

建议 P0 事件名：

```text
xcode.invocation
xcode.package-resolve
xcode.compile
xcode.link
xcode.diagnostic
xcode.test-discovery
xcode.test-case
xcode.test-progress
xcode.test-failure
xcode.summary
xcode.run.phase
process.command
process.stdout
process.stderr
process.exit
```

### Build Summary

```json
{
  "ok": true,
  "action": "xcode.build",
  "workspace": "App.xcworkspace",
  "scheme": "App",
  "configuration": "Debug",
  "simulatorUDID": "0333546D-2AC6-4C22-AF01-293E2F4BA5BC",
  "derivedDataPath": ".triton/DerivedData",
  "appPath": ".triton/DerivedData/Build/Products/Debug-iphonesimulator/App.app",
  "bundleID": "com.example.App",
  "durationMs": 42000,
  "warnings": [],
  "errors": []
}
```

### Test Summary

```json
{
  "ok": false,
  "action": "xcode.test",
  "passed": 128,
  "failed": 2,
  "skipped": 0,
  "resultBundlePath": "/tmp/App.xcresult",
  "failures": [
    {
      "test": "LoginTests.testSubmit",
      "message": "Expected Home",
      "file": "LoginTests.swift",
      "line": 42
    }
  ]
}
```

## Artifact Layout

默认 artifact 目录：

```text
.triton/
  host-defaults.json
  DerivedData/
    <project>-<hash>/
  artifacts/
    xcode/
      <timestamp>-build.log
      <timestamp>-test.log
      <timestamp>-result.xcresult
    logs/
      <bundle-id>-console-<timestamp>.log
      <bundle-id>-oslog-<timestamp>.log
```

规则：

1. 默认 DerivedData 必须 workspace-scoped，避免污染全局 DerivedData，也避免不同仓库互相覆盖。
2. 用户显式指定 `--derived-data-path`、`--result-bundle`、`--output` 时以显式路径为准。
3. `.app` path 优先从 `xcodebuild -showBuildSettings` 的 `BUILT_PRODUCTS_DIR + FULL_PRODUCT_NAME` 解析，不手猜 `Build/Products`。
4. bundle id 通过 Info.plist 读取，失败时返回 `bundle_id_unresolved`。
5. build/test/log/coverage artifact 后续必须能进入 `.tritonevidence`。

## Parser Strategy

`xcodebuild` 输出不稳定，P0 parser 采用 best-effort 策略：

1. stdout/stderr streaming parser 只提取 progress、warning、error、test case、test summary 和 xcresult path。
2. final test counts 首选 `xcrun xcresulttool get test-results summary --path <xcresult>`。
3. test failures 首选 `xcrun xcresulttool get test-results tests --path <xcresult>`。
4. coverage 首选 `xcrun xccov view --report --json <xcresult>` 与 `--functions-for-file`。
5. 解析失败时保留 raw log artifact，并返回 diagnostics，不吞掉原始错误。

## Error Codes

P0 错误码至少包括：

```text
xcode_not_available
xcodebuild_failed
xcresulttool_failed
invalid_workspace_path
invalid_project_path
ambiguous_workspace
ambiguous_scheme
scheme_not_found
simulator_not_found
app_path_unresolved
bundle_id_unresolved
result_bundle_not_found
```

P1 扩展：

```text
xccov_failed
coverage_not_available
log_stream_failed
daemon_required
```

## Integration Rules

1. Use `xcodebuild -json` only when it is stable enough for the requested output; otherwise parse with structured xcresult/log tools and keep raw log as artifact.
2. Long commands use JSONL progress and final summary.
3. Store build/test/log artifacts under explicit output paths or `.triton/` workspace state; do not scatter temp files in repo root.
4. `xcode run` must not claim business readiness after launch; it should recommend runtime `status/wait/assert`.
5. Any signing/provisioning command is read-only in early phases; automatic mutation of developer accounts is out of scope.
6. Optional XcodeBuildMCP bridge, if added, must be internal and wrapped by Triton error/output contracts.

## Harness Build Lessons

Harness 的 `XcodeBuilder` 对 TritonKit 有两个直接可用的经验：

1. 不要默认用 `CODE_SIGNING_ALLOWED=NO` 逃避 simulator 签名问题；这样可能导致 entitlements 不应用，业务 App 的 Keychain / App Group 等能力在 simulator 下表现失真。
2. 可评估 ad-hoc signing 作为 simulator build/run 默认策略：

```text
CODE_SIGN_IDENTITY=-
CODE_SIGNING_REQUIRED=YES
CODE_SIGNING_ALLOWED=YES
CODE_SIGN_STYLE=Manual
DEVELOPMENT_TEAM=
ONLY_ACTIVE_ARCH=YES
```

该策略仍需在真实业务项目上验证，尤其是多个 target、extension、test host、capabilities 组合；如果失败，错误必须稳定映射到 signing/provisioning diagnostics，而不是自动修改开发者账号资产。

## Not Imported

- XcodeBuildMCP MCP tool names as public API.
- Xcode IDE Bridge as first-class dependency.
- Workflow enable/disable config as product control plane.
- Node runtime as required TritonKit dependency.
- UI automation that conflicts with embedded runtime semantics.

## P0 Implementation Tasks

2026-05-21 已完成 P0 最小执行面：

1. Shared models:
   - `TKXcodeWorkspaceDefaults`
   - `TKXcodeDiscoveryResult`
   - `TKXcodebuildCommand`
   - `TKXcodeSchemeList`
   - `TKXcodeBuiltAppProduct`
   - `TKXcodeActionSummary`
   - `TKXcodeProgressEvent`
2. Pure parsers:
   - project/workspace/package discovery
   - `xcodebuild -list -json` scheme parser
   - `xcodebuild -showBuildSettings -json` app product parser
3. CLI:
   - `triton xcode discover`
   - `triton xcode use`
   - `triton xcode schemes`
   - `triton xcode settings`
   - `triton xcode build --jsonl`
   - `triton xcode test --jsonl --result-bundle`
   - `triton xcode run --jsonl`

仍未完成：

1. coverage summary/uncovered
2. logs stream/collect
3. `capture/evidence --include xcode,host`
4. 真正 streaming 的 xcodebuild stdout/stderr 细粒度 progress parser

1. Shared models:
   - `TKXcodeDiscoveryResult`
   - `TKXcodeDefaults`
   - `TKXcodeBuildProgressEvent`
   - `TKXcodeBuildSummary`
   - `TKXcodeTestSummary`
   - `TKXcresultFailure`
2. Pure parsers:
   - project/workspace/package discovery
   - `xcodebuild -list`
   - `xcodebuild -showBuildSettings`
   - xcodebuild line parser
   - xcresult summary/failure JSON parser
3. CLI:
   - `triton xcode discover`
   - `triton xcode use`
   - `triton xcode schemes`
   - `triton xcode settings`
   - `triton xcode build --jsonl`
   - `triton xcode test --jsonl`
   - `triton xcode run --jsonl`
   - `triton xcresult summary/failures`
4. Integration:
   - `xcode run` 复用现有 `triton sim/app` host adapter。
   - `xcode test` final summary 内联 top failures，并保留 `.xcresult` artifact。
   - `capture/evidence` 支持 include xcode artifact。

## Test Strategy

1. Unit tests:
   - project discovery fixture parsing;
   - `xcodebuild` argv generation;
   - JSONL event parsing;
   - xcresult summary fixture;
   - coverage fixture;
   - ambiguous workspace/scheme handling.
2. CLI tests:
   - schema exposes xcode/xcresult/coverage/logs commands;
   - validation errors are stable JSON.
3. Smoke tests:
   - small SwiftPM package build/test;
   - sample iOS app build/run on dedicated simulator;
   - failing test fixture produces stable `xcresult failures`.
4. Evidence tests:
   - `capture --include xcode,host,runtime` writes manifest artifacts.
