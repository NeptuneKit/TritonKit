# ai-phone Emulator CLI Technical Design

## 设计目标

本设计覆盖本机三端模拟器/仿真器 CLI：

1. `triton` 是唯一对外入口。
2. 所有命令默认机器可读：JSON 或 JSONL。
3. 每个 host/runtime action 都可进入 command ledger。
4. Evidence 是本地 filesystem portable directory。
5. 不做 Web、远端 agent、真实设备、Postgres、Kafka、Webhook。

## 目标架构

```text
AI agent / CI
  |
  | triton CLI
  v
Triton local CLI
  - schema / doctor / plan
  - local target resolver
  - platform process runner
  - app lifecycle adapters
  - UI snapshot / screenshot adapters
  - runtime bridge
  - command ledger writer
  - evidence writer
  - replay / assert
```

## Target DTO

```json
{
  "targetId": "ios-sim:0333546D-2AC6-4C22-AF01-293E2F4BA5BC",
  "platform": "ios",
  "kind": "simulator",
  "transport": "xcrun-simctl",
  "state": "Booted",
  "readiness": "ready",
  "workspaceDefault": true,
  "capabilities": ["app.install", "app.openUrl", "screenshot", "privacy", "location"],
  "lastSeenAt": "2026-05-21T00:00:00+08:00"
}
```

平台 target id 建议：

| 平台 | target id |
| --- | --- |
| iOS Simulator | `ios-sim:<udid>` |
| Android Emulator | `android-emulator:<serial>` |
| Harmony Emulator | `harmony-emulator:<hdc-target>` |

## CommandLedgerEvent

```json
{
  "schemaVersion": 1,
  "event": "command_result",
  "messageId": "cmd_01HW...",
  "runId": "run_01HW...",
  "targetId": "ios-sim:0333546D-...",
  "platform": "ios",
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

## CLI 命令面

### 通用

```text
triton schema --json
triton doctor --json
triton capabilities --json
triton plan --json

triton device list --platform ios|android|harmony --json
triton device use --platform ios|android|harmony --target <target> --json
triton device wait-ready --platform ios|android|harmony --target <target> --jsonl
```

### iOS Simulator

```text
triton sim list/use/boot/shutdown/screenshot --json
triton sim privacy grant|revoke|reset <service> --bundle-id <id> --json
triton sim location set|clear --json
triton sim ui appearance light|dark --json
triton sim ui status-bar override --json

triton app list/info/install/uninstall/launch/terminate/open-url/container/prefs --platform ios --json
```

### Android Emulator（后续接入）

```text
triton app list/info/install/uninstall/launch/terminate/open-url --platform android --json
triton screenshot --platform android --output <png> --json
triton ax --platform android --json
triton logs collect --platform android --output <dir> --json
```

Android adapter 可以后续接入；接入时只承诺 emulator target，不承诺真机。底层可用 `adb devices`、`adb shell am`、`adb install/uninstall`、`uiautomator dump`、`screencap`、`logcat -d -t`。

### Harmony Emulator

```text
triton device doctor --platform harmony --json
triton app inspect --platform harmony --bundle <bundle> --json
triton app launch --platform harmony --bundle <bundle> --ability <ability> --json
triton screenshot --platform harmony --output <png> --json
triton ax --platform harmony --json
triton logs collect --platform harmony --output <dir> --json
```

底层可用 `hdc list targets -v`、`param get bootevent.boot.completed`、`aa start`、`bm dump`、`uitest dumpLayout`、`uitest screenCap`、`hilog`。

### Evidence / replay

```text
triton evidence --output <dir.tritonevidence> --json
triton evidence inspect <dir.tritonevidence> --json
triton evidence commands <dir.tritonevidence> --jsonl
triton capture --case <case> --output <dir.tritonevidence> --json

triton case lint <file.tritoncase> --json
triton run submit --file <file.tritonbatch> --output <dir> --json
triton replay <file.tritonplan> --checkpoint-policy strict --json
```

## Evidence Layout

```text
case.tritonevidence/
  manifest.json
  commands/
    commands.jsonl
  artifacts/
    ios-simulator/
    android-emulator/
    harmony-emulator/
    runtime/
  run/
    events.jsonl
    meta.json
```

## Error Codes

| code | 场景 |
| --- | --- |
| `ambiguous_target` | 多个本机 emulator/simulator 且未指定 |
| `target_not_ready` | target 未 boot 或不可操作 |
| `app_not_installed` | bundle/package 不存在 |
| `app_info_not_available` | 元数据不可用 |
| `command_timeout` | 底层命令超时 |
| `unsupported_capability` | 当前平台不支持 |
| `destructive_action_requires_policy` | erase、uninstall、data install 等写入动作缺少 policy |

## Safety Rules

| rule | 触发 |
| --- | --- |
| `unverified_host_action` | open-url、launch、install 后没有 wait/assert/screenshot/evidence |
| `same_screen_revisit` | 多次动作后 screenshot hash 近似不变 |
| `same_coordinate_repeat` | 多次 tap 命中同一坐标桶 |
| `destructive_without_artifact` | uninstall、erase、data install 没有记录 ledger |

## 测试策略

### 单元测试

- 三端 target DTO 归一化。
- iOS simctl parser。
- Android adb parser。
- Harmony hdc parser。
- command ledger redaction。
- error envelope。
- `.tritonevidence` manifest 链接 commands。

### 集成 smoke

- iOS 使用 disposable simulator。
- Harmony 使用 DevEco Emulator fixture。
- Android 使用 emulator fixture 或 fake adb adapter。
- 不要求真实设备、远端 agent 或 Web。
