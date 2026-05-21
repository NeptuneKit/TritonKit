# AI CLI SDK Boundary Technical Research v01

## 背景

目标是让 AI 通过 `triton` CLI 直接和 App 内 iOS embedded SDK 沟通，提升 AI 操控 App 的能力边界上限。这个方向必须先定义边界：哪些能力应该通过 embedded SDK 暴露，哪些能力必须交给 host-side adapter，哪些能力默认禁止或只允许业务 opt-in。

本调研对应 50 轮执行表的第 01、03、04、48 轮，并作为 S0 能力边界的前置产物。

## 现有代码入口

当前可复用入口：

1. `Sources/TritonKitShared/TKMessage.swift`
   - `TKRequestType` 当前支持 `ping/appInfo/hierarchy/input/accessibility/hitTest/screenshot/geometry/allAttrGroups/fetchObject` 等。
   - 尚无 `runtimeManifest/state/snapshot/ledger` request type。
2. `Sources/TritonKit/TritonKitRequestHandler.swift`
   - embedded SDK 端按 `TKRequestType` 分发请求。
   - 当前已处理 `appInfo/hierarchy/input/accessibility/hitTest/screenshot/geometry`。
   - `button/press` 在 embedded runtime 内返回 host-side HID unsupported。
3. `Sources/TritonKitCLI/main.swift`
   - `buildCapabilities` 使用 `/status` 判断 server 与 target 状态，并输出能力矩阵。
   - `runtimeCapabilities` 已区分 connected 依赖，并明确 `press` unsupported。
   - `commandSchemas()` 已为 CLI 命令输出 `requiresServer/requiresTarget/runtimeScope/options/examples/successShape/failureShape/providedCapabilities`。
4. `Sources/TritonKitShared/TKCLITransportModels.swift`
   - `TKCommandSchema` 已具备 `runtimeScope` 和 `providedCapabilities`，适合承载 AI-facing 能力发现。
   - `TKCLIErrorDetail` 已具备 `code/message/endpoint/hint/nextAction`，可作为边界拒绝的统一 envelope。
5. `Sources/TritonKitShared/TKEvidenceModels.swift`
   - evidence manifest 已有 `artifact/skipped/freshness/redactionStatus/sourceCommand/target` 字段，可复用到 snapshot/state/ledger artifact。

## 能力边界矩阵

| 能力 | 应归属 | 原因 | 默认状态 |
| --- | --- | --- | --- |
| SDK manifest、capabilities、schema 发现 | CLI + embedded SDK | AI 需要先知道当前 App 内 SDK 能力和限制 | P0 |
| App/scene/window/route/responder 状态 | embedded SDK | 只能在 App 进程内用公开 UIKit/Foundation API 准确读取 | P0 |
| AX 安全控件树、hit、geometry、screenshot metadata | embedded SDK | 已有基础能力，继续作为 AI App 内观察层 | 已实现/P0 增强 |
| attrs v2：accessibility/responder/control/text/scroll | embedded SDK | 帮 AI 解释控件为何可操作或失败 | P0 |
| focus/set-text/select-segment/set-switch/scroll | embedded SDK | 使用公开 UIKit API，可减少坐标依赖 | P0/P1 |
| press home、App Switcher、Home、系统键盘全局输入 | host-side adapter | 需要 Simulator/HID/系统级权限，App 进程内不应伪装 | unsupported in embedded |
| SpringBoard/CoreSimulatorBridge 系统弹窗 | host-side adapter 或人工 | embedded SDK 只能看到 App 内 view tree | unsupported in embedded |
| install/uninstall/launch/open-url/container/preferences | host-side adapter | 作用对象是 simulator/device 和 App container，不是 App 进程内 | 已归 host-side |
| UserDefaults allowlist | opt-in provider | 业务持久化语义，默认读取风险高 | P2 brainstorm |
| network breadcrumbs | opt-in provider | 默认 hook 网络风险高，必须由业务显式接入 | P2 brainstorm |
| app logs/debug state | opt-in provider | 业务语义和隐私边界必须由业务控制 | P2 brainstorm |
| file artifacts/sandbox dump/keychain/clipboard dump | 禁止或单独 break-glass | 隐私与破坏性风险过高，不适合默认 SDK | out of scope |

## AI-facing 契约要求

### `runtime manifest`

建议新增 embedded request type：`runtimeManifest`。

建议 CLI：

```bash
triton runtime manifest --target triton:local --json
```

建议 JSON shape：

```json
{
  "ok": true,
  "platform": "ios",
  "runtime": "embedded",
  "transport": "embedded-websocket",
  "enabled": true,
  "sdkVersion": "0.1.1",
  "buildConfiguration": "debug",
  "capabilities": [
    {"name": "state.app", "supported": true, "scope": "embedded"},
    {"name": "press", "supported": false, "scope": "host-side", "reason": "Host-side HID is not available in the embedded runtime"}
  ],
  "limits": {
    "maxSnapshotBytes": 1048576,
    "maxAXNodes": 800,
    "maxLedgerEntries": 100
  },
  "redaction": {
    "secureText": "length-only",
    "clipboard": "not-collected",
    "network": "opt-in-only",
    "logs": "opt-in-only"
  }
}
```

Release/no-op shape 必须保持 API 可编译但不可采集：

```json
{
  "ok": true,
  "platform": "ios",
  "runtime": "embedded",
  "transport": "embedded-websocket",
  "enabled": false,
  "buildConfiguration": "release",
  "capabilities": [],
  "redaction": {
    "policy": "disabled-runtime"
  }
}
```

### `capabilities` / `schema`

现有 `runtimeCapabilities` 只有 `name/supported/reason`，适合继续兼容；但为了 AI 决策，需要补强：

1. `scope`: `cli`、`embedded`、`host-side`、`opt-in-provider`、`unsupported`。
2. `requires`: `server`、`target`、`hierarchy`、`runtimeManifest`、`provider`。
3. `boundary`: `app-process`、`simulator-host`、`business-opt-in`、`forbidden`.
4. `nextAction`: 当 unsupported 或 missing runtime 时，给出可执行下一步。

不一定要一次修改 `TKRuntimeCapability` 结构；第一阶段可以先在 `runtime manifest` 内提供增强 capability，并逐步同步到 `capabilities/schema`。

### 统一 unsupported reason

embedded SDK 不应只返回自然语言失败。建议错误分类：

| code | 场景 |
| --- | --- |
| `unsupported_runtime_scope` | 请求属于 host-side 或系统级能力 |
| `runtime_disabled` | Release/no-op 或 SDK 未启用 |
| `target_unavailable` | server 存活但没有 embedded target |
| `runtime_ui_interrupted` | 系统弹窗或非 App UI 遮挡 |
| `ambiguous_target` | selector 命中多候选 |
| `action_not_supported` | 目标控件无公开 API 可执行 |
| `redacted` | 数据存在但按策略不回显 |

## 可用公开 API

P0 可以依赖：

1. `Bundle.main`：bundle id、display name、version/build。
2. `ProcessInfo.processInfo`：uptime、OS 摘要、环境边界。
3. `UIApplication.shared.connectedScenes`：scene/window 列表。
4. `UIWindow`：key window、bounds、safe area、screen scale。
5. `UIViewController` 容器公开 API：presented、navigation、tab、split。
6. `UIView` / `UIControl` / `UIResponder`：可见性、enabled、firstResponder、target/actions。
7. `UITextField` / `UITextView`：placeholder、secure、keyboard traits、editable。
8. `UISegmentedControl` / `UISwitch` / `UISlider` / `UIStepper` / `UIScrollView`：公开状态和控制。

## 不可做清单

1. 不反射 SwiftUI 私有 tree；只输出 `UIHostingController` 和可见 UIKit/AX 线索。
2. 不触发 SpringBoard、Home、App Switcher、系统权限弹窗。
3. 不 dump Keychain、剪贴板、sandbox 文件、UserDefaults 全量。
4. 不默认 hook URLProtocol、URLSession、OSLog。
5. 不在 Release build 采集、上传或响应控制。
6. 不将 host-side simulator 能力伪装成 embedded SDK 能力。

## 推荐实现顺序

1. 新增 shared DTO：`TKRuntimeManifestResponse`、`TKRuntimeCapabilityDetail`、`TKRuntimeLimits`、`TKRuntimeRedactionPolicy`。
2. 新增 `TKRequestType.runtimeManifest`，CLI 通过 `/request` 同步读取。
3. CLI 新增 `triton runtime manifest --json`，并写入 `commandSchemas()`。
4. `capabilities` 暂时保留旧 shape，但新增 manifest 中的增强能力矩阵。
5. Release/no-op 先用 shared DTO 测试固定 shape。
6. 再进入 `state app|scene|route|responder` 和 `attrs v2`。

## 测试建议

1. `TritonKitSharedTests`：
   - manifest DEBUG shape encode/decode。
   - manifest Release disabled shape encode/decode。
   - capability detail 支持 embedded/host-side/unsupported/opt-in-provider。
   - redaction policy 不包含敏感明文。
2. CLI schema tests：
   - `schema --command runtime --json` 暴露 `runtime manifest`。
   - `capabilities --json` 不破坏旧字段。
3. Runtime tests / harness：
   - DEBUG App 返回 `enabled=true`。
   - Release fallback 返回 `enabled=false`。
4. Smoke:
   - 无 server：`triton runtime manifest --json` 返回 server unavailable envelope。
   - 有 server 无 target：返回 target unavailable。
   - 有 target：返回 manifest。

## 风险

1. `capabilities` 旧 DTO 若直接扩字段，可能影响现有 consumer；建议先在 manifest 内承载增强矩阵。
2. Release/no-op 必须在 app-side `#if DEBUG` 外也可编译，但不能触发连接或采集。
3. manifest 不应暴露环境变量、文件路径、App 私有配置。
4. 如果把 host-side 能力写进 embedded SDK capability，需要明确 `scope=host-side` 且 `supported=false`，避免 AI 误调 embedded 路径。

## 结论

S0 首个可执行切片应是 `runtime manifest`，不是直接实现 `focus` 或 `set-text`。理由是 AI 需要先通过 CLI 获得能力边界、限制和 next action，否则后续语义命令失败时仍然无法判断是 SDK 不支持、App 状态不满足、系统 UI 遮挡，还是应该转向 host-side adapter。
