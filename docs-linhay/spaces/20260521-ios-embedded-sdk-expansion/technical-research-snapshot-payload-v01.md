# Technical Research: Snapshot Payload v01

## 背景

S2 的目标是让 AI agent 一次读取可决策、可验证、可归档的 App 内状态，而不是分别调用 `state`、`ax`、`geometry` 后自行拼接。该能力必须仍保持 DEBUG-only、App 进程内、机器可读和可控 payload 大小。

## 现有代码入口

- Shared DTO：`Sources/TritonKitShared/TKRuntimeLoopModels.swift`
- Request routing：`Sources/TritonKitShared/TKMessage.swift` 的 `runtimeSnapshot`
- Embedded handler：`Sources/TritonKit/TritonKitRequestHandler.swift` 的 `currentRuntimeSnapshot`
- CLI：`Sources/TritonKitCLI/main.swift` 的 `Snapshot`
- Smoke：`docs-linhay/scripts/verify-intent-cli-smoke.sh`

## 可用公开 API

1. App state 复用 `Bundle`、`Locale`、`ProcessInfo` 与 UIApplication/scene 公开 API。
2. Scene/window/route/responder 复用 S1 已确认的 UIKit 公开 API。
3. AX 与 geometry 复用现有 `currentAccessibilityTree()` 与 `currentGeometry()`。
4. Screenshot 首期只返回 metadata，不在 snapshot 内联图片字节，避免 payload 失控。

## 不可做清单

1. 不读取 SwiftUI 私有 tree。
2. 不读取系统级 SpringBoard/CoreSimulatorBridge 内容。
3. 不在 snapshot 中默认内联截图二进制。
4. 不默认读取剪贴板、UserDefaults、Keychain、网络日志或 App 文件。
5. 不让超大 AX tree 导致 runtime 崩溃或 WebSocket payload 不可控。

## 推荐 DTO / 命令 Shape

```bash
triton snapshot --include app,scene,route,ax,geometry --json
```

响应核心字段：

- `ok/capturedAt/runtime/targetConnectionState`
- `include[]`
- `app/scene/route/responder/geometry/ax/screenshot?`
- `artifacts[]`：每个被采集片段的 `name/capturedAt/freshness`
- `skipped[]`：未采集片段的 `name/reason`
- `truncation`：`truncated/reason/originalCount/returnedCount`

## 测试建议

1. Shared encode/decode 覆盖 snapshot、artifact、skipped、truncation。
2. CLI schema 覆盖 `--include`、`--max-ax-nodes`、默认 JSON 输出。
3. Mock smoke 覆盖 `/request type=runtimeSnapshot`、输出 shape 和 request log。
4. 真实 harness 后续补充超限 AX tree 与 screenshot metadata。

## 风险

1. 复杂页面 AX 节点过多，需要持续验证 `maxAXNodes` 与 truncation 行为。
2. 一次 snapshot 不是严格事务时间点，只能保证同一次请求内尽量相近的采集时间；`artifacts[].capturedAt` 和 `freshness` 必须保留。
3. Evidence/capture 后续纳入 snapshot artifact 时，需要避免重复写入大 payload。
