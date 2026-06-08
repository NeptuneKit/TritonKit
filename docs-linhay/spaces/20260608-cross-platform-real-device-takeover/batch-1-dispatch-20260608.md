# Batch 1 Dispatch - 2026-06-08

## 状态

Batch 1 已完成并通过 Gate 1。当前可声明的是 P0 target 发现、scope/kind 契约、ready 诊断和 schema 机器可读入口已集成；这仍不等价于完整真机接入完成。

下一步进入 Batch 2：App Lifecycle 与 Smoke Evidence，目标是 P1 install / launch / open-url / wait / assert / evidence 的真实设备编排契约。

## Baseline

已完成：

```bash
docs-linhay/scripts/check-docs.sh
/usr/bin/python3 - <<'PY' # real-device subagent TOML parse check
swift build --package-path CLI --scratch-path .build/cli --product triton
```

结果：

- docs 结构校验通过。
- 7 个 real-device subagent TOML 均可解析，且 `sandbox_mode="danger-full-access"`、`approval_policy="never"`。
- CLI `triton` debug build 通过。

注意：

- `swift test --filter DeviceCrossPlatformTests`
- `swift test --filter FailureDiagnosticsTests`
- `swift test --filter EvidenceBundleTests`

以上三个短 filter 在当前 SwiftPM 测试发现方式下均返回 `No matching test cases were run`，不能作为有效 baseline。后续 Gate 1 必须使用 `swift test list` 中的真实测试名，例如 `TritonKitCLITests.DeviceCrossPlatformTests/<case>` 或对应 suite/case 过滤方式。

## Subagents

| Agent | ID | 任务 |
| --- | --- | --- |
| RealContract | `019ea333-4945-7471-9ba5-01b121ec2968` | Contract/schema/DTO/failure-code/evidence contract |
| iOSDevice | `019ea333-7ca2-7863-a1b9-9dea8b1b588f` | iOS real-device `devicectl` P0 |
| ADBReal | `019ea333-7e76-7582-897d-0bf2fb75856d` | Android real-device ADB P0 |
| HDCReal | `019ea333-842c-7410-9c54-89ca2e1b3df8` | Harmony real-device HDC P0 |

## Gate 1

主控合并 Batch 1 后已验证：

```bash
swift test list
swift test --filter 'TritonKitSharedTests.TKHostAdapterModelsTests|TritonKitSharedTests.TKAndroidADBFixturesTests'
swift test --package-path CLI --scratch-path .build/gate1-device --filter DeviceCrossPlatformTests
swift test --package-path CLI --scratch-path .build/gate1-schema --filter SchemaFactSourceTests
swift test --package-path CLI --scratch-path .build/gate1-failure --filter FailureDiagnosticsTests
swift test --package-path CLI --scratch-path .build/cli --filter EvidenceBundleTests
swift build --package-path CLI --scratch-path .build/cli --product triton
.build/cli/debug/triton schema --command device --json
.build/cli/debug/triton schema --command app --json
.build/cli/debug/triton schema --command smoke --json
.build/cli/debug/triton schema --command evidence --json
```

结果：

- Shared Gate：`TKHostAdapterModelsTests` / `TKAndroidADBFixturesTests` 39 tests 通过。
- CLI Device Gate：`DeviceCrossPlatformTests` 23 tests 通过。
- CLI Schema Gate：`SchemaFactSourceTests` 106 tests 通过。
- CLI Failure Gate：`FailureDiagnosticsTests` 7 tests 通过。
- CLI Evidence Gate：`EvidenceBundleTests` 6 tests 通过。
- CLI `triton` debug build 通过。

验收判断已满足：

1. `device` schema 包含 `--scope real`。
2. 三端 target 可表达 `kind=real-device`，并在 output contract 中暴露 `scope`、`kind`、`blockedReasons`、`sensitive`。
3. iOS Simulator、Android Emulator、Harmony DevEco Emulator 旧路径不回归。
4. `app` / `smoke` schema 已暴露 real-device selector 占位，并明确 host action success 不等于业务 ready。
5. `evidence` schema 已包含 `real-device.diagnostics`、`host.app-action`、`runtime.snapshot`、`host.layout`、`build.summary`。
6. 没有真实设备时必须返回空列表、skipped 或 blocked envelope，不崩溃；真实设备 smoke 仍待 Batch 2/3 和本机设备环境验证。

## Batch 2 Dispatch Gate

Batch 2 可以启动：

- App Lifecycle：实现三端 real-device install / launch / open-url / terminate / info/list 的 P1 契约与 fixture。
- Smoke Evidence：实现三端 real-device smoke/evidence proof path；业务通过必须来自 runtime、host layout、wait/assert 或 evidence。

主控约束：

1. App agent 不直接改 smoke/evidence runtime。
2. Smoke Evidence agent 不把 host launch/open-url 成功当作业务通过。
3. 两个 agent 若需要新增 schema 字段，主控在 Gate 2 统一校准 `SchemaFactSourceTests`。
