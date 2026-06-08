# Batch 4 Line Governance Dispatch - 2026-06-08

## 状态

Batch 4 已完成。它处理 Batch 3 收尾后留下的 Swift 文件超过 1500 行治理项。

本批次目标不是新增真机能力，而是在保持 P0/P1/P2 行为不变的前提下，将超线文件按职责拆分，降低后续维护成本。主控 agent 继续负责需求边界、subagent 调度、集成、验证、docs、memory、qmd 和最终完成判断。

## 超线文件

启动前行数：

| File | Lines | 初步拆分方向 |
| --- | ---: | --- |
| `Sources/TritonKitCLI/CLIHostCommands.swift` | 2775 | Sim / HostApp / Device commands |
| `Sources/TritonKitCLI/CLIHostRuntime.swift` | 2085 | Device runtime / Harmony runtime / process and error runtime |
| `Sources/TritonKitCLI/CLISmokeRuntime.swift` | 1549 | iOS / Android / Harmony smoke runtime |
| `Sources/TritonKitCLI/CLIEvidenceRuntime.swift` | 1803 | Replay / capture / artifact helpers |

## Subagents

| Agent | ID | 写入范围 | 任务 |
| --- | --- | --- | --- |
| HostCommands | `019ea538-fd27-7303-be60-83cdd9ebf6be` | `CLIHostCommands.swift`、`CLIHostSimCommands.swift`、`CLIHostAppCommands.swift`、`CLIHostDeviceCommands.swift` | 将 CLI command declarations 按 Sim / HostApp / Device 拆出，保持参数与输出不变 |
| HostRuntime | `019ea5e7-0387-7d92-ba86-739b8ebf12a9` | `CLIHostRuntime.swift`、`CLIHostDeviceRuntime.swift`、`CLIHostHarmonyRuntime.swift`、`CLIHostProcessRuntime.swift` | 将 device selection、Harmony artifact/emulator、host process/error helpers 拆出 |
| SmokeRuntime | `019ea5e7-4349-7a53-8f1f-d8b5f2606e7e` | `CLISmokeRuntime.swift`、`CLISmokeIOSRuntime.swift`、`CLISmokeAndroidRuntime.swift`、`CLISmokeHarmonyRuntime.swift` | 将三端 smoke runtime 按平台拆出 |
| EvidenceRuntime | `019ea5e7-74ac-71b3-8a43-64f7645470fa` | `CLIEvidenceRuntime.swift`、`CLIEvidenceReplayRuntime.swift`、`CLIEvidenceCaptureRuntime.swift`、`CLIEvidenceArtifactsRuntime.swift` | 将 replay、capture、artifact helpers 拆出 |
| SchemaFactSourceTests | `019ea606-d7bf-76c0-a43a-3e9ff8edcc0e` | `SchemaFactSourceTests.swift`、`SchemaFactSourceWorkflowTests.swift`、`SchemaFactSourceCapabilityTests.swift`、`SchemaFactSourcePlanTests.swift`、`SchemaFactSourceContractTests.swift`、`SchemaFactSourceSurfaceContractTests.swift`、`SchemaFactSourceContractHelpers.swift`、`SchemaFactSourceTaxonomies.swift`、`SchemaFactSourceFixtures.swift` | 将超线 schema fact source 测试按 workflow / capability / plan / contract / fixture 拆出 |

## 约束

1. 不改变 CLI 参数名、schema、JSON/JSONL 输出 shape、failure code、nextAction 或真机行为。
2. 每个 subagent 只写自己的源文件和新增拆分文件，避免互相覆盖。
3. 不回滚当前工作区已有改动。
4. 不拆测试和文档，测试和文档由主控收口。
5. 每个原始超线文件拆分后必须低于 1500 行。

## Gate

主控收口时至少执行：

```bash
wc -l Sources/TritonKitCLI/CLIHostCommands.swift Sources/TritonKitCLI/CLIHostRuntime.swift Sources/TritonKitCLI/CLISmokeRuntime.swift Sources/TritonKitCLI/CLIEvidenceRuntime.swift
swift test --package-path CLI --scratch-path .build/cli --filter 'DeviceCrossPlatformTests|AppOpenURLFlowTests|SmokeRuntimeTests|SmokeAndroidRuntimeTests|SmokeHarmonyRuntimeTests|EvidenceBundleTests|FailureDiagnosticsTests|SchemaFactSourceTests|BuildRuntimeTests|BuildRunnerTests'
swift build --package-path CLI --scratch-path .build/cli --product triton
docs-linhay/scripts/verify.sh --local
docs-linhay/scripts/check-docs.sh
git diff --check
docs-linhay/scripts/qmd-sync.sh
```

## 完成结果

完成后 Swift 文件最大行数：

| File | Lines |
| --- | ---: |
| `Sources/TritonKitCLI/CLIActionCommands.swift` | 1454 |
| `Sources/TritonKitShared/TKReplayPlanModels.swift` | 1349 |
| `Sources/TritonKitCLI/CLIHostAppCommands.swift` | 1336 |
| `Sources/TritonKitShared/TKXcodeWorkflowModels.swift` | 1175 |
| `CLI/Tests/TritonKitCLITests/SchemaFactSourceContractTests.swift` | 1089 |

拆分后的原始超线文件：

| File | Lines |
| --- | ---: |
| `Sources/TritonKitCLI/CLIHostCommands.swift` | 33 |
| `Sources/TritonKitCLI/CLIHostRuntime.swift` | 535 |
| `Sources/TritonKitCLI/CLISmokeRuntime.swift` | 160 |
| `Sources/TritonKitCLI/CLIEvidenceRuntime.swift` | 505 |
| `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift` | 742 |

Batch 4 不新增真机能力；P0/P1/P2 的准确状态保持为：target 发现、app/smoke/evidence 契约、build schema、iOS build 聚合入口、Android/Harmony build runner 已集成。仍不能宣称真实设备 smoke 已通过，因为本机缺 ready iOS/Android/Harmony 真机与真实 Debug artifact。

## 验收判断

完成需要同时满足：

1. 4 个原始超线文件均低于 1500 行。
2. 新拆出的文件职责清晰，且不产生新的超过 1500 行文件。
3. focused gate 和本地门禁通过，或明确记录环境 blocker。
4. space、memory 和 qmd 已写回。
