# SP-127 iOS Real-Device Terminate PID

## 状态与范围

- 状态：执行（安全 fallback 已实现；等待主控 checkpoint 审核）。
- Issue：[#168](https://github.com/NeptuneKit/TritonKit/issues/168)。
- Owner：`linhay`；当前 issue 为 open，无 assignee。
- 基线：`feat/SP-126-testrec-convergence@5f6c2f6f`。
- Branch：`feat/SP-127-issue-168-ios-real-device-terminate-pid`。
- Worktree：`../TritonKit-worktrees/SP-127-issue-168-ios-real-device-terminate-pid/`。
- 影响层：CLI host app lifecycle + `TritonKitShared` iOS `devicectl` command contract。

本 slice 只修复 `triton app terminate --platform ios --scope real --bundle-id <id>` 的 PID / recovery contract。Simulator、Android、Harmony、embedded runtime、evidence/screenshot、testrec/importer、Web/Wails 和第二执行器均不在范围内。

## 已知事实

当前 real-device 路径为 `HostAppTerminate.run` -> `planHostAppTerminate` -> `TKDevicectlCommand.terminateApp`。Xcode 26.6 的本地 help 明确要求 `devicectl device process terminate` 使用 `--device` 与 `--pid`，不能把 bundle ID 作为 positional PID。官方本地模型审计没有证明 bundle ID 到运行 PID 的一一映射，因此本 slice 不实现 `device info processes` 调用、JSON parser 或 PID join，也不从 URL、basename、安装路径、进程名或宿主 `ps` 猜测 PID。

### 官方本地证据与裁决

- `/Applications/Xcode.app/Contents/Developer/usr/bin/devicectl` 仅为 wrapper；实际 CoreDevice binary 为 `/Library/Developer/PrivateFrameworks/CoreDevice.framework/Versions/A/Resources/bin/devicectl`。`strings -a -t x` 在 `0x128150` 指向 `Sources/CoreDevice/devicectl/Commands/Device/Info/Processes.swift`，`0x128220` 为 running-processes 命令说明；`0x12d1f0` 说明 JSON 文件是 versioned/stable script interface，stdout 不是稳定接口。
- `/Library/Developer/PrivateFrameworks/CoreDevice.framework/Versions/A/Frameworks/CoreDeviceClientJSONSupport.framework/Versions/A/CoreDeviceClientJSONSupport` 的本地符号显示 `AppInfo` 只有 `bundleIdentifier`、版本、名称和可选 `url` 等安装元数据，没有 executable 字段；`ProcessInformation` 有可选 `executable: URL?` 与 `processIdentifier: Int32`，没有 bundleIdentifier。`DeviceInfoAppsResult` 与 `DeviceInfoProcessesResult` 也没有官方声明的跨模型 join 或路径正常化规则。
- `xcrun devicectl device info apps --help` 支持精确 `--bundle-id` 及通用 table/JSON field filter；`xcrun devicectl device info processes --help` 只有独立的 processes 查询和通用 filter/columns，没有 `--bundle-id`。help 不能表达已证实的 bundleID -> executable -> PID 链。
- 结论：**no evidence**。因此 real iOS public terminate 在构造任何 terminate 命令前稳定返回 `app_terminate_pid_resolution_unavailable`；不提交 `info processes`，不猜测 PID。若用户选择 `nextAction`，`app launch` 仅是可选冷重启替代操作，不表示 terminate 成功。

本轮 Triton-first 事实：

- `triton status --json`、`doctor --json`、`plan --json`：`ok=false`，`server_unavailable`，endpoint 为 `127.0.0.1:19421`；未启动 server 或连接 runtime。
- `triton capabilities --json`：host-device / iOS real-device contract 可发现，但 live target 未连接。
- 未运行真实设备动作；真实设备不可用时只使用 fake/devicectl adapter tests，不能将环境 blocker 记为通过。

## BDD 场景

### 1. Command builder 只接受明确 PID

给定一个已解析且 ready 的 iOS real-device，以及一个明确的正整数 PID，
当调用 shared `TKDevicectlCommand.terminateApp(identifier:pid:jsonOutput:logOutput:)`，
那么 argv 必须包含 `--device <target> --pid <pid>`，不能携带 bundle ID positional 参数，也不能由 builder 从 bundle ID 猜测 PID。

### 2. Real iOS terminate 在无可证实 PID 时 fail closed

给定 ready 的 iOS real-device 与 bundle ID，
当 lifecycle 发现当前 Xcode/CoreDevice 没有可证实的 bundle ID -> running PID 合同，
那么在构造任何 terminate command 前返回稳定的 `app_terminate_pid_resolution_unavailable`，不调用 `device info processes`，不提交 `devicectl device process terminate`，也不以 URL、basename、路径或进程名猜测 PID。

### 3. Fail-closed 结果提供明确且脱敏的恢复动作

给定 public selector（例如 `ios-real:abc123`）和 raw target（例如 `00008110-PRIVATE`），
当 real-device terminate 被拒绝时，
那么 stdout 只有一个 failure envelope，`message`/`hint` 说明没有 terminate command 被提交；`nextAction` 使用 public selector 生成 `triton app launch --device <selector> --scope real --platform ios --bundle-id <id> --json`。该 launch 只是用户可选择的冷重启替代操作，**不表示 terminate 成功**，且 envelope 不泄露 raw target。

### 4. devicectl 失败保持既有诊断边界

给定 PID 已解析但 devicectl 返回 not found、未信任、锁屏、Developer Mode、DDI 或 target offline，
那么错误继续映射到既有稳定代码和 recovery command，stdout 只输出一个 JSON envelope，不二次包装；terminate command 的 JSON/log artifact 仍按现有 host artifact 规则处理。

### 5. 其他平台和 scope 不回归

给定 iOS Simulator、Android 或 Harmony terminate 请求，
那么继续使用既有 `simctl` / `adb` / `hdc` 路径；本 slice 不改变它们的 argv、错误和输出契约。

## 验收与测试门禁

实现前必须先有 focused failing tests；当前实现与 focused 验证至少覆盖：

1. shared builder 接收显式 PID 并生成精确 `--pid <pid>` argv；
2. real-device plan 在 PID resolution 不可证实时抛出专用错误，且在 builder 前不产生 terminate command；
3. 单 JSON envelope 暴露 code、Xcode/CoreDevice 诊断、public-selector launch nextAction，并锁住 cold-restart 不等于 terminate 成功的语义；raw target 不泄露；
4. app root 与 `terminate` 子命令 schema 都声明该 failure code，子命令 summary 明确 iOS real-device fail-closed 边界；
5. Simulator、Android、Harmony 既有 terminate tests 保持通过。

当前没有可用于证明映射的真实设备 JSON artifact；这不是 parser fixture blocker，而是停止实现 PID join 的官方证据缺口。若未来取得脱敏 artifact，也必须先证明字段语义和一一关系，再另建 slice；本 slice 不新增 parser、resolver、adapter 或 DI。

优先使用 `TritonKitShared` command-builder tests 与 CLI plan/error/schema tests；不启动真实 server，不占用共享 scratch path。验证顺序：

```sh
swift test --scratch-path .build/sp127-issue168-focused-shared --filter TKHostAdapterModelsTests
swift test --package-path CLI --scratch-path .build/sp127-issue168-focused-cli --filter HostAppTerminatePIDTests
swift test --package-path CLI --scratch-path .build/sp127-issue168-focused-cli --filter FailureDiagnosticsTests
swift test --package-path CLI --scratch-path .build/sp127-issue168-focused-cli --filter SchemaFactSourceTests
docs-linhay/scripts/check-docs.sh
git diff --check
```

slice 收口前再按变更范围运行 `docs-linhay/scripts/verify.sh --local` 或明确记录环境 blocker。没有 real device 时，真实 `triton app terminate` smoke 只能记为 blocked，不得记为 passed。

## 实现边界

- 允许修改 shared `TKDevicectlCommand` 的显式 PID command contract、CLI host app terminate fail-closed 控制流和对应 schema/error tests。
- 本 slice 不包含 PID resolver、`device info processes` 调用、JSON parser、adapter 或 DI；不得用宿主 macOS `ps`、安装 App metadata、URL/path/basename 或进程名伪造 iOS App PID。
- iOS real caller 必须在构造 terminate command 前返回专用 unsupported；不能保留以 bundle ID 作为 terminate positional PID 的调用。其他 scope/platform 继续使用既有 builder。
- 不得把 `triton app launch --device <selector> --scope real --platform ios --bundle-id <id> --json` 偷换成 terminate 成功；它只能作为用户明确选择的 optional cold-restart recovery path，且 hint/message 必须明确“不表示 terminate 成功”。
- app root 与 `terminate` 子命令 schema 均声明 `app_terminate_pid_resolution_unavailable`，使 agent 可规划该 fail-closed 分支。
- 不得修改任何 evidence / screenshot / #164 文件，不得混入 #166、#167、serve-Web、testrec/importer、Android 或远端能力。
- 不 push、PR、merge、tag、release、关闭 issue，不清理其他 worktree。

## 停止条件

出现以下任一情况立即停止并报告，而不是扩展范围：

1. Xcode/devicectl 没有可证实的 bundle-ID 到 running PID resolver，且需要新增未经证实的设备协议（本 slice 已据此停止 PID join 并采用 fallback）；
2. 只能通过启动 App、猜测 PID 或宿主进程列表实现，无法保持 terminate 语义；
3. 真实设备不可用且 fake adapter 无法覆盖目标合同；
4. 测试要求改动 evidence/screenshot、testrec/importer、Android、Web/Wails 或第二执行器；
5. 出现与 baseline 无关的共享 scratch、设备状态或服务进程冲突。

## 当前收口状态

- 已实现：shared builder 只接受明确 PID 并生成 `--pid <pid>`；iOS real plan 在 builder 前抛出 `app_terminate_pid_resolution_unavailable`；error detail 使用 public selector，raw target 不进入 envelope；`app` root 与 `terminate` 子命令 schema 均登记该 code。
- 已验证：focused shared/CLI tests 通过；`SchemaFactSourceTests` 全 suite 仍有 baseline 中与本 slice 无关的 schema contract failures，详见当日 memory/最终报告。
- 未完成：真实设备 smoke 被 live target/server 不可用阻塞；本 worktree 保持未 stage、未 commit，等待主控 checkpoint 审核。
