# Simulator Takeover Technical Design

## 设计立场

实现采用 `triton` 原生 host adapter，底层封装 Apple 官方 CLI。XcodeBuildMCP 是架构参考，不是主依赖；Baguette 是动作模型参考，不是 runtime 边界来源。

核心设计目标：

- CLI / HTTP / future MCP 只是一层入口，共用同一 domain service。
- host-side adapter 和 embedded runtime 分层清晰。
- 所有能力先进入 `triton schema --json`，再进入 README、skills 和真实项目文档。
- 单元测试优先 fake process runner，真实 simulator smoke 放脚本。
- Harness 是 UX run / agent loop / evidence 参考：可吸收 append-only run log、friction taxonomy、credential redaction、clean screenshot invariant、PlatformAdapter/UXDriving 抽象和 WebDriverAgent 评估，但不吸收其 GUI-first 产品形态。

## 架构

```text
AI agent
  |
  | triton CLI / HTTP JSON
  v
Command Router
  |
  +-- Schema / Doctor / Capabilities
  |
  +-- Target Resolver
  |     +-- Workspace defaults
  |     +-- Simulator registry
  |     +-- App registry
  |     +-- Runtime registry
  |
  +-- Host Adapter Service
  |     +-- SimctlAdapter
  |     +-- XcodebuildAdapter
  |     +-- DevicectlAdapter
  |     +-- XctraceAdapter
  |     +-- XcresultAdapter
  |     +-- HostUIAdapter
  |
  +-- Runtime Service
  |     +-- WebSocket request/response
  |     +-- AX / input / screenshot / hierarchy
  |
  +-- Plan / Evidence Service
        +-- .tritonplan
        +-- .tritonevidence
        +-- action trace JSONL
```

约束：

- Host Adapter 不调用 Runtime Service。
- Runtime Service 不调用 Host Adapter。
- Plan / Evidence 可以编排两者，但不持有底层工具逻辑。
- Host UI 是独立 adapter，不能复用 embedded `tap/type/press` 的语义。

## Target Resolver

### Target ID

```text
host:<workspace-id>
sim:<udid>
sim:<udid>:app:<bundle-id>
runtime:<target-id>
```

### 解析规则

1. 显式参数优先：`--simulator`、`--bundle-id`、`--target`。
2. workspace defaults 次之：由 `triton sim use <udid>` 写入。
3. 单一 booted simulator 可自动选择。
4. 单一 runtime target 可自动选择。
5. App target 和 runtime target bundle id 一致时建立绑定。
6. 多候选时返回 `ambiguous_target`，输出候选列表和推荐命令。

## 数据契约

### SimulatorTarget

```json
{
  "id": "sim:0333546D-2AC6-4C22-AF01-293E2F4BA5BC",
  "udid": "0333546D-2AC6-4C22-AF01-293E2F4BA5BC",
  "name": "TritonKit Dedicated iPhone 17 Simulator",
  "platform": "iOS Simulator",
  "runtime": "iOS 26.5",
  "state": "Booted",
  "isAvailable": true,
  "isBooted": true,
  "source": "simctl"
}
```

### AppTarget

```json
{
  "id": "sim:0333546D-2AC6-4C22-AF01-293E2F4BA5BC:app:cn.example.app",
  "simulatorUDID": "0333546D-2AC6-4C22-AF01-293E2F4BA5BC",
  "bundleID": "cn.example.app",
  "name": "Example",
  "installed": true,
  "containers": {
    "data": "/path/to/Data/Application/..."
  }
}
```

### HostActionResult

```json
{
  "ok": true,
  "action": "app.open-url",
  "runtimeScope": "host-simulator",
  "target": "sim:0333546D-2AC6-4C22-AF01-293E2F4BA5BC:app:cn.example.app",
  "tool": "simctl",
  "toolVersion": "xcrun version 72",
  "durationMs": 240,
  "exitCode": 0,
  "artifacts": [],
  "note": "URL was submitted to the simulator; verify in-app completion with runtime wait/assert."
}
```

### HostActionError

```json
{
  "ok": false,
  "error": {
    "code": "simulator_not_booted",
    "message": "Simulator is not booted.",
    "hint": "Run triton sim boot <udid> --wait --jsonl.",
    "nextAction": {
      "command": "sim",
      "args": ["boot", "0333546D-2AC6-4C22-AF01-293E2F4BA5BC", "--wait", "--jsonl"]
    }
  }
}
```

## CLI Surface

### P0 Simulator

```bash
triton sim list --json
triton sim use <udid> --json
triton sim boot [<udid>] --wait --jsonl
triton sim shutdown [<udid>] --json
triton sim screenshot --output <path> --json
```

### P0 App

```bash
triton app list --simulator <udid> --json
triton app info --simulator <udid> --bundle-id <id> --json
triton app install --simulator <udid> --app <path.app> --json
triton app launch --simulator <udid> --bundle-id <id> --json
triton app terminate --simulator <udid> --bundle-id <id> --json
triton app open-url <url> --simulator <udid> --json
triton app container --simulator <udid> --bundle-id <id> --kind data --json
triton app prefs dump --simulator <udid> --bundle-id <id> --json
triton app prefs get --simulator <udid> --bundle-id <id> --key <key> --json
```

### P1 Simulator Environment

```bash
triton sim privacy grant|revoke|reset <service> --bundle-id <id> --json
triton sim location set <lat,lon> --json
triton sim location clear --json
triton sim ui appearance light|dark --json
triton sim ui content-size <size> --json
triton sim status-bar override --time 09:41 --battery-level 100 --json
triton sim push --bundle-id <id> --payload <file> --json
triton sim media add <path>... --json
triton sim keychain add-root-cert <path> --json
triton sim keychain add-cert <path> --json
triton sim keychain reset --confirm --json
triton sim pasteboard copy <text> --json
triton sim pasteboard sync host|<udid> host|<udid> --json
triton sim icloud sync --json
triton app data install --simulator <udid> --xcappdata <path.xcappdata> --confirm --json
```

### P2 Debugging / Host UI / Performance

```bash
triton logs stream --simulator <udid> --bundle-id <id> --level debug --jsonl
triton logs collect --simulator <udid> --bundle-id <id> --output <dir> --json
triton sim record --output <path.mov> --duration <seconds> --jsonl
triton sim diagnose --output <dir> --json
triton sim env get <name> --json
triton host ui snapshot --simulator <udid> --json
triton host ui tap --text <text> --simulator <udid> --json
triton host ui tap --at x,y --simulator <udid> --json
triton host ui type <text> --simulator <udid> --json
triton host ui press home --simulator <udid> --json
triton perf templates --json
triton perf record --simulator <udid> --bundle-id <id> --template "Time Profiler" --duration 30 --output <trace> --jsonl
```

### P3 Xcode Workflow

```bash
triton xcode discover --path <repo> --json
triton xcode build --workspace <path> --scheme <scheme> --simulator <udid> --jsonl
triton xcode test --workspace <path> --scheme <scheme> --simulator <udid> --result-bundle <path> --jsonl
triton xcode result summary --path <xcresult> --json
triton xcode coverage summary --path <xcresult> --json
triton xcode coverage uncovered --path <xcresult> --target <name> --json
triton spm build --package-path <path> --jsonl
triton spm test --package-path <path> --jsonl
triton scaffold ios --name <name> --output <path> --json
```

### P4 Maintenance

```bash
triton sim erase [<udid>] --confirm --json
triton app uninstall --simulator <udid> --bundle-id <id> --confirm --json
triton sim clone <udid> --name <name> --json
triton sim rename <udid> --name <name> --json
triton sim upgrade <udid> --runtime <runtime-id> --json
triton sim runtime list --json
triton sim runtime add <path.dmg> --jsonl
triton sim runtime delete <identifier> --dry-run --json
triton sim runtime verify <identifier> --json
triton sim runtime match list --json
triton sim pair --watch <watch-udid> --phone <phone-udid> --json
triton sim unpair --watch <watch-udid> --json
triton sim pair activate --watch <watch-udid> --phone <phone-udid> --json
```

P4 命令默认不进入 `triton plan` 的推荐步骤。涉及删除、替换或重置状态的命令必须要求 `--confirm`。

## Harness 参考采纳

### UX Run Log

后续 `.tritonevidence` 应支持 Harness 风格的 run event 子流：

```text
run_started
step_started
tool_call
tool_result
friction
step_completed
run_completed
```

约束：

1. JSONL append-only，不重写历史行。
2. screenshot 先写文件，再写 `step_started`。
3. screenshot path 使用相对路径，保证 evidence 可整体搬迁。
4. parser 容忍最后一行截断，旧 schema 永久可读。
5. `friction` 采用固定 taxonomy：`dead_end`、`ambiguous_label`、`unresponsive`、`confusing_copy`、`unexpected_state`、`auth_required`、`agent_blocked`。

### Clean Screenshot Invariant

若后续为 agent 增加 AX candidate、tap target 或 Set-of-Mark overlay：

1. agent-only marked image 只能进入内存 payload 或 debug artifact。
2. 默认 evidence screenshot 必须保持用户真实看到的干净画面。
3. replay / issue report / friction report 默认引用 clean screenshot。

### WebDriverAgent Boundary

Harness 将 WDA 用作 iOS Simulator 输入层，理由是 iOS 26+ 上 idb HID injection 可能只显示触点而不进入 UIKit responder chain。TritonKit 采纳边界：

1. P0/P1 不引入 WDA 默认依赖，继续优先 embedded runtime + host simctl。
2. P2/P3 可评估 WDA 作为黑盒 App fallback，服务未接入 TritonKit runtime 的业务 App。
3. 若引入，必须按 iOS runtime + WDA SHA 缓存 build，并把 WDA build/test runner log 纳入 evidence artifact。
4. WDA 不能替代 embedded runtime 的 App 内语义；只能作为 fallback 输入 driver。

## Plan Schema

`.tritonplan` 升级到 schema version 2，新增 host action namespace。

```json
{
  "schemaVersion": 2,
  "name": "login-smoke",
  "target": {
    "simulator": "${simulatorUDID}",
    "bundleID": "${bundleID}"
  },
  "steps": [
    { "type": "sim.boot", "wait": true },
    { "type": "app.openURL", "url": "${debugURL}" },
    { "type": "runtime.wait", "text": "首页", "timeoutSeconds": 15 },
    { "type": "app.prefs.get", "key": "DEBUG-mock", "expect": false },
    { "type": "sim.screenshot", "output": "after-login.png" }
  ]
}
```

规则：

- `replay --dry-run` 必须校验变量、路径、target 和危险动作确认位。
- host step 失败默认停止后续步骤。
- secret 变量继续使用 `--var key-env=ENV_NAME`。
- `sim.erase`、`app.uninstall`、`app.data.install`、`sim.keychain.reset`、`sim.runtime.delete` 必须显式 `confirm: true`。

## Evidence Schema

`manifest.json` 新增 host scope：

```json
{
  "artifacts": [
    {
      "name": "host-simulator-status",
      "scope": "host",
      "type": "json",
      "path": "host/simulator-status.json",
      "source": "simctl"
    },
    {
      "name": "runtime-ax",
      "scope": "runtime",
      "type": "json",
      "path": "runtime/ax.json",
      "source": "triton-runtime"
    }
  ]
}
```

Host action trace 写入 `host/actions.jsonl`，每行是一个 `HostActionResult` 或 `HostActionError`。

`capture --include host` 默认采集：

- simulator status
- selected simulator defaults
- app info
- host screenshot
- runtime status / ax / screenshot
- action trace
- logs 摘要，如果日志采集已开启

## Process Runner

定义可注入协议：

```text
HostProcessRunning.run(command, args, stdin, env, cwd, timeout) -> HostProcessResult
HostProcessRunning.stream(command, args, env, cwd, timeout) -> AsyncSequence<HostProcessEvent>
```

实现策略：

1. P0 可先用仓库内薄封装 `Foundation.Process`。
2. 进入日志流、`xctrace record`、PTY 或长生命周期 session 时，引入 `SKProcessRunner`。
3. 上层 adapter 只依赖协议；单元测试使用 fake runner。

## Error Codes

首批稳定错误码：

- `xcode_not_found`
- `xcrun_not_found`
- `tool_unavailable`
- `simulator_not_found`
- `simulator_ambiguous`
- `simulator_not_booted`
- `app_not_installed`
- `bundle_id_required`
- `app_container_not_found`
- `plist_not_found`
- `host_action_timeout`
- `host_action_failed`
- `host_ui_unavailable`
- `unsupported_host_capability`
- `destructive_confirmation_required`
- `artifact_write_failed`
- `plan_host_step_failed`

## Test Strategy

单元测试：

- CLI 参数解析和 schema 输出。
- Target resolver：唯一、缺失、多候选、workspace default。
- Adapter argv 构造。
- `simctl` / `xcodebuild` stdout、stderr、exit code 到 JSON envelope 的映射。
- plist 解析：string、bool、int、array、dictionary、missing key。
- `.xcappdata` 安装结果必须说明会替换 container 并终止 App。
- media、keychain、icloud、pasteboard、env 命令 argv 构造。
- destructive 命令必须要求 `--confirm`。

集成 smoke：

- 使用 `TritonKit Dedicated iPhone 17 Simulator` 或动态创建专用 simulator。
- 覆盖 `sim list -> boot -> screenshot`。
- 覆盖 `app install -> launch -> open-url -> prefs get`。
- 覆盖 `capture --include host`。

不进默认 `swift test`：

- 真实 `xcodebuild build/test`。
- 长时间 `xctrace record`。
- host UI automation 点击系统弹窗。
- `sim erase`、`app uninstall`、runtime 管理命令。

## Adoption Notes

实现完成后必须同步：

- `README.md`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `.agents/tritonkit-skills/public/tritonkit-emulator-cli-takeover`
- `.agents/tritonkit-skills/public/tritonkit-real-project-regression`
- `.agents/tritonkit-skills/public/tritonkit-dev-feedback`
- `docs-linhay/spaces/20260520-xcrun-host-adapter-research/README.md`
- GitHub issue #11 和 #12 的状态
