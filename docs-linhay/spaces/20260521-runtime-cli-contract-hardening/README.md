# 20260521 Runtime CLI Contract Hardening

## 背景

本需求来自对近期实现的代码审视。当前 TritonKit 已推进 iOS embedded runtime、Harmony direct runtime、host-side HDC adapter、Xcode workflow takeover 和 WebView / whole-app 联合观测规划。整体方向成立，但已有实现里出现了几类会影响 AI agent 稳定使用的契约问题：

1. CLI JSON 输出在失败路径上可能出现多段输出，破坏机器可读性。
2. direct runtime 与 Triton server runtime 的参数语义不完全一致，部分参数会被静默丢弃。
3. Harmony snapshot 的 `include` 查询参数在 CLI 层看起来支持，但 standalone Harmony SDK 当前未实际裁剪。
4. shared snapshot DTO 偏 iOS embedded 形态，后续 Host + Runtime 融合和 Harmony viewTree / inspector 归档可能需要更中性的 artifact 模型。
5. `xcode run` 仍需要后置 `showBuildSettings` 解析 product，长任务体验还有优化空间。
6. direct runtime HTTP client 缺少显式 timeout 和更清晰的 runtime unavailable / timeout 错误码。

本 space 把这些问题保存为独立优化需求，不阻塞当前 WebView Runtime Bridge 本期规划，但后续进入实现时应优先消除 P0 契约风险。

## 目标

让 TritonKit CLI / HTTP / direct embedded runtime 在失败、参数、输出和超时方面更适合 AI agent 稳定调用：

1. 所有 JSON 命令一次 invocation 只输出一个 JSON value 或一组合法 JSONL lines。
2. direct runtime 和 server runtime 对同一 CLI 参数给出一致语义；无法支持时明确返回 unsupported，而不是静默忽略。
3. Harmony direct runtime 的 snapshot/include 语义与 SDK 能力一致。
4. 为后续 Host + Runtime 联合观测预留平台中性的 snapshot artifact / source 模型。
5. Xcode workflow 长任务继续保持可观测，减少不必要后置阻塞。
6. direct runtime 连接失败、超时、HTTP 错误都有稳定错误码和可操作 hint。

## 范围

### In Scope

1. 修复 semantic action 失败路径的 JSON 输出一致性。
2. 梳理 `focus` / `set-text` / `select-segment` / `set-switch` 在 `--runtime-base-url` 下的 `--index`、`--within`、`--at` 支持边界。
3. 调整 `TKSemanticActionRequest` 或 CLI validation，让 direct runtime 参数不再静默丢失。
4. 对 Harmony `/v2/runtime/snapshot` 的 `include` / `maxAXNodes` 建立真实契约：实现支持或明确 best-effort / unsupported。
5. 设计 snapshot artifact/source 扩展，覆盖 iOS `ax/geometry`、Harmony `viewTree/inspector`、host `layout/screenshot`、WebView `descriptor/dom/events`。
6. 为 direct runtime HTTP client 增加 timeout 参数和统一错误 envelope。
7. 为 `xcode run` 增加 product override 或缓存策略，降低 `showBuildSettings` 后置阻塞。
8. 更新 CLI schema、README、相关 public skills、smoke tests 和 memory。

### Out of Scope

1. 不在本需求内实现 WebView bridge 本身。
2. 不恢复 Web/Wails UI。
3. 不引入远端 agent、设备云或多租户服务。
4. 不把 Harmony host-only layout 伪装成 Web DOM / JS runtime。
5. 不重构全部 CLI 到多文件结构，除非实现过程中已形成明确必要性。

## 问题清单

### P0：semantic action 失败输出可能不是单一 JSON

当前 `runSemanticActionRequest` 会先打印 `TKSemanticActionResponse`，如果 `ok=false` 再抛错；外层 catch 又会调用 `failCommand` 输出错误 envelope。JSON 模式下，这可能导致一次命令输出两个 JSON 对象。

验收标准：

1. Given runtime provider 返回 `ok=false`
2. When 执行 `triton set-text ... --json`
3. Then stdout 只包含一个合法 JSON object
4. And exit code 非 0
5. And JSON 中保留 provider 的 `action/strategy/error/message/redaction` 或等价错误详情

### P0：direct runtime selector 参数被静默丢弃

`--runtime-base-url` 分支当前只向 provider 传 `x/y`、selector、text 等字段。`--index` 和 `--within` 已被 CLI 解析，却没有进入 `TKSemanticActionRequest`；如果用户传这些参数，provider 无法消歧。

验收标准：

1. Given 用户传 `--runtime-base-url` 和 `--within x,y,w,h`
2. When provider 支持 bounds selector
3. Then request body 包含 bounds 信息
4. When provider 或 shared contract 不支持该参数
5. Then CLI 返回明确 `unsupported_selector_constraint`，不能静默忽略

### P1：Harmony snapshot include 语义不一致

CLI direct runtime 会把 `snapshot --include app,route` 转为 query，但当前 Harmony SDK `/v2/runtime/snapshot` 没有读取 query，而是聚合全部 runtimeSnapshot。

验收标准：

1. Given `triton snapshot --runtime-base-url ... --include app,route --json`
2. Then 输出的 `include/artifacts/skipped` 与 SDK 实际处理一致
3. And 如果 SDK 不支持裁剪，manifest/schema 或 response 明确标记 `includeMode=best-effort`

### P1：snapshot DTO 需要支持多来源 artifact

当前 shared `TKRuntimeSnapshotResponse` 更适合 iOS embedded runtime。后续 Host + Runtime 联合观测需要表达 host-layout、runtime-tree、webview-provider、screenshot 等来源，并保留 source confidence / missing source。

验收标准：

1. snapshot response 能表达 `sources[]`
2. 每个 artifact 能表达 `name/source/capturedAt/freshness/available/reason`
3. Harmony viewTree / inspector 不需要塞进 iOS `ax` 字段
4. 旧 iOS response 仍保持兼容

### P2：xcode run 后置 product 解析可优化

`triton xcode build` 已修复成功 summary 后不再隐式 `showBuildSettings`，但 `triton xcode run` 仍需要解析 app path / bundle id。长工程中后置 settings 仍可能成为等待点。

验收标准：

1. `triton xcode run --app-path <path> --bundle-id <id>` 可跳过后置 settings
2. 未传 override 时仍保留现有 build/settings/install/launch JSONL 事件
3. settings timeout 失败时错误 hint 指向 `--app-path/--bundle-id` workaround

### P2：direct runtime HTTP timeout 与错误码

direct runtime client 使用默认 `URLSession.shared`，缺少命令级 timeout。Harmony runtime 未启动、端口映射失效或 provider 卡住时，agent 难以快速判断下一步。

验收标准：

1. runtime/state/snapshot/ledger/semantic action 支持 `--timeout`
2. 连接失败返回 `runtime_unreachable`
3. 超时返回 `runtime_timeout`
4. HTTP 非 2xx 保留 status、body 摘要和 endpoint

## 建议实施顺序

1. R0：补失败测试，锁定 semantic action 单 JSON 输出和 direct runtime 参数丢失。
2. R1：修复 `TKSemanticActionRequest` / CLI validation / mock smoke。
3. R2：对齐 Harmony snapshot include 契约，必要时同步 `harmony-tritonkit`。
4. R3：新增 direct runtime timeout 与错误码。
5. R4：设计 snapshot source/artifact 扩展，为 Host + Runtime 联合观测铺路。
6. R5：补 `xcode run --app-path/--bundle-id` 优化。

## 验证策略

1. Swift 单元测试覆盖 shared model、CLI command request、error envelope。
2. `verify-harmony-runtime-base-url-smoke.sh` 增加 provider 失败、selector constraints、timeout mock。
3. `verify.sh --local` 覆盖 semantic action 单 JSON 输出。
4. 如涉及 Harmony SDK，同步运行 `harmony-tritonkit` Node contract smoke 和 HAR build。
5. 不需要真实模拟器即可完成 P0/P1 mock contract；真实 DevEco Emulator 只在验证 runtime-url / host adapter 时使用专用 target。

## 当前状态

已记录需求，尚未进入实现。当前本期 WebView / whole-app 联合观测规划可以继续推进；本 space 作为后续 hardening backlog。
