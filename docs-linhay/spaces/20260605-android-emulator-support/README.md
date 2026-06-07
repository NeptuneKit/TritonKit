# 20260605 Android Emulator Support

## 背景

TritonKit 当前 emulator takeover 的产品边界是本机 CLI + 本机模拟器/仿真器。iOS Simulator 与 HarmonyOS / DevEco Emulator 已经有统一 `triton device` 入口，Android Emulator 仍只停留在规划 slot。

本 space 用于定义 Android Emulator 支持计划，目标是把 Android 接入同一套 agent-facing CLI 契约，而不是新增 Web/Wails UI、远端 agent、设备云或真机控制链路。

## 目标

1. 通过 `triton device --platform android` 发现、选择、等待和截图本机 Android Emulator。
2. 通过 `triton app --platform android` 覆盖 Debug APK 的安装、卸载、启动、终止、deep link / intent 打开。
3. 通过 host-side Android adapter 输出机器可读 JSON / JSONL、稳定 error code、source command、artifact path 和 recovery nextAction。
4. 在 evidence / smoke / replay 中保留 Android artifact 与 command ledger，且明确区分 host 命令成功和业务状态通过。
5. 为后续 Android embedded runtime 预留 Debug-only 接入边界，但首期不依赖 embedded runtime 才能完成 host-side smoke。

## 非目标

1. 不支持 Android 真机、USB 授权、设备农场、远端 adb server 或多机 agent。
2. 不做 Web/Wails UI、设备大盘、队列、权限系统、多租户或中心服务。
3. 不内置 VLM loop，不把截图理解能力放进 TritonKit core。
4. 不承诺系统安全绕过、root-only 能力、Play Protect 绕过或生产环境采集。
5. 不在 P0 引入 Android embedded SDK；如需 Android App 内 runtime，另行拆分 Debug-only runtime space。

## 产品边界

Android 首期只接本机 Android Emulator，底层工具是 Android SDK / platform-tools：

| 能力域 | 底层工具 | Triton 入口 |
| --- | --- | --- |
| 工具诊断 | `adb version`, `emulator -version` | `triton device doctor --platform android --json` |
| target 发现 | `adb devices -l` | `triton device list --platform android --json` |
| ready 等待 | `adb shell getprop sys.boot_completed`, `pm path android` | `triton device wait-ready --platform android --jsonl` |
| 截图 | `adb exec-out screencap -p` | `triton device screenshot --platform android --output <path.png> --json` |
| app 生命周期 | `adb install`, `pm list packages`, `am start`, `am force-stop`, `pm uninstall` | `triton app ... --platform android --json` |
| UI tree / text | `uiautomator dump`, `adb pull/cat` | `triton ax/wait/tap --platform android --json` |
| 日志 | bounded `adb logcat` | P2 `triton logs/capture --platform android --json` |

## BDD 验收

### 场景一：agent 可以发现 Android Emulator

- Given 本机安装 Android SDK platform-tools
- And 至少一个 Android Emulator 通过 `adb devices -l` 可见
- When 执行 `triton device list --platform android --json`
- Then 输出 `ok=true`
- And `targets[]` 使用统一 `HostDeviceTarget` envelope
- And target id 使用 `android:<adb-serial>`
- And 每个 target 至少包含 `platform/id/target/state/ready/source`

### 场景二：没有 emulator 时返回可恢复诊断

- Given 本机可执行 `adb`
- And `adb devices -l` 没有 emulator target
- When 执行 `triton device list --platform android --json`
- Then 输出合法 JSON
- And `targets=[]`
- And `defaultTarget=null`
- And `nextAction` 指向 `triton device doctor --platform android --json` 或启动 emulator 的文档化恢复步骤

### 场景三：agent 可以等待 Android ready

- Given 一个 Android Emulator 已启动但可能仍在 booting
- When 执行 `triton device wait-ready --platform android --target <adb-serial> --timeout 60 --jsonl`
- Then JSONL 事件持续报告 boot 状态
- And ready 判定至少要求 `sys.boot_completed=1`
- And timeout 时返回 `device_not_ready`，不吞掉底层 adb 错误

### 场景四：agent 可以采集截图证据

- Given Android Emulator 已 ready
- When 执行 `triton device screenshot --platform android --target <adb-serial> --output <path.png> --json`
- Then 写出 PNG artifact
- And 输出包含 `target/sourceCommands/artifact/path/format`
- And artifact 失败时返回 `artifact_write_failed` 或 `android_screenshot_failed`

### 场景五：agent 可以安装并启动 Debug APK

- Given 一个本地 Debug APK
- And Android Emulator 已 ready
- When 执行 `triton app install --platform android --apk <path.apk> --json`
- Then Triton 调用 `adb install -r`
- And 输出不把安装成功误判为业务状态成功

- When 执行 `triton app open-url --platform android <url> --bundle <package> --json`
- Then Triton 调用 `adb shell am start -a android.intent.action.VIEW -d <url> <package>`
- And 后续必须通过 `wait/assert/screenshot/evidence` 验证业务状态

### 场景六：平台能力差异稳定表达

- Given Android 首期不支持某个 iOS/Harmony 专属能力
- When agent 调用对应 CLI
- Then 返回 `unsupported_capability`
- And `nextAction.category=plan`
- And 不回退到裸 `adb` 人读输出

## 分期

详细实施计划见 [20260605-android-emulator-support-plan-v01.md](plans/20260605-android-emulator-support-plan-v01.md)。

逐步执行拆解见 [20260605-android-emulator-execution-breakdown-v01.md](plans/20260605-android-emulator-execution-breakdown-v01.md)。

## 当前进度

截至 2026-06-07，本 space 的 Android host-side P0/P1/P1.5 主链路已经接通，并完成一轮真实 emulator smoke 验收。

- 自动化测试：
  - `swift test --package-path CLI --scratch-path .build/cli`
  - `swift test`
  - Android 定向测试与 schema/fact source 回归已通过；CLI test bundle 在本机偶发命中 macOS system policy 拒载时，需要先执行 `codesign -s - .build/cli/arm64-apple-macosx/debug/TritonKitCLIPackageTests.xctest/Contents/MacOS/TritonKitCLIPackageTests` 再重跑。
- 真实 Android Emulator 环境：
  - AVD: `Neptune_API_34`
  - adb serial: `emulator-5554`
  - alias: `android-a`
- 真实命令验收已通过：
  - `triton device doctor --platform android --json`
  - `triton device list --platform android --json`
  - `triton device wait-ready --platform android --target emulator-5554 --timeout 60 --interval 1 --json`
  - `triton device alias set android-a --platform android --target emulator-5554 --json`
  - `triton app list --platform android --device android-a --json`
  - `triton app launch --platform android --device android-a --package-name com.android.settings --json`
  - `triton observe tree --platform android --target emulator-5554 --json`
  - `triton tap --platform android --target emulator-5554 'Network & internet' --json`
  - `triton device screenshot --device android-a --output <path> --json`
  - `triton smoke android --device android-a --package com.android.settings --wait-text 'Settings' --tap-text 'Network & internet' --post-tap-wait-text 'Internet' --screenshot <path> --evidence <path> --json`

## 本轮真实修复

1. Android app launch 默认路径不再依赖不稳定的 `adb shell monkey -p <package> 1`。
   - 现改为先执行 `adb shell cmd package resolve-activity --brief <package>`，再执行 `adb shell am start -n <resolved-component>`。
   - 真实验证中 `com.android.settings` 已稳定落到 `adb -s emulator-5554 shell am start -n com.android.settings/.Settings`。
2. Android host observe / wait / tap / smoke 不再把 `uiautomator dump` 的 stdout 误当作 XML。
   - 现改为 `uiautomator dump /sdcard/window_dump.xml` 后，再执行 `adb shell cat /sdcard/window_dump.xml` 读取真实 XML。
   - 真实验证中 `wait`、`tap`、`smoke android` 已可稳定解析 UIAutomator tree。
3. Android host `tap` 的文本未命中错误映射已修正。
   - 之前会错误返回 Harmony 专属 `harmony_layout_text_not_found`。
   - 现统一返回 `text_not_found`，并给出 Android host observe 的恢复 hint。

## 真实证据

- 2026-06-06:
  - `screenshots/20260606/android/20260606-android-device-home-after-v01.png`
  - `screenshots/20260606/android/20260606-android-settings-after-v01.png`
  - `screenshots/20260606/android/20260606-android-network-after-v01.png`
  - `screenshots/20260606/android/20260606-android-observe-settings-after-v01.xml`
  - `screenshots/20260606/android/20260606-android-network-after-v01.xml`
- 2026-06-07:
  - `screenshots/20260607/android/20260607-android-network-after-v01.png`
  - `screenshots/20260607/android/20260607-android-smoke-network-after-v01.png`
  - evidence bundle: `/tmp/20260607-android-settings-smoke.tritonevidence`

## 验收备注

- Android host-side `wait`、`tap`、`observe tree` 都会依赖 `uiautomator dump` + `adb shell cat`。
- 同一台 emulator 上不要并发执行多条依赖 UIAutomator dump/read-back 的 host observe 命令；并发压测时曾出现 `Host command exited 137`，串行执行后 `wait -> tap -> post-wait -> screenshot -> smoke` 链路稳定通过。

## 交付物

1. Android host adapter runtime / model / command 分层。
2. `device`、`app`、`ax/wait/tap/screenshot` 的 schema、capabilities 和 failure code 更新。
3. fake adb fixture 与单元测试。
4. 至少一轮真实 Android Emulator smoke 证据。
5. README、`docs-linhay/dev/ai-cli-readable-control.md`、public skill 与 memory 写回。

## 风险

1. Android SDK 安装路径差异较大，P0 必须支持显式 `--adb <path>`，同时在 doctor 中暴露 PATH 探测结果。
2. `adb devices -l` 对 offline / unauthorized / booting 的表达不一致，parser 要先用 fake fixture 锁住。
3. `uiautomator dump` 可能无法覆盖 Compose 语义或 WebView DOM，P1/P2 必须把 host layout 与 app 业务语义区分清楚。
4. Android action 的坐标、密度、导航栏和软键盘会影响 replay 稳定性，首期只承诺明确 selector 或坐标，不承诺智能重定位。
