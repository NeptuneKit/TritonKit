# iOS Real Device Takeover Technical Design

## 设计立场

真机接入是 host-side Apple workflow 的独立分支：底层封装 Apple 官方 CLI，产品契约仍然是 `triton` CLI/HTTP schema。agent 不直接消费 `devicectl`、`xcodebuild`、`xctrace` 或 LLDB 输出。

首期采用低侵入路径：

```text
triton CLI / HTTP / future MCP
  |
  v
Command schema + target resolver + defaults
  |
  +-- IOSRealDeviceService
  |     +-- DevicectlAdapter
  |     +-- XcodeDeviceBuildAdapter
  |     +-- DeviceLogAdapter
  |     +-- SigningDiagnosticsMapper
  |
  +-- Existing XcodeWorkflowService
  |     +-- discover/use/settings/build/test/run
  |
  +-- Existing App Host Service
  |     +-- install/launch/terminate/open-url
  |
  +-- Embedded Runtime Service
  |     +-- status/wait/find/assert/snapshot/evidence
  |
  +-- Evidence / Plan Service
        +-- devicectl JSON artifacts
        +-- xcode action summaries
        +-- runtime snapshots
```

## 工具事实

本机 Xcode `devicectl` help 明确约束：

1. `--json-output <path>` 写出的 JSON 才是脚本和程序可消费的稳定接口。
2. stdout 面向人读，不保证稳定。
3. 顶层 JSON 包含 `info` 与 `result`，`info` 提供 `jsonVersion`、`version`、`outcome`、`arguments` 等兼容性信息。
4. `devicectl list devices --json-output <path>` 的设备项来自 `result.devices[]`，常见字段包括 `identifier`、`deviceProperties`、`hardwareProperties`、`connectionProperties`、`capabilities`、`tags`、`visibilityClass`。
5. 安装 App 的稳定入口是 `devicectl device install app --device <identifier> <path> --json-output <path>`。
6. 启动 App 的稳定入口是 `devicectl device process launch --device <identifier> <bundle-id-or-path> --json-output <path>`，支持 `--payload-url`、`--terminate-existing`、`--start-stopped` 和 `DEVICECTL_CHILD_` 环境。

因此 `DevicectlAdapter` 必须总是：

1. 为每次执行创建独立 artifact 目录。
2. 传入 `--json-output <fresh-path>` 与 `--log-output <fresh-path>`。
3. 拒绝覆盖既有 JSON/log 文件和符号链接。
4. 解析 JSON 文件并生成 Triton normalized envelope。
5. 将 raw JSON/log 作为 evidence artifact 引用，默认脱敏私有字段。

## Target Graph

新增或明确 target 类型：

```text
device:ios-real:<stable-hash>
device:ios-real:<stable-hash>:app:<bundle-id>
xcode:<workspace>:scheme:<scheme>:configuration:<configuration>:device:<stable-hash>
runtime:<target-id>:device:<stable-hash>:app:<bundle-id>
artifact:devicectl:<action>:<uuid>
```

`stable-hash` 由真实设备标识计算，但默认只输出短 hash。完整 `identifier`、serial、UDID、ECID 只在本地 artifact 中保留，并且 evidence 默认脱敏。

## Defaults

`.triton/host-targets.json` 继续作为跨平台 target alias 存储，alias entry 需要增加 `kind` 与 `sensitiveRef`：

```json
{
  "schemaVersion": 2,
  "current": "iphone-dev",
  "aliases": {
    "iphone-dev": {
      "platform": "ios",
      "kind": "real-device",
      "target": "ios-real:<hash>",
      "sensitiveRef": ".triton/devices/ios-real-<hash>.json"
    }
  }
}
```

`.triton/host-defaults.json` 的 Xcode defaults 需要支持真机 destination：

```json
{
  "xcode": {
    "workspace": "App.xcworkspace",
    "scheme": "App",
    "configuration": "Debug",
    "sdk": "iphoneos",
    "destination": "id=<device-identifier>",
    "device": "iphone-dev",
    "derivedDataPath": ".triton/DerivedData"
  }
}
```

解析优先级：

1. 显式 `--device <selector>`。
2. `.triton/host-targets.json` current alias。
3. `.triton/host-defaults.json` Xcode device。
4. 单一 ready 真机候选。
5. 多候选返回 `ambiguous_target`。

## Command Surface

### Device

```bash
triton device doctor --platform ios --scope real --json
triton device list --platform ios --scope real --json
triton device use <selector> --platform ios --scope real --json
triton device current --json
triton device resolve <selector> --platform ios --scope real --ready --json
triton device wait-ready --device <selector> --jsonl
```

兼容策略：

1. `--platform ios` 默认可继续列 simulator target，但新增 `--scope simulator|real|all` 消除歧义。
2. `--device sim:<udid>` 永远指向 simulator。
3. `--device ios-real:<hash>` 或 alias 指向真机。
4. 裸设备名匹配多个 simulator/real target 时必须报 `ambiguous_target`。

### Xcode

```bash
triton xcode use --workspace App.xcworkspace --scheme App --configuration Debug --device iphone-dev --json
triton xcode build --device iphone-dev --jsonl
triton xcode test --device iphone-dev --result-bundle /tmp/App.xcresult --jsonl
triton xcode run --device iphone-dev --jsonl
```

实现策略：

1. `build --device` 使用 `iphoneos` SDK 与真机 destination。
2. `run --device` 是复合命令：build -> resolve app path -> install -> launch -> optional runtime wait。
3. `test --device` 首期只支持用户显式请求；默认 smoke 不要求真机 XCTest，因为 signing、trust、unlock 状态不稳定。
4. signing/provisioning 诊断从 `xcodebuild` summary、stderr sample、`.xcresult` 和 known pattern 映射到稳定错误码。

### App

```bash
triton app install --device iphone-dev --app /tmp/Demo.app --json
triton app launch --device iphone-dev --bundle-id com.example.demo --json
triton app launch --device iphone-dev --bundle-id com.example.demo --payload-url example://debug --wait-ready --json
triton app terminate --device iphone-dev --bundle-id com.example.demo --json
triton app info --device iphone-dev --bundle-id com.example.demo --json
```

首期能力：

1. install：`devicectl device install app`。
2. launch/open-url：`devicectl device process launch` + `--payload-url`。
3. terminate：`devicectl device process terminate`，若当前 Xcode 版本语义不足，先返回 `unsupported_host_action` 并给出后续切片。
4. info/list：`devicectl device info apps`。
5. container/prefs：首期不承诺，除非官方 CLI 提供稳定 JSON 可读能力。

### Logs

```bash
triton logs collect --device iphone-dev --bundle-id com.example.demo --duration 10 --output /tmp/logs --json
triton logs stream --device iphone-dev --bundle-id com.example.demo --duration 10 --jsonl
```

日志来源按可靠性分层：

1. P1 使用 `log stream` / `log show` predicate，以 process/bundle/subsystem 过滤。
2. P1 只做有界 collect，默认不做无限 stream。
3. raw log 只写 artifact，summary 返回 bytes、duration、predicate、redaction 状态。

### Smoke

```bash
triton smoke ios --device iphone-dev --bundle-id com.example.demo --open-url example://debug --wait-text Ready --json
```

步骤：

1. resolve device。
2. optional install。
3. launch/open-url。
4. wait runtime ready。
5. assert text/route/state。
6. evidence capture。

## Output Contracts

### Device Target

```json
{
  "platform": "ios",
  "kind": "real-device",
  "id": "ios-real:abc123",
  "target": "ios-real:abc123",
  "state": "connected",
  "ready": true,
  "source": "devicectl",
  "name": "iPhone",
  "runtime": "iOS 26.5",
  "transport": "usb",
  "blockedReasons": [],
  "sensitive": false
}
```

### Devicectl Action Summary

```json
{
  "ok": true,
  "action": "ios-device.app.install",
  "device": "ios-real:abc123",
  "bundleID": "com.example.demo",
  "artifact": "artifacts/devicectl/install.json",
  "logArtifact": "artifacts/devicectl/install.log",
  "jsonVersion": "1",
  "sourceCommand": "xcrun devicectl device install app --device <redacted> /tmp/Demo.app --json-output <path>",
  "durationMs": 12000
}
```

### Failure Envelope

```json
{
  "ok": false,
  "error": {
    "code": "device_not_trusted",
    "message": "The selected iOS device is visible but not trusted for development.",
    "hint": "Unlock the device, trust this Mac, enable Developer Mode if needed, then rerun `triton device wait-ready --device iphone-dev --jsonl`.",
    "nextAction": {
      "command": "device",
      "args": ["wait-ready", "--device", "iphone-dev", "--jsonl"]
    }
  }
}
```

## 错误码

P0/P1 固定错误码：

- `devicectl_not_found`
- `devicectl_json_missing`
- `devicectl_json_parse_failed`
- `device_not_found`
- `device_not_ready`
- `device_not_trusted`
- `developer_mode_required`
- `device_locked`
- `device_offline`
- `ddi_missing`
- `xcode_signing_failed`
- `provisioning_profile_missing`
- `team_not_configured`
- `bundle_id_mismatch`
- `app_install_failed`
- `app_launch_failed`
- `runtime_not_connected`
- `network_unreachable`
- `debug_runtime_disabled`
- `unsupported_host_action`
- `artifact_output_rejected`

所有 target 类失败都必须提供 `triton device list/use/wait-ready` 方向的 recovery。所有 Xcode/signing 类失败都必须提供 `triton xcode discover/use/build` 或人工 signing 修复提示，但不能自动改 signing 资产。

## 安全与隐私

1. 默认脱敏 UDID、serial、ECID、Apple account、Team ID、私有 bundle id、绝对路径和 token。
2. `--include-sensitive` 只允许本地输出，不进入 public issue 模板。
3. evidence 只复制显式 action summary 和 devicectl JSON/log artifact，不扫描用户 Home、DerivedData 或 MobileDevice 目录。
4. destructive action 如 uninstall、reboot、sysdiagnose 必须显式 `--confirm` 或先以 unsupported/blocker 处理。
5. 真机 App 内控制只能作用于 Debug embedded runtime 暴露的 App 范围，不做系统 UI 越权控制。

## 测试策略

自动化测试：

1. `TKDevicectlCommandBuilderTests`：锁定 list/install/launch/info 的 argv。
2. `TKDevicectlJSONParserTests`：使用脱敏 fixture 覆盖 ready、offline、not trusted、locked、missing fields。
3. `DeviceCrossPlatformTests`：schema 暴露 `--scope real`、real-device kind、错误码和 next commands。
4. `XcodeWorkflowModelsTests`：workspace defaults 支持 `device` 与 `iphoneos` destination。
5. `EvidenceBundleTests`：devicectl artifact 进入 manifest 且默认脱敏。
6. `FailureDiagnosticsTests`：签名、未信任、Developer Mode、runtime 未建连的 hint 和 nextAction 稳定。

本地真机 smoke：

```bash
triton device doctor --platform ios --scope real --json
triton device list --platform ios --scope real --json
triton device use iphone-dev --json
triton xcode build --device iphone-dev --jsonl
triton app install --device iphone-dev --app /tmp/Demo.app --json
triton app launch --device iphone-dev --bundle-id com.example.demo --wait-ready --json
triton assert text-exists Ready --json
triton evidence --include host,xcode,runtime --output /tmp/ios-real-device.tritonevidence --json
```

CI 策略：

1. 普通 CI 不要求真机在线。
2. 默认 CI 只跑 parser、schema、command builder、redaction 和 error mapping。
3. 真机 smoke 作为 manual workflow 或本地维护者门禁，缺真机时输出 skipped evidence。
