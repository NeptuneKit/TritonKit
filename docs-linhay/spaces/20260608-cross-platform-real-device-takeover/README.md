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

## Web mock 真机 App runtime mirror 约束（2026-06-18）

- `Web/` 仍是 mock / diagnostics UI，不是业务控制入口。
- `/web/host-targets` 可以消费 `triton device list --platform ios|android|harmony --scope real --json`，但 Web mock 左侧只展示 `ready=true` 且具备直接连接证明（当前为 `transport=wired|usb`）的真机目标。
- 真机 `ready=false`、离线、未信任、未授权、DDI 缺失、无线配对或无直接连接证明时不进入 Web mock 左侧设备列表；这类诊断仍由 CLI / HTTP 机器可读契约暴露。
- host bridge 返回任意真实 target 时，不再补齐缺失平台的 QA mock target，避免 Android / Harmony 未启动时仍出现 mock 设备。
- 用户接受的真机展示底线是 App 启动、App 实时画面与模拟手势；Web mock 对 iOS 真机采用 App 内 embedded runtime mirror，不承诺整机系统级投屏或 HID。
- iOS 真机画面走 `triton screenshot --output <tmp> --json` 的 embedded runtime screenshot；手势走 `triton input --json` 的 embedded runtime input。runtime 未连接时返回 `app_runtime_unavailable`，提示启动 `triton serve` 并启动 Debug App。
- 真实设备安装、启动、wait/assert/evidence 仍走 CLI / HTTP 机器可读契约；Web 在没有 bundle id / runtime target 时不猜测启动哪个 App。

## 真机安装与 runtime mirror 验证结论（2026-06-18）

- 已用 Triton-first 路径验证 `Examples/TritonKitDemo/TritonKitDemo.xcodeproj`：`triton xcode discover`、`triton xcode settings` 能发现工程、scheme 与 `.app` 产物路径。
- 真实 iOS device build 首次暴露 Triton 能力缺口：`triton xcode build` 原本不能传递 Xcode 自动签名所需的 `-allowProvisioningUpdates`。本轮已新增 `--allow-provisioning-updates`，schema、CLI fake `xcodebuild` smoke 与真实工程 build invocation 均已验证该参数进入 `sourceCommand`。
- 用户补齐 Xcode signing 后，真机安装与启动已跑通：`triton xcode build --allow-provisioning-updates` 成功产出 Debug `.app`，`triton app install --platform ios --scope real --device ios-real:73f725dfa795` 成功安装，`triton app launch --bundle-id com.neptunekit.tritonkit.demo` 成功启动。
- `triton serve --host 0.0.0.0 --port 19421` 后，真机 Debug App 能连接 embedded runtime；`triton status --json` 返回 `connected=true`、`runtime=embedded`、`targetCount=1`、`activeHierarchyAvailable=true`。
- App runtime screenshot 已验证：`triton screenshot --output /tmp/tritonkit-real-runtime.png --json` 返回 `402x874` PNG；Web bridge `/web/host-screenshot?...source=runtime` 返回 `ok=true`。
- App runtime input 已验证：`printf '{"type":"tap","x":194,"y":330}' | triton input --json --summary --strict` 命中 `UIButton` 并返回 `failedCount=0`；重启 34127 到最新 bridge 后，`POST /web/host-input?...source=runtime` 也返回 `ok=true`。
- Web canvas 拖动滑块已验证：前端拖拽仍统一转为 runtime `swipe`，iOS runtime 对命中的 `UISlider` 走 `slider-drag` 策略并按 end point 计算 value；真机实测 `POST /web/host-input?...source=runtime` 返回 `ok=true`、`strategy=slider-drag`，截图 `/tmp/tritonkit-slider-after-drag.png` 显示进度从 60% 更新到 93%。
- Web 设备列表不再对 iOS 真机 runtime mirror 显示“前台 App 未暴露”：host 真机 discovery 仍不伪造 foreground app identity；当缺少 `appName` 但目标是 iOS 真机时，初始展示为“App runtime 镜像”，runtime 截图成功且 `runtimeScope=app-runtime` 后同步为“App runtime 已连接”。真实 App 名 / bundle id 需要后续补 runtime target identity join 后再展示。
- 真机 runtime 连接需要避免 `127.0.0.1` 默认值。`TritonKitDemo` 现在支持通过 Info.plist build setting `TRITONKIT_DEFAULT_HOST` 注入 Mac 可达 IP；本机实测默认路由 IP `192.168.228.128` 可用，未设置时仍回落到 `127.0.0.1`，保证模拟器路径不变。

推荐的真机验证命令：

```bash
triton serve --host 0.0.0.0 --port 19421

TRITONKIT_DEFAULT_HOST=<mac-lan-ip> \
triton xcode build \
  --project Examples/TritonKitDemo/TritonKitDemo.xcodeproj \
  --scheme TritonKitDemo \
  --configuration Debug \
  --sdk iphoneos \
  --destination 'generic/platform=iOS' \
  --derived-data-path /tmp/tritonkit-real-dd \
  --allow-provisioning-updates \
  --jsonl

triton app install \
  --platform ios \
  --scope real \
  --device <ios-real-target> \
  --app /tmp/tritonkit-real-dd/Build/Products/Debug-iphoneos/TritonKitDemo.app \
  --json

triton app launch \
  --platform ios \
  --scope real \
  --device <ios-real-target> \
  --bundle-id com.neptunekit.tritonkit.demo \
  --json
```

## 验收标准

1. `triton schema --command device --json` 暴露 `--scope real`、`kind=real-device`、三端错误码和 recovery。
2. `triton schema --command app --json` 暴露三端真机 install/launch/open-url 的参数和 failure codes。
3. `triton smoke ios|android|harmony` 的 schema 都能描述 host action 只是提交，wait/assert/evidence 才是业务证明。
4. 无真机环境下 CI 通过 parser/schema/redaction/error-mapping 测试。
5. 有真机环境下，本地 smoke 能生成 `.tritonevidence`，并在 summary 中明确平台、target、runtime/host-layout 证据来源。
