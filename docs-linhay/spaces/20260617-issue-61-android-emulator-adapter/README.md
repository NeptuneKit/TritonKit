# 20260617 Issue 61 Android Emulator Adapter

## 背景

GitHub Issue #61 反馈 released CLI 中 `triton device list/doctor --platform android --json` 会被 ArgumentParser 拒绝为 invalid platform，help 也只展示 `ios|harmony`。这会让 agent 无法通过统一 `triton device` surface 发现 Android Emulator，即使仓库内已有 Android ADB parser/runtime 能力。

本 space 只修复 `device` command 的 public platform surface，使 Android Emulator P0 能力和 schema/help/capabilities 保持一致。

## 范围

### 目标

1. `triton device doctor --platform android --json` 可被 CLI 参数层接受，并输出机器可读 JSON。
2. `triton device list --platform android --json` 可被 CLI 参数层接受，并复用现有 Android ADB parser/runtime。
3. `triton device wait-ready --platform android ...` 和 `triton device screenshot --platform android ...` 至少达到现有实现能力与 schema/help 一致。
4. Android target id 继续使用 `android:<adb-serial>`，默认 agent 入口继续优先支持 `--device <selector>`。
5. 未实现能力必须以 stable JSON error 表达 `unsupported_capability`，不能让 ArgumentParser 报 invalid value。
6. Android 失败路径保持机器可读：missing adb、no emulator、ambiguous emulator、offline、unauthorized、screenshot failure 等错误码稳定。

### 非目标

1. 不新增 Android 真机、远端 adb server、设备云或 Web/Wails UI。
2. 不实现新的 app install/open-url 生命周期能力；仅确认既有 schema/help 口径不与 device surface 冲突。
3. 不实现 UIAutomator observe/action、smoke/evidence/replay。
4. 不把 adb 命令成功解释为业务状态通过；后续状态验证仍交给 wait/assert/screenshot/evidence。
5. 本 worker 不运行 `qmd-sync`，也不写 memory；由主控统一集成。

## BDD 验收场景

### 场景一：Android platform 不再被参数层拒绝

- Given 当前 CLI 支持 `device` command
- When agent 执行 `triton device doctor --platform android --json`
- Then CLI 不返回 ArgumentParser 的 invalid platform
- And stdout/stderr 中的结果是 Triton JSON error 或 JSON success envelope
- And 错误码是 stable Triton code，例如 `android_adb_not_found`

### 场景二：Android Emulator list 复用 ADB 输出契约

- Given fake adb 返回一个 ready emulator
- When 执行 `triton device list --platform android --json`
- Then 输出 `ok=true`
- And `targets[0].platform=android`
- And `targets[0].id=android:emulator-5554`
- And `defaultTarget.id=android:emulator-5554`
- And `sourceCommands[]` 记录 adb 命令。

### 场景三：无 emulator 时快速返回机器可读结果

- Given fake adb 可执行但 `adb devices -l` 没有 emulator
- When 执行 `triton device list --platform android --json`
- Then 输出合法 JSON
- And `targets=[]`
- And `defaultTarget=null`
- And `nextAction` 指向 doctor 或启动 emulator 的恢复步骤。

### 场景四：wait-ready / screenshot 的 Android schema 与运行时一致

- Given CLI schema 暴露 `device wait-ready` 和 `device screenshot`
- When agent 使用 `--platform android` 或 `--device android:<serial>`
- Then 参数层接受 Android
- And wait-ready 用 JSON/JSONL 表达 ready/timeout/offline/unauthorized
- And screenshot 输出 artifact envelope，包含 `artifact`、`format=png`、`target`、`sourceCommands[]`

### 场景五：暂不支持能力有稳定 unsupported

- Given 某个 device 子命令当前没有 Android runtime
- When agent 使用 `--platform android --json`
- Then 返回 JSON error `unsupported_capability`
- And `nextAction.category=plan`
- And help/schema/capabilities 不误导 agent 认为能力已覆盖。

## 测试计划

1. 先补 focused tests 证明 `--platform android` 不再由 ArgumentParser invalid value 拒绝。
2. 复用或补充 fake adb fixture，覆盖 `doctor/list/wait-ready/screenshot` 的 success 与关键失败路径。
3. 运行定向 Swift 测试：
   - `swift test --package-path CLI --scratch-path .build/cli --filter DeviceCrossPlatformTests`
   - `swift test --package-path CLI --scratch-path .build/cli --filter FailureDiagnosticsTests`
   - `swift test --filter TKAndroidADBFixturesTests`
   - `swift test --filter TKHostAdapterModelsTests`
4. 若本机没有 adb/emulator，只执行 fake adb/unit/schema 测试并在交付说明中标注未跑真实 emulator smoke。

## 影响面

优先检查并最小修改：

- `Sources/TritonKitShared/TKAndroidADBSupport.swift`
- `Sources/TritonKitCLI/CLIHostDeviceCommands.swift`
- `Sources/TritonKitCLI/CLIHostDeviceRuntime.swift`
- `Sources/TritonKitCLI/CLIAndroidActionRuntime.swift`
- `Sources/TritonKitCLI/CLISchemaHostCommands.swift`
- `Tests/TritonKitSharedTests/TKAndroidADBFixturesTests.swift`
- `Tests/TritonKitSharedTests/TKHostAdapterModelsTests.swift`
- `CLI/Tests/TritonKitCLITests/DeviceCrossPlatformTests.swift`
- `CLI/Tests/TritonKitCLITests/FailureDiagnosticsTests.swift`

## 本轮实现记录

1. `device resolve` 新增 `--device <selector>`，并在 help/schema 中明确 `ios|android|harmony`。
2. `device` schema 增补 Android resolve 示例，screenshot 文案改为 iOS / Android / Harmony 三平台。
3. `device list --platform android` 在 adb 不存在时返回 `android_adb_not_found` JSON error。
4. `device list --platform android` 空列表返回 `targets=[]`、`defaultTarget=null`，并带 `nextAction` 指向 `device doctor --platform android --json`。
5. `device runtime-url/stop --platform android --json` 返回 `unsupported_capability`，不再让 agent 误判为已支持能力。
6. `device screenshot` 的 host artifact 输出保留旧 `artifact` path 字段，并补充 `format` 字段；Android screenshot 未 ready 时优先映射 `android_target_offline` / `android_target_unauthorized` / `android_debugging_disabled`。
7. 顶层 `triton screenshot --platform android ...` 增加并传递 `--adb`，与 `device screenshot` 走同一 Android host adapter。

## 验证记录

已通过：

- `swift build --package-path CLI --scratch-path .build/cli --product triton`
- `swift test --filter TKAndroidADBFixturesTests`
- `swift test --filter TKHostAdapterModelsTests`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
- fake adb CLI smoke：
  - `triton device list --platform android --adb <fake-adb> --json`
  - `triton device wait-ready --platform android --device android:emulator-5554 --adb <fake-adb> --timeout 1 --json`
  - `triton device screenshot --platform android --device android:emulator-5554 --adb <fake-adb> --output <path> --json`
  - `triton device list --platform android --adb <fake-adb-empty> --json`
  - `triton device runtime-url --platform android --device android:emulator-5554 --json`

未完成：

- `swift test --package-path CLI --scratch-path .build/cli --filter DeviceCrossPlatformTests` 当前在编译 CLI test target 时被既有 `WebCommandTests` / `WebLaunchPlan` API 不匹配阻塞，未进入本测试用例执行。
- 本 worker 未执行真实 Android Emulator screenshot/wait-ready smoke；真实 emulator 验收由主控 agent 统一决定。

## 2026-07-11 路线裁决

- 状态：已归档。
- 旧 `WebCommandTests` 编译 blocker 已消失；当前主线 `DeviceCrossPlatformTests` 93 项全部通过，其中包含 Issue 61 Android public P0 command parsing。
- Android Emulator 主链已经在 `20260605-android-emulator-support` 和后续 strong-control 工作中完成真实 smoke。
- 本 space 不再保留独立未完成项；后续 Android 回归统一走现有 emulator takeover 能力。
