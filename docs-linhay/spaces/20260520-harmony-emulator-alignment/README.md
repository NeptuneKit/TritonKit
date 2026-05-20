# 20260520 Harmony Emulator Alignment

## 背景

TritonKit 已经在 `20260520-simulator-takeover` 中定义了 Apple Simulator 的 host-side adapter 方向：通过 `triton` CLI/HTTP 统一模拟器发现、启动、App 生命周期、截图、日志、证据包和 `.tritonplan` 回放。

本 space 用来评估 TritonKit 是否可以把同一套 agent-facing 契约扩展到 HarmonyOS NEXT / DevEco Emulator。参考对象是项目内 `.agents/skills/harmony-next`，尤其是其 Emulator playbook 对 DevEco Emulator、HDC、uitest、aa、bm、hilog、hidumper 的能力和风险分级。

ai-phone 作为补充参考提供三端设备池视角：Harmony 不应只作为单个 HDC 命令集合接入，还应能进入 device registry、readiness、lock、command ledger 和 evidence summary，与 Apple Simulator host adapter 保持同构。

## 参考资料

- `.agents/skills/harmony-next/SKILL.md`
- `.agents/skills/harmony-next/references/ideGuides/DevEco模拟器私有接口与AI自动化.md`
- `docs-linhay/spaces/20260520-simulator-takeover/README.md`
- `docs-linhay/spaces/20260520-harmony-emulator-alignment/plans/20260520-technical-implementation-assessment.md`
- `.agents/skills/tritonkit-ops-governance/SKILL.md`
- ai-phone 参考：`docs-linhay/references/ai-phone.md`
- ai-phone device cloud：`docs-linhay/spaces/20260521-ai-phone-device-cloud/README.md`
- Harmony upstream issue: `https://github.com/linhay/harmony-next.skills/issues/10`
- Harmony scaffold upstream issue: `https://github.com/linhay/harmony-next.skills/issues/11`（已解决，`harmony-next` v1.3.7 起包含 Empty Ability scaffold）

## 目标

1. 判断 HarmonyOS Emulator 能否接入 TritonKit host-side adapter 模型。
2. 给出 TritonKit 对齐 HarmonyOS Emulator 的能力等级和不可承诺边界。
3. 保持 TritonKit 对 AI agent 的核心原则：CLI/HTTP 优先、JSON/JSONL 机器可读、稳定 error code、可审计 artifact、可进入 `.tritonplan`。
4. 不把 DevEco 私有接口误包装成稳定公开 API；版本、路径、端口、输出字段都必须探测后使用。
5. 长自动化模式不应被交互式人工确认打断；用户默认拥有完整执行权限，policy 只描述执行模式、产物目录和脱敏契约。

## 对齐结论

### 可以高度对齐

这些能力可以和 Apple Simulator host adapter 形成同构契约，底层从 `xcrun simctl` 换成 DevEco Emulator / `hdc` / 设备侧 shell：

1. **设备发现与选择**：`Emulator -list -details`、`hdc list targets -v` 可映射到 `triton device list/use --platform harmony --json`。
2. **启动状态探测**：`param get bootevent.boot.completed` 可映射到 `triton device wait-ready --jsonl`。
3. **App 包与 Ability 诊断**：`bm dump`、`aa dump` 可映射到 `triton app inspect --platform harmony --json`。
4. **App 启动**：`aa start -b <bundle> -a <ability>` 可映射到 `triton app launch --platform harmony --json`。
5. **UI 树只读探测**：`uitest dumpLayout` 可映射到 `triton ax --platform harmony --json` 或 `triton host ui snapshot --platform harmony --json`。
6. **UI 输入**：`uitest uiInput click/swipe/drag/keyEvent/text` 可映射到 `triton tap/swipe/press/type --platform harmony --json`。
7. **截图**：`uitest screenCap` + `hdc file recv` 可映射到 `triton screenshot --platform harmony --output <png> --json`。
8. **日志与诊断**：`hilog`、`hidumper` 可映射到 `triton logs` / `triton diagnose --platform harmony --jsonl`。
9. **证据包**：layout、screenshot、target 状态、日志摘要可进入 `.tritonevidence` manifest。
10. **计划回放**：发现 target、等待 boot、启动 App、输入、断言、截图可以进入 `.tritonplan`。

### 需要运行配置约束

这些能力可以做，但需要明确 target、artifactDir、脱敏策略、timeout、审计记录和版本探测，不能变成无界后台任务：

1. **启动或停止 DevEco Emulator**：需要 HVD 名称、路径、imageRoot、trace name 等版本敏感参数。
2. **安装、卸载、清数据**：涉及设备写入或破坏性操作，必须进入明确的自动化模式并记录 source command。
3. **真实 layout / 截图 / 日志归档**：可能包含业务文本、路径、账号或调试信息，必须提供 artifactDir 和脱敏策略。
4. **端口转发**：`fport/rport` 会改变本地网络状态，必须记录端口、目标和清理动作。
5. **性能与系统诊断**：`hitrace`、大范围 `hilog -x`、`hidumper` 深度指标只适合诊断模式。
6. **多 target 自动选择**：存在多个 `Connected` target 时不能默认选第一个，必须返回 `ambiguous_target` 和 candidates。

### 不应直接对齐

这些能力不适合作为 TritonKit 默认能力：

1. `hdc smode`、`target mount`、`flash`、`erase`、`format`、`sideload` 等系统级动作只能进入明确的 `break-glass` 模式，不进入默认回归链路。
2. 未提供 target、timeout、artifactDir 或审计记录的 HVD 创建、复制、删除、清理。
3. 未隔离验证的 DevEco 私有协议、trace pipe、IDE 内部端口或 CodeGenie 本地服务。
4. 没有 layout 坐标、截图辅助定位或明确坐标来源的桌面坐标盲点、`uinput` 底层注入。
5. 回显完整日志、完整 layout、设备文件或可能含 token/account/serial 的参数。

## 推荐产品形态

推荐把 HarmonyOS Emulator 作为 TritonKit 的第二个 host-side platform adapter：

```text
triton device list --platform harmony --json
triton device use --platform harmony --target 127.0.0.1:10100 --json
triton device wait-ready --platform harmony --target 127.0.0.1:10100 --jsonl
triton app inspect --platform harmony --bundle <bundleName> --json
triton app launch --platform harmony --bundle <bundleName> --ability <abilityName> --json
triton ax --platform harmony --json
triton tap "<text>" --platform harmony --json
triton screenshot --platform harmony --output <png> --json
triton logs tail --platform harmony --limit 100 --jsonl
triton capture --case <case> --platform harmony --output <dir.tritonevidence> --json
```

契约上和 Apple Simulator 对齐，底层 adapter 明确记录：

- `platform=harmony`
- `transport=hdc`
- `target=127.0.0.1:<port>`
- `toolVersions.emulator`
- `toolVersions.hdc`
- `sourceCommand`
- `riskLevel=readonly|evidence|automation|diagnostic|break-glass|unknown`
- `policy`
- `artifacts[]`
- `redactionStatus`

## Target 模型

建议把 target 模型扩展为跨平台结构：

- `sim:<udid>`：Apple Simulator。
- `sim:<udid>:app:<bundle-id>`：Apple Simulator App。
- `harmony:<target>`：HarmonyOS HDC target，如 `127.0.0.1:10100`。
- `harmony:<target>:app:<bundle-name>`：Harmony App。
- `runtime:<target-id>`：已接入 TritonKit embedded runtime 的 App 进程。
- `host:<workspace>`：当前 Mac host adapter session。

Harmony target 选择规则：

1. 只选择 `Connected` target，忽略 `Offline`。
2. 只有一个 `Connected` target 时可以自动选择，但返回结果必须写明选择来源。
3. 多个 `Connected` target 时返回 `ambiguous_target`，要求显式传 `--target`。
4. 所有命令必须设置超时，禁止无限日志流或后台进程悬挂。

## BDD 验收场景

### 场景一：agent 只读发现 Harmony Emulator 能力

- Given 当前机器可能安装 DevEco Studio
- When 执行 `triton device doctor --platform harmony --json`
- Then 输出 DevEco Emulator 路径探测结果、HDC 路径探测结果、版本摘要和可用能力
- And 不保存真实 UI、layout、日志正文或设备文件

### 场景二：agent 列出并选择 HDC target

- Given 当前存在一个或多个 HDC target
- When 执行 `triton device list --platform harmony --json`
- Then 输出 target 列表，包含 `target/state/transport/isConnected/source`
- And `Offline` target 不进入默认候选
- When 有多个 `Connected` target 且未指定 target
- Then 返回 `ambiguous_target` 和 candidates

### 场景三：agent 等待模拟器可操作

- Given 指定 target 为 `Connected`
- When 执行 `triton device wait-ready --platform harmony --target <target> --jsonl`
- Then 轮询 `bootevent.boot.completed`
- And 成功时输出 `ready=true`
- And 超时时停止后续 UI 操作，返回 `device_not_ready`

### 场景四：agent 启动 Harmony App

- Given 已知 `bundleName`，但未知 `abilityName`
- When 执行 `triton app inspect --platform harmony --bundle <bundleName> --json`
- Then 从 `bm dump -n` 摘要中返回候选 ability
- When 执行 `triton app launch --platform harmony --bundle <bundleName> --ability <abilityName> --json`
- Then 底层使用 `aa start`，返回启动 ack 和下一步验证建议

### 场景五：agent 读取 UI 树并执行输入

- Given target 已 ready 且 App 前台可见
- When 执行 `triton ax --platform harmony --json`
- Then 底层优先使用 `uitest dumpLayout`
- And 输出结构化节点、bounds、text、role 摘要
- When 执行 `triton tap "<text>" --platform harmony --json`
- Then 坐标来自 UI 树节点 bounds
- And 每次输入后重新探测状态

### 场景六：agent 采集截图和日志证据

- Given 本次运行 policy 为 `evidence` 或 `automation`
- And 已提供 artifactDir、脱敏策略和 timeout
- When 执行 `triton capture --case harmony-login --platform harmony --output <dir.tritonevidence> --json`
- Then 写出 screenshot、layout 摘要、target 状态和 hilog 摘要
- And manifest 标记 policy、riskLevel、敏感 artifact 与脱敏状态

### 场景七：agent 对客观配置缺失返回 blocked

- Given 请求需要真实 artifact 或长任务
- And 未提供 target、artifactDir、脱敏策略、timeout 或可审计命令记录
- When 执行对应 TritonKit 命令
- Then TritonKit 返回 machine-readable `blocked`
- And 输出 `missingConfig` 与 `requiredMode`

### 场景八：agent 标记系统级 break-glass 操作

- Given 用户目标明确要求系统级调试
- When 请求触发 `hdc flash`、`erase`、`format`、`smode` 或 `target mount`
- Then TritonKit 不做人工确认拦截
- And 输出 `riskLevel=break-glass`、source command、target、timeout 和审计摘要

## 分期建议

### P0：只读发现与安全边界

- 探测 DevEco Emulator / HDC 路径与版本。
- `device list/doctor/wait-ready --platform harmony`。
- `capabilities` 和 `schema` 暴露 Harmony adapter 能力。
- 错误码覆盖：`tool_not_found`、`ambiguous_target`、`target_offline`、`device_not_ready`、`blocked_missing_config`、`unsupported_tool_output`。

### P1：App 与 UI 基础回归

- `app inspect/launch --platform harmony`。
- `ax/find/tap/swipe/type/press --platform harmony`。
- UI 输入优先使用 `uitest uiInput`，禁止默认桌面坐标点击。
- `.tritonplan` 支持 Harmony step。

### P2：证据包与诊断

- `screenshot/capture/evidence --platform harmony`。
- `logs tail --platform harmony --jsonl`。
- `diagnose --platform harmony` 汇总 `hilog`、`hidumper` 裁剪摘要。
- artifact manifest 标记来源、敏感性、脱敏状态。

### P3：模拟器生命周期

- 通过 `automation` policy 支持启动/停止指定 HVD。
- 支持 HVD 参数探测和失败摘要。
- 不沉淀私有 trace pipe 协议为稳定产品契约。

## Harmony DEBUG-only 内置采集器

结论：Harmony P0/P1 不依赖内置采集器，host-side `hdc` / `uitest` adapter 仍是首选入口。内置采集器只作为中长期增强，用于在业务 App 主动集成 TritonKit 时提供更高质量的 App 内状态、ArkUI 语义树、路由、脱敏快照和截图元数据。

首期不新增不可编译的 Harmony 工程；先在 `TritonKitShared` 固化 JSON 契约，供后续 ArkTS/ArkUI runtime、CLI/HTTP schema 和 evidence/capture 复用。

硬边界：

1. 只允许 DEBUG 编译配置启用；Release 必须可编译但 `enabled=false`、不采集、不上传、不响应控制。
2. 默认 transport 为 `embedded-websocket`，platform 固定为 `harmony`，不能伪装成 host-side HDC 能力。
3. 首期只定义 manifest、configuration、snapshot 和 redaction 契约，不承诺 ArkTS 实现、自动注入或 DevEco 插件。
4. snapshot 只能携带已脱敏或可审计字段；截图正文默认不内联，只输出尺寸、格式、artifact 引用和脱敏状态。

### Collector BDD 验收场景

#### 场景九：DEBUG collector manifest 可被 agent 发现

- Given Harmony App 在 DEBUG 配置下集成 TritonKit collector
- When collector 暴露 manifest JSON
- Then `platform=harmony`
- And `transport=embedded-websocket`
- And `enabled=true`
- And capabilities 至少包含 `app-info`、`view-snapshot`、`accessibility`、`geometry`、`screenshot-metadata`

#### 场景十：Release collector 明确 no-op

- Given Harmony App 在 Release 配置下包含同一套 API surface
- When collector 暴露 manifest 或 configuration
- Then `enabled=false`
- And capabilities 为空
- And 不采集 UI、截图、日志或路由状态

#### 场景十一：snapshot 复用 TritonKit 共享观察模型

- Given DEBUG collector 已采集当前页面
- When 输出 snapshot JSON
- Then snapshot 包含 `app`、`page`、`geometry`、`accessibility`、`redactionStatus`
- And `accessibility` 复用 `TKAXNode`
- And `geometry` 复用 `TKGeometryResponse`
- And 自定义 ArkUI 状态只能放入 `extras` 的 JSON 值对象

#### 场景十二：截图只输出元数据和引用

- Given 本次采集包含截图
- When 输出 snapshot JSON
- Then screenshot 字段只包含 `format/width/height/scale/dataRef`
- And 不内联 base64 图片正文
- And `redactionStatus` 标明策略和被处理字段

## 与 Apple Simulator 接管的差异

1. Apple 首期可优先依赖公开 `xcrun simctl`；Harmony 需要把 DevEco Emulator 私有行为视为版本敏感能力。
2. Harmony UI 自动化更依赖设备侧 `uitest`，TritonKit 应把它视作 host-side platform adapter，而不是 embedded runtime。
3. Harmony target 使用 HDC target 字符串，不具备 Apple Simulator UDID 那样稳定的统一标识体验。
4. Harmony 截图、layout、日志更容易直接触碰真实业务内容，默认只读探测不应保存 artifact。
5. Harmony 高风险命令更多，必须内建风险分级；但风险分级不等于授权 gate。

## 完成定义

1. 本 space 明确 TritonKit 对齐 HarmonyOS Emulator 的可做、运行配置约束和 break-glass 边界。
2. 后续实现前，先补 `schema/capabilities` 和 adapter-level 测试，再实现底层命令。
3. 任一真实设备或模拟器操作都必须输出 JSON/JSONL，并有稳定 error code。
4. 真实截图、layout、日志和文件收集必须进入可审计 policy，并带 artifactDir 与脱敏状态。
5. 若后续进入实现，需要新增或扩展项目级 skill，指导 Harmony adapter 的安全使用和回归验收。

## 2026-05-20 执行记录

本轮已完成 P0 的最小实现闭环：

1. Host Adapter Core 从 `requiresConfirmation` 改为 `riskLevel`、`requiredConfig`、`TKHostExecutionPolicy` 和 `sourceCommand`。
2. Host runner 不再硬编码 `/usr/bin/xcrun`，支持自定义 executable、timeout、stdout/stderr 截断标记和 source command。
3. 新增 Harmony HDC P0 模型与 parser：`TKHarmonyHDCCommand`、`TKHarmonyTarget`、`TKHdcTargetListParser`、`TKHarmonyBootCompletedParser`。
4. 新增 CLI：`triton device doctor/list/use/wait-ready --platform harmony`。
5. `triton schema --command device --json` 和 `triton capabilities --json` 已暴露 Harmony P0 能力。
6. `TKEvidenceArtifact` 增加可选 `platform/riskLevel/policy/redactionStatus/sourceCommand/target` 字段，保持旧 manifest 兼容。
7. fake HDC smoke 脚本固定在 `fake-hdc-smoke.sh`，用于无 DevEco 环境下验证 target list、ambiguous target 和 wait-ready。

已验证：

- `swift test`：58 个测试通过。
- `.build/debug/triton device doctor --platform harmony --hdc docs-linhay/spaces/20260520-harmony-emulator-alignment/fake-hdc-smoke.sh --json`
- `.build/debug/triton device list --platform harmony --hdc docs-linhay/spaces/20260520-harmony-emulator-alignment/fake-hdc-smoke.sh --json`
- `.build/debug/triton device use --platform harmony --hdc docs-linhay/spaces/20260520-harmony-emulator-alignment/fake-hdc-smoke.sh --json` 返回 `ambiguous_target`。
- `.build/debug/triton device wait-ready --platform harmony --target 127.0.0.1:10100 --hdc docs-linhay/spaces/20260520-harmony-emulator-alignment/fake-hdc-smoke.sh --timeout 2 --json`
- `.build/debug/triton schema --command device --json`
- `.build/debug/triton capabilities --json` 包含 `host-device` 与 Harmony P0 capabilities。

未做真实 DevEco / Harmony Emulator 验证；P0 当前只承诺契约、parser、fake HDC smoke 和可配置 host runner，真实设备操作仍需本机 DevEco 环境后单独执行。

补充反馈：`harmony-next.skills` 曾只提供 DevEco 新工程向导文档、`module.json5` 参考和 Emulator/HDC 自动化 playbook，缺少可直接复制的 HarmonyOS NEXT 最小测试工程 scaffold。上游 issue `https://github.com/linhay/harmony-next.skills/issues/11` 已解决，本地 `harmony-next` skill `v1.3.7` 已包含 `references/quickStart/ets/minimal-project-scaffold.md` 和 `references/templates/empty-ability-app/`。后续需要创建 Harmony fixture 时，优先复制该模板，不再从本机其他工程拼凑配置。

2026-05-21 继续执行：已基于 `harmony-next` Empty Ability scaffold 新增 `fixtures/harmony-collector-smoke/`，作为 TritonKit Harmony DEBUG-only collector 的最小测试工程。该 fixture 固定 bundleName `com.neptunekit.tritonkit.collectorsmoke`，页面暴露 `Triton Collector Ready`、`collector-debug-manifest`、`collector-capabilities`、`collector-release-noop`、`collector-snapshot-metadata`、`smoke-increment` 等稳定 `uitest dumpLayout` 信号。

已验证：

- `fixtures/harmony-collector-smoke/verify-local.sh` 通过。
- `ohpm install` 通过。
- `hvigorw --mode module -p module=entry@default assembleHap` 通过，生成 `entry/build/default/outputs/default/entry-default-unsigned.hap`。
- 启动 `Codex Test Phone` HVD 后，HDC target `127.0.0.1:10100` 进入 `TCP/Connected` 且 `bootevent.boot.completed=true`。
- `hdc install entry-default-unsigned.hap` 成功。
- `hdc shell aa start -b com.neptunekit.tritonkit.collectorsmoke -a EntryAbility` 成功。
- `uitest dumpLayout` 验证页面包含 `Triton Collector Ready`、`harmony|embedded-websocket|enabled=true`、`app-info,view-snapshot,accessibility,geometry,screenshot-metadata`、`releaseEnabled=false|capabilities=0|screenshots=false`、`com.neptunekit.tritonkit.collectorsmoke|EntryAbility|/collector-smoke|png|dataRef=artifacts/harmony-collector-smoke.png`。
- 点击 `smoke-increment` 后，`uitest dumpLayout` 验证 `Triton Collector Tapped` 与 `tapCount=1`。
- 截图和 layout 已归档到 `screenshots/20260521/harmony/`：
  - `20260521-harmony-collector-layout-before-v01.json`
  - `20260521-harmony-collector-screen-before-v01.png`
  - `20260521-harmony-collector-layout-after-v01.json`
  - `20260521-harmony-collector-screen-after-v01.png`
- 真实 smoke 暴露并修复了 `TKHdcTargetListParser` 问题：`hdc list targets -v` 输出为 `target TCP Connected localhost` 时，旧 parser 把 `TCP` 当成 state，导致 `triton device wait-ready` 误报 `target_offline`；现已兼容 verbose transport/state 列。

2026-05-21 第二轮真实 smoke 复测：

- `fixtures/harmony-collector-smoke/verify-local.sh` 通过，HAP 产物保持稳定。
- `hdc list targets -v` 返回 `127.0.0.1:10100 TCP Connected localhost`。
- 重新安装 `entry-default-unsigned.hap` 并通过 `aa start` 启动 `EntryAbility`。
- before layout 验证 `Triton Collector Ready`、`tapCount=0`、DEBUG manifest、capabilities、Release no-op 和 snapshot metadata。
- 以 `smoke-increment` 节点 bounds `[368,2017][940,2157]` 的中心点 `654,2087` 执行 `uitest uiInput click`，after layout 验证 `Triton Collector Tapped` 与 `tapCount=1`。
- `.build/debug/triton device wait-ready --platform harmony --target 127.0.0.1:10100 --timeout 10 --json` 返回 `ready=true`，target 解析为 `transport=TCP`、`state=Connected`。
- 第二轮证据已归档：
  - `20260521-harmony-collector-layout-before-v02.json`
  - `20260521-harmony-collector-screen-before-v02.png`
  - `20260521-harmony-collector-layout-after-v02.json`
  - `20260521-harmony-collector-screen-after-v02.png`
