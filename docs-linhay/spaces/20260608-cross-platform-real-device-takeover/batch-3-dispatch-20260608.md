# Batch 3 Dispatch - 2026-06-08

## 状态

Batch 3 已完成 P2 Build / Run 的机器可读契约切片，并补上 iOS 聚合入口与 Android / Harmony 最小实际 build runner。

本记录不表示三端真机接入已完成；当前完成的是 agent 可发现、可规划、可分类失败的 schema 契约，iOS Xcode build 聚合入口，以及 Android Gradle / Harmony hvigor 的 debug artifact build runner。ready 真机补验、真实项目 artifact 验收和 1500 行治理仍是剩余工作。

## 前置 Gate

Batch 3 基于 Batch 1 / Gate 1 与 Batch 2 / Gate 2 通过后启动：

- P0 target 发现、scope/kind、ready 诊断和 schema 入口已集成。
- P1 app lifecycle 与 smoke/evidence proof path 已集成。
- 当前本机 iOS real-device envelope 可列出，但所有目标均 offline / DDI missing；Android / Harmony real-device 列表为空。
- 当前 `triton schema --command xcode --json` 可用。
- 启动 Batch 3 前，`triton schema --command build --json` 返回 `unknown_command_schema`，属于 Batch 3 待补契约。

## Subagents

| Agent | ID | 任务 |
| --- | --- | --- |
| Build | `019ea370-48f7-7193-af44-6e69a0087e81` | P2 iOS Xcode real-device build-run、Android Gradle、Harmony hvigor build-run 契约 |

Build subagent 启动后长时间无响应；主控 interrupt 后仍未收到可集成回报。为避免 Batch 3 停在调度态，主控接管最小 P2 schema 契约切片：

- 新增 `Sources/TritonKitCLI/CLISchemaBuildCommands.swift`。
- 在 `Sources/TritonKitCLI/CLISchemaRuntime.swift` 注册 `build` schema。
- 在 `Sources/TritonKitCLI/CLISchemaXcodeCommands.swift` 增补 iOS real-device `--device`、`sdk=iphoneos` examples、签名/provisioning/DDI 失败码和 `xcode.final.device` 输出字段。
- 在 `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift` 将命令 inventory 更新为 54，新增 `buildSchemasExposeRealDeviceBuildContracts`，并让 `_missing` 失败码归入 project/diagnose recovery。

随后主控再次派发新的 Build subagent `019ea50d-f0d7-7970-b3d8-07a66932c880` 继续 P2 runner；该 agent 超时未返回，关闭时状态仍为 running，但已在关闭前留下半截 `CLIBuildModels.swift` / `BuildRunnerTests.swift`。主控保留并修正这些半截产物，继续接管实现：

- 新增 `Sources/TritonKitCLI/CLIBuildModels.swift`，定义 `CLIBuildRequest`、`CLIBuildPlan`、`TKBuildProgressEvent`、`TKBuildActionSummary` 和 build 专属错误。
- 新增 `Sources/TritonKitCLI/CLIBuildRuntime.swift`，实现 Gradle / hvigor 工具解析、工作目录执行、stdout/stderr log、APK/HAP artifact discovery、diagnostics summary、failure code 和 nextAction。
- 新增 `Sources/TritonKitCLI/CLIBuildCommands.swift`，接入 `triton build ios`、`triton build android` 与 `triton build harmony`。
- 修改 `Sources/TritonKitCLI/TritonKitCLI.swift`，注册 `Build.self` root command。
- 新增并修正 `BuildRuntimeTests` / `BuildRunnerTests`，覆盖 wrapper 解析、artifact discovery、missing tool、missing artifact、non-zero exit summary 与 fake build runner。

当前 `triton build ios` 已作为聚合入口复用既有 Xcode runner，并输出 `TKBuildActionSummary` / `build.ios.summary`；`triton build android` / `triton build harmony` 已是实际 runner。

收尾跑 `verify.sh --local` 时发现一个既有门禁回归：Harmony app install 缺少 `--hap` 时，`ValidationError` 被 `failHostCommand` 归类为 `host_action_failed`，导致 Harmony host smoke 负例失败。主控已将 host-side `ValidationError` 统一映射为 `validation_failed`，并在 `FailureDiagnosticsTests` 增加回归测试。

## 写入边界

Build agent:

- 可写：`Sources/TritonKitCLI/CLIXcode*.swift`、`Sources/TritonKitCLI/CLISchemaXcodeCommands.swift`、`Sources/TritonKitShared/TKXcodeWorkflowModels.swift`、`Tests/TritonKitSharedTests/TKXcodeWorkflowModelsTests.swift`。
- 如新增 cross-platform build 命令，可写：`Sources/TritonKitCLI/CLIBuildCommands.swift`、`Sources/TritonKitCLI/CLIBuildModels.swift`、`Sources/TritonKitCLI/CLIBuildRuntime.swift`、`Sources/TritonKitCLI/CLISchemaBuildCommands.swift` 和对应 CLI tests。
- 可按需更新：CLI root command 注册、schema runtime inventory。
- 禁止：P0 device parser、P1 app lifecycle/smoke/evidence 主流程、签名/证书/profile 资产、真实项目配置。

## 主控追加收口

主控继续补上 `triton build ios` 薄聚合入口：

- `BuildIOS` 复用 `resolveXcodeInvocation` / `runXcodeBuild`，默认将 `--device <udid>` 合成为 `destination=platform=iOS,id=<udid>`，并在有 `--device` 时默认 `sdk=iphoneos`。
- iOS build 输出统一适配为 `TKBuildActionSummary`，`action=build.ios`、`platform=ios`、`artifactKind=app`，成功时给出 `triton app install --platform ios --app <path.app>` nextAction。
- schema 子命令使用 `oneOfRequiredOptions=[["--workspace","--project"]]` 表达 workspace/project 二选一，避免非法复合参数引用。
- `build ios` 的 JSONL 语义收敛为 `build.ios.invocation` / `build.ios.summary`，并通过父 `build.progress` / `build.final` output contract 暴露。
- 缺 workspace/project 时抽样输出稳定 `invalid_workspace_path`，并给出 `triton xcode discover --path . --json` nextAction。

## Gate 3 结果

主控接管并合并最小 schema 切片后完成验证：

```bash
swift test --filter TKXcodeWorkflowModelsTests
swift test --package-path CLI --scratch-path .build/cli --filter SchemaFactSourceTests
swift test --package-path CLI --scratch-path .build/cli --filter 'DeviceCrossPlatformTests|AppOpenURLFlowTests|SmokeRuntimeTests|SmokeAndroidRuntimeTests|SmokeHarmonyRuntimeTests|EvidenceBundleTests|FailureDiagnosticsTests|SchemaFactSourceTests'
swift build --package-path CLI --scratch-path .build/cli --product triton
.build/cli/debug/triton schema --command xcode --json
.build/cli/debug/triton schema --command build --json
.build/cli/debug/triton build android --project <tmp> --gradle <fake-gradle> --variant debug --device android-a --json
.build/cli/debug/triton build harmony --project <tmp> --hvigor <fake-hvigor> --module entry --mode debug --device harmony-a --json
.build/cli/debug/triton build ios --jsonl
docs-linhay/scripts/check-docs.sh
docs-linhay/scripts/qmd-sync.sh
docs-linhay/scripts/verify.sh --local
```

通过结果：

- `TKXcodeWorkflowModelsTests`：13 tests 通过。
- 三端真机 focused CLI gate：8 suites / 153 tests 通过。
- `SchemaFactSourceTests`：107 tests 通过。
- `swift build --package-path CLI --scratch-path .build/cli --product triton` 通过。
- `triton schema --command xcode --json` 抽样确认 `--device`、`iphoneos`、`xcode_signing_failed` 暴露。
- `triton schema --command build --json` 抽样确认 `gradle_not_found`、`hvigor_not_found`、`build.progress`、`build.final` 暴露。
- `triton schema --command build --json` 抽样确认 `ios` 子命令暴露 `oneOfRequiredOptions=[--workspace,--project]`、`build.ios.summary`、`build.progress`、`build.final`。
- `triton build ios --jsonl` 参数负例抽样返回 `action=build.ios`、`platform=ios`、`error.code=invalid_workspace_path`、`nextAction.command=xcode`。
- `FailureDiagnosticsTests`：8 tests 通过，覆盖 host-side `ValidationError -> validation_failed`。
- `BuildRuntimeTests|BuildRunnerTests`：9 tests 通过，覆盖 Android/Harmony build runner。
- `triton build android` fake Gradle smoke 通过，输出 `build.android`、`artifactKind=apk`、`nextAction.command=app`。
- `triton build harmony` fake hvigor smoke 通过，输出 `build.harmony`、`artifactKind=hap`、`nextAction.command=app`。
- P2 runner focused gate：`BuildRuntimeTests|BuildRunnerTests|SchemaFactSourceTests|DeviceCrossPlatformTests|AppOpenURLFlowTests|SmokeRuntimeTests|SmokeAndroidRuntimeTests|SmokeHarmonyRuntimeTests|EvidenceBundleTests|FailureDiagnosticsTests`，10 suites / 163 tests 通过。
- `verify-harmony-host-smoke.sh` 复现点通过。
- `docs-linhay/scripts/check-docs.sh` 通过。
- `docs-linhay/scripts/qmd-sync.sh` 通过。
- runner 落地后重新执行 `docs-linhay/scripts/verify.sh --local` 通过，覆盖 SwiftPM dependency boundary、iOS DEBUG isolation、Swift tests 166 tests、release CLI build/smoke、Harmony host smoke、iOS runtime observe smoke、iOS Simulator build、docs structure 和 git diff whitespace check。

验收判断：

1. 已满足：`xcode` schema 能表达 iOS real-device selector、`sdk=iphoneos` 和 real destination。
2. 已满足：`build` schema 可用，并能表达 iOS Xcode、Android Gradle 与 Harmony hvigor 的 debug artifact discovery。
3. 已满足 runner 层：iOS 聚合入口、Android/Harmony runner 输出包含 source command、artifact path 或稳定失败码、recovery next action。
4. signing / provisioning / keystore / certificate / profile 问题只能诊断和映射错误码，不得自动修改资产。
5. 没有 ready 真机或真实项目 artifact 时，真实设备 build/run 记录为环境 skipped，不宣称实机构建验收通过。

## 剩余风险

1. 真实设备和真实项目 artifact 仍未满足本机实测条件。
2. iOS runner 复用既有 `xcode` build 能力，尚未在本机 ready 真机和真实签名项目上跑通。
3. Android/Harmony runner 已用 fake build tool 验证，仍需真实 Gradle / hvigor 项目 artifact 补验。
4. `CLIHostCommands.swift`、`CLIHostRuntime.swift`、`CLISmokeRuntime.swift`、`CLIEvidenceRuntime.swift` 已超过 1500 行治理线；Batch 3 未拆文件，后续应独立治理。
