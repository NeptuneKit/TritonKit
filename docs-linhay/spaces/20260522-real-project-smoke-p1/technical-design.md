# Real Project Smoke P1 Technical Design

## 设计结论

本轮不继续堆单点 CLI，而是新增一个小的 smoke orchestration layer。底层仍调用现有 domain services：

- `xcode`：发现、构建、运行、占用诊断。
- `sim` / `app`：simulator 与 App host-side 生命周期。
- `runtime`：wait、assert、snapshot、ledger、WebView provider。
- `harmony`：HDC target、Ability、layout、input、screenshot。
- `evidence`：manifest、artifact、summary、redaction。

`smoke ios` 和 `smoke harmony` 只负责顺序、错误边界、artifact 归档和最终 summary。这样可以关闭 #15/#17 的一命令诉求，同时不把 #12/#18 的全部能力塞进一个不可测试的巨型命令。

## 命令面

### Xcode diagnostics

```bash
triton xcode status --json
triton xcode wait-idle --workspace <workspace> --timeout 120 --json
```

`status` 是只读诊断。它先用 `pgrep` 缩小候选 PID，再通过 `ps -p` / process inspection 采样，避免全量 `ps -axo ...` 在进程很多时因为 pipe 未及时读取而卡住：

- `xcodebuild`
- `swift-build`
- `SwiftBuildService`
- `XCBBuildService`
- `xctest`

首期只承诺 best-effort 字段，不能从进程参数可靠解析的字段保持为空或标记 `confidence=low`。

输出草案：

```json
{
  "ok": true,
  "active": true,
  "processes": [
    {
      "pid": 123,
      "name": "xcodebuild",
      "workspace": "App.xcworkspace",
      "scheme": "App",
      "destination": "platform=iOS Simulator,id=<udid>",
      "derivedDataPath": "<path>",
      "elapsedSeconds": 42,
      "confidence": "medium"
    }
  ],
  "summary": {
    "xcodebuildCount": 1,
    "buildServiceCount": 1,
    "matchingWorkspaceCount": 1
  }
}
```

`wait-idle` 每隔短周期采样 `status`，只要 matching workspace/project 没有活动 build/test process 即 pass；timeout 时返回 `xcode_not_idle`。

### Smoke iOS

```bash
triton smoke ios \
  --simulator booted \
  --bundle-id <bundle-id> \
  --open-url <url> \
  --wait-text <text> \
  --assert-text <text> \
  --timeout 20 \
  --screenshot /tmp/case.png \
  --evidence /tmp/case.tritonevidence \
  --json
```

首期只接受显式参数，不先设计复杂 YAML/plan DSL。后续 `.tritonplan` 可以复用同一个 step model。

默认步骤：

1. resolve simulator target。
2. optional `app info` 校验 bundle 是否安装。
3. optional `app launch` 或 `app open-url`。
4. wait runtime target ready。
5. wait texts。
6. assert texts。
7. capture simulator screenshot。
8. write evidence artifacts。
9. emit summary。

### Smoke Harmony

```bash
triton smoke harmony \
  --target <hdc-target> \
  --bundle <bundle-name> \
  --ability <ability-name> \
  --open-url <url> \
  --wait-text <text> \
  --timeout 20 \
  --screenshot /tmp/case.jpeg \
  --evidence /tmp/case.tritonevidence \
  --json
```

默认步骤：

1. resolve HDC target。
2. `device wait-ready`。
3. optional `app inspect`。
4. `app launch` or `aa start -U` equivalent。
5. repeat layout dump until text appears or timeout。
6. capture screenshot，处理 `.jpeg` suffix quirk。
7. write evidence artifacts。
8. emit summary。

### WebView / route assertion

```bash
triton webview current-url --json
triton route assert-current-url <expected-url> --json
```

`current-url` 是 `webview current` 的窄化 alias，方便 issue #18 的高频用例。它只依赖 provider metadata，不做 DOM/JS。

URL 比较首期支持：

- exact match。
- optional `--ignore-query`。
- optional `--contains <fragment>` 后续再加，不进入第一刀。

### Preferences set

```bash
triton app prefs set <key> <json-value> \
  --bundle-id <bundle-id> \
  --simulator booted \
  --json
```

首期只支持 simulator data container 的 `Library/Preferences/<bundle-id>.plist`。约束：

- `<json-value>` 必须是合法 JSON scalar / array / object。
- 写入前读取 previous value。
- 写入后重新读取校验。
- 输出 restart advice，不自动 kill/relaunch，除非调用方显式要求后续 smoke step。

### Evidence summary / redact

```bash
triton evidence summary <dir.tritonevidence> --json
triton evidence redact <dir.tritonevidence> --profile ios-private --output <redacted.tritonevidence> --json
```

首期 summary 默认只输出：

- manifest schema/version。
- command names and statuses。
- platform/tool versions。
- artifact counts and relative paths。
- failure code / failed step。
- redaction status。

默认不输出：

- screenshot binary。
- full logs。
- raw private bundle id / URL / account / local absolute path。

## 数据模型

### SmokeRunSummary

```swift
struct SmokeRunSummary: Codable {
    var schemaVersion: Int
    var status: SmokeStatus
    var platform: SmokePlatform
    var target: SmokeTargetSummary
    var steps: [SmokeStepSummary]
    var assertions: [SmokeAssertionSummary]
    var artifacts: [SmokeArtifactSummary]
    var evidence: SmokeEvidenceSummary?
    var failure: SmokeFailureSummary?
    var redaction: SmokeRedactionSummary
    var startedAt: Date
    var endedAt: Date
    var elapsedMs: Int
}
```

### SmokeStepSummary

```swift
struct SmokeStepSummary: Codable {
    var id: String
    var kind: String
    var status: SmokeStepStatus
    var sourceCommand: [String]
    var target: String?
    var elapsedMs: Int
    var artifacts: [SmokeArtifactSummary]
    var error: TritonErrorEnvelope?
    var nextActions: [String]
}
```

### Failure diagnostics

失败 envelope 复用现有 error contract，但为 wait/find/tap/assert 增加：

```swift
struct TextFailureDiagnostics: Codable {
    var query: String
    var nearestText: [String]
    var candidateCount: Int
    var snapshotArtifact: String?
    var axArtifact: String?
    var suggestedCommands: [String]
}
```

## 服务分层

建议新增文件，避免回到巨型 CLI 文件：

```text
Sources/TritonKitCLI/
  CLISmokeCommands.swift
  CLISmokeModels.swift
  CLISmokeRuntime.swift
  CLIXcodeDiagnosticsModels.swift
  CLIXcodeDiagnosticsRuntime.swift
```

职责：

- `*Commands.swift`：ArgumentParser 参数和 schema glue。
- `*Models.swift`：Codable wire contract。
- `*Runtime.swift`：编排逻辑和 domain service 调用。

已有 service 能复用就复用；如果当前 sim/app/evidence runtime 只有 CLI glue，先抽出最小可复用函数，不把 smoke 逻辑写成 shell-like 字符串拼接。

## 错误码

新增或复用：

| Code | 含义 |
| --- | --- |
| `xcode_not_idle` | 指定 workspace/project 在 timeout 内仍有 build/test 占用 |
| `runtime_not_connected` | iOS smoke 需要 runtime wait/assert，但未发现目标 runtime |
| `smoke_step_failed` | smoke 编排中某一步失败的外层包装 |
| `text_not_found` | wait/assert 未找到目标文本 |
| `webview_provider_unavailable` | 当前 runtime 没有 WebView provider metadata |
| `url_assertion_failed` | 当前 URL 与 expected 不匹配 |
| `invalid_preferences_value` | prefs set 的 JSON value 非法或无法写入 plist |
| `ambiguous_target` | 多 simulator / runtime / HDC target 未显式指定 |
| `artifact_write_failed` | screenshot/evidence/redacted output 写入失败 |

## Evidence 目录

一命令 smoke 写出的 evidence 推荐结构：

```text
case.tritonevidence/
  manifest.json
  summary.json
  run/
    events.jsonl
  artifacts/
    host/
      screenshot.png
      xcode-status.json
    runtime/
      snapshot.json
      ax.json
    harmony/
      layout.json
      screenshot.jpeg
```

路径必须是相对路径。manifest 中记录 artifact sensitivity：

```json
{
  "path": "artifacts/host/screenshot.png",
  "kind": "screenshot",
  "sensitivity": "private",
  "redactionStatus": "excluded-from-summary"
}
```

## 测试策略

### 单元测试

1. `SmokeRunSummary` Codable round-trip。
2. iOS smoke step ordering。
3. host open-url 成功但 runtime wait 失败时 summary 为 fail。
4. Harmony text wait 成功与 timeout。
5. HDC target ambiguous。
6. screenshot `.jpeg` suffix 处理。
7. evidence summary 默认排除敏感 artifact。
8. evidence redact profile path rewrite。
9. prefs set JSON scalar / array / object / invalid JSON。
10. Xcode status parser 解析常见 `xcodebuild` argv。

### CLI schema tests

1. `triton schema --command smoke --json` 暴露 `ios` / `harmony`。
2. `triton schema --command xcode --json` 暴露 `status` / `wait-idle`。
3. `triton schema --command evidence --json` 暴露 `summary` / `redact`。
4. `triton schema --command app --json` 暴露 `prefs set`。

### Mock smoke

1. Fake process runner for Xcode diagnostics。
2. Fake host adapter for iOS sim/app。
3. Fake runtime client for wait/assert/snapshot。
4. Fake HDC runner for Harmony layout/screenshot。
5. Fake filesystem for evidence summary/redact。

### Real local smoke

只在机器安全时执行：

```bash
.build/cli/debug/triton xcode status --json
.build/cli/debug/triton smoke ios ... --json
TRITON_BIN=.build/cli/debug/triton docs-linhay/scripts/verify-harmony-host-smoke.sh
```

真实 smoke 输出不得提交私有 App 证据，只能提交脱敏摘要或 mock fixture。

## 实施顺序

1. 文档与 BDD：本 space。
2. S1：Xcode diagnostics，最小可独立交付。
3. S2：Smoke shared models + `smoke ios` mock tests。
4. S3：Evidence summary/redact。
5. S4：WebView current URL / route assertion / prefs set。
6. S5：`smoke harmony`。
7. S6：failure diagnostics 统一补强。
8. GitHub issue 评论与关闭。

这个顺序让 #18 的最高优先级先落地，再关闭 #17，随后关闭 #15。#12 保持 epic 追踪，除非 P1 后续全部完成。

## 文档同步

实现时同步更新：

- `README.md`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `docs-linhay/spaces/20260520-simulator-takeover/README.md`
- `docs-linhay/spaces/20260520-harmony-emulator-alignment/README.md`
- `docs-linhay/spaces/20260520-xcode-workflow-takeover/README.md`
- `docs-linhay/spaces/20260521-harness-ux-run-evidence/README.md`
- `.agents/tritonkit-skills/public/tritonkit-real-project-regression/SKILL.md`
- `.agents/tritonkit-skills/public/tritonkit-emulator-cli-takeover/SKILL.md`
- `.agents/tritonkit-skills/internal/tritonkit-xcode-workflow-takeover/SKILL.md`
- `docs-linhay/memory/YYYY-MM-DD.md`

只有 smoke / evidence / xcode diagnostics 形成稳定长期规则后，才更新 `AGENTS.md`。
