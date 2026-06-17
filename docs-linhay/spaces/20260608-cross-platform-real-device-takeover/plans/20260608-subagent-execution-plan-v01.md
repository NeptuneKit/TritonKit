# 三端真机 Subagent 执行计划 v01

## 目标

把当前“三端真机规划”推进为可执行实现队列。主控 agent 负责边界、调度、集成、验证、文档和最终完成判断；subagent 只负责自己清晰的写入面。

本计划不等价于“已经接入真机”。当前完成的是规划、subagent 配置和调度计划；真正实现从 Batch 1 开始。

## 前置条件

1. 主控先确认当前工作区状态，避免覆盖用户未提交改动：

```bash
git status --short --branch
```

2. 若进入多日实现，使用独立 worktree：

```bash
git worktree add ../TritonKit-worktrees/20260608-cross-platform-real-device-takeover -b feat/20260608-cross-platform-real-device-takeover main
```

3. 主控在启动 subagent 前跑 baseline：

```bash
swift test --filter DeviceCrossPlatformTests
swift test --filter FailureDiagnosticsTests
swift test --filter EvidenceBundleTests
swift build --package-path CLI --scratch-path .build/cli --product triton
docs-linhay/scripts/check-docs.sh
```

4. 若 baseline 已因既有代码失败，主控记录失败点，并把对应失败归入第一个 Contract 批次，不让平台 agent 先扩散修复。

## 总体批次

| 批次 | 并行度 | Subagent | 目标 |
| --- | --- | --- | --- |
| Batch 0 | 主控 | Main | 冻结边界、建 worktree、跑 baseline、派发任务 |
| Batch 1 | 4 并行 | Contract / iOS Device / Android Device / Harmony Device | P0 只读发现、scope、ready 诊断 |
| Gate 1 | 主控 | Main | 集成 P0、跑 focused tests、稳定 schema |
| Batch 2 | 2 并行 | App Lifecycle / Smoke Evidence | P1 install/launch/open-url、wait/assert/evidence |
| Gate 2 | 主控 | Main | 集成 P1、跑 schema + smoke mock、更新 docs |
| Batch 3 | 1 串行 | Build | P2 Xcode / Gradle / hvigor build-run |
| Gate 3 | 主控 | Main | 完整门禁、可选真实设备 smoke、memory |

## 文件写入边界

| 区域 | 允许写入 agent | 备注 |
| --- | --- | --- |
| `Sources/TritonKitCLI/CLIHostModels.swift` | Contract 先改；平台 agent 只在 Contract 合并后补字段使用 | 防止 DTO/schema 字段漂移 |
| `Sources/TritonKitCLI/CLISchemaHostCommands.swift` | Contract | App/Smoke 需要 schema 变动先提给 Contract |
| `Sources/TritonKitCLI/CLIHostCommands.swift` | Contract / App，不能同批改同一区域 | 命令入口 glue 由主控合并 |
| `Sources/TritonKitCLI/CLIHostRuntime.swift` | iOS / Android / Harmony / App，按函数区分 | 主控在 Gate 1/2 做冲突整合 |
| `Sources/TritonKitShared/TKHostAdapterModels.swift` | iOS / Harmony shared host models；Contract 仅加通用模型 | 避免平台 parser 混写 |
| `Sources/TritonKitShared/TKAndroidADBSupport.swift` | Android Device / App | Android 真机与 emulator parser 要保持兼容 |
| `Sources/TritonKitCLI/CLISmokeRuntime.swift` | Smoke Evidence | App agent 不直接改 smoke |
| `Sources/TritonKitCLI/CLIEvidenceRuntime.swift` | Smoke Evidence | Evidence taxonomy 变动需同步 Contract |
| `Sources/TritonKitCLI/CLIXcode*.swift` | Build | iOS Device 不改 Xcode build-run |
| `Tests/TritonKitSharedTests/*` | 对应平台 agent / Contract | fixture 命名要带 `real-device` |
| `CLI/Tests/TritonKitCLITests/*` | 对应 agent | focused tests 先红后绿 |
| `docs-linhay/spaces/20260608-cross-platform-real-device-takeover/` | 主控为主；subagent 可追加实现 notes | 最终 docs 由主控收口 |
| `docs-linhay/memory/` / 文档记录 | 主控 | subagent 不写 memory |

## Batch 0：主控准备

主控任务：

1. 确认 `docs-linhay/spaces/20260608-cross-platform-real-device-takeover/` 是需求源。
2. 确认 7 个 subagent 配置均存在且 TOML 可解析：

```bash
/usr/bin/python3 - <<'PY'
import pathlib, tomli
for path in sorted(pathlib.Path('.codex/agents').glob('tritonkit_*real_device*_agent.toml')):
    data = tomli.load(path.open('rb'))
    assert data['sandbox_mode'] == 'danger-full-access'
    assert data['approval_policy'] == 'never'
    print(data['name'])
PY
```

3. 采集 baseline schema：

```bash
.build/cli/debug/triton schema --command device --json > /tmp/triton-device-schema-before.json
.build/cli/debug/triton schema --command app --json > /tmp/triton-app-schema-before.json
```

4. 给每个 subagent 派发独立任务，明确“不得修改”的区域。

## Batch 1：P0 真机发现与 ready 诊断

### Contract Agent

配置：`.codex/agents/tritonkit_real_device_contract_agent.toml`

任务包：

1. 新增或扩展 `HostDeviceScope`：`simulator|emulator|real|all`。
2. 扩展 `HostDeviceTarget`：`scope`、`kind`、`blockedReasons[]`、`sensitive`。
3. 扩展 alias schema v2，但保持旧 `.triton/host-targets.json` 可读。
4. `triton schema --command device --json` 暴露：
   - `--scope`
   - `kind=real-device`
   - `device list/use/resolve/wait-ready --scope real`
   - 三端错误码和 recovery。
5. `triton schema --command app --json` 先暴露 real-device 参数占位。
6. 增加/更新测试：
   - `DeviceCrossPlatformTests`
   - `SchemaFactSourceTests`
   - `FailureDiagnosticsTests`
   - `EvidenceBundleTests`

红灯测试：

```bash
swift test --filter DeviceCrossPlatformTests
swift test --filter SchemaFactSourceTests
swift test --filter FailureDiagnosticsTests
```

交付物：

1. Contract DTO 和 schema 通过 focused tests。
2. 平台 agent 可以基于 `HostDeviceScope` 和 `kind` 编译。
3. 不实现平台 adapter 执行逻辑。

### iOS Device Agent

配置：`.codex/agents/tritonkit_ios_real_device_agent.toml`

任务包：

1. 新增 `TKDevicectlCommand` command builder，覆盖：
   - `list devices`
   - `device info details`
   - `device info apps`
   - `device install app`
   - `device process launch`
2. 新增 devicectl JSON parser fixtures：
   - ready connected device
   - offline device
   - not trusted / developer mode required / locked / DDI missing
   - malformed JSON / missing result.devices
3. 实现 `triton device list --platform ios --scope real --json` 的只读路径。
4. 实现 `triton device wait-ready --device <ios-real-selector> --jsonl` 的轮询 skeleton。
5. iOS target id 默认脱敏为 `ios-real:<hash>`。

主要文件：

1. `Sources/TritonKitCLI/CLIHostRuntime.swift`
2. `Sources/TritonKitShared/TKHostAdapterModels.swift`
3. `Tests/TritonKitSharedTests/TKHostAdapterModelsTests.swift`
4. `CLI/Tests/TritonKitCLITests/DeviceCrossPlatformTests.swift`

不得修改：

1. Android/Harmony adapter。
2. `triton app` lifecycle。
3. Xcode build-run。

交付物：

```bash
swift test --filter TKHostAdapterModelsTests
swift test --filter DeviceCrossPlatformTests
```

### Android Device Agent

配置：`.codex/agents/tritonkit_android_real_device_agent.toml`

任务包：

1. 扩展 `TKAdbDeviceListParser`，区分：
   - `emulator-*` -> `scope=emulator`
   - 真实 serial -> `scope=real`
2. 增加 fake adb fixtures：
   - real authorized
   - unauthorized
   - offline
   - mixed emulator + real
   - package manager unavailable
3. 实现 `triton device list --platform android --scope real --json`。
4. 实现 real-device wait-ready：adb state + `pm path android` 或等价 package manager probe。
5. 保持既有 Android Emulator 测试通过。

主要文件：

1. `Sources/TritonKitShared/TKAndroidADBSupport.swift`
2. `Sources/TritonKitCLI/CLIHostRuntime.swift`
3. `Tests/TritonKitSharedTests/TKAndroidADBFixturesTests.swift`
4. `CLI/Tests/TritonKitCLITests/DeviceCrossPlatformTests.swift`

不得修改：

1. Android app lifecycle。
2. UIAutomator observe / smoke。
3. iOS/Harmony adapter。

交付物：

```bash
swift test --filter TKAndroidADBFixturesTests
swift test --filter DeviceCrossPlatformTests
swift test --filter SmokeAndroidRuntimeTests
```

### Harmony Device Agent

配置：`.codex/agents/tritonkit_harmony_real_device_agent.toml`

任务包：

1. 扩展 HDC target parser，区分 DevEco emulator 与真实 HDC target。
2. 增加 fake HDC fixtures：
   - real connected
   - unauthorized
   - offline
   - booting
   - shell unavailable
   - mixed emulator + real
3. 实现 `triton device list --platform harmony --scope real --json`。
4. 实现 real-device wait-ready：Connected + bootevent + shell probe。
5. 保持既有 DevEco Emulator 测试通过。

主要文件：

1. `Sources/TritonKitCLI/CLIHostRuntime.swift`
2. `Sources/TritonKitShared/TKHostAdapterModels.swift`
3. `CLI/Tests/TritonKitCLITests/DeviceCrossPlatformTests.swift`
4. `CLI/Tests/TritonKitCLITests/SmokeHarmonyRuntimeTests.swift`

不得修改：

1. Harmony app lifecycle。
2. uitest observe / smoke。
3. iOS/Android adapter。

交付物：

```bash
swift test --filter DeviceCrossPlatformTests
swift test --filter SmokeHarmonyRuntimeTests
```

## Gate 1：主控集成 P0

主控合并 Batch 1 后执行：

```bash
swift test --filter DeviceCrossPlatformTests
swift test --filter SchemaFactSourceTests
swift test --filter FailureDiagnosticsTests
swift test --filter TKHostAdapterModelsTests
swift test --filter TKAndroidADBFixturesTests
swift build --package-path CLI --scratch-path .build/cli --product triton
.build/cli/debug/triton schema --command device --json
```

验收：

1. `device` schema 包含 `--scope real`。
2. 三端 target 可表达 `kind=real-device`。
3. emulator/simulator 旧路径不回归。
4. 没有真实设备时返回空列表或 skipped/blocked envelope，而不是崩溃。

## Batch 2：P1 App Lifecycle 与 Smoke/Evidence

### App Lifecycle Agent

配置：`.codex/agents/tritonkit_real_device_app_agent.toml`

任务包：

1. `triton app install --device <selector>` 支持：
   - iOS `.app`
   - Android `.apk`
   - Harmony `.hap`
2. `triton app launch/open-url/terminate/info/list` 支持 real-device selector。
3. host action summary 增加：
   - `proofSource=host-action`
   - `businessReady=false`
   - `nextAction` 指向 wait/assert/smoke/evidence。
4. destructive `uninstall` 保留 `--confirm`。
5. 平台命令输出进入 artifact，不把 raw stdout 当业务契约。

主要文件：

1. `Sources/TritonKitCLI/CLIHostCommands.swift`
2. `Sources/TritonKitCLI/CLIHostRuntime.swift`
3. `Sources/TritonKitCLI/CLIHostOpenURLRuntime.swift`
4. `Sources/TritonKitCLI/CLISchemaHostCommands.swift`，仅按 Contract 已定 schema 补实现细节
5. `CLI/Tests/TritonKitCLITests/DeviceCrossPlatformTests.swift`

不得修改：

1. P0 device parser。
2. smoke/evidence 主流程。
3. build-run。

交付物：

```bash
swift test --filter DeviceCrossPlatformTests
swift test --filter AppOpenURLFlowTests
swift build --package-path CLI --scratch-path .build/cli --product triton
.build/cli/debug/triton schema --command app --json
```

### Smoke Evidence Agent

配置：`.codex/agents/tritonkit_real_device_smoke_evidence_agent.toml`

任务包：

1. 扩展 `triton smoke ios|android|harmony --device <selector>`，识别 real-device target。
2. 输出证明来源：
   - `runtime`
   - `host-layout`
   - `host-action`
3. Android/Harmony 可复用 host layout fallback：
   - Android `uiautomator dump`
   - Harmony `uitest dumpLayout`
4. iOS 真机首期只认 embedded runtime，不承诺 host layout。
5. Evidence primary artifacts 增加：
   - `real-device.diagnostics`
   - `host.app-action`
   - `runtime.snapshot`
   - `host.layout`
   - `screenshot`
   - `logs`
6. 无真实设备时生成 skipped evidence 测试路径。

主要文件：

1. `Sources/TritonKitCLI/CLISmokeRuntime.swift`
2. `Sources/TritonKitCLI/CLISmokeCommands.swift`
3. `Sources/TritonKitCLI/CLIEvidenceRuntime.swift`
4. `Sources/TritonKitShared/TKEvidenceModels.swift`
5. `CLI/Tests/TritonKitCLITests/SmokeAndroidRuntimeTests.swift`
6. `CLI/Tests/TritonKitCLITests/SmokeHarmonyRuntimeTests.swift`
7. 新增 iOS real-device smoke fixture tests

不得修改：

1. P0 device parser。
2. App lifecycle core。
3. build-run。

交付物：

```bash
swift test --filter SmokeAndroidRuntimeTests
swift test --filter SmokeHarmonyRuntimeTests
swift test --filter EvidenceBundleTests
.build/cli/debug/triton schema --command smoke --json
```

## Gate 2：主控集成 P1

主控合并 Batch 2 后执行：

```bash
swift test --filter DeviceCrossPlatformTests
swift test --filter AppOpenURLFlowTests
swift test --filter SmokeAndroidRuntimeTests
swift test --filter SmokeHarmonyRuntimeTests
swift test --filter EvidenceBundleTests
swift build --package-path CLI --scratch-path .build/cli --product triton
.build/cli/debug/triton schema --command device --json
.build/cli/debug/triton schema --command app --json
.build/cli/debug/triton schema --command smoke --json
```

可选真实设备 smoke，只有设备和 Debug artifact 可用时执行：

```bash
.build/cli/debug/triton device list --platform ios --scope real --json
.build/cli/debug/triton device list --platform android --scope real --json
.build/cli/debug/triton device list --platform harmony --scope real --json
```

如果没有真机，主控必须记录为环境 skipped，不宣称真实设备已验收。

## Batch 3：P2 Build / Run

### Build Agent

配置：`.codex/agents/tritonkit_real_device_build_agent.toml`

任务包：

1. iOS：
   - `triton xcode use --device <ios-real-selector>`
   - `triton xcode build --device <ios-real-selector>`
   - `triton xcode run --device <ios-real-selector>`
   - `sdk=iphoneos`
   - signing/provisioning 错误映射
2. Android：
   - `triton build android --project <path> --variant debug --jsonl`
   - Gradle wrapper discovery
   - APK artifact discovery
   - keystore/signing error summary
3. Harmony:
   - `triton build harmony --project <path> --module entry --mode debug --jsonl`
   - hvigor/hvigorw discovery
   - HAP artifact discovery
   - certificate/profile error summary

主要文件：

1. `Sources/TritonKitCLI/CLIXcode*.swift`
2. `Sources/TritonKitShared/TKXcodeWorkflowModels.swift`
3. 新增 `CLIBuild*` 文件时按 1500 行治理拆分
4. `Tests/TritonKitSharedTests/TKXcodeWorkflowModelsTests.swift`
5. 新增 Gradle/hvigor command builder tests

不得修改：

1. P0 device parser。
2. P1 app lifecycle/smoke。
3. signing/certificate/profile 资产和真实项目配置。

交付物：

```bash
swift test --filter TKXcodeWorkflowModelsTests
swift build --package-path CLI --scratch-path .build/cli --product triton
.build/cli/debug/triton schema --command xcode --json
.build/cli/debug/triton schema --command build --json
```

## Gate 3：主控完整验收

主控执行：

```bash
swift test
swift build --package-path CLI --scratch-path .build/cli --product triton
docs-linhay/scripts/verify.sh --local
docs-linhay/scripts/check-docs.sh
docs-linhay/scripts/check-docs.sh
```

手动真机验收矩阵：

| 平台 | 最低真实验收 | 可跳过条件 |
| --- | --- | --- |
| iOS | `device list --scope real` + `wait-ready` + Debug runtime smoke | 无可用 iPhone/iPad、签名资产缺失、未信任 |
| Android | `device list --scope real` + APK install + smoke wait-text | 无可用授权 Android 真机 |
| Harmony | `device list --scope real` + HAP install + smoke wait-text | 无可用授权 Harmony 真机 |

若跳过，必须在交付说明中写明：

1. 缺失平台。
2. 具体 blocker。
3. 已通过的 fixture/mock/schema 替代验证。
4. 后续真实设备补验命令。

## 派发 Prompt 清单

Batch 1：

```text
Use tritonkit_real_device_contract_agent. Implement Batch 1 Contract tasks from docs-linhay/spaces/20260608-cross-platform-real-device-takeover/plans/20260608-subagent-execution-plan-v01.md. Start with red tests. Do not implement platform adapters beyond compile-only stubs.
```

```text
Use tritonkit_ios_real_device_agent. Implement Batch 1 iOS Device tasks from docs-linhay/spaces/20260608-cross-platform-real-device-takeover/plans/20260608-subagent-execution-plan-v01.md. Do not implement app lifecycle or Xcode build-run.
```

```text
Use tritonkit_android_real_device_agent. Implement Batch 1 Android Device tasks from docs-linhay/spaces/20260608-cross-platform-real-device-takeover/plans/20260608-subagent-execution-plan-v01.md. Preserve existing Android Emulator behavior.
```

```text
Use tritonkit_harmony_real_device_agent. Implement Batch 1 Harmony Device tasks from docs-linhay/spaces/20260608-cross-platform-real-device-takeover/plans/20260608-subagent-execution-plan-v01.md. Preserve existing DevEco Emulator behavior.
```

Batch 2：

```text
Use tritonkit_real_device_app_agent. Implement Batch 2 App Lifecycle tasks from docs-linhay/spaces/20260608-cross-platform-real-device-takeover/plans/20260608-subagent-execution-plan-v01.md. Host action success must not be marked as business readiness.
```

```text
Use tritonkit_real_device_smoke_evidence_agent. Implement Batch 2 Smoke Evidence tasks from docs-linhay/spaces/20260608-cross-platform-real-device-takeover/plans/20260608-subagent-execution-plan-v01.md. Business pass must come from runtime, host layout, wait/assert, or evidence.
```

Batch 3：

```text
Use tritonkit_real_device_build_agent. Implement Batch 3 Build tasks from docs-linhay/spaces/20260608-cross-platform-real-device-takeover/plans/20260608-subagent-execution-plan-v01.md. Do not modify signing/certificate/profile assets.
```

## 主控合并规则

1. 每批 subagent 返回后，主控先看 `git diff --stat` 和 focused test 输出。
2. 若两个 subagent 改同一文件，主控按写入面表决定保留方向；不能让 subagent 自行互相覆盖。
3. 每过一个 gate 更新该 plan 的状态记录或新增 implementation note。
4. 只有 Gate 3 通过，才可以宣称“三端真机接入实现完成”。Gate 1 只能宣称“P0 target 发现完成”，Gate 2 只能宣称“P1 App/smoke 闭环完成”。
