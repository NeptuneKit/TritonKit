# Harmony Collector Contract

## 决策

Harmony P0/P1 继续优先走 host-side HDC / DevEco adapter；DEBUG-only 内置采集器只作为后续增强，不阻塞 `triton device doctor/list/use/wait-ready --platform harmony` 和后续 UI 自动化。

本轮只在 `TritonKitShared` 固化可复用 JSON 契约，不新增 ArkTS/ArkUI 工程，也不声明已经具备 Harmony App 内 runtime。

## 契约类型

- `TKHarmonyCollectorManifest`：描述 collector identity，固定 `platform=harmony`、默认 `transport=embedded-websocket`。
- `TKHarmonyCollectorConfiguration`：描述 DEBUG/Release 启停、endpoint、redaction policy 和截图策略。
- `TKHarmonyCollectorSnapshot`：承载 App、页面、geometry、accessibility、screenshot metadata、redaction status 和 extras。
- `TKHarmonyCollectorAppInfo` / `TKHarmonyCollectorPageState`：承载 bundle、ability、page、route 和自定义状态。
- `TKHarmonyCollectorScreenshotMetadata`：只承载 `format/width/height/scale/dataRef`，不内联 base64 图片正文。
- `TKHarmonyCollectorRedactionStatus`：承载 policy、status、redacted fields 和 notes。

## DEBUG / Release 边界

- DEBUG 默认 `enabled=true`，capabilities 包含 `app-info`、`view-snapshot`、`accessibility`、`geometry`、`screenshot-metadata`。
- Release 必须 `enabled=false`，capabilities 为空，且不采集 UI、截图、日志、路由状态或 extras。
- Release API surface 可以保持可编译，便于业务 App 统一接入，但行为必须 no-op。

## 与 Host Adapter 的分层

Host-side Harmony adapter 的 transport 是 `hdc`，负责设备发现、启动状态、App lifecycle、UI 输入、截图、日志和 evidence/capture。Embedded collector 的 transport 是 `embedded-websocket`，只在业务 App DEBUG 包内提供更高质量的 App 内状态快照。

二者可以在 evidence/capture 中汇合，但 source、transport、risk/policy 和 redaction status 必须分开记录。

## 验证

新增 `Tests/TritonKitSharedTests/TKHarmonyCollectorModelsTests.swift` 覆盖：

1. DEBUG manifest identity、transport 和 capabilities。
2. Release disabled manifest/configuration。
3. snapshot 复用 `TKGeometryResponse`、`TKAXNode` 和 `TKJSONValue`。
4. screenshot metadata 不包含 `dataBase64`。
