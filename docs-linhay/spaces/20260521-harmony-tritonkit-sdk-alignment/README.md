# 20260521 Harmony TritonKit SDK Alignment

## 背景

用户希望先在 Harmony 方向试跑 embedded SDK 对齐：直接吸收并覆盖 `https://github.com/NeptuneKit/neptune-sdk-harmony`，将该仓库改名为 `harmony-TritonKit`，并保留其发布到鸿蒙中心仓库的能力。目标品牌名为 `TritonKit`。

现有 `neptune-sdk-harmony` 已具备 Harmony HAR library、Demo HAP、OHPM 发布 workflow、本地日志导出、RDB 持久化、gateway discovery、WebSocket client、callback command route 和 ArkUI view tree 采集雏形，适合作为 TritonKit Harmony embedded SDK 的起点。

## 北极星目标

Harmony embedded SDK 的目标与 iOS embedded SDK 保持一致：让 AI 通过 `triton` CLI / 本机管理面直接和 App 内 SDK 沟通，提升 AI 操控 App 的能力边界上限。

这不是单纯把 Neptune 文案替换成 TritonKit，也不是做通用日志 SDK。迁移后必须服务五个闭环：

1. 观察：从 App 进程内读取 Harmony App 状态、日志、ArkUI tree 和 SDK manifest。
2. 解释：让 AI 知道当前 SDK 能采集什么、能执行什么、哪些能力在 Harmony 内置 SDK 边界之外。
3. 执行：逐步承接 App 内安全命令，先从 callback ping / command ack 扩展到可控动作。
4. 验证：通过机器可读 HTTP/CLI 契约判断任务是否完成。
5. 复盘：保留日志、metrics、sources、command ack、错误码和 redaction 状态。

## 目标

1. 将 `NeptuneKit/neptune-sdk-harmony` 吸收为 TritonKit Harmony embedded SDK 基底，目标 GitHub 仓库名为 `harmony-TritonKit`。
2. 保留并验证现有 OHPM/HAR 发布链路，确保后续可发布到鸿蒙中心仓库。
3. 建立包名、品牌名、import path、内部 SDK identity、demo bundle、数据库名、mDNS service 和文档的统一改名策略。
4. 对齐 TritonKit embedded runtime 机器可读契约：manifest、capabilities、logs/sources、command callback、view tree/snapshot、ledger。
5. 明确 host-side Harmony adapter 与 embedded Harmony SDK 的边界，避免把 hdc/uitest/DevEco Emulator 接管能力塞进 App 内 SDK。

## 范围修订

2026-05-21 继续 H6 后，本 space 已开始修改 TritonKit 主仓的 host-side CLI 适配层：新增 direct embedded runtime HTTP 映射，使 `triton` 在 Harmony SDK demo server 尚未接入 `triton serve` 时，也能通过 `--runtime-base-url` 直接访问 `/v2/runtime/*`。因此原“本 space 不直接修改 TritonKit 主仓代码”只适用于最初 H0-H5 Harmony SDK 仓库迁移阶段，H6 同步阶段已纳入 TritonKit 主仓文档、CLI schema、测试和 smoke 脚本。

## 非目标

1. 本 space 不立即发布 OHPM 包，不消耗 `OHPM_PRIVATE_KEY_PEM` 或 `OHPM_PUBLISH_ID`。
2. 不把 Harmony embedded SDK 做成真机/模拟器 host-side 接管工具；host 侧仍由 `triton device/app --platform harmony` 方向负责。
3. 不默认采集敏感存储、剪贴板、账号 token、业务日志正文或全量网络流量。
4. 不破坏当前 iOS embedded SDK S0-S4 未提交改动。

## 当前基线

对 `/tmp/neptune-sdk-harmony` 的只读调研结论：

1. 仓库当前 commit 为 `0c7a752 ci: adopt reusable auto-tag-on-main workflow`。
2. HAR 模块位于 `library/`，源代码源头位于 `src/main/ets/`，同步脚本为 `scripts/sync-harmony-module.sh`。
3. 当前 OHPM 包名为 `neptune-sdk-harmony`，版本为 `1.0.6`，依赖 `@cxy/webserver` 与 `harmony-log`。
4. Demo HAP 位于 `entry/`，通过 `"neptune-sdk-harmony": "file:../library"` 引用本地 HAR。
5. 发布 workflow 为 `.github/workflows/publish-ohpm.yml`，使用 `NeptuneKit/.github/.github/workflows/ohpm-publish.yml@main`，发布源为 `https://ohpm.openharmony.cn/ohpm/`。
6. 已有能力包括 `/v2/export/health`、`/v2/export/metrics`、`/v2/logs`、`/v2/export/sources`、`/v2/ui-tree/inspector`、`/v2/ui-tree/snapshot`、`/v2/client/command`、`POST /v2/clients:register`、gateway discovery 和 `/v2/ws` WebSocket client。

## 命名结论

初步调研发现：OHPM `oh-package.json5` 的 `name` 字段不支持大写 `TritonKit`。本机 OHPM schema 与 validator 均要求包名除 `@` 和 `/` 外只能包含小写字母、数字、下划线和中划线。因此：

1. GitHub 仓库名可以按用户目标使用 `harmony-TritonKit`。
2. README、鸿蒙中心展示文案、SDK identity 和品牌名可以使用 `TritonKit`。
3. OHPM 实际 package id 确认为 `tritonkit`，ArkTS import path 同步使用 `tritonkit`。
4. 如果鸿蒙中心另有展示名字段支持 `TritonKit`，可以将展示名设为 `TritonKit`，但 `oh-package.json5.name` 仍应保持小写。

## BDD 验收场景

### 场景 1：迁移后包身份明确

- Given `harmony-TritonKit` 仓库已完成改名
- When 查看 `library/oh-package.json5`
- Then `name` 使用通过 OHPM 校验的小写 package id
- And `description`、`author`、`repository`、`homepage`、README 和 changelog 均使用 TritonKit 品牌
- And 文档明确“中心展示名 TritonKit”和“实际 package id”的关系

### 场景 2：业务 App 能通过 TritonKit 包导入 Harmony SDK

- Given 业务 Harmony App 配置了新的 OHPM dependency
- When ArkTS 代码导入 SDK
- Then 示例统一使用 `tritonkit`
- And 旧 `neptune-sdk-harmony` import 不再出现在主文档
- And 如保留兼容 alias，必须标注 deprecated 和移除窗口

### 场景 3：HAR 仍可构建并通过现有契约测试

- Given 已完成包名与源码 namespace 改名
- When 运行 Node 契约验证、`ohpm install --all` 和 HAR build
- Then `library/build/**/*.har` 能生成
- And `/v2/export/*`、`/v2/client/command`、`/v2/clients:register`、`/v2/ws`、`/v2/ui-tree/*` 契约仍通过

### 场景 4：发布 workflow 支持干跑

- Given GitHub Actions 已配置发布 workflow
- When 通过 `workflow_dispatch` 传入版本号并启用 dry run
- Then workflow 使用 `scripts/ci/build-ohpm-har.sh <version>` 构建 HAR
- And 跳过真实 `ohpm publish`
- And 产物包含 license、readme、changelog

### 场景 5：Harmony embedded SDK 对齐 TritonKit 机器可读能力

- Given Demo App 启动了 embedded SDK
- When host 或 CLI 访问本地导出服务
- Then 能读取 health、metrics、logs、sources、ui-tree/snapshot
- And 能通过 callback command route 获得稳定 command ack
- And sources 中的 `sdkName` / `appId` / serviceName / databaseName 不再使用 Neptune 默认值

## 初始分期

1. H0：命名与发布可行性调研，确认 OHPM package id 为 `tritonkit`、中心展示名为 `TritonKit`、仓库名为 `harmony-TritonKit`。
2. H1：包元数据与文档改名，保持 API 行为不变。
3. H2：源码 namespace 与 SDK identity 改名，处理 deprecated alias。
4. H3：TritonKit embedded 契约对齐，补 manifest/capabilities/snapshot/ledger 映射。
5. H4：OHPM dry-run 发布链路验证。
6. H5：Demo App 和 smoke 验收，证明业务接入路径可用。
7. H6：TritonKit 主仓文档、public skills、memory 和 release 指南同步。

## 施工状态

截至 2026-05-21，已在独立目标仓目录 `/Users/linhey/Desktop/linhay-open-sources/harmony-tritonkit` 完成首轮 H0/H1/H4 对齐：

1. 固定 OHPM package id 与 ArkTS import path 为 `tritonkit`。
2. 将 HAR 元数据、Demo HAP 依赖、README、library README、AppScope、entry 文案、验证脚本从 Neptune 口径改为 TritonKit 口径。
3. 将公开 logging helper 从 `NeptuneHarmonyLogger` / `createNeptuneHarmonyLogger` / `setNeptuneHarmonyMetadata` 改为 `TritonKitHarmonyLogger` / `createTritonKitHarmonyLogger` / `setTritonKitHarmonyMetadata`。
4. 更新默认 runtime identity：`tritonkit-harmony-demo`、`tritonkit-harmony-export`、`tritonkit_harmony_logs.db`、`_tritonkit._tcp`。
5. `scripts/sync-harmony-module.sh` 已同步 `src/main/ets` 到 `library/src/main/ets`，HAR build 成功生成 `library/build/default/outputs/default/library.har`。

验证结果：

```bash
node scripts/verify-harmony-log-integration.mjs
node scripts/verify-demo-entry.mjs
node scripts/demo-smoke.mjs
node scripts/verify-source-dedup.mjs
node scripts/verify-client-callback-contract.mjs
node scripts/verify-gateway-discovery.mjs
node scripts/verify-gateway-ws-contract.mjs
node scripts/verify-ui-tree-contract.mjs
node scripts/verify-log-persistence.mjs
node scripts/verify-log-query-filtering.mjs
/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm install --all
env PATH=/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin:/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin:/Applications/DevEco-Studio.app/Contents/tools/hvigor:$PATH bash scripts/ci/build-ohpm-har.sh 1.0.6
```

全部通过。系统 PATH 上的 `/Users/linhey/harmonyOS-command-line-tools/bin/ohpm` 缺少 `graceful-fs`，因此本次 HAR 构建显式使用 DevEco Studio 自带 `ohpm 6.0.1`。

继续施工后，H3 已从最小 manifest 扩展为 Harmony runtime loop 对齐：

1. 新增并扩展 `RuntimeManifestResponse`、`RuntimeCapabilityDetail`、`RuntimeLimits`、`RuntimeRedactionPolicy`、`RuntimeLedger*`、`RuntimeSnapshot*`、`RuntimeAppStateResponse`、`RuntimeUnsupportedResponse` DTO。
2. `ExportServer` 新增 `GET /v2/runtime/manifest`、`GET /v2/runtime/snapshot`、`GET /v2/runtime/ledger`、`GET /v2/runtime/state/app`、`GET /v2/runtime/state/scene`、`GET /v2/runtime/state/route`、`GET /v2/runtime/state/responder`、`POST /v2/runtime/action`。
3. capabilities 改为对齐 iOS `TKRuntimeCapabilityName` raw value：`runtime.manifest`、`state.*`、`snapshot`、`semantic.*`、`ledger`、`app.info`、`hierarchy`、`accessibility`、`geometry`、`hit-test`、`screenshot`、`input.*`、`press`、`system-alerts`、`network-breadcrumbs`，并保留 Harmony 现有 `logs`、`sources`、`ui-tree-*`、`client-command`、`gateway-discovery`、`websocket`。
4. HAR 能直接覆盖的能力标 `scope=embedded`、`boundary=app-process`；系统级输入/截图/系统弹窗标 `host-side/simulator-host`；业务网络 breadcrumbs 标 `opt-in-provider/business-opt-in`。
5. Harmony HAR 不能通用实现的 `scene/route/responder`、语义动作、input、screenshot、hit-test 等 endpoint 统一返回 `errorCode=unsupported_runtime_scope`，等待 App provider 或 host-side adapter。
6. 新增 `scripts/verify-runtime-loop-contract.mjs`，并更新 `scripts/verify-runtime-manifest-contract.mjs`、`scripts/demo-smoke.mjs`。
7. HAR 重新构建通过；过程中继续规避 ArkTS indexed access type 限制，使用显式 union/static 字符串类型约束 capability name/scope/boundary。

继续 H6 后，已补 App provider 扩展点：

1. 新增 `RuntimeStateProviderResponse`、`RuntimeSemanticActionRequest`、`RuntimeSemanticActionResponse`。
2. `ExportServer` 新增 `setRuntimeSceneStateProvider`、`setRuntimeRouteStateProvider`、`setRuntimeResponderStateProvider`、`setRuntimeActionProvider`。
3. `scene/route/responder` endpoint 优先返回 App provider 结果；未注册时继续返回 `unsupported_runtime_scope`。
4. `POST /v2/runtime/action` 优先交给 App action provider；未注册或 provider 不处理时返回 `unsupported_runtime_scope`。
5. manifest 中 `state.scene`、`state.route`、`state.responder`、`semantic.*` 会根据 provider 是否注册动态标记 supported。
6. 新增 `scripts/verify-runtime-provider-contract.mjs`，HAR 构建继续通过。

继续 H6 后，TritonKit 主仓已补第一片 host-side direct runtime 映射：

1. 新增共享 `TKEmbeddedRuntimeHTTPRoute`，把 `runtimeManifest`、`stateApp/Scene/Route/Responder`、`runtimeSnapshot`、`runtimeLedger`、`semanticAction` 映射到 Harmony SDK `/v2/runtime/*`。
2. `triton runtime manifest`、`triton state app|scene|route|responder`、`triton snapshot`、`triton ledger`、`triton focus`、`triton set-text`、`triton select-segment`、`triton set-switch` 新增 `--runtime-base-url`。
3. `triton device runtime-url --platform harmony` 新增 HDC fport 准备入口，返回可直接传给 `--runtime-base-url` 的 `baseURL`，并支持 `--probe-manifest` 探测 Harmony runtime manifest。
4. 不传 `--runtime-base-url` 时仍走本机 `triton serve` `/request`；传入后绕过 Triton server，直接调用 embedded HTTP runtime，适合 Harmony SDK demo server 和业务 App provider smoke。
5. 新增 `docs-linhay/scripts/verify-harmony-runtime-base-url-smoke.sh`，使用 mock Harmony runtime 和 fake HDC 验证 CLI schema 暴露、runtime-url、manifest、state route、snapshot、ledger JSONL 和 secure `set-text` provider action。
