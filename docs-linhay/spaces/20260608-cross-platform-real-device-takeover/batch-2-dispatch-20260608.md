# Batch 2 Dispatch - 2026-06-08

## 状态

Batch 2 已完成并通过主控 Gate 2。当前可声明的是 P1 App Lifecycle 与 Smoke Evidence 的机器可读契约、fixture/mock proof path 和 CLI schema 已集成。

本记录不表示三端真机接入已完成；真实设备 install / launch / smoke 仍依赖本机可用设备、授权状态和 Debug artifact。只有 Gate 3 与真实设备补验完成后，才能声明三端真机接入实现完成。

## 前置 Gate

Batch 2 基于 Batch 1 / Gate 1 通过后启动：

- Shared Gate：`TKHostAdapterModelsTests` / `TKAndroidADBFixturesTests` 39 tests 通过。
- CLI Device Gate：`DeviceCrossPlatformTests` 23 tests 通过。
- CLI Schema Gate：`SchemaFactSourceTests` 106 tests 通过。
- CLI Failure Gate：`FailureDiagnosticsTests` 7 tests 通过。
- CLI Evidence Gate：`EvidenceBundleTests` 6 tests 通过。
- CLI `triton` debug build 通过。
- `triton schema --command device/app/smoke/evidence --json` 已抽样确认 `--scope real`、`kind=real-device`、三端错误码与 real-device evidence taxonomy。

## Subagents

| Agent | ID | 任务 |
| --- | --- | --- |
| App Lifecycle | `019ea356-f7f0-78c0-b07b-b5b6c81ec050` | P1 三端 real-device install / launch / open-url / terminate / info/list |
| Smoke Evidence | `019ea356-f8d8-7ea3-b72d-ad2da5a79d10` | P1 三端 real-device smoke / wait / assert / evidence proof path |

## 写入边界

App Lifecycle agent:

- 可写：`CLIHostCommands.swift`、`CLIHostRuntime.swift`、`CLIHostModels.swift`、`CLISchemaHostCommands.swift` 中 app lifecycle 相关区域。
- 可按需少量写：`TKAndroidADBSupport.swift`、`TKHostAdapterModels.swift` 的 app lifecycle 支撑模型。
- 测试：`AppOpenURLFlowTests.swift`、`DeviceCrossPlatformTests.swift`、`SchemaFactSourceTests.swift`。
- 禁止：`CLISmokeRuntime.swift`、`CLIEvidenceRuntime.swift` 的 smoke/evidence proof 主实现，build-run，签名/证书资产。

Smoke Evidence agent:

- 可写：`CLISmokeRuntime.swift`、`CLISmokeCommands.swift`、`CLISmokeModels.swift`、`CLIEvidenceRuntime.swift`、`CLIEvidenceCommands.swift`、smoke/evidence schema 区域。
- 测试：`SmokeRuntimeTests.swift`、`SmokeAndroidRuntimeTests.swift`、`SmokeHarmonyRuntimeTests.swift`、`EvidenceBundleTests.swift`、`SchemaFactSourceTests.swift`。
- 禁止：app lifecycle host command 主实现，build-run，签名/证书资产。

## Gate 2

主控合并 Batch 2 后已验证：

```bash
swift test --filter 'TritonKitSharedTests.TKHostAdapterModelsTests|TritonKitSharedTests.TKAndroidADBFixturesTests|TritonKitSharedTests.TKRuntimeStateModelsTests'
swift test --package-path CLI --scratch-path .build/cli --filter 'DeviceCrossPlatformTests|AppOpenURLFlowTests|SmokeRuntimeTests|SmokeAndroidRuntimeTests|SmokeHarmonyRuntimeTests|EvidenceBundleTests|FailureDiagnosticsTests|SchemaFactSourceTests'
swift test --package-path CLI --scratch-path .build/cli --filter SchemaFactSourceTests
swift build --package-path CLI --scratch-path .build/cli --product triton
.build/cli/debug/triton schema --command device --json
.build/cli/debug/triton schema --command app --json
.build/cli/debug/triton schema --command smoke --json
.build/cli/debug/triton schema --command evidence --json
```

结果：

- Shared Gate：43 tests 通过。
- CLI focused Gate：8 suites / 152 tests 通过。
- Schema focused recheck：`SchemaFactSourceTests` 106 tests 通过。
- CLI `triton` debug build 通过。
- Schema 抽样已确认：
  - `device/app/smoke` 包含 `--scope real` 示例或用法。
  - `app` output contract 包含 `hostAction.proofSource` 与 `hostAction.businessReady`。
  - `smoke` output contract 包含 `steps[].proofSource`、`steps[].businessReady` 与 `assertions[].proofSource`。
  - `smoke/evidence` 包含 `real-device.diagnostics`。

本机真实设备探测：

```bash
.build/cli/debug/triton device list --platform ios --scope real --json
.build/cli/debug/triton device list --platform android --scope real --json
.build/cli/debug/triton device list --platform harmony --scope real --json
```

结果：

- iOS：`devicectl` 可返回 real-device envelope，共 11 个记录，但均为 offline / DDI missing，不能执行 wait-ready、install、launch 或 smoke。
- Android：real-device 列表为空。
- Harmony：real-device 列表为空。

验收判断已满足：

1. `app` schema 与 tests 能表达三端 `--scope real` install / launch / open-url / terminate / info/list。
2. host action summary 明确 `proofSource=host-action`、`businessReady=false` 或等价机器可读字段/next action。
3. `smoke` schema 与 tests 能表达三端 real-device selector、wait/assert/evidence proof path。
4. Smoke pass 不得只来自 host launch/open-url 成功，必须来自 runtime、host layout、wait/assert 或 evidence。
5. `evidence` manifest 能记录 real-device diagnostics、host app action、runtime snapshot、host layout、截图/日志 summary 或 skipped reason。
6. 没有 ready 真机时，fixture/mock/schema 验证通过；真实设备 smoke 记录为环境 skipped，不宣称实机已验收。

## 剩余风险

1. 真实设备 smoke 未跑：当前环境没有 ready iOS 设备，Android/Harmony 无 real-device target。
2. P2 build-run 未开始：Xcode real-device build、Gradle APK、hvigor HAP 仍待 Batch 3。
3. `CLIHostCommands.swift`、`CLIHostRuntime.swift`、`CLISmokeRuntime.swift`、`CLIEvidenceRuntime.swift` 已超过 1500 行治理线；本轮为控制风险未拆文件，Batch 3 或收尾应安排拆分治理。
