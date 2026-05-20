# ai-phone Device Cloud Technical Design

## 设计目标

本设计把 ai-phone 的可取部分收敛成 TritonKit 可渐进实现的技术方向：

1. `triton` 仍是 AI agent 看到的稳定入口。
2. host/runtime/device action 都能进入统一 command ledger。
3. target 模型从本机单设备扩展到可承载远端 host agent。
4. batch case、device readiness、lock、安全检测和终态事件都有机器可读契约。
5. 不引入 ai-phone 的技术栈依赖，不复制 GPLv3 代码。

## 目标架构

```text
External AI agent / CI
  |
  | CLI / HTTP JSON
  v
Triton control plane
  - target registry
  - command dispatcher
  - command ledger writer
  - evidence writer
  - case / batch parser
  - assertion runner
  |
  +-- local host agent
  |     - xcrun simctl
  |     - xcodebuild
  |     - hdc / DevEco
  |
  +-- remote host agent
        - simulator / emulator / physical device adapters
        - runtime bridge
        - artifact upload
```

首期 `control plane` 和 `local host agent` 可以是同一个 `triton serve` 进程，但 DTO 要保留远端字段。

## 核心模型

### TargetDescriptor

```json
{
  "targetId": "sim:0333546D-2AC6-4C22-AF01-293E2F4BA5BC",
  "platform": "ios",
  "kind": "simulator",
  "hostId": "local",
  "agentId": "local",
  "transport": "xcrun-simctl",
  "state": "Booted",
  "readiness": "ready",
  "isDefault": true,
  "capabilities": ["screenshot", "app.install", "app.openUrl"],
  "locks": [],
  "lastSeenAt": "2026-05-21T00:00:00+08:00"
}
```

`readiness` 建议取值：

| 值 | 含义 |
| --- | --- |
| `unknown` | 未探测 |
| `not_ready` | 在线但不可执行动作 |
| `booting` | 正在启动 |
| `ready` | 可执行自动化 |
| `interrupted` | 系统弹窗、锁屏、信任弹窗等阻断 |
| `offline` | 不在线 |

### DeviceLock

```json
{
  "lockId": "lock_123",
  "targetId": "sim:...",
  "kind": "session",
  "owner": "replay:login_001",
  "createdAt": "2026-05-21T00:00:00+08:00",
  "expiresAt": "2026-05-21T00:10:00+08:00"
}
```

首期本地 lock 可只在进程内或 evidence 中表达；远端 agent 阶段再引入跨进程 lease。

### CommandLedgerEvent

```json
{
  "schemaVersion": 1,
  "event": "command_result",
  "messageId": "cmd_01HW...",
  "runId": "run_01HW...",
  "targetId": "sim:...",
  "agentId": "local",
  "method": "app.openUrl",
  "paramsSummary": {
    "bundleId": "cn.dxy.iDxyer",
    "urlScheme": "dxy-dxyer"
  },
  "sourceCommand": {
    "tool": "xcrun",
    "args": ["simctl", "openurl", "<udid>", "<redacted-url>"]
  },
  "startedAt": "2026-05-21T00:00:00+08:00",
  "finishedAt": "2026-05-21T00:00:01+08:00",
  "elapsedMs": 1024,
  "ok": true,
  "error": null,
  "artifacts": [],
  "nextAction": "verify_with_wait_or_assert"
}
```

脱敏规则：

1. URL query、token、password、authorization、cookie 默认摘要化。
2. 文件路径保留 basename 和 artifact id，敏感绝对路径可降级为 hash。
3. `sourceCommand` 只记录可复现的安全摘要，不强制保存完整 argv。

### TritonCase

```json
{
  "schemaVersion": 1,
  "caseId": "login_001",
  "title": "手机号密码登录后首页右上角显示用户头像",
  "preconditions": [
    "关闭 App 后重新打开",
    "使用 dev 环境",
    "mock 关闭"
  ],
  "steps": [
    "从启动页点击「登录」入口",
    "在「手机号」输入框输入 13800138000",
    "在「密码」输入框输入 ${LOGIN_PASSWORD}",
    "点击「登录」按钮"
  ],
  "expectedResult": "首页右上角显示用户头像"
}
```

### TritonBatch

```json
{
  "schemaVersion": 1,
  "submissionName": "smoke-2026-05-21",
  "retryMax": 1,
  "items": [
    {
      "caseId": "login_001",
      "platforms": ["ios"],
      "deviceAliasPools": {"ios": ["iPhone-1"]},
      "case": {"$ref": "./cases/login_001.tritoncase"}
    }
  ]
}
```

## CLI / HTTP 候选入口

## CLI Admission Decision

### 判断标准

能力进入 CLI 必须至少满足一个条件：

1. AI agent 在一次回归中需要直接调用它。
2. 输出需要稳定 JSON/JSONL，供上层自动决策。
3. 动作或结果需要进入 `.tritonevidence`。
4. 无 Web、无后台大盘时仍要能复跑。
5. 它能替代裸 `xcrun`、`hdc`、`adb`、`plutil` 等不稳定人读命令。

如果能力主要依赖常驻调度器、数据库、多人权限、运维展示或重型消息队列，它不进入 CLI 首期，只放 HTTP/serve 后台或后续平台化。

### CLI-first 命令面

```text
triton schema --json
triton doctor --json
triton capabilities --json
triton plan --json

triton device list/use/wait-ready/lock/unlock --json
triton device pool list/resolve --json

triton sim list/use/boot/shutdown/screenshot --json

triton app list/info/install/uninstall/launch/terminate/open-url/container/prefs --json

triton ax/find/tap/swipe/type/paste/clear/press/wait/assert --json
triton screenshot --json

triton evidence --output <dir.tritonevidence> --json
triton evidence inspect <dir.tritonevidence> --json
triton evidence commands <dir.tritonevidence> --jsonl
triton capture --case <case> --output <dir.tritonevidence> --json

triton case lint <file.tritoncase> --json
triton run submit --file <file.tritonbatch> --output <dir> --json
triton run status <submission-id> --json
triton run cancel <submission-id> --json

triton record --output <file.tritonplan> --json
triton plan inspect <file.tritonplan> --json
triton replay <file.tritonplan> --output <dir.tritonevidence> --json

triton agent connect --server <url> --token-env <env> --json
triton agent status --json
triton agent disconnect --json
```

其中 `device pool list/resolve` 是只读 CLI；全局池写入不进入 agent 默认 CLI。

### HTTP / serve-only

```text
GET  /api/agents
POST /api/agents/heartbeat
POST /api/agents/capabilities
POST /api/commands/dispatch
POST /api/commands/result
POST /api/artifacts/upload
POST /api/runs/submissions
GET  /api/runs/submissions/{id}
POST /api/runs/submissions/{id}/cancel
GET  /api/runs/{id}/commands
```

这些 API 需要 serve 维护状态、路由和超时；CLI 只作为人/agent 的前端入口，不重复实现后台控制面。

### Explicitly Not CLI

| 能力 | 处理 |
| --- | --- |
| 数据库 migration | 部署脚本 / 文档 |
| Kafka 生产消费 | serve 后台配置 |
| 运维大盘 | Web 只读 |
| 多租户权限 | serve admin |
| 全局设备池写入 | admin API / 配置文件 |
| 内置 VLM loop | 暂不做 |
| V2/V3 轨迹自动重定位 | 后续研究 |
| 系统安全绕过 | 不承诺 |

### P0 Ledger

```bash
triton evidence inspect out.tritonevidence --json
triton capture --case login --output out.tritonevidence --json
triton replay plan.tritonplan --output out.tritonevidence --json
```

内部变化：host/runtime action 自动写 command ledger。

### P1 Device Registry

```bash
triton device list --json
triton device list --platform ios --json
triton device wait-ready --target sim:<udid> --jsonl
triton device lock --target sim:<udid> --owner replay:login --ttl 600 --json
triton device unlock --lock-id <lock> --json
```

### P2 Case / Batch

```bash
triton case lint login.tritoncase --json
triton run submit --file smoke.tritonbatch --output smoke.tritonbatchrun --json
triton run status <submission-id> --json
```

### P3 Remote Agent

```bash
triton agent connect --server http://127.0.0.1:19421 --token-env TRITON_AGENT_TOKEN --json
triton agent list --json
triton agent disconnect <agent-id> --json
```

HTTP 可与 CLI 同 schema：

```text
GET  /api/devices
POST /api/runs/submissions
GET  /api/runs/submissions/{id}
GET  /api/runs/{id}/commands
POST /api/agents/connect
```

## Evidence Layout

建议扩展 `.tritonevidence`：

```text
case.tritonevidence/
  manifest.json
  run/
    events.jsonl
    meta.json
  commands/
    commands.jsonl
  artifacts/
    host/
    runtime/
    device/
  reports/
    summary.json
```

也可以把 command ledger 作为 `run/events.jsonl` 的一种 event kind。首期为了降低 parser 复杂度，单独 `commands/commands.jsonl` 更清晰。

## Safety Metadata

本地安全规则输出 warning，不首期自动打断：

```json
{
  "kind": "execution_safety_warning",
  "rule": "same_screen_revisit",
  "severity": "warning",
  "targetId": "sim:...",
  "step": 6,
  "detail": "Recent screenshots are visually identical after repeated tap actions.",
  "recommendation": "Use wait/assert or inspect current screen before continuing."
}
```

可先覆盖规则：

| rule | 输入 | 输出 |
| --- | --- | --- |
| `same_coordinate_repeat` | 最近 N 次 tap 坐标桶 | warning / blocked |
| `same_screen_revisit` | screenshot hash | warning |
| `scroll_oscillation` | swipe direction history | warning |
| `no_visual_progress` | before/after diff | warning |
| `unverified_host_action` | host action 后无验证 | recommendation |

## Error Codes

建议新增或统一：

| code | 场景 |
| --- | --- |
| `ambiguous_target` | 多候选未指定 |
| `device_not_ready` | target 在线但不可执行 |
| `device_locked` | target 被其他 session/job/manual lock 占用 |
| `agent_unavailable` | host agent 离线 |
| `command_timeout` | driver command 超时 |
| `command_dispatch_failed` | 下发失败 |
| `checkpoint_mismatch` | replay checkpoint 不满足 |
| `case_lint_warning` | case 可执行性风险 |
| `unsupported_capability` | 当前 target 不支持该能力 |

## 测试策略

### P0 单元测试

- `CommandLedgerEvent` Codable / JSON schema。
- source command redaction。
- elapsed / ok / error envelope。
- evidence manifest 链接 commands artifact。

### P1 单元测试

- Apple Simulator DTO 与 Harmony target DTO 归一化。
- readiness state mapping。
- lock conflict。
- ambiguous target selection。

### P2 单元测试

- `.tritoncase` 四字段解析。
- case lint：占位词、多断言、条件分支、缺失前置。
- `.tritonbatch` 展开为 per-platform item。

### 集成验证

- 使用 disposable simulator 或 fake host adapter 生成 evidence。
- 不在测试中要求真实远端 agent。
- destructive app install/uninstall、清数据、证书、隐私等能力只在显式 smoke 中跑。

## 风险与边界

1. 远端 agent 会引入鉴权、网络、心跳、路由、超时和 artifact 传输复杂度，不进入 P0。
2. device lock 如果只做本地内存，不具备跨进程一致性；必须在 schema 中标清实现等级。
3. command ledger 可能记录敏感信息，必须先做 redaction。
4. case lint 只能发现结构风险，不能证明 case 一定可执行。
5. replay checkpoint 只能降低漂移风险，不能替代最终断言。
6. 真机 iOS 的信任、解锁、证书、WDA 生命周期仍需人工或部署策略配合，不能承诺全自动。
