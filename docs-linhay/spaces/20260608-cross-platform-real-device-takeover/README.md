# 20260608 Cross-Platform Real Device Takeover

## 背景

用户要求“三端一起规划”。TritonKit 现有产品边界是本机 CLI + 本机 iOS Simulator / Android Emulator / HarmonyOS DevEco Emulator；真机、远端 agent 和设备云被明确排除。因此本 space 单独重定三端真机边界：iOS/iPadOS 真机、Android 真机、HarmonyOS 真机统一规划，但仍只做本机 Mac/开发机直连或本机可见设备，不做云端调度。

本 space 是三端总入口。Apple 端的 `devicectl` 细化材料保留在 `docs-linhay/spaces/20260608-ios-real-device-takeover/`，后续实现以本总方案为边界来源。

## 产品边界

包含：

1. 本机可见 iOS/iPadOS 真机：USB、同一开发机 CoreDevice 可见设备，底层优先 `xcrun devicectl`、`xcodebuild`、`xctrace`、`log`。
2. 本机可见 Android 真机：ADB 可见设备，底层 `adb`、`uiautomator`、`logcat`。
3. 本机可见 HarmonyOS 真机：HDC 可见设备，底层 `hdc`、`aa`、`bm`、`uitest`、`hilog`。
4. Debug App 内 embedded runtime：用于 App 内观察、wait/assert、语义 action 和 evidence。
5. CLI/HTTP 机器可读契约：`triton device/app/xcode|build/logs/smoke/evidence`。

不包含：

1. 设备云、远端 agent、USB over network、真机农场、多租户调度。
2. Web/Wails 管理页面或对外 HTTP 产品面。
3. 自动修改 Apple signing、Android keystore、Harmony certificate/profile 等账号和签名资产。
4. 默认系统级 HID 越权控制；各端只接官方 host tool 明确稳定支持的能力。
5. Release 包内运行时采集、上传或响应控制。

## 统一目标

1. 用同一套 `triton device` 发现、诊断、选择、别名、ready 等待三端真机。
2. 用同一套 `triton app` 覆盖安装、卸载、启动、终止、deep link/open-url 和 App 元数据。
3. 用同一套 `triton smoke <platform>` 串起 launch/open-url、runtime/host observe、wait/assert、screenshot/log/evidence。
4. 所有底层工具输出都转成稳定 JSON/JSONL envelope；raw stdout/stderr 只作为 artifact。
5. 真机不可用、未授权、未信任、签名失败、runtime 未连等状态都暴露稳定错误码和 nextAction。

## 统一命令面

### Device

```bash
triton device doctor --platform ios|android|harmony --scope real --json
triton device list --platform ios|android|harmony --scope real --json
triton device use <selector> --platform ios|android|harmony --scope real --json
triton device resolve <selector> --platform ios|android|harmony --scope real --ready --json
triton device wait-ready --device <selector> --jsonl
triton device screenshot --device <selector> --output /tmp/device.png --json
```

`--scope` 约定：

| 平台 | simulator/emulator scope | real scope |
| --- | --- | --- |
| iOS | `simulator` | `real` |
| Android | `emulator` | `real` |
| Harmony | `emulator` | `real` |

默认策略：

1. 新真机能力必须显式支持 `--scope real`。
2. `--scope all` 只用于诊断和列表，不用于自动选择 destructive/action target。
3. 旧命令未传 `--scope` 时保持兼容；有真机和 emulator 同名时返回 `ambiguous_target`。

### App

```bash
triton app install --device <selector> --app|--apk|--hap <path> --json
triton app uninstall --device <selector> --bundle-id|--package-name|--bundle <id> --confirm --json
triton app launch --device <selector> --bundle-id|--package-name|--bundle <id> --json
triton app open-url <url> --device <selector> --bundle-id|--package-name|--bundle <id> --json
triton app terminate --device <selector> --bundle-id|--package-name|--bundle <id> --json
```

### Build

```bash
triton xcode build --device <ios-real-selector> --jsonl
triton xcode run --device <ios-real-selector> --jsonl
triton build android --device <android-real-selector> --variant debug --jsonl
triton build harmony --device <harmony-real-selector> --mode debug --jsonl
```

说明：

1. iOS 复用现有 `triton xcode`。
2. Android/Harmony 是否新增 `triton build` namespace 可在 P2 再定；P0/P1 可先要求用户传入已构建的 Debug APK/HAP。
3. 三端都不自动修改 signing 配置。

### Smoke

```bash
triton smoke ios --device <selector> --bundle-id <id> --open-url <url> --wait-text <text> --json
triton smoke android --device <selector> --package <id> --open-url <url> --wait-text <text> --json
triton smoke harmony --device <selector> --bundle <id> --ability <ability> --open-url <url> --wait-text <text> --json
```

## BDD 场景

### 场景一：三端真机发现

- Given 本机安装对应平台工具
- When 分别执行 `triton device list --platform ios|android|harmony --scope real --json`
- Then 输出统一 `HostDeviceTarget` envelope
- And 每个 target 带 `platform`、`kind=real-device`、`id`、`state`、`ready`、`source`、`blockedReasons[]`
- And 默认脱敏 UDID、serial、ECID、账号、私有 bundle id 和绝对路径

### 场景二：授权/信任/调试状态诊断

- Given 真机被工具发现但不可用于调试
- When 执行 `triton device wait-ready --device <selector> --jsonl`
- Then iOS 返回 `device_not_trusted`、`developer_mode_required`、`device_locked` 或 `ddi_missing`
- And Android 返回 `android_target_unauthorized`、`android_target_offline` 或 `android_debugging_disabled`
- And Harmony 返回 `harmony_target_unauthorized`、`harmony_target_offline` 或 `harmony_debugging_disabled`
- And 每个错误都给出平台相关 nextAction，不要求 agent 解析人读日志

### 场景三：三端安装启动

- Given Debug app artifact 已构建
- When 执行 `triton app install --device <selector> ... --json`
- Then Triton 调用平台 host tool 并返回 normalized install summary
- When 执行 `triton app launch --device <selector> ... --json`
- Then 返回 launch 提交结果、进程/ability/activity 信息和 artifact 路径
- And launch 成功不等于业务 ready，后续必须用 wait/assert/snapshot/evidence 证明

### 场景四：Debug runtime ready

- Given Debug App 启动了 TritonKit embedded runtime
- When 执行 `triton smoke <platform> ... --wait-text Ready --json`
- Then 先完成 host launch/open-url，再等待 runtime 或 host layout ready
- And runtime 未连接时返回 `runtime_not_connected` 或 `debug_runtime_disabled`
- And Android/Harmony 如未集成 runtime，允许降级到 host layout `uiautomator` / `uitest` wait/assert

### 场景五：三端证据包

- Given smoke 执行完成或失败
- When 执行 `triton evidence --include host,runtime,logs --output /tmp/case.tritonevidence --json`
- Then manifest 包含设备 target、host action summaries、日志/截图/layout/runtime snapshot primary artifacts
- And raw 私有日志和设备标识默认脱敏
- And 缺少真机时输出 skipped evidence，不阻塞普通 CI

## 平台分层

| 能力 | iOS 真机 | Android 真机 | Harmony 真机 |
| --- | --- | --- | --- |
| 工具诊断 | `xcrun devicectl`, `xcodebuild` | `adb version`, SDK path | `hdc version`, DevEco path |
| 目标发现 | `devicectl list devices --json-output` | `adb devices -l` | `hdc list targets -v` |
| ready 判断 | trust, Developer Mode, DDI, unlocked | `device`, authorized, boot complete, package manager | Connected, authorized, boot completed |
| 安装 | `.app` via `devicectl device install app` | `.apk` via `adb install -r` | `.hap` via `hdc install -r` |
| 启动/open-url | `devicectl device process launch --payload-url` | `am start`, `monkey` fallback 禁用 | `aa start`, `aa start -U` |
| UI observe | embedded runtime first | runtime first, fallback `uiautomator dump` | runtime first, fallback `uitest dumpLayout` |
| 截图 | P1/P2 只在官方稳定能力明确后启用 | `adb exec-out screencap -p` | `snapshot_display` / `uitest screenCap` |
| 日志 | bounded `log stream/show` | bounded `adb logcat` | bounded `hilog` |
| 构建 | `triton xcode` | P2 Gradle wrapper adapter | P2 hvigor adapter |

## 分期

1. P0：统一 target 发现与 ready 诊断。只读，不安装、不启动。
2. P1：三端 install/launch/open-url + wait/assert/evidence。Android/Harmony 可先沿用 host layout fallback，iOS 依赖 embedded runtime。
3. P2：三端 build/run 编排。iOS 走 `triton xcode`，Android 走 Gradle，Harmony 走 hvigor。
4. P3：日志、截图、录屏、性能、LLDB/调试能力，全部显式 opt-in。

## 验收标准

1. `triton schema --command device --json` 暴露 `--scope real`、`kind=real-device`、三端错误码和 recovery。
2. `triton schema --command app --json` 暴露三端真机 install/launch/open-url 的参数和 failure codes。
3. `triton smoke ios|android|harmony` 的 schema 都能描述 host action 只是提交，wait/assert/evidence 才是业务证明。
4. 无真机环境下 CI 通过 parser/schema/redaction/error-mapping 测试。
5. 有真机环境下，本地 smoke 能生成 `.tritonevidence`，并在 summary 中明确平台、target、runtime/host-layout 证据来源。
