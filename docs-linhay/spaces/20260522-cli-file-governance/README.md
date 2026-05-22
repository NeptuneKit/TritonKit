# 20260522 CLI File Governance

## 背景

用户要求开始治理超过 1500 行的文件，并把 CLI 子命令与独立数据模型文件设计清楚。当前代码热点为：

1. `Sources/TritonKitCLI/TritonKitCLI.swift`：约 9900 行，承载入口、子命令、HTTP client、host adapter helper、输出模型和渲染函数。
2. `Sources/TritonKit/TritonKitRequestHandler.swift`：约 1900 行，承载 embedded runtime HTTP/WebSocket handler 与请求分发。

本轮先治理 CLI，因为近期 iOS / Harmony observe 与 `node resolve` 新增在 CLI 单文件中继续堆叠，最容易放大维护成本。随后补做 `TritonKitRequestHandler.swift`，确保当前 Swift 源文件没有超过 1500 行的热点。

## 目标

1. 以 1500 行作为治理阈值：新增功能不能继续默认塞进单个巨型 Swift 文件。
2. CLI 按命令域拆分：入口只保留 root command 注册和通用能力；子命令放到独立 commands 文件；运行逻辑放 runtime/service 文件；wire 输出模型放 models 文件。
3. 保持 agent-facing CLI JSON/schema 不变。
4. 不借重构改变 iOS / Harmony 本期行为边界：iOS 仍走 DEBUG embedded runtime，Harmony P0 仍走 host layout。

## 已完成拆分

CLI 入口与子命令已按域拆分：

1. `Sources/TritonKitCLI/CLIObservationModels.swift`
   - `ObservationPlatform`
   - `ObserveSourceOutput`
   - `ObserveNodeOutput`
   - `ObserveOutput`
   - `NodeResolveOutput`
2. `Sources/TritonKitCLI/CLIObservationCommands.swift`
   - `observe current`
   - `observe tree`
   - `node resolve`
3. `Sources/TritonKitCLI/CLIObservationRuntime.swift`
   - iOS runtime snapshot observation
   - Harmony host layout observation
   - node resolve filtering / candidate selection
4. `Sources/TritonKitCLI/CLIBuildInfo.swift`
   - `TritonKitBuildInfo.cliVersion`
   - CI version stamping 只 patch 这个小文件，不再 patch CLI 巨型入口文件
5. `Sources/TritonKitCLI/CLIXcodeCommands.swift` / `CLIXcodeModels.swift` / `CLIXcodeRuntime.swift`
   - `xcode discover/use/schemes/settings/build/test/run`
   - Xcode workflow DTO 与 build/test/run streaming helper
6. `Sources/TritonKitCLI/CLIHostCommands.swift` / `CLIHostModels.swift` / `CLIHostRuntime.swift`
   - `sim`、`device`、host-side `app` 系列命令
   - iOS Simulator 与 Harmony HDC host adapter 输出模型
7. `Sources/TritonKitCLI/CLIRuntimeCommands.swift` / `CLIRuntimeRuntime.swift` / `CLIRuntimeTransport.swift`
   - `runtime manifest`、`state`、`snapshot`、`ledger`
   - embedded runtime HTTP client、server HTTP client、capabilities/error rendering
8. `Sources/TritonKitCLI/CLIInspectionCommands.swift`
   - `plan`、`list`、`inspect`、`hierarchy`、`nodes`、`node`、`attrs`、`object`
9. `Sources/TritonKitCLI/CLIEvidenceCommands.swift` / `CLIEvidenceRuntime.swift`
   - `export`、`evidence`、`capture`、`assert`、`record`、`replay`
10. `Sources/TritonKitCLI/CLIActionCommands.swift` / `CLIRegressionRuntime.swift` / `CLITargetingRuntime.swift`
    - `find`、`wait`、`tap`、`swipe`、`type`、`paste`、`clear`、`press`、`geometry`、`ax`、`hit`、`screenshot`、`input`
    - 等待、输入、AX targeting、tap candidate 解析
11. `Sources/TritonKitCLI/CLIServeCommand.swift` / `CLIServerModels.swift` / `CLIServerRuntime.swift`
    - 本地 server command、WebSocket/session state、hierarchy rendering helper
12. `Sources/TritonKitCLI/CLICoreCommands.swift` / `CLICoreModels.swift` / `CLISchemaRuntime.swift`
    - `version/status/doctor/capabilities/schema`
    - 输出格式、语言、中文 help、schema 渲染

同时把原 `main.swift` 改名为 `TritonKitCLI.swift`，避免 SwiftPM executable target 在多源文件下把 `main.swift` 当脚本入口，导致 `@main` 编译失败。

Embedded runtime handler 已按职责拆分：

1. `Sources/TritonKit/TritonKitRequestHandler.swift`
   - 只保留 `TritonKitDelegate`、message routing 与 handler glue。
2. `Sources/TritonKit/TKRuntimeSupport.swift`
   - runtime ledger store、ledger 记录、时间戳、基础 response payload、对象 class chain。
3. `Sources/TritonKit/TKRuntimeInputActions.swift`
   - UIKit input / semantic action dispatch、text input、tap/swipe/clear/focus helper。
4. `Sources/TritonKit/TKRuntimeStateSnapshot.swift`
   - app / scene / route / responder / snapshot 状态采集。
5. `Sources/TritonKit/TKRuntimeAXBuilder.swift`
   - hit test、geometry、screenshot、AX tree builder、UIKit enum/string helper。

## 拆分原则

1. `*Models.swift` 只放 Codable/Encodable/Argument enum 等 wire contract，不执行 host/runtime 动作。
2. `*Commands.swift` 只放 ArgumentParser command、参数定义和调用 glue，不放复杂采集、解析或 I/O。
3. `*Runtime.swift` / `*Service.swift` 放 command 背后的执行逻辑，可调用 shared parser、HTTP client 和 host adapter helper。
4. `TritonKitCLI.swift` 只保留 root command 注册、`@main` 和默认端口常量。
5. 每次迁移必须先跑 schema/smoke，证明命令名、参数和 JSON 输出未回归。

## 当前行数结果

`rg --files -g '*.swift' | xargs wc -l | sort -nr | head -40` 显示当前最高 Swift 文件为：

1. `Sources/TritonKitCLI/CLISchemaRuntime.swift`：1220 行。
2. `Sources/TritonKitCLI/CLIEvidenceRuntime.swift`：1081 行。
3. `Sources/TritonKitCLI/CLIActionCommands.swift`：896 行。
4. `Sources/TritonKit/TritonKitRequestHandler.swift`：379 行。

当前仓库 Swift 源文件均低于 1500 行治理阈值。

## 验收标准

### 场景 1：observe schema 不变

Given CLI 已拆分为多文件  
When 执行 `triton schema --command observe --json`  
Then 返回合法 JSON  
And command name 仍为 `observe`

### 场景 2：node schema 不变

Given CLI 已拆分为多文件  
When 执行 `triton schema --command node --json`  
Then 返回合法 JSON  
And command name 仍为 `node`

### 场景 3：iOS / Harmony observe smoke 不回归

Given observe/node 的命令、模型和执行逻辑已迁出 `TritonKitCLI.swift`  
When 执行本地门禁  
Then iOS runtime observe smoke 与 Harmony host smoke 均通过

### 场景 4：release version stamping 不回归

Given `TritonKitBuildInfo` 已迁出到 `CLIBuildInfo.swift`  
When 执行 version stamping 验证  
Then CI 能继续写入 `cliVersion`

## 当前状态

治理拆分已完成并通过以下验证：

1. `swift build`
2. `swift build --package-path CLI --scratch-path .build/cli --product triton`
3. `swift test`
4. `docs-linhay/scripts/verify-version-stamping.sh`
5. `docs-linhay/scripts/verify-ci-validate-mode.sh`
6. `.build/cli/debug/triton schema --command runtime --json`
7. `.build/cli/debug/triton schema --command snapshot --json`
8. `.build/cli/debug/triton schema --command set-text --json`
9. `.build/cli/debug/triton schema --command observe --json`
10. `.build/cli/debug/triton schema --command node --json`
11. `TRITON_BIN=.build/cli/debug/triton docs-linhay/scripts/verify-ios-runtime-observe-smoke.sh`
12. `TRITON_BIN=.build/cli/debug/triton docs-linhay/scripts/verify-harmony-host-smoke.sh`

注意：CLI scratch 曾缓存旧 dependency source list，导致新增 `TKRuntime*.swift` 未进入 `.build/cli` 的 `TritonKit.build/sources`；已通过 `swift package --package-path CLI --scratch-path .build/cli clean` 刷新，随后标准 `.build/cli` 构建通过。
