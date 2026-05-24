# Harness UX Run Evidence Technical Design

## 设计立场

该 space 不负责 simulator lifecycle、Xcode build/test 或 embedded runtime 本身；它负责把一次“真实用户式尝试”的过程沉淀为稳定、可回放、可审计、可贴 issue 的 evidence。

核心原则：

1. filesystem portable first：结果是一个可复制的目录，不依赖数据库。
2. CLI/HTTP first：外部 agent 可以写入和读取，不要求 GUI。
3. append-only first：run log 是事件流，不重写历史。
4. clean evidence first：主截图是真实用户画面，agent overlay 只能做 debug artifact。
5. redaction first：凭证值不进入 prompt、plan、JSONL、manifest。

## 数据结构

### Run Directory

```text
<case>.tritonevidence/
  manifest.json
  run/
    events.jsonl
    meta.json
    step-001.png
    step-002.png
    debug/
      step-001-marked.png
  artifacts/
    host/
    runtime/
    xcode/
```

### Common Event Envelope

```json
{
  "schemaVersion": 1,
  "runId": "9AEF3F9F-4B0E-4B93-B16E-A78F4CBB4C0E",
  "ts": "2026-05-21T10:12:13.000Z",
  "kind": "tool_call"
}
```

规则：

1. 每行必须是完整 JSON object。
2. 必须以 `\n` 结尾。
3. parser 遇到最后一行 partial JSON 时截断，不报错。
4. parser 遇到未知 `kind` 时保留 raw 或跳过并记录 warning，不中断。

### `run_started`

```json
{
  "schemaVersion": 1,
  "runId": "...",
  "ts": "...",
  "kind": "run_started",
  "caseName": "login-smoke",
  "goal": "完成登录并进入首页",
  "persona": "第一次使用的普通用户",
  "mode": "external-agent",
  "target": {
    "platform": "ios-simulator",
    "simulatorUDID": "...",
    "bundleID": "cn.example.app",
    "runtimeTargetID": "..."
  },
  "budgets": {
    "steps": 40,
    "timeoutSeconds": 300
  },
  "credential": {
    "label": "dev-account",
    "username": "test@example.com"
  }
}
```

`credential` 只允许 public-safe identity，不允许 password/token。

### `step_started`

```json
{
  "schemaVersion": 1,
  "runId": "...",
  "ts": "...",
  "kind": "step_started",
  "step": 1,
  "screenshot": "step-001.png",
  "debugScreenshot": "debug/step-001-marked.png",
  "source": "runtime.screenshot"
}
```

`screenshot` 是 clean screenshot。`debugScreenshot` 可选，只用于 agent overlay / target marks。

### `tool_call`

```json
{
  "schemaVersion": 1,
  "runId": "...",
  "ts": "...",
  "kind": "tool_call",
  "step": 1,
  "tool": "tap",
  "scope": "runtime",
  "observation": "我看到登录页，有手机号和密码输入框。",
  "intent": "我要先填写账号，才能进入首页。",
  "input": {
    "text": "登录"
  }
}
```

`observation` / `intent` 对外部 agent 可选，但对 `triton run` 内置 agent 模式必须必填。

### `tool_result`

```json
{
  "schemaVersion": 1,
  "runId": "...",
  "ts": "...",
  "kind": "tool_result",
  "step": 1,
  "tool": "tap",
  "scope": "runtime",
  "success": true,
  "durationMs": 42,
  "error": null,
  "artifacts": []
}
```

### `friction`

```json
{
  "schemaVersion": 1,
  "runId": "...",
  "ts": "...",
  "kind": "friction",
  "step": 3,
  "frictionKind": "ambiguous_label",
  "detail": "按钮只写了 Go，我不知道它会提交还是跳转。",
  "source": "agent"
}
```

`frictionKind` 取值：

```text
dead_end
ambiguous_label
unresponsive
confusing_copy
unexpected_state
auth_required
agent_blocked
```

### `step_completed`

```json
{
  "schemaVersion": 1,
  "runId": "...",
  "ts": "...",
  "kind": "step_completed",
  "step": 1,
  "durationMs": 812,
  "status": "completed"
}
```

### `run_completed`

```json
{
  "schemaVersion": 1,
  "runId": "...",
  "ts": "...",
  "kind": "run_completed",
  "verdict": "success",
  "summary": "登录成功并进入首页。",
  "frictionCount": 1,
  "wouldRealUserSucceed": true,
  "stepCount": 8
}
```

`verdict` 取值：

```text
success
failure
blocked
```

## Shared Models

建议新增模型：

```swift
public struct TKEvidenceRunEvent: Codable, Sendable {
    public var schemaVersion: Int
    public var runId: String
    public var timestamp: String
    public var kind: TKEvidenceRunEventKind
}

public enum TKEvidenceRunEventKind: String, Codable, Sendable {
    case runStarted = "run_started"
    case stepStarted = "step_started"
    case toolCall = "tool_call"
    case toolResult = "tool_result"
    case friction
    case stepCompleted = "step_completed"
    case runCompleted = "run_completed"
}

public enum TKEvidenceFrictionKind: String, Codable, Sendable {
    case deadEnd = "dead_end"
    case ambiguousLabel = "ambiguous_label"
    case unresponsive
    case confusingCopy = "confusing_copy"
    case unexpectedState = "unexpected_state"
    case authRequired = "auth_required"
    case agentBlocked = "agent_blocked"
}
```

实现时不要强行用一个巨型 enum 承载所有 payload；可以用 tagged envelope + per-kind payload，保证 forward compatibility。

### 2026-05-24 implementation checkpoint

已落地首期 Shared-only 模型与 parser：

1. `Sources/TritonKitShared/TKEvidenceRunModels.swift` 新增 `TKEvidenceRunEvent`、`TKEvidenceRunEventKind`、`TKEvidenceFrictionKind`、`TKEvidenceRunVerdict`、`TKEvidenceRunMetadata` 与 parse result / warning / summary 类型。
2. `TKEvidenceRunEventKind` 使用 raw-value wrapper，而不是封闭 enum；已知 kind 有静态常量，未知 kind 可以保留 raw value 并由 parser 产生 `unknown_kind` warning。
3. `TKEvidenceRunLogParser` 已支持逐行解析、最后一行 partial JSON 截断容忍、中间坏行 `malformedEvent`、`run_started` 首行校验、unsupported schemaVersion 稳定错误、缺少 `run_completed` 时返回 `incomplete`。
4. `TKEvidenceRunCredential` 只建模 `label` / `username`，不提供 password / token / secret 字段。

本 checkpoint 暂不包含 writer、CLI / HTTP 写入口、`capture` / `replay` 集成或 manifest run artifact 引用。

## Writer / Parser

### Writer

`TKEvidenceRunLogWriter`：

1. 初始化时创建 `run/` 目录和 `events.jsonl`。
2. 写 screenshot 使用 atomic file write。
3. 写 event 使用 append。
4. 每行写完后 flush。
5. 不允许 `run_completed` 后继续 append。

### Parser

`TKEvidenceRunLogParser`：

1. 逐行解析。
2. 最后一行解析失败时视为 partial tail。
3. 中间行解析失败时返回 `malformed_event`。
4. 校验 `run_started` 是否第一行。
5. 若缺少 `run_completed`，run 状态为 `incomplete`，不是 parser failure。
6. unknown kind 保留 raw event 或 warning。

## CLI / HTTP Surface

首期不一定要暴露所有底层 writer 命令，但需要给外部 agent 一个写入口。

候选 CLI：

```bash
triton evidence run start --case login --goal "完成登录" --persona "首次用户" --output login.tritonevidence --json
triton evidence run step --screenshot step-001.png --observation "..." --intent "..." --json
triton evidence run tool-result --step 1 --tool tap --success true --json
triton evidence run friction --step 3 --kind ambiguous_label --detail "..." --json
triton evidence run complete --verdict success --summary "..." --json
```

候选 HTTP：

```text
POST /v1/evidence/runs
POST /v1/evidence/runs/{runId}/events
POST /v1/evidence/runs/{runId}/complete
GET  /v1/evidence/runs/{runId}
```

实际实现可以先走内部 API，让 `capture` / `replay` 写入，再评估 CLI 写入口。

## 与现有能力关系

### `.tritonplan`

`.tritonplan` 是可复跑计划；UX run 是一次执行记录。

关系：

```text
.tritonplan replay -> events.jsonl
```

plan step 对应 `tool_call`，执行结果对应 `tool_result`。外部 agent 可补 observation / intent / friction。

### `.tritonevidence`

`.tritonevidence` 是证据包；UX run 是证据包内的一类 artifact。

关系：

```text
manifest.json
  -> artifacts[]
  -> run.eventsPath
  -> run.metaPath
```

### Runtime / Host / Xcode

`tool_call.scope` 用于区分动作来源：

```text
runtime
host-simulator
host-ui
xcode
spm
device
harmony
```

这避免把 host UI tap、runtime tap、xcode build 都混成同一种动作。

## 安全与脱敏

1. `tool_call.input` 不允许包含 password、token、secret。
2. credential 只记录 label / username。
3. screenshot 可能包含敏感信息；manifest 必须支持 `redactionStatus`。
4. 若生成 marked screenshot，主 evidence 默认不引用 marked 版本。
5. issue summary 默认不展开 full JSONL，只摘要 friction、verdict、关键截图路径。

## 测试策略

1. model round-trip：
   - run_started / step / friction / run_completed 全字段编码解码。
2. writer：
   - append-only 顺序。
   - run_completed 后禁止 append。
   - screenshot 先于 event。
3. parser：
   - partial tail tolerant。
   - missing run_completed -> incomplete。
   - unknown kind forward compatible。
   - schemaVersion unsupported 返回稳定错误。
4. redaction：
   - password 不进入 events JSON。
   - credential 只包含 label / username。
5. evidence manifest：
   - run events path、meta path、screenshot artifact 可解析。

## 不进入首期的技术

1. 内置 LLM provider client。
2. prompt caching。
3. GUI replay view。
4. SwiftData history。
5. WDA runner。
6. Web WKWebView driving。
7. Human approval UI。

## P0 DoD

1. `TKEvidenceRunEvent` / friction models 可编解码。
2. writer/parser 测试覆盖 partial tail。
3. `.tritonevidence` manifest 能引用 `run/events.jsonl`。
4. `capture` 或 `replay` 至少一个入口能写基础 run events。
5. docs 和 skill 明确 Harness 是 UX evidence 参考，不是 GUI 产品模板。

2026-05-24 状态：

1. 已完成：`TKEvidenceRunEvent` / friction models 可编解码。
2. 已部分完成：parser 覆盖 partial tail、unknown kind、middle malformed line、`run_started` 首行约束和 credential public identity；writer 尚未实现。
3. 未完成：manifest run artifact 引用、`capture` / `replay` 写入入口、CLI / HTTP 写入口。
