# Technical Research: Neptune SDK Harmony Inventory v01

## 背景

用户指定 Harmony embedded SDK 先吸收 `https://github.com/NeptuneKit/neptune-sdk-harmony`，目标改名为 `harmony-TritonKit`，并保留发布到鸿蒙中心仓库的能力。本调研只读盘点 `/tmp/neptune-sdk-harmony`，用于制定迁移计划。

## 仓库基线

- 临时路径：`/tmp/neptune-sdk-harmony`
- 当前分支：`main`
- 当前 commit：`0c7a752 ci: adopt reusable auto-tag-on-main workflow`
- 项目类型：Harmony project shell + HAR library module + Demo HAP

## 目录结构

| 路径 | 作用 |
| --- | --- |
| `src/main/ets/` | SDK 源码源头 |
| `library/` | HAR library module，包含 `Index.ets`、`Index.d.ets`、`oh-package.json5`、README、changelog、LICENSE |
| `entry/` | Demo HAP，依赖本地 `library` |
| `scripts/sync-harmony-module.sh` | 将 `src/main/ets` 同步到 `library` |
| `scripts/ci/build-ohpm-har.sh` | OHPM 发布前构建 HAR 并写入版本 |
| `.github/workflows/publish-ohpm.yml` | 发布到鸿蒙中心仓库的 GitHub Actions |
| `docs-linhay/` / `memory/` | 旧项目自身文档与记忆 |

## 当前包元数据

`library/oh-package.json5`：

```json5
{
  "name": "neptune-sdk-harmony",
  "version": "1.0.6",
  "description": "NeptuneKit v2 Harmony SDK with local log export skeleton",
  "main": "Index.ets",
  "author": "NeptuneKit",
  "license": "Apache-2.0",
  "compatibleSdkVersion": 12,
  "dependencies": {
    "@cxy/webserver": "^2.0.2",
    "harmony-log": "^1.0.9"
  }
}
```

`entry/oh-package.json5`：

```json5
{
  "name": "neptune-sdk-harmony-demo",
  "version": "0.1.0",
  "description": "Harmony demo app for the Neptune SDK HAR module",
  "compatibleSdkVersion": 12,
  "dependencies": {
    "neptune-sdk-harmony": "file:../library"
  }
}
```

## 源码模块

| 模块 | 文件 | 当前能力 |
| --- | --- | --- |
| callback | `callback/*.ets` | `POST /v2/clients:register` 注册、本地 `/v2/client/command` command ack |
| core | `core/*.ets` | `LogQueue`、内存 store、RDB store、持久化队列 factory |
| discovery | `discovery/*.ets` | mDNS/manual DSN/gateway discovery HTTP 解析 |
| logging | `logging/NeptuneHarmonyLogger.ets` | `harmony-log` 封装与 metadata |
| model | `model/LogModels.ets` | log、source、export、ui-tree DTO |
| server | `server/ExportServer.ets` | 本地 HTTP export server |
| ui-tree | `ui-tree/ArkUIViewTreeCollector.ets` | ArkUI view tree / inspector snapshot 契约 |
| ws | `ws/*.ets` | NetworkKit WebSocket client 与 manager |
| index | `index.ets` | 公开 export 聚合 |

## 现有 HTTP / WebSocket 契约

本地 export server：

- `GET /v2/export/health`
- `GET /v2/export/metrics`
- `GET /v2/logs`
- `GET /v2/export/sources`
- `GET /v2/ui-tree/inspector`
- `GET /v2/ui-tree/snapshot`
- `POST /v2/client/command`

gateway/client：

- `GET /v2/gateway/discovery`
- `POST /v2/clients:register`
- `ws://<host>:<port>/v2/ws`
- WebSocket hello frame 使用 `{"type":"hello","role":"sdk"}`。

## 发布 workflow

`.github/workflows/publish-ohpm.yml`：

- workflow 名称：`Publish To OHPM`
- 触发：任意 tag、`workflow_dispatch`
- `workflow_dispatch` 参数：`version`、`dry_run`
- reusable workflow：`NeptuneKit/.github/.github/workflows/ohpm-publish.yml@main`
- build command：`bash scripts/ci/build-ohpm-har.sh <version>`
- HAR glob：`library/build/**/*.har`
- registry：`https://ohpm.openharmony.cn/ohpm/`
- 附带文件：`library/LICENSE`、`library/README.md`、`library/changelog.md`
- 依赖 secret：`OHPM_PRIVATE_KEY_PEM`、`OHPM_PUBLISH_ID`

## OHPM 包名约束

本机 OHPM schema 路径：

- `/Users/linhey/harmonyOS-command-line-tools/ohpm/resources/schemas/oh-package-json5-schema.json`
- `/Users/linhey/harmonyOS-command-line-tools/ohpm/lib/core/validator/OhPkgValidationConfig.json`
- `/Users/linhey/harmonyOS-command-line-tools/ohpm/lib/common/Regex.js`

结论：

1. `oh-package.json5.name` 的规则要求 group 和 package name 只能包含小写字母、数字、下划线和中划线。
2. `TritonKit` 含大写字母，不应作为实际 OHPM package id。
3. 用户已确认实际 package id 使用 `tritonkit`。
4. 品牌名、README 标题、中心展示文案仍可使用 `TritonKit`。

## 改名影响面

必须替换：

- `library/oh-package.json5`
- `entry/oh-package.json5`
- root `README.md`
- `library/README.md`
- `library/changelog.md`
- `scripts/verify-*.mjs`
- `scripts/demo-smoke.mjs`
- `scripts/start-demo-via-hdc.sh`
- `src/main/ets/logging/NeptuneHarmonyLogger.ets`
- `src/main/ets/logging/index.ets`
- `src/main/ets/ws/GatewayWsModels.ets`
- `src/main/ets/server/ExportServer.ets`
- `src/main/ets/core/RdbLogStore.ets`
- `src/main/ets/callback/GatewayClientCallbackManager.ets`
- `src/main/ets/discovery/GatewayDiscoveryMdnsProvider.ets`

需要策略决策：

1. 是否保留 `createNeptuneHarmonyLogger` alias。
2. 是否保留 `_neptune._tcp` mDNS service type 兼容。
3. 是否让 source `sdkName` 使用 display 值 `TritonKit`，还是稳定 id `tritonkit-harmony`。
4. 是否迁移旧 RDB 数据库名，还是新包直接使用新库名。
5. 是否保留旧 import path 的迁移说明。

## 与 TritonKit 对齐的缺口

已有能力可复用：

- logs/sources 可对应 TritonKit 的日志与来源采集。
- `/v2/client/command` 可作为 Harmony embedded command ingress 初始版本。
- `/v2/ui-tree/*` 可作为 Harmony snapshot / inspector 初始数据源。
- WebSocket client 可作为后续主动连接 gateway 的选项。

缺口：

- 缺少 TritonKit runtime manifest / capabilities。
- 缺少统一 redaction policy 与 payload limits。
- 缺少 runtime ledger 概念。
- command 当前主要支持 ping/ack，尚未形成 App 内语义动作集合。
- 现有 `/v2` 路由命名仍偏 Neptune gateway，需要映射到 TritonKit CLI/HTTP schema。

## 风险

1. **OHPM 包名大小写**：用户目标“中心仓库名 TritonKit”与 package id 规则冲突，需要区分展示名和实际依赖名。
2. **发布所有权**：真实 publish 需要 `OHPM_PRIVATE_KEY_PEM` 与 `OHPM_PUBLISH_ID`，迁移仓库后 secret 与 owner 需要重新配置。
3. **兼容策略**：hard rename 会让旧 import 直接失效；alias 会增加维护面。
4. **mDNS/serviceName 兼容**：改 `_neptune._tcp` 会影响旧 gateway discovery。
5. **主仓混杂风险**：TritonKit 当前有 iOS S0-S4 未提交改动，Harmony 迁移应在目标仓执行，不应把 ArkTS 源码塞进主仓。

## 建议

1. H0 已确认实际 OHPM package id：`tritonkit`。
2. 迁移实现放在 `harmony-TritonKit` 目标仓，TritonKit 主仓只保留规划、契约和接入文档。
3. 第一版优先 hard rename 文档和 package metadata；源码 API alias 是否保留单独决策。
4. 发布前必须跑 dry run，不在没有 secret 与 owner 确认时真实 publish。
5. H3 再补 TritonKit runtime manifest/capabilities/ledger，而不是在 H1 改名时一次性改大架构。
