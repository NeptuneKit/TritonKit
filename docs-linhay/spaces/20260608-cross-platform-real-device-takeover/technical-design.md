# Cross-Platform Real Device Takeover Technical Design

## 总体架构

三端真机接入复用现有 host adapter 思路，但新增 `scope=real` 和 `kind=real-device`，避免与 simulator/emulator 混淆。

```text
triton CLI / HTTP / future MCP
  |
  v
Command schema + target resolver + defaults
  |
  +-- RealDeviceService
  |     +-- IOSDevicectlAdapter
  |     +-- AndroidADBRealDeviceAdapter
  |     +-- HarmonyHDCRealDeviceAdapter
  |     +-- RealDeviceErrorMapper
  |
  +-- HostAppService
  |     +-- install / uninstall / launch / terminate / open-url
  |
  +-- BuildService
  |     +-- XcodeWorkflowService
  |     +-- AndroidGradleAdapter
  |     +-- HarmonyHvigorAdapter
  |
  +-- RuntimeService
  |     +-- Debug embedded runtime
  |     +-- host layout fallback where available
  |
  +-- EvidenceService
        +-- host action summaries
        +-- target diagnostics
        +-- logs / screenshots / layout / runtime snapshots
```

## Target Identity

统一 target id：

```text
ios-real:<stable-hash>
android-real:<adb-serial-or-hash>
harmony-real:<hdc-target-or-hash>
sim:<udid>
android:<emulator-serial>
harmony:<hdc-emulator-target>
```

字段约定：

```json
{
  "platform": "android",
  "scope": "real",
  "kind": "real-device",
  "id": "android-real:abc123",
  "target": "android-real:abc123",
  "state": "device",
  "ready": true,
  "source": "adb",
  "name": "Pixel",
  "runtime": "Android 15",
  "transport": "usb",
  "blockedReasons": []
}
```

默认输出不暴露完整 serial / UDID / ECID。需要本地排障时可用 `--include-sensitive`，但 public issue / evidence redact 必须移除。

## Defaults 与 Alias

`.triton/host-targets.json` schema 升级到 v2：

```json
{
  "schemaVersion": 2,
  "current": "android-phone",
  "aliases": {
    "android-phone": {
      "platform": "android",
      "scope": "real",
      "kind": "real-device",
      "target": "android-real:abc123",
      "sensitiveRef": ".triton/devices/android-real-abc123.json"
    }
  }
}
```

规则：

1. alias 永远绑定具体 kind/scope，不随设备列表自动漂移。
2. alias 指向离线设备时返回 `target_offline`。
3. 多平台同名 alias 禁止；需要 `android-phone`、`ios-phone` 这类显式命名。

## Adapter Contract

每个平台 adapter 输出统一结构：

```swift
struct TKRealDeviceAdapterResult: Codable, Sendable {
    var ok: Bool
    var platform: String
    var action: String
    var target: HostDeviceTarget?
    var artifacts: [TKEvidenceArtifactSummary]
    var sourceCommands: [String]
    var error: TKCLIErrorDetail?
}
```

底层工具解析规则：

1. iOS：`devicectl` 必须使用 `--json-output <fresh-path>`；stdout 不解析。
2. Android：`adb devices -l`、`getprop`、`pm`、`am`、`uiautomator`、`logcat` 输出进入 parser/fixture；不可直接拼人读 stdout 给 agent。
3. Harmony：`hdc list targets -v`、`shell bm/aa/uitest/hilog` 输出进入 parser/fixture；保留 emulator 与 real target 的 scope 判定。
4. 所有 artifact 输出路径拒绝覆盖既有文件和 symlink。

## Device Readiness

P0 readiness matrix：

| 平台 | ready 条件 | blockedReasons |
| --- | --- | --- |
| iOS | CoreDevice visible, trusted, Developer Mode 可用, DDI 可用, unlocked 或命令允许锁屏 | `not-trusted`, `developer-mode-required`, `locked`, `ddi-missing`, `offline` |
| Android | adb state `device`, authorized, package manager 响应, API 可读 | `unauthorized`, `offline`, `debugging-disabled`, `package-manager-unavailable` |
| Harmony | HDC state Connected, authorized, bootevent completed, shell 命令可执行 | `unauthorized`, `offline`, `booting`, `shell-unavailable` |

## App Lifecycle Mapping

| Triton action | iOS | Android | Harmony |
| --- | --- | --- | --- |
| install | `devicectl device install app` | `adb install -r` | `hdc install -r` |
| uninstall | `devicectl device uninstall app` if stable, else P2 | `adb uninstall` | `bm uninstall` / `hdc uninstall` if stable |
| launch | `devicectl device process launch` | `am start -n` after resolve activity | `aa start` |
| open-url | launch `--payload-url` | `am start -a VIEW -d` | `aa start -U` |
| terminate | `devicectl device process terminate` | `am force-stop` | `aa force-stop` |
| info/list | `devicectl device info apps` | `pm list packages`, `dumpsys package` | `bm dump -n` |

首期所有 destructive 操作都需要 `--confirm` 或明确 unsupported。

## Build Mapping

P0/P1 不强制引入 Android/Harmony build adapter；真实项目通常已有 CI 或本地构建脚本，Triton 可以先消费 Debug artifact。

P2 目标：

```bash
triton build android --project <path> --variant debug --device <selector> --jsonl
triton build harmony --project <path> --module entry --mode debug --device <selector> --jsonl
```

约束：

1. Adapter 只包装 Gradle/hvigor 执行与 artifact discovery，不修改 keystore/certificate/profile。
2. 构建日志写 artifact，summary 只给路径、bytes、warnings/errors 摘要。
3. signing/certificate/profile 失败映射为稳定错误码。

## Runtime 与 Host Layout

三端验证优先级：

1. Debug embedded runtime：最强，能提供 App 内状态、语义 action、route、AX/geometry、snapshot。
2. Host layout fallback：Android `uiautomator`、Harmony `uitest`，适合文本等待、点击和截图；iOS 真机首期不承诺 host layout fallback。
3. Host launch/install action：只证明动作提交，不证明业务 ready。

输出必须标记 evidence source：

```json
{
  "proofSource": "runtime|host-layout|host-action",
  "businessReady": true
}
```

## 错误码

通用：

- `ambiguous_target`
- `target_not_found`
- `target_offline`
- `device_not_ready`
- `device_locked`
- `debug_runtime_disabled`
- `runtime_not_connected`
- `artifact_output_rejected`
- `host_action_failed`
- `host_command_timeout`
- `unsupported_host_action`

iOS：

- `devicectl_not_found`
- `devicectl_json_missing`
- `devicectl_json_parse_failed`
- `device_not_trusted`
- `developer_mode_required`
- `ddi_missing`
- `xcode_signing_failed`
- `provisioning_profile_missing`

Android：

- `android_adb_not_found`
- `android_target_unauthorized`
- `android_target_offline`
- `android_debugging_disabled`
- `android_package_manager_unavailable`
- `android_app_install_failed`
- `android_activity_resolve_failed`
- `android_uiautomator_failed`

Harmony：

- `harmony_hdc_not_found`
- `harmony_target_unauthorized`
- `harmony_target_offline`
- `harmony_debugging_disabled`
- `harmony_shell_unavailable`
- `harmony_app_install_failed`
- `harmony_ability_launch_failed`
- `harmony_uitest_failed`

## Evidence Policy

`.tritonevidence` primary artifacts 排序：

1. `real-device.diagnostics`
2. `host.app-action`
3. `runtime.snapshot`
4. `host.layout`
5. `screenshot`
6. `logs`
7. `build.summary`

脱敏：

1. iOS：UDID、serial、ECID、Apple ID、Team ID、bundle id、私有路径。
2. Android：serial、account、package id、keystore path、私有路径。
3. Harmony：HDC target、bundle、certificate/profile path、账号、私有路径。

## 测试策略

自动化：

1. 三端 command builder tests。
2. 三端 parser fixture tests。
3. `DeviceCrossPlatformTests` 覆盖 `--scope real`、`kind=real-device`、alias/current/resolve。
4. `SchemaFactSourceTests` 覆盖三端错误码 recovery category。
5. `EvidenceBundleTests` 覆盖 real-device diagnostics 与 redaction。
6. `FailureDiagnosticsTests` 覆盖授权、签名、runtime 未连。

真实设备 smoke 不进普通 CI，只作为手动维护者门禁：

```bash
triton device doctor --platform ios --scope real --json
triton device doctor --platform android --scope real --json
triton device doctor --platform harmony --scope real --json
```
