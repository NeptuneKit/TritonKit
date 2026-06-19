# Cross-Platform Real Device Takeover P0-P3 Plan

## P0：三端真机只读发现与诊断

目标：agent 可以知道三端真机是否存在、是否 ready、为什么不可用。

范围：

1. `HostDevicePlatform` 保持 `ios|android|harmony`，新增 `HostDeviceScope`：`simulator|emulator|real|all`。
2. `HostDeviceTarget` 增加 `scope`、`kind`、`blockedReasons[]`、`sensitive`。
3. iOS `DevicectlAdapter`：doctor/list/wait-ready parser。
4. Android ADB real-device parser：区分 `emulator-*` 与真实 serial，覆盖 unauthorized/offline/device。
5. Harmony HDC real-device parser：区分 DevEco emulator target 与真实 target，覆盖 offline/connected/unauthorized。
6. Alias schema v2 与 migration。
7. Schema、错误码、nextAction、redaction。

测试：

```bash
swift test --filter DeviceCrossPlatformTests
swift test --filter FailureDiagnosticsTests
swift test --filter EvidenceBundleTests
```

验收：

```bash
swift test
swift build --package-path CLI --scratch-path .build/cli --product triton
.build/cli/debug/triton schema --command device --json
docs-linhay/scripts/check-docs.sh
```

## P1：三端 App 安装、启动、open-url、runtime/host wait

目标：已有 Debug artifact 时，三端都能 install/launch/open-url，并用 wait/assert/evidence 证明业务状态。

范围：

1. `triton app install` 支持 iOS `.app` 真机、Android `.apk` 真机、Harmony `.hap` 真机。
2. `triton app launch/open-url/terminate/info` 支持三端真机 selector。
3. `triton smoke ios|android|harmony --device <selector>` 串接 launch/open-url、wait/assert、screenshot/log/evidence。
4. iOS 优先 embedded runtime；Android/Harmony 可使用 embedded runtime 或 host layout fallback。
5. launch/open-url 成功只标记 `hostAction.ok=true`，不标记业务 pass。

测试：

1. 三端 install/launch command builder。
2. 三端 action summary parser。
3. runtime 未连 / host layout 未找到文本失败 envelope。
4. evidence primary artifacts 排序。

验收：

```bash
swift test
swift build --package-path CLI --scratch-path .build/cli --product triton
.build/cli/debug/triton schema --command app --json
.build/cli/debug/triton schema --command smoke --json
```

## P2：三端 build/run 编排

目标：从真实项目源码到真机 smoke 的闭环可由 `triton` 编排。

范围：

1. iOS：`triton xcode use/build/run/test --device <ios-real-selector>`。
2. Android：`triton build android` 包装 Gradle wrapper 或显式 Gradle path。
3. Harmony：`triton build harmony` 包装 hvigor/hvigorw。
4. signing/certificate/profile 失败结构化。
5. build artifact discovery 进入 install/run。

测试：

1. iOS xcode defaults 支持 `sdk=iphoneos` 与 real destination。
2. Android Gradle command builder 和 artifact discovery fixture。
3. Harmony hvigor command builder 和 HAP discovery fixture。
4. signing/certificate/profile 错误映射。

验收：

```bash
swift test
swift build --package-path CLI --scratch-path .build/cli --product triton
.build/cli/debug/triton schema --command xcode --json
.build/cli/debug/triton schema --command build --json
```

## P3：日志、截图、录屏、调试与高级能力

目标：补齐真实回归证据，但保持显式 opt-in。

范围：

1. `triton logs collect/stream --device <selector>` 三端有界采集。
2. Android/Harmony 真机截图接入已稳定 host tool；iOS 只在官方稳定接口确认后接入。
3. 录屏、性能 trace、LLDB/debug 命令显式 opt-in，不进入默认 smoke。
4. uninstall/reboot/sysdiagnose 等高风险能力需要 `--confirm` 与 riskLevel。

验收：

```bash
swift test
.build/cli/debug/triton schema --command logs --json
.build/cli/debug/triton evidence --include host,logs --output /tmp/real-device.tritonevidence --json
```

## 三端手动 smoke 模板

iOS：

```bash
triton device list --platform ios --scope real --json
triton device use ios-phone --platform ios --scope real --json
triton xcode run --device ios-phone --jsonl
triton smoke ios --device ios-phone --bundle-id <bundle-id> --open-url <url> --wait-text <text> --json
```

Android：

```bash
triton device list --platform android --scope real --json
triton device use android-phone --platform android --scope real --json
triton app install --device android-phone --apk /tmp/app-debug.apk --json
triton smoke android --device android-phone --package <package> --open-url <url> --wait-text <text> --json
```

Harmony：

```bash
triton device list --platform harmony --scope real --json
triton device use harmony-phone --platform harmony --scope real --json
triton app install --device harmony-phone --hap /tmp/entry-debug.hap --json
triton smoke harmony --device harmony-phone --bundle <bundle> --ability <ability> --open-url <url> --wait-text <text> --json
```

## Subagent 拆分

项目级 subagent 配置已落在 `.codex/agents/`，调度说明见 `.agents/skills/tritonkit-device-subagent-orchestration/SKILL.md` 的 cross-platform real-device track，具体派发计划见 `plans/20260608-subagent-execution-plan-v01.md`。

| Agent | 阶段 | 主要写入面 |
| --- | --- | --- |
| `tritonkit_real_device_contract_agent` | P0/P1 | schema、DTO、selector、failure code、evidence contract |
| `tritonkit_ios_real_device_agent` | P0 | iOS `devicectl` doctor/list/readiness parser 与 fixtures |
| `tritonkit_android_real_device_agent` | P0 | Android ADB 真机发现、授权状态、ready parser 与 fixtures |
| `tritonkit_harmony_real_device_agent` | P0 | Harmony HDC 真机发现、授权状态、ready parser 与 fixtures |
| `tritonkit_real_device_app_agent` | P1 | 三端 install/launch/open-url/terminate/info |
| `tritonkit_real_device_smoke_evidence_agent` | P1/P3 | 三端 smoke、wait/assert proof、evidence、日志/截图摘要 |
| `tritonkit_real_device_build_agent` | P2 | iOS Xcode 真机 build、Android Gradle、Harmony hvigor build-run |

批次：

1. Batch 1：Contract、iOS Device、Android Device、Harmony Device 可并行。
2. Batch 2：target identity / resolver 稳定后启动 App Lifecycle 与 Smoke Evidence。
3. Batch 3：P0/P1 surface 稳定后启动 Build agent。
