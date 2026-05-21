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

## 2026-05-21 Runtime Loop 对齐补充

Harmony embedded SDK 的 runtime loop 对齐策略是“能直接对齐就直接对齐，不能通用推断的能力必须显式 unsupported 或交给 App provider”。

已对齐的 runtime endpoint / capability：

1. `GET /v2/runtime/manifest`
2. `GET /v2/runtime/snapshot`
3. `GET /v2/runtime/ledger`
4. `GET /v2/runtime/state/app`
5. `GET /v2/runtime/state/scene`
6. `GET /v2/runtime/state/route`
7. `GET /v2/runtime/state/responder`
8. `POST /v2/runtime/action`

能力命名对齐 iOS `TKRuntimeCapabilityName` raw value，包括 `runtime.manifest`、`state.*`、`snapshot`、`semantic.*`、`ledger`、`app.info`、`hierarchy`、`accessibility`、`geometry`、`hit-test`、`screenshot`、`input.*`、`press`、`system-alerts`、`network-breadcrumbs`；Harmony 侧保留 `logs`、`sources`、`ui-tree-*`、`client-command`、`gateway-discovery`、`websocket` 等平台能力。

App provider 扩展点：

1. `setRuntimeSceneStateProvider`
2. `setRuntimeRouteStateProvider`
3. `setRuntimeResponderStateProvider`
4. `setRuntimeActionProvider`

provider 注册后，manifest 中 `state.scene`、`state.route`、`state.responder` 和 `semantic.*` 会动态标记为 supported。未注册时继续返回 `unsupported_runtime_scope`，避免把 HAR 无法通用推断的业务语义伪装成已支持能力。

## 验证

新增 `Tests/TritonKitSharedTests/TKHarmonyCollectorModelsTests.swift` 覆盖：

1. DEBUG manifest identity、transport 和 capabilities。
2. Release disabled manifest/configuration。
3. snapshot 复用 `TKGeometryResponse`、`TKAXNode` 和 `TKJSONValue`。
4. screenshot metadata 不包含 `dataBase64`。

Harmony SDK 外部仓本轮补充验证：

1. `scripts/verify-runtime-manifest-contract.mjs`
2. `scripts/verify-runtime-loop-contract.mjs`
3. `scripts/verify-runtime-provider-contract.mjs`
4. 全量 Node contract smoke
5. DevEco `ohpm install --all`
6. `bash scripts/ci/build-ohpm-har.sh 1.0.6`
