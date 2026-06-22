# Issue #85：Harmony DevEco device/build workflows

## 背景

GitHub issue #85 反馈，真实 Dxyer Harmony smoke 中，agent 已按 Triton-first 使用 `triton device` / `triton build harmony`，但遇到三类 Harmony / DevEco workflow 缺口：

1. `device start --platform harmony` 在 DevEco Emulator 首次协议确认阻塞时仍返回 `ok=true`、`started=true` 和 PID；后续 `wait-ready` 才失败为 `harmony_target_offline`。
2. `device stop --platform harmony` 失败时返回 iOS/Xcode/simctl 导向的 recovery hint，不适用于 Harmony HVD。
3. `build harmony` 只生成 `hvigor.js --mode entry@debug assembleHap`，不支持该 DevEco 项目验证通过的 `node hvigor.js assembleApp --no-daemon -p product=default -p buildMode=debug` 与显式 JBR/SDK 环境。

## 范围

本 space 只处理本机 Harmony Emulator / DevEco build 的 CLI 合同：

- Harmony `device start` 的首次协议阻塞识别与机器可读错误；
- Harmony `device stop` 的平台化 recovery hint；
- Harmony `build` 的 DevEco assembleApp 参数与环境合同；
- schema / tests / memory 同步。

不处理真机、远端 agent、设备云、Web/Wails UI 或自动接受第三方协议的默认行为。

## BDD 场景

### 场景 1：Emulator 首次协议阻塞

- Given DevEco Emulator stdout/stderr 日志包含协议确认提示或 `Please agree to the agreement first`
- When agent 执行 `triton device start --platform harmony --json`
- Then CLI 返回 `ok=false`
- And error code 为 `emulator_license_agreement_required` 或同等 Harmony 专用机器码
- And 不把该状态报告为 actionable `started=true`
- And hint 指向显式协议确认或后续 opt-in 参数，而不是继续等待 HDC ready

### 场景 2：Harmony stop 失败提示

- Given `device stop --platform harmony` 底层 launchctl / service stop 失败
- When CLI 返回错误
- Then hint 必须指向 Harmony HVD / DevEco Emulator / HDC 检查路径
- And 不出现 Xcode / simctl / simulator UDID / bundle id 导向提示

### 场景 3：DevEco assembleApp build

- Given Harmony 项目要求 `node hvigor.js assembleApp --no-daemon -p product=default -p buildMode=debug`
- And 需要显式 `JAVA_HOME` 与 `DEVECO_SDK_HOME`
- When agent 执行 `triton build harmony` 并提供对应选项
- Then CLI 生成 verified DevEco command shape
- And 支持 app-level artifact discovery
- And JSON summary 保留 sourceCommand、环境来源、artifact path 或稳定错误码

## 验收标准

1. 有测试覆盖 Emulator 协议阻塞日志识别，且不会返回成功 started 状态。
2. 有测试覆盖 Harmony stop 失败 hint，不再使用 iOS/Xcode/simctl 文案。
3. 有测试覆盖 DevEco assembleApp command shape：node、JAVA_HOME、DEVECO_SDK_HOME、assembleApp、--no-daemon、product、buildMode。
4. CLI schema 暴露新增 Harmony build/device 选项、failure code 或 output contract 字段。
5. focused Swift tests、docs-linhay/scripts/check-docs.sh、git diff --check 通过。

## 2026-06-22 实现记录

- `triton build harmony` 新增 DevEco / hvigor.js 合同参数：`--node`、`--java-home`、`--deveco-sdk-home`、`--product`、`--task`、`--no-daemon`。
- 默认 Harmony build 行为保持兼容：未显式传入 DevEco 选项时仍生成 `hvigorw|hvigor --mode <module>@<mode> assembleHap`。
- 显式 DevEco 路径时支持 `node <hvigor.js> assembleApp --no-daemon -p product=<name> -p buildMode=<mode>`，并把 `JAVA_HOME`、`DEVECO_SDK_HOME`、`PATH=<JAVA_HOME>/bin:$PATH` 注入 build process；`sourceCommand` 同步包含环境前缀，便于 agent 审计。
- `triton device start --platform harmony` 在 detached 启动后会读取显式 stdout/stderr log，若识别到 DevEco 首次协议确认提示，则输出 `emulator_license_agreement_required`，不继续报告 actionable `started=true`。
- `triton device stop --platform harmony` 的 launchctl / DevEco Emulator stop failure 现在映射为 `harmony_emulator_stop_failed`，hint 指向 Harmony HVD、DevEco Emulator、launchd label/domain 与 `--skip-launchd` 排查路径，不再落到 iOS/Xcode/simctl 通用提示。
- `triton schema --command build --json` 已暴露新增 Harmony build 参数与 DevEco assembleApp 示例；`triton schema --command device --json` 已暴露 `emulator_license_agreement_required` 与 `harmony_emulator_stop_failed`。

验证命令：

- `swift test --package-path CLI --scratch-path .build/issue-85-tests --filter BuildRunnerTests`
- `swift test --package-path CLI --scratch-path .build/issue-85-tests --filter DeviceCrossPlatformTests`
- `swift test --package-path CLI --scratch-path .build/issue-85-tests --filter BuildRuntimeTests`
- `swift test --package-path CLI --scratch-path .build/issue-85-tests --filter SchemaFactSourceTests`
- `.build/issue-85-tests/arm64-apple-macosx/debug/triton schema --command build --json`
- `.build/issue-85-tests/arm64-apple-macosx/debug/triton schema --command device --json`
- `swift build --package-path CLI --scratch-path .build/issue-85-tests --product triton`
