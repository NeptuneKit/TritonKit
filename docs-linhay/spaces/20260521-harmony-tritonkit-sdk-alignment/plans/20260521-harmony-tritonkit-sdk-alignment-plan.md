# 20260521 Harmony TritonKit SDK Alignment Plan

## 推荐方案

采用“先吸收并改名，后对齐 TritonKit embedded 契约”的两段式迁移。

第一段只处理 Harmony SDK 仓库自身：仓库名、OHPM package id、README、demo、源码 namespace、验证脚本、发布 workflow 和 dry run。第二段再把它纳入 TritonKit 多端 embedded runtime 体系：manifest、capabilities、view tree/snapshot、command callback、ledger、logs/sources 与 CLI/HTTP schema 对齐。

原因：`neptune-sdk-harmony` 已经具备 HAR 与发布链路，直接重写成本高且容易丢失 OHPM 发布经验；但它当前语义仍是 Neptune 日志导出 SDK，需要通过契约层逐步变成 TritonKit Harmony embedded SDK。

## 执行表

| 阶段 | 目标 | 具体动作 | 技术调研前置 | 验收标准 |
| --- | --- | --- | --- | --- |
| H0 命名可行性 | 确认 `harmony-TritonKit` / `TritonKit` / `tritonkit` 的分工 | 检查 OHPM schema、发布 workflow、中心仓库命名规则；固定实际 `oh-package.json5.name` 为 `tritonkit` | `technical-research-neptune-sdk-harmony-inventory-v01.md` | GitHub repo 名为 `harmony-TritonKit`，品牌/展示名为 `TritonKit`，实际 package id 和 import path 为 `tritonkit` |
| H1 元数据改名 | 不改行为，先完成包身份替换 | 改 `library/oh-package.json5`、`entry/oh-package.json5`、root README、`library/README.md`、changelog、license 包装、workflow 标题/说明 | H0 结论 | `rg Neptune|neptune` 只剩历史说明或 deprecated alias；新安装示例可复制 |
| H2 源码 namespace | 把公开 API 与内部 identity 从 Neptune 迁到 TritonKit | `NeptuneHarmonyLogger` 改名；`createNeptuneHarmonyLogger` 改名；logger tag、serviceName、databaseName、mDNS type、`DEFAULT_GATEWAY_WS_APP_ID`、source `sdkName` 改名 | API 兼容策略调研 | ArkTS export index、类型声明、验证脚本全部通过；旧 API 是否保留有明确 deprecated 策略 |
| H3 Embedded 契约 | 对齐 TritonKit 的 AI-facing SDK 能力模型 | 增加/映射 manifest、capabilities、runtime limits、redaction、snapshot、command ack、ledger；保留 `/v2/export/*` 作为日志/sources 能力 | TritonKit iOS S0-S4 DTO 与 Harmony 现有模型对比 | host/CLI 能以同一概念理解 iOS 与 Harmony embedded runtime；unsupported reason 稳定 |
| H4 发布 dry run | 保留鸿蒙中心仓库发布能力 | 更新 `.github/workflows/publish-ohpm.yml`；验证 `scripts/ci/build-ohpm-har.sh <version>`；确认 license/readme/changelog 进入 HAR | OHPM 证书/secret 边界调研 | GitHub workflow_dispatch dry run 可生成 HAR；无 secret 时不执行真实 publish |
| H5 Demo smoke | 证明业务 App 接入路径可运行 | 更新 `entry` demo 依赖、bundleName 文档、UI 文案、启动脚本、demo smoke 数据 | DevEco/ohpm/hvigor 本机工具链可用性调研 | `ohpm install --all`、HAR build、demo HAP build 或脚本级 contract smoke 通过 |
| H6 TritonKit 同步 | 主项目知道 Harmony SDK 的新边界 | 更新 TritonKit README、public skills、dev 文档、memory；必要时新增 release checklist | H0-H5 结果稳定 | 用户和外部 agent 能按新文档接入 Harmony SDK；qmd 可检索 |

## 技术调研执行表

| 序号 | 调研主题 | 关键问题 | 产物 | 通过条件 | 后续实现切片 |
| --- | --- | --- | --- | --- | --- |
| 1 | Neptune Harmony 仓库盘点 | 现有模块、源码、发布 workflow、验证脚本、能力边界是什么？ | `technical-research-neptune-sdk-harmony-inventory-v01.md` | 列出文件入口、当前 API、发布链路、改名影响面 | H1/H2 |
| 2 | OHPM 命名规则 | `TritonKit` 大写能否作为 `oh-package.json5.name`？中心展示名和 package id 是否可分离？ | 更新 H0 章节 | 有 schema/validator 证据；确认实际 package id 采用 `tritonkit` | H0 |
| 3 | 兼容策略 | 是否保留 `neptune-sdk-harmony` import 或 Neptune API alias？保留多久？ | `technical-research-harmony-api-compatibility-v01.md` | 明确 hard rename / deprecated alias / 双包过渡三选一 | H2 |
| 4 | TritonKit 契约映射 | iOS manifest/snapshot/ledger 与 Harmony logs/sources/ui-tree/command 如何对齐？ | `technical-research-harmony-tritonkit-contract-mapping-v01.md` | 产出 DTO/route/CLI 概念映射表 | H3 |
| 5 | OHPM 发布链路 | workflow、secret、dry run、HAR 内容、registry 是否满足发布要求？ | `technical-research-harmony-ohpm-publish-v01.md` | dry run 和真实 publish 的门禁、secret、失败回滚路径清晰 | H4 |
| 6 | Demo 与真实接入 | Demo App 如何证明新包名、import path、服务启动和导出 API 可用？ | `technical-research-harmony-demo-smoke-v01.md` | 可复跑 smoke 命令和预期输出明确 | H5 |

## 关键决策

1. **实际 OHPM package id 固定为 `tritonkit`**：本机 OHPM schema 要求小写包名；品牌和展示名使用 `TritonKit`。
2. **仓库名按用户目标走 `harmony-TritonKit`**：GitHub 仓库名不受 OHPM package id 小写规则约束。
3. **首期不做双仓同步**：迁移应该在目标 Harmony SDK 仓库完成，不把 Harmony ArkTS 源码复制进 TritonKit 主仓。
4. **host-side 与 embedded 分层**：HDC、uitest、DevEco Emulator、安装启动、截图等仍是 host-side adapter；HAR 内只承诺 App 进程内 SDK 能力。
5. **发布先 dry run**：没有用户明确授权和 secret 校验前，不执行真实 `ohpm publish`。

## 改名影响面

| 区域 | 当前值 | 目标建议 | 说明 |
| --- | --- | --- | --- |
| GitHub repo | `neptune-sdk-harmony` | `harmony-TritonKit` | 用户指定 |
| OHPM package id | `neptune-sdk-harmony` | `tritonkit` | 用户确认，且满足小写规则 |
| 品牌/展示名 | `NeptuneKit Harmony SDK` | `TritonKit Harmony SDK` | 文档和中心展示可用 |
| import path | `neptune-sdk-harmony` | `tritonkit` | ArkTS 示例统一替换 |
| demo package | `neptune-sdk-harmony-demo` | `tritonkit-harmony-demo` | 保持小写 |
| bundleName 示例 | `io.github.neptune.sdk.harmony` | `io.github.tritonkit.sdk.harmony` 或组织约定 | Demo 专用 |
| logger helper | `NeptuneHarmonyLogger` | `TritonKitHarmonyLogger` | 需处理 alias |
| source sdkName | `neptune-sdk-harmony` | `TritonKit` 或 `tritonkit-harmony` | 建议 display 和 id 分开 |
| databaseName | `neptune_sdk_harmony_logs.db` | `tritonkit_harmony_logs.db` | 避免新旧数据混淆 |
| serviceName | `neptune-sdk-harmony-export` | `tritonkit-harmony-export` | discovery/metrics 可读 |
| mDNS type | `_neptune._tcp` | `_tritonkit._tcp` | 可能影响兼容 |

## 最小落地切片

第一轮只做 H0-H1-H4 的规划验证，不直接碰源码：

1. 明确 OHPM package id 小写约束，并固定为 `tritonkit`。
2. 输出 Neptune Harmony 仓库盘点。
3. 输出迁移执行表和验收标准。
4. 验证现有发布 workflow 的 dry-run 入口和 build 命令。
5. 记录 memory 和 qmd。

第二轮如果用户确认“直接做”，再进入目标仓库实施 H1-H2，并优先跑脚本级验证。

### 首轮施工结果

用户确认开始施工后，已在 `/Users/linhey/Desktop/linhay-open-sources/harmony-tritonkit` 执行首轮改名与发布链路验证：

| 项目 | 状态 | 说明 |
| --- | --- | --- |
| H0 命名 | 完成 | GitHub 目录使用 `harmony-tritonkit`，OHPM package id 与 import path 使用 `tritonkit`，品牌展示使用 `TritonKit` |
| H1 元数据改名 | 完成 | `library/oh-package.json5` 改为 `"name": "tritonkit"`；`entry/oh-package.json5` 改为依赖 `"tritonkit": "file:../library"` |
| H2 源码 namespace 改名 | 部分完成 | logging helper 已改为 `TritonKitHarmony*`；其余领域类型如 `Gateway*`、`LogQueue`、`ExportServer` 保持语义名不变 |
| H3 Embedded 契约 | 基本完成 | 已新增 `/v2/runtime/manifest`、`/v2/runtime/snapshot`、`/v2/runtime/ledger`、`/v2/runtime/state/*`、`/v2/runtime/action`；capabilities 对齐 iOS raw value；无法由 HAR 通用实现的能力返回 `unsupported_runtime_scope` |
| H6 App Provider | 部分完成 | 已新增 scene/route/responder/action provider hook；App 可主动把业务状态和语义动作结果交给 embedded SDK；network breadcrumbs 等 opt-in 业务打点未展开 |
| H4 HAR dry-run build | 完成 | 使用 DevEco 自带 `ohpm 6.0.1` 和 hvigor 成功生成 `library/build/default/outputs/default/library.har` |
| H5 Demo smoke | 部分完成 | 脚本级 demo smoke 通过；未安装到 Harmony 模拟器做 HAP 实机 smoke |
| H6 TritonKit CLI direct runtime | 完成首片 | 主仓新增 `TKEmbeddedRuntimeHTTPRoute`、`--runtime-base-url` 和 `triton device runtime-url --platform harmony`；CLI 可准备 HDC fport 并直接访问 Harmony SDK `/v2/runtime/manifest`、`state/*`、`snapshot`、`ledger`、`action`；mock smoke 已覆盖 schema、fake HDC 和 secure semantic action |

剩余工作：

1. 决定是否改 GitHub remote / 创建真实 `NeptuneKit/harmony-tritonkit` 仓库。
2. 处理 `.github/workflows/publish-ohpm.yml` 中 reusable workflow owner 与真实 publish secret。
3. 继续 H6：补 provider 示例、network breadcrumbs opt-in 打点约定，以及真实 App 接入 smoke。
4. 继续 Host-side：把 Harmony runtime loop 契约接入真实 HAP / DevEco Emulator，补 hdc port-forward / target discovery 后的端到端 smoke。
5. 若要跑 HAP Demo 实机 smoke，需要确认签名 profile 与 `AppScope.app.bundleName=io.github.tritonkit.sdk.harmony` 匹配。

## 验证命令

规划阶段：

```bash
docs-linhay/scripts/check-docs.sh
docs-linhay/scripts/qmd-sync.sh
```

目标 Harmony SDK 仓实现阶段：

```bash
node scripts/verify-runtime-manifest-contract.mjs
node scripts/verify-runtime-loop-contract.mjs
node scripts/verify-runtime-provider-contract.mjs
node scripts/verify-harmony-log-integration.mjs
node scripts/verify-client-callback-contract.mjs
node scripts/verify-gateway-discovery.mjs
node scripts/verify-gateway-ws-contract.mjs
node scripts/verify-ui-tree-contract.mjs
node scripts/demo-smoke.mjs
ohpm install --all
./hvigorw --mode module -p module=library assembleHar --no-daemon
bash scripts/ci/build-ohpm-har.sh 0.0.0-dryrun
```

若本机 `ohpm` 缺依赖或 DevEco SDK 不完整，至少先跑 Node contract verifiers，并在交付说明中明确 HAR build 未验证原因。

TritonKit 主仓 direct runtime smoke：

```bash
swift test --filter TKHostAdapterModelsTests/embeddedRuntimeHTTPRoutes
swift build --package-path CLI --scratch-path .build/cli --product triton
TRITON_BIN=.build/cli/debug/triton docs-linhay/scripts/verify-harmony-runtime-base-url-smoke.sh
```
